//
//  SpectrumRenderer.swift
//  VoxExtension
//
//  Metal-accelerated FFT spectrum renderer.
//  Drains AtomicScopeBuffer each frame, computes FFT via Accelerate/vDSP,
//  then draws frequency bins as filled bars with F1/F2 formant markers.
//

import Metal
import MetalKit
import Accelerate
import Synchronization

/// Metal renderer for real-time formant spectrum display.
/// FFT is computed on the display thread (NOT audio thread) after draining the ring buffer.
@available(macOS 15.0, *)
public final class SpectrumRenderer: NSObject, MTKViewDelegate {
    
    // MARK: - Metal State
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let spectrumPipeline: MTLRenderPipelineState
    private let markerPipeline: MTLRenderPipelineState
    
    // MARK: - FFT Configuration
    
    /// FFT size (must be power of 2).
    public static let fftSize: Int = 2048
    
    /// Number of displayable bins (fftSize / 2).
    public static let binCount: Int = fftSize / 2
    
    /// Log2 of FFT size for vDSP.
    private let log2n: vDSP_Length
    
    /// vDSP FFT setup (reused each frame).
    private let fftSetup: FFTSetup
    
    // MARK: - FFT Buffers (display thread only)
    
    /// Staging buffer to drain ring buffer into.
    private var timeDomainBuffer: [Float]
    
    /// Hann window for FFT.
    private let window: [Float]
    
    /// Windowed samples.
    private var windowedSamples: [Float]
    
    /// Split complex for vDSP FFT.
    private var splitReal: [Float]
    private var splitImag: [Float]
    
    /// Magnitude spectrum (normalized 0..1).
    private var magnitudes: [Float]
    
    /// Smoothed magnitudes for display (exponential moving average).
    private var smoothedMagnitudes: [Float]
    
    /// Smoothing factor (0 = no smoothing, 1 = frozen).
    private let smoothingFactor: Float = 0.7
    
    // MARK: - Triple Buffering
    
    private let maxBins: Int
    private let magnitudeBuffers: [MTLBuffer]
    private let uniformBuffers: [MTLBuffer]
    private var currentBufferIndex: Int = 0
    private let inflightSemaphore = DispatchSemaphore(value: 3)
    
    // MARK: - Data Source & Parameters
    
    /// Ring buffer to drain audio samples from.
    public var scopeBuffer: AtomicScopeBuffer<Float>?
    
    /// Sample rate (needed to map bins to frequencies).
    public var sampleRate: Float = 44100.0
    
    /// Formant 1 frequency in Hz (for marker display).
    public var f1Frequency: Float = 0.0
    
    /// Formant 2 frequency in Hz (for marker display).
    public var f2Frequency: Float = 0.0
    
    /// Uniform struct matching the shader.
    private struct SpectrumUniforms {
        var binCount: Float
        var maxFrequency: Float
        var f1Frequency: Float
        var f2Frequency: Float
    }
    
    // MARK: - Init
    
    public init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        let fftSize = Self.fftSize
        let binCount = Self.binCount
        self.maxBins = binCount
        
        // FFT setup
        let log2n = vDSP_Length(log2(Double(fftSize)))
        self.log2n = log2n
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        self.fftSetup = setup
        
        // Allocate FFT buffers
        self.timeDomainBuffer = [Float](repeating: 0, count: fftSize)
        self.windowedSamples = [Float](repeating: 0, count: fftSize)
        self.splitReal = [Float](repeating: 0, count: binCount)
        self.splitImag = [Float](repeating: 0, count: binCount)
        self.magnitudes = [Float](repeating: 0, count: binCount)
        self.smoothedMagnitudes = [Float](repeating: 0, count: binCount)
        
        // Create Hann window
        var win = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&win, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = win
        
        // Triple-buffered Metal buffers
        var magBuffers: [MTLBuffer] = []
        var uniBuffers: [MTLBuffer] = []
        for _ in 0..<3 {
            guard let mb = device.makeBuffer(length: MemoryLayout<Float>.stride * binCount, options: .storageModeShared),
                  let ub = device.makeBuffer(length: MemoryLayout<SpectrumUniforms>.stride, options: .storageModeShared)
            else { return nil }
            magBuffers.append(mb)
            uniBuffers.append(ub)
        }
        self.magnitudeBuffers = magBuffers
        self.uniformBuffers = uniBuffers
        
        // Load shaders
        guard let library = device.makeDefaultLibrary(),
              let specVert = library.makeFunction(name: "spectrum_vertex"),
              let specFrag = library.makeFunction(name: "spectrum_fragment"),
              let markVert = library.makeFunction(name: "marker_vertex"),
              let markFrag = library.makeFunction(name: "marker_fragment")
        else { return nil }
        
        // Spectrum pipeline
        let specDesc = MTLRenderPipelineDescriptor()
        specDesc.vertexFunction = specVert
        specDesc.fragmentFunction = specFrag
        specDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        specDesc.colorAttachments[0].isBlendingEnabled = true
        specDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        specDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        // Marker pipeline
        let markDesc = MTLRenderPipelineDescriptor()
        markDesc.vertexFunction = markVert
        markDesc.fragmentFunction = markFrag
        markDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        markDesc.colorAttachments[0].isBlendingEnabled = true
        markDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        markDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            self.spectrumPipeline = try device.makeRenderPipelineState(descriptor: specDesc)
            self.markerPipeline = try device.makeRenderPipelineState(descriptor: markDesc)
        } catch {
            print("SpectrumRenderer: Failed to create pipeline: \(error)")
            return nil
        }
        
        super.init()
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    // MARK: - FFT Computation (display thread only)
    
    /// Perform FFT on the time-domain buffer and produce normalized magnitudes.
    /// Called each frame on the render thread.
    private func computeFFT() {
        let n = Self.fftSize
        let halfN = Self.binCount
        
        // Apply Hann window
        vDSP_vmul(timeDomainBuffer, 1, window, 1, &windowedSamples, 1, vDSP_Length(n))
        
        // Pack into split complex format
        windowedSamples.withUnsafeBufferPointer { src in
            var splitComplex = DSPSplitComplex(
                realp: UnsafeMutablePointer(mutating: splitReal),
                imagp: UnsafeMutablePointer(mutating: splitImag)
            )
            // Use a mutable copy for the pointers
            splitReal.withUnsafeMutableBufferPointer { realBuf in
                splitImag.withUnsafeMutableBufferPointer { imagBuf in
                    var sc = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                    src.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &sc, 1, vDSP_Length(halfN))
                    }
                    // Forward FFT
                    vDSP_fft_zrip(fftSetup, &sc, 1, log2n, FFTDirection(kFFTDirection_Forward))
                    
                    // Compute magnitudes (squared, then sqrt for linear magnitude)
                    var mags = [Float](repeating: 0, count: halfN)
                    vDSP_zvabs(&sc, 1, &mags, 1, vDSP_Length(halfN))
                    
                    // Normalize: scale by 2/N
                    var scale: Float = 2.0 / Float(n)
                    vDSP_vsmul(mags, 1, &scale, &mags, 1, vDSP_Length(halfN))
                    
                    // Convert to dB, then normalize to 0..1 range
                    // dB = 20 * log10(magnitude), map -80dB..0dB to 0..1
                    for i in 0..<halfN {
                        let db = 20.0 * log10(max(mags[i], 1e-10))
                        let normalized = max(0, min(1, (db + 80.0) / 80.0))
                        
                        // Exponential smoothing
                        smoothedMagnitudes[i] = smoothingFactor * smoothedMagnitudes[i] + (1 - smoothingFactor) * normalized
                    }
                    
                    magnitudes = smoothedMagnitudes
                }
            }
        }
    }
    
    // MARK: - MTKViewDelegate
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        _ = inflightSemaphore.wait(timeout: .now() + 0.016)
        
        let bufIdx = currentBufferIndex
        currentBufferIndex = (currentBufferIndex + 1) % 3
        
        // Drain ring buffer into time-domain buffer
        if let ringBuffer = scopeBuffer {
            let fftSize = Self.fftSize
            let dest = UnsafeMutablePointer<Float>.allocate(capacity: fftSize)
            defer { dest.deallocate() }
            
            let drained = ringBuffer.drainInto(dest, maxCount: fftSize)
            if drained > 0 {
                // If we got fewer than fftSize samples, zero-pad
                if drained < fftSize {
                    // Shift existing data and prepend new
                    let shift = fftSize - drained
                    for i in 0..<shift {
                        timeDomainBuffer[i] = timeDomainBuffer[i + drained]
                    }
                    for i in 0..<drained {
                        timeDomainBuffer[shift + i] = dest[i]
                    }
                } else {
                    for i in 0..<fftSize {
                        timeDomainBuffer[i] = dest[i]
                    }
                }
                
                computeFFT()
            }
        }
        
        // Copy magnitudes to Metal buffer
        let magBuffer = magnitudeBuffers[bufIdx]
        let magPtr = magBuffer.contents().assumingMemoryBound(to: Float.self)
        magnitudes.withUnsafeBufferPointer { src in
            magPtr.update(from: src.baseAddress!, count: min(magnitudes.count, maxBins))
        }
        
        // Update uniforms
        let uniPtr = uniformBuffers[bufIdx].contents().assumingMemoryBound(to: SpectrumUniforms.self)
        uniPtr.pointee = SpectrumUniforms(
            binCount: Float(maxBins),
            maxFrequency: sampleRate / 2.0,
            f1Frequency: f1Frequency,
            f2Frequency: f2Frequency
        )
        
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            inflightSemaphore.signal()
            return
        }
        
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        descriptor.colorAttachments[0].loadAction = .clear
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            inflightSemaphore.signal()
            return
        }
        
        // Draw spectrum bars
        encoder.setRenderPipelineState(spectrumPipeline)
        encoder.setVertexBuffer(magBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffers[bufIdx], offset: 0, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: maxBins * 6)
        
        // Draw F1/F2 markers (if frequencies are set)
        if f1Frequency > 0 || f2Frequency > 0 {
            encoder.setRenderPipelineState(markerPipeline)
            encoder.setVertexBuffer(uniformBuffers[bufIdx], offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 12) // 2 lines × 6 verts
        }
        
        encoder.endEncoding()
        
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.inflightSemaphore.signal()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
