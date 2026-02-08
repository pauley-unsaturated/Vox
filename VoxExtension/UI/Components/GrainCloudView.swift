//
//  GrainCloudView.swift
//  VoxExtension
//
//  SwiftUI wrapper for the Metal grain cloud scatter plot visualization.
//  Uses MTKView via NSViewRepresentable, renders 2D grain particle cloud.
//

import SwiftUI
import MetalKit

/// SwiftUI view wrapping a Metal-rendered grain cloud scatter plot.
///
/// Usage:
/// ```swift
/// GrainCloudView(buffer: grainPointBuffer)
///     .frame(width: 200, height: 200)
/// ```
@available(macOS 15.0, *)
public struct GrainCloudView: NSViewRepresentable {

    /// Ring buffer of GrainPoint data from the audio thread.
    public let buffer: AtomicScopeBuffer<GrainPoint>

    /// Preferred frames per second.
    public var preferredFPS: Int = 60

    public init(buffer: AtomicScopeBuffer<GrainPoint>, preferredFPS: Int = 60) {
        self.buffer = buffer
        self.preferredFPS = preferredFPS
    }

    public func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("GrainCloudView: Metal not supported")
        }

        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0.01, green: 0.02, blue: 0.06, alpha: 1.0)
        mtkView.preferredFramesPerSecond = preferredFPS
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false

        if let renderer = GrainCloudRenderer(device: device) {
            renderer.grainBuffer = buffer
            context.coordinator.renderer = renderer
            mtkView.delegate = renderer
        }

        return mtkView
    }

    public func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.preferredFramesPerSecond = preferredFPS
        context.coordinator.renderer?.grainBuffer = buffer
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public class Coordinator {
        var renderer: GrainCloudRenderer?
    }
}

// MARK: - Preview with Dummy Stochastic Grain Data

/// Preview that generates random stochastic grain bursts for visual verification.
@available(macOS 15.0, *)
public struct GrainCloudPreview: View {
    @State private var buffer = AtomicScopeBuffer<GrainPoint>(capacity: 4096)
    @State private var timer: Timer?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            GrainCloudView(buffer: buffer)
                .frame(width: 300, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )

            Text("Grain Cloud — Stochastic Scatter")
                .font(.caption)
                .foregroundColor(.blue.opacity(0.6))
                .padding(.top, 4)
        }
        .padding()
        .background(Color.black)
        .onAppear { startGrainGenerator() }
        .onDisappear { timer?.invalidate() }
    }

    private func startGrainGenerator() {
        // Simulate stochastic grain bursts
        nonisolated(unsafe) var phase: Double = 0
        let grainsPerTick = 24

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            phase += 0.02

            // Generate a burst of grains with some randomness
            for i in 0..<grainsPerTick {
                let t = Float(i) / Float(grainsPerTick)

                // Stochastic positions: clusters with spread
                let clusterX = Float(sin(phase)) * 0.4
                let clusterY = Float(cos(phase * 0.7)) * 0.3

                // Random spread around cluster center (simple hash-based pseudo-random)
                let seed = UInt32(i) &* 2654435761 &+ UInt32(phase * 1000)
                let rx = Float(Int32(bitPattern: seed &* 16807 &>> 8) % 1000) / 1000.0 - 0.5
                let ry = Float(Int32(bitPattern: seed &* 48271 &>> 8) % 1000) / 1000.0 - 0.5

                let x = clusterX + rx * 0.6
                let y = clusterY + ry * 0.5

                // Grain size varies (duration proxy)
                let grainSize = 0.2 + t * 0.6

                // Amplitude varies per grain
                let amp = 0.3 + Float(Int32(bitPattern: seed &* 69621 &>> 8) % 700) / 1000.0

                let point = GrainPoint(
                    x: max(-1, min(1, x)),
                    y: max(-1, min(1, y)),
                    size: grainSize,
                    age: 0,
                    amplitude: amp
                )
                buffer.write(point)
            }
        }
    }
}

@available(macOS 15.0, *)
#Preview("Grain Cloud") {
    GrainCloudPreview()
        .frame(width: 350, height: 380)
}