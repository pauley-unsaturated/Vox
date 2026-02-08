//
//  GrainCloudRenderer.swift
//  VoxExtension
//
//  Metal renderer for 2D grain cloud scatter plot visualization.
//  Drains AtomicScopeBuffer<GrainPoint> each frame, maintains a particle history,
//  and renders as a fading point cloud with additive blending.
//

import Metal
import MetalKit
import Synchronization

/// Metal renderer for real-time grain cloud particle visualization.
/// Triple-buffered for smooth rendering on Apple Silicon unified memory.
@available(macOS 15.0, *)
public final class GrainCloudRenderer: NSObject, MTKViewDelegate {

    // MARK: - Metal State

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    // MARK: - Particle History

    /// Maximum points in the particle history.
    private let maxParticlePoints: Int = 4096

    /// Circular particle buffer — stores accumulated grains with age.
    private var particleBuffer: [GrainPoint]

    /// Current write position in the particle buffer.
    private var particleWritePos: Int = 0

    /// Number of valid points (grows up to maxParticlePoints).
    private var particleCount: Int = 0

    // MARK: - Triple Buffering

    private let pointBuffers: [MTLBuffer]
    private let uniformBuffers: [MTLBuffer]
    private var currentBufferIndex: Int = 0
    private let inflightSemaphore = DispatchSemaphore(value: 3)

    // MARK: - Data Source

    /// Ring buffer to drain grain points from (set by owner).
    public var grainBuffer: AtomicScopeBuffer<GrainPoint>?

    /// Uniform struct matching the shader.
    private struct GrainCloudUniforms {
        var pointCount: Float
        var aspectRatio: Float
        var time: Float
        var padding: Float
    }

    // MARK: - Staging buffer for draining ring buffer

    private let stagingBuffer: UnsafeMutablePointer<GrainPoint>
    private let maxDrainPerFrame: Int = 512

    // MARK: - Animation

    private var animationTime: Float = 0

    // MARK: - Init

    public init?(device: MTLDevice) {
        self.device = device

        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue

        // Initialize particle buffer
        self.particleBuffer = [GrainPoint](repeating: GrainPoint(), count: 4096)

        // Staging buffer for draining
        self.stagingBuffer = .allocate(capacity: 512)

        // Create triple-buffered GPU buffers
        let pointStride = MemoryLayout<GrainPoint>.stride
        var pBuffers: [MTLBuffer] = []
        var uBuffers: [MTLBuffer] = []
        for _ in 0..<3 {
            guard let pb = device.makeBuffer(length: pointStride * 4096, options: .storageModeShared),
                  let ub = device.makeBuffer(length: MemoryLayout<GrainCloudUniforms>.stride, options: .storageModeShared)
            else { return nil }
            pBuffers.append(pb)
            uBuffers.append(ub)
        }
        self.pointBuffers = pBuffers
        self.uniformBuffers = uBuffers

        // Load shaders and create pipeline
        guard let library = device.makeDefaultLibrary(),
              let vertexFunc = library.makeFunction(name: "grain_cloud_vertex"),
              let fragmentFunc = library.makeFunction(name: "grain_cloud_fragment")
        else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Additive blending for glowing cloud effect
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("GrainCloudRenderer: Failed to create pipeline: \(error)")
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

        // Advance animation time
        animationTime += 1.0 / 60.0

        // Drain new points from ring buffer into particle history
        if let ringBuffer = grainBuffer {
            let drained = ringBuffer.drainInto(stagingBuffer, maxCount: maxDrainPerFrame)
            for i in 0..<drained {
                particleBuffer[particleWritePos] = stagingBuffer[i]
                particleWritePos = (particleWritePos + 1) % maxParticlePoints
                particleCount = min(particleCount + 1, maxParticlePoints)
            }
        }

        guard particleCount >= 2 else {
            inflightSemaphore.signal()
            return
        }

        // Copy particles into GPU buffer with age calculation
        let gpuPtr = pointBuffers[bufferIndex].contents()
            .assumingMemoryBound(to: GrainPoint.self)

        for i in 0..<particleCount {
            let readIdx: Int
            if particleCount < maxParticlePoints {
                readIdx = i
            } else {
                readIdx = (particleWritePos + i) % maxParticlePoints
            }
            var point = particleBuffer[readIdx]
            // oldest (i=0) gets age=1, newest gets age=0
            point.age = 1.0 - Float(i) / Float(max(particleCount - 1, 1))
            gpuPtr[i] = point
        }

        // Update uniforms
        let drawableSize = view.drawableSize
        let aspect = Float(drawableSize.width / drawableSize.height)
        let uniformPtr = uniformBuffers[bufferIndex].contents()
            .assumingMemoryBound(to: GrainCloudUniforms.self)
        uniformPtr.pointee = GrainCloudUniforms(
            pointCount: Float(particleCount),
            aspectRatio: aspect,
            time: animationTime,
            padding: 0.0
        )

        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            inflightSemaphore.signal()
            return
        }

        // Very dark blue-black background
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.01, green: 0.02, blue: 0.06, alpha: 1.0
        )
        descriptor.colorAttachments[0].loadAction = .clear

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            inflightSemaphore.signal()
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(pointBuffers[bufferIndex], offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffers[bufferIndex], offset: 0, index: 1)
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
        encoder.endEncoding()

        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.inflightSemaphore.signal()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}