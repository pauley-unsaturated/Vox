//
//  DriftTimelineRenderer.swift
//  VoxExtension
//
//  Metal-accelerated drift timeline renderer.
//  Maintains a scrolling history buffer of drift values and renders
//  a filled area + line strip showing drift evolution over time.
//

import Metal
import MetalKit
import Synchronization

/// Metal renderer for real-time drift timeline display.
/// Triple-buffered for smooth, tear-free rendering on Apple Silicon unified memory.
///
/// Maintains an internal history buffer (~4-8 seconds of data at display rate)
/// that shifts left each frame as new drift values arrive.
@available(macOS 15.0, *)
public final class DriftTimelineRenderer: NSObject, MTKViewDelegate {
    
    // MARK: - Metal State
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let linePipelineState: MTLRenderPipelineState
    private let fillPipelineState: MTLRenderPipelineState
    private let centerPipelineState: MTLRenderPipelineState
    
    // MARK: - Triple Buffering
    
    /// Number of history points to display (width resolution of timeline).
    public let historySize: Int
    
    /// Triple-buffered sample data.
    private let sampleBuffers: [MTLBuffer]
    
    /// Uniform buffers (one per flight).
    private let uniformBuffers: [MTLBuffer]
    
    /// Current buffer index (0, 1, 2).
    private var currentBufferIndex: Int = 0
    
    /// Semaphore for triple-buffer synchronization.
    private let inflightSemaphore = DispatchSemaphore(value: 3)
    
    // MARK: - History Buffer
    
    /// CPU-side history of drift values. Shifts left as new data arrives.
    private var history: [Float]
    
    /// Number of valid samples in history.
    private var historyCount: Int = 0
    
    // MARK: - Data Source
    
    /// Ring buffer to drain drift values from (set by owner).
    public var scopeBuffer: AtomicScopeBuffer<Float>?
    
    /// Uniform struct matching the shader.
    private struct DriftTimelineUniforms {
        var sampleCount: Float
        var lineWidth: Float
        var timeScale: Float
        var padding: Float
    }
    
    // MARK: - Init
    
    /// Initialize with a Metal device.
    /// - Parameters:
    ///   - device: The Metal device.
    ///   - historySize: Number of history points (default 512 ≈ ~8.5s at 60fps).
    /// - Returns: nil if pipeline creation fails.
    public init?(device: MTLDevice, historySize: Int = 512) {
        self.device = device
        self.historySize = historySize
        self.history = [Float](repeating: 0.0, count: historySize)
        
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        // Create triple-buffered sample buffers
        var buffers: [MTLBuffer] = []
        var uniforms: [MTLBuffer] = []
        for _ in 0..<3 {
            guard let buf = device.makeBuffer(
                length: MemoryLayout<Float>.stride * historySize,
                options: .storageModeShared
            ) else { return nil }
            buffers.append(buf)
            
            guard let ubuf = device.makeBuffer(
                length: MemoryLayout<DriftTimelineUniforms>.stride,
                options: .storageModeShared
            ) else { return nil }
            uniforms.append(ubuf)
        }
        self.sampleBuffers = buffers
        self.uniformBuffers = uniforms
        
        // Load shaders and create pipelines
        guard let library = device.makeDefaultLibrary() else { return nil }
        
        // Line pipeline
        guard let lineVert = library.makeFunction(name: "drift_line_vertex"),
              let lineFrag = library.makeFunction(name: "drift_line_fragment")
        else { return nil }
        
        let lineDesc = MTLRenderPipelineDescriptor()
        lineDesc.vertexFunction = lineVert
        lineDesc.fragmentFunction = lineFrag
        lineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        lineDesc.colorAttachments[0].isBlendingEnabled = true
        lineDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        lineDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        // Fill pipeline
        guard let fillVert = library.makeFunction(name: "drift_fill_vertex"),
              let fillFrag = library.makeFunction(name: "drift_fill_fragment")
        else { return nil }
        
        let fillDesc = MTLRenderPipelineDescriptor()
        fillDesc.vertexFunction = fillVert
        fillDesc.fragmentFunction = fillFrag
        fillDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        fillDesc.colorAttachments[0].isBlendingEnabled = true
        fillDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        fillDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        // Center line pipeline
        guard let centerVert = library.makeFunction(name: "drift_center_vertex"),
              let centerFrag = library.makeFunction(name: "drift_center_fragment")
        else { return nil }
        
        let centerDesc = MTLRenderPipelineDescriptor()
        centerDesc.vertexFunction = centerVert
        centerDesc.fragmentFunction = centerFrag
        centerDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        centerDesc.colorAttachments[0].isBlendingEnabled = true
        centerDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        centerDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            self.linePipelineState = try device.makeRenderPipelineState(descriptor: lineDesc)
            self.fillPipelineState = try device.makeRenderPipelineState(descriptor: fillDesc)
            self.centerPipelineState = try device.makeRenderPipelineState(descriptor: centerDesc)
        } catch {
            print("DriftTimelineRenderer: Failed to create pipeline state: \(error)")
            return nil
        }
        
        super.init()
    }
    
    // MARK: - MTKViewDelegate
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No-op: shaders normalize to clip space
    }
    
    public func draw(in view: MTKView) {
        _ = inflightSemaphore.wait(timeout: .now() + 0.016)
        
        let bufferIndex = currentBufferIndex
        currentBufferIndex = (currentBufferIndex + 1) % 3
        
        // Drain new drift values from ring buffer and append to history
        updateHistory()
        
        // Copy history into Metal buffer
        let sampleBuffer = sampleBuffers[bufferIndex]
        let destPtr = sampleBuffer.contents().assumingMemoryBound(to: Float.self)
        let drawCount = historyCount
        
        guard drawCount >= 2 else {
            inflightSemaphore.signal()
            return
        }
        
        // Copy the most recent historyCount values
        let startOffset = historySize - drawCount
        for i in 0..<drawCount {
            destPtr[i] = history[startOffset + i]
        }
        
        // Update uniforms
        let uniformPtr = uniformBuffers[bufferIndex].contents()
            .assumingMemoryBound(to: DriftTimelineUniforms.self)
        uniformPtr.pointee = DriftTimelineUniforms(
            sampleCount: Float(drawCount),
            lineWidth: 1.0,
            timeScale: Float(historySize) / 60.0, // approximate seconds
            padding: 0.0
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
            red: 0.04, green: 0.04, blue: 0.07, alpha: 1.0
        )
        descriptor.colorAttachments[0].loadAction = .clear
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            inflightSemaphore.signal()
            return
        }
        
        // 1. Draw filled area under curve
        encoder.setRenderPipelineState(fillPipelineState)
        encoder.setVertexBuffer(sampleBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffers[bufferIndex], offset: 0, index: 1)
        // Each pair of adjacent samples = 1 quad = 6 vertices
        let fillVertexCount = max(0, (drawCount - 1) * 6)
        if fillVertexCount > 0 {
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: fillVertexCount)
        }
        
        // 2. Draw center baseline
        encoder.setRenderPipelineState(centerPipelineState)
        encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: 2)
        
        // 3. Draw line on top
        encoder.setRenderPipelineState(linePipelineState)
        encoder.setVertexBuffer(sampleBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffers[bufferIndex], offset: 0, index: 1)
        encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: drawCount)
        
        encoder.endEncoding()
        
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.inflightSemaphore.signal()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // MARK: - History Management
    
    /// Staging buffer for draining ring buffer data.
    private var stagingBuffer = [Float](repeating: 0.0, count: 256)
    
    /// Drain new values from ring buffer, downsample to 1 point per frame,
    /// and shift history left.
    private func updateHistory() {
        guard let ringBuffer = scopeBuffer else { return }
        
        // Drain all available values
        let drained = stagingBuffer.withUnsafeMutableBufferPointer { ptr in
            ringBuffer.drainInto(ptr.baseAddress!, maxCount: ptr.count)
        }
        
        guard drained > 0 else { return }
        
        // Average the drained values to get one history point per frame
        var sum: Float = 0.0
        for i in 0..<drained {
            sum += stagingBuffer[i]
        }
        let avgValue = sum / Float(drained)
        
        // Shift history left by 1 and append new value
        for i in 0..<(historySize - 1) {
            history[i] = history[i + 1]
        }
        history[historySize - 1] = avgValue
        
        // Track how full the history is
        if historyCount < historySize {
            historyCount += 1
        }
    }
}