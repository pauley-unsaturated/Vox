//
//  ScopeRenderer.swift
//  VoxExtension
//
//  Metal-accelerated oscilloscope renderer.
//  Drains AtomicScopeBuffer each frame into a triple-buffered MTLBuffer,
//  then draws as a line strip.
//

import Metal
import MetalKit
import Synchronization

/// Metal renderer for real-time oscilloscope display.
/// Triple-buffered for smooth, tear-free rendering on Apple Silicon unified memory.
@available(macOS 15.0, *)
public final class ScopeRenderer: NSObject, MTKViewDelegate {
    
    // MARK: - Metal State
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    
    // MARK: - Triple Buffering
    
    /// Maximum samples per frame.
    private let maxSamples: Int = 4096
    
    /// Triple-buffered sample data — .storageModeShared for zero-copy on Apple Silicon.
    private let sampleBuffers: [MTLBuffer]
    
    /// Uniform buffers (one per flight).
    private let uniformBuffers: [MTLBuffer]
    
    /// Current buffer index (0, 1, 2).
    private var currentBufferIndex: Int = 0
    
    /// Semaphore for triple-buffer synchronization.
    private let inflightSemaphore = DispatchSemaphore(value: 3)
    
    /// Number of valid samples in the current frame.
    private var currentSampleCount: Int = 0
    
    // MARK: - Data Source
    
    /// Ring buffer to drain samples from (set by owner).
    public var scopeBuffer: AtomicScopeBuffer<Float>?
    
    /// Uniform struct matching the shader.
    private struct ScopeUniforms {
        var sampleCount: Float
        var lineWidth: Float
    }
    
    // MARK: - Init
    
    /// Initialize with a Metal device. Returns nil if pipeline creation fails.
    public init?(device: MTLDevice) {
        self.device = device
        
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        // Create triple-buffered sample buffers (.storageModeShared for unified memory)
        var buffers: [MTLBuffer] = []
        var uniforms: [MTLBuffer] = []
        for _ in 0..<3 {
            guard let buf = device.makeBuffer(
                length: MemoryLayout<Float>.stride * 4096,
                options: .storageModeShared
            ) else { return nil }
            buffers.append(buf)
            
            guard let ubuf = device.makeBuffer(
                length: MemoryLayout<ScopeUniforms>.stride,
                options: .storageModeShared
            ) else { return nil }
            uniforms.append(ubuf)
        }
        self.sampleBuffers = buffers
        self.uniformBuffers = uniforms
        
        // Load shaders and create pipeline
        guard let library = device.makeDefaultLibrary(),
              let vertexFunc = library.makeFunction(name: "scope_vertex"),
              let fragmentFunc = library.makeFunction(name: "scope_fragment")
        else { return nil }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Enable alpha blending
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("ScopeRenderer: Failed to create pipeline state: \(error)")
            return nil
        }
        
        super.init()
    }
    
    // MARK: - MTKViewDelegate
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No-op: shaders normalize to clip space
    }
    
    public func draw(in view: MTKView) {
        _ = inflightSemaphore.wait(timeout: .now() + 0.016) // ~1 frame timeout
        
        let bufferIndex = currentBufferIndex
        currentBufferIndex = (currentBufferIndex + 1) % 3
        
        // Drain ring buffer into current Metal buffer
        let sampleBuffer = sampleBuffers[bufferIndex]
        let destPtr = sampleBuffer.contents().assumingMemoryBound(to: Float.self)
        
        var sampleCount = 0
        if let ringBuffer = scopeBuffer {
            sampleCount = ringBuffer.drainInto(destPtr, maxCount: maxSamples)
        }
        
        // If no new data, keep previous frame's data visible (don't clear)
        guard sampleCount >= 2 else {
            inflightSemaphore.signal()
            return
        }
        
        // Update uniforms
        let uniformPtr = uniformBuffers[bufferIndex].contents()
            .assumingMemoryBound(to: ScopeUniforms.self)
        uniformPtr.pointee = ScopeUniforms(
            sampleCount: Float(sampleCount),
            lineWidth: 1.0
        )
        
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            inflightSemaphore.signal()
            return
        }
        
        // Dark background
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0
        )
        descriptor.colorAttachments[0].loadAction = .clear
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            inflightSemaphore.signal()
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(sampleBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffers[bufferIndex], offset: 0, index: 1)
        encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: sampleCount)
        encoder.endEncoding()
        
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.inflightSemaphore.signal()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
