//
//  VoiceConstellationRenderer.swift
//  VoxExtension
//
//  Metal renderer for circular voice constellation display.
//  Reads per-voice state from an atomic array and renders 8 voice positions
//  as glowing points arranged in a ring, with a subtle ring outline.
//

import Metal
import MetalKit
import Synchronization

/// Metal renderer for the voice constellation circular display.
/// Triple-buffered for smooth rendering on Apple Silicon unified memory.
@available(macOS 15.0, *)
public final class VoiceConstellationRenderer: NSObject, MTKViewDelegate {

    // MARK: - Constants

    /// Maximum number of voices to display.
    public static let maxVoices: Int = 8

    /// Segments for the ring outline.
    private let ringSegments: Int = 129  // 128 segments + closing vertex

    // MARK: - Metal State

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pointPipeline: MTLRenderPipelineState
    private let ringPipeline: MTLRenderPipelineState

    // MARK: - Triple Buffering

    private let voiceBuffers: [MTLBuffer]
    private let uniformBuffers: [MTLBuffer]
    private var currentBufferIndex: Int = 0
    private let inflightSemaphore = DispatchSemaphore(value: 3)

    // MARK: - Animation

    private var startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    // MARK: - Data Source

    /// Atomic array of per-voice state. Audio thread writes, renderer reads.
    /// Must have capacity >= maxVoices.
    public var voiceBuffer: AtomicScopeBuffer<VoiceConstellationPoint>?

    /// Direct voice data for preview/testing (bypasses ring buffer).
    public var directVoiceData: [VoiceConstellationPoint]?

    private struct ConstellationUniforms {
        var voiceCount: Float
        var aspectRatio: Float
        var time: Float
        var padding: Float
    }

    // MARK: - Staging

    private let stagingBuffer: UnsafeMutablePointer<VoiceConstellationPoint>

    // MARK: - Init

    public init?(device: MTLDevice) {
        self.device = device

        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue

        self.stagingBuffer = .allocate(capacity: VoiceConstellationRenderer.maxVoices)

        // Triple-buffered GPU buffers
        let pointStride = MemoryLayout<VoiceConstellationPoint>.stride
        var vBuffers: [MTLBuffer] = []
        var uBuffers: [MTLBuffer] = []
        for _ in 0..<3 {
            guard let vb = device.makeBuffer(
                length: pointStride * VoiceConstellationRenderer.maxVoices,
                options: .storageModeShared
            ),
            let ub = device.makeBuffer(
                length: MemoryLayout<ConstellationUniforms>.stride,
                options: .storageModeShared
            ) else { return nil }
            vBuffers.append(vb)
            uBuffers.append(ub)
        }
        self.voiceBuffers = vBuffers
        self.uniformBuffers = uBuffers

        // Load shaders
        guard let library = device.makeDefaultLibrary(),
              let pointVert = library.makeFunction(name: "constellation_vertex"),
              let pointFrag = library.makeFunction(name: "constellation_fragment"),
              let ringVert = library.makeFunction(name: "constellation_ring_vertex"),
              let ringFrag = library.makeFunction(name: "constellation_ring_fragment")
        else { return nil }

        // Point pipeline (additive blending for glow)
        let pointDesc = MTLRenderPipelineDescriptor()
        pointDesc.vertexFunction = pointVert
        pointDesc.fragmentFunction = pointFrag
        pointDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        pointDesc.colorAttachments[0].isBlendingEnabled = true
        pointDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pointDesc.colorAttachments[0].destinationRGBBlendFactor = .one
        pointDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        pointDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        // Ring pipeline (alpha blending)
        let ringDesc = MTLRenderPipelineDescriptor()
        ringDesc.vertexFunction = ringVert
        ringDesc.fragmentFunction = ringFrag
        ringDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        ringDesc.colorAttachments[0].isBlendingEnabled = true
        ringDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        ringDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

        do {
            self.pointPipeline = try device.makeRenderPipelineState(descriptor: pointDesc)
            self.ringPipeline = try device.makeRenderPipelineState(descriptor: ringDesc)
        } catch {
            print("VoiceConstellationRenderer: Failed to create pipeline: \(error)")
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

        let maxVoices = VoiceConstellationRenderer.maxVoices

        // Get voice data
        let gpuPtr = voiceBuffers[bufferIndex].contents()
            .assumingMemoryBound(to: VoiceConstellationPoint.self)

        var voiceCount = 0
        if let direct = directVoiceData {
            // Direct data mode (preview)
            voiceCount = min(direct.count, maxVoices)
            for i in 0..<voiceCount {
                gpuPtr[i] = direct[i]
            }
        } else if let ringBuffer = voiceBuffer {
            // Drain from ring buffer — take the latest snapshot
            voiceCount = ringBuffer.drainInto(stagingBuffer, maxCount: maxVoices)
            if voiceCount > 0 {
                for i in 0..<voiceCount {
                    gpuPtr[i] = stagingBuffer[i]
                }
            }
        }

        guard voiceCount > 0 else {
            inflightSemaphore.signal()
            return
        }

        // Update uniforms
        let drawableSize = view.drawableSize
        let aspect = Float(drawableSize.width / drawableSize.height)
        let time = Float(CFAbsoluteTimeGetCurrent() - startTime)

        let uniformPtr = uniformBuffers[bufferIndex].contents()
            .assumingMemoryBound(to: ConstellationUniforms.self)
        uniformPtr.pointee = ConstellationUniforms(
            voiceCount: Float(maxVoices),
            aspectRatio: aspect,
            time: time,
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
            red: 0.03, green: 0.03, blue: 0.06, alpha: 1.0
        )
        descriptor.colorAttachments[0].loadAction = .clear

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            inflightSemaphore.signal()
            return
        }

        // Draw ring outline first
        encoder.setRenderPipelineState(ringPipeline)
        encoder.setVertexBuffer(uniformBuffers[bufferIndex], offset: 0, index: 0)
        encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: ringSegments)

        // Draw voice points on top
        encoder.setRenderPipelineState(pointPipeline)
        encoder.setVertexBuffer(voiceBuffers[bufferIndex], offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffers[bufferIndex], offset: 0, index: 1)
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: voiceCount)

        encoder.endEncoding()

        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.inflightSemaphore.signal()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}