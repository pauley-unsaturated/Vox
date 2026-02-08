//
//  ChaosAttractorRenderer.swift
//  VoxExtension
//
//  Metal renderer for 2D chaos attractor phase-space visualization.
//  Drains AtomicScopeBuffer<ChaosPoint> each frame, maintains a trail history,
//  and renders as a fading point cloud.
//

import Metal
import MetalKit
import Synchronization

/// Metal renderer for real-time chaos attractor trail visualization.
/// Triple-buffered for smooth rendering on Apple Silicon unified memory.
@available(macOS 15.0, *)
public final class ChaosAttractorRenderer: NSObject, MTKViewDelegate {
    
    // MARK: - Metal State
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    
    // MARK: - Trail History
    
    /// Maximum points in the trail history.
    private let maxTrailPoints: Int = 4096
    
    /// Circular trail buffer — stores accumulated points with age.
    /// This is the renderer's own copy; audio data is drained into it each frame.
    private var trailBuffer: [ChaosPoint]
    
    /// Current write position in the trail buffer.
    private var trailWritePos: Int = 0
    
    /// Number of valid points in the trail (grows up to maxTrailPoints).
    private var trailCount: Int = 0
    
    // MARK: - Triple Buffering
    
    /// Triple-buffered GPU point data.
    private let pointBuffers: [MTLBuffer]
    
    /// Uniform buffers (one per flight).
    private let uniformBuffers: [MTLBuffer]
    
    /// Current buffer index (0, 1, 2).
    private var currentBufferIndex: Int = 0
    
    /// Semaphore for triple-buffer synchronization.
    private let inflightSemaphore = DispatchSemaphore(value: 3)
    
    // MARK: - Data Source
    
    /// Ring buffer to drain chaos points from (set by owner).
    public var chaosBuffer: AtomicScopeBuffer<ChaosPoint>?
    
    /// Uniform struct matching the shader.
    private struct ChaosUniforms {
        var pointCount: Float
        var aspectRatio: Float
        var trailLength: Float
        var padding: Float
    }
    
    // MARK: - Staging buffer for draining ring buffer
    
    private let stagingBuffer: UnsafeMutablePointer<ChaosPoint>
    private let maxDrainPerFrame: Int = 512
    
    // MARK: - Init
    
    public init?(device: MTLDevice) {
        self.device = device
        
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        // Initialize trail buffer
        self.trailBuffer = [ChaosPoint](repeating: ChaosPoint(), count: 4096)
        
        // Staging buffer for draining
        self.stagingBuffer = .allocate(capacity: 512)
        
        // Create triple-buffered GPU buffers
        let pointStride = MemoryLayout<ChaosPoint>.stride
        var pBuffers: [MTLBuffer] = []
        var uBuffers: [MTLBuffer] = []
        for _ in 0..<3 {
            guard let pb = device.makeBuffer(length: pointStride * 4096, options: .storageModeShared),
                  let ub = device.makeBuffer(length: MemoryLayout<ChaosUniforms>.stride, options: .storageModeShared)
            else { return nil }
            pBuffers.append(pb)
            uBuffers.append(ub)
        }
        self.pointBuffers = pBuffers
        self.uniformBuffers = uBuffers
        
        // Load shaders and create pipeline
        guard let library = device.makeDefaultLibrary(),
              let vertexFunc = library.makeFunction(name: "chaos_attractor_vertex"),
              let fragmentFunc = library.makeFunction(name: "chaos_attractor_fragment")
        else { return nil }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Additive blending for glowing trail effect
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("ChaosAttractorRenderer: Failed to create pipeline: \(error)")
            return nil
        }
        
        super.init()
    }
    
    deinit {
        stagingBuffer.deallocate()
    }
    
    // MARK: - MTKViewDelegate
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        _ = inflightSemaphore.wait(timeout: .now() + 0.016)
        
        let bufferIndex = currentBufferIndex
        currentBufferIndex = (currentBufferIndex + 1) % 3
        
        // Drain new points from ring buffer into trail
        if let ringBuffer = chaosBuffer {
            let drained = ringBuffer.drainInto(stagingBuffer, maxCount: maxDrainPerFrame)
            for i in 0..<drained {
                trailBuffer[trailWritePos] = stagingBuffer[i]
                trailWritePos = (trailWritePos + 1) % maxTrailPoints
                trailCount = min(trailCount + 1, maxTrailPoints)
            }
        }
        
        guard trailCount >= 2 else {
            inflightSemaphore.signal()
            return
        }
        
        // Copy trail into GPU buffer with age calculation
        let gpuPtr = pointBuffers[bufferIndex].contents()
            .assumingMemoryBound(to: ChaosPoint.self)
        
        for i in 0..<trailCount {
            // Read from trail in order: oldest first
            let readIdx: Int
            if trailCount < maxTrailPoints {
                readIdx = i
            } else {
                readIdx = (trailWritePos + i) % maxTrailPoints
            }
            var point = trailBuffer[readIdx]
            point.age = Float(i) / Float(max(trailCount - 1, 1))
            // Invert: i=0 is oldest (age=0→1), i=trailCount-1 is newest (age=1→0)
            // Actually we want oldest=1, newest=0 for the shader
            point.age = 1.0 - point.age
            gpuPtr[i] = point
        }
        
        // Update uniforms
        let drawableSize = view.drawableSize
        let aspect = Float(drawableSize.width / drawableSize.height)
        let uniformPtr = uniformBuffers[bufferIndex].contents()
            .assumingMemoryBound(to: ChaosUniforms.self)
        uniformPtr.pointee = ChaosUniforms(
            pointCount: Float(trailCount),
            aspectRatio: aspect,
            trailLength: 1.0,
            padding: 0.0
        )
        
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            inflightSemaphore.signal()
            return
        }
        
        // Very dark background
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0
        )
        descriptor.colorAttachments[0].loadAction = .clear
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            inflightSemaphore.signal()
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(pointBuffers[bufferIndex], offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffers[bufferIndex], offset: 0, index: 1)
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: trailCount)
        encoder.endEncoding()
        
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.inflightSemaphore.signal()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
