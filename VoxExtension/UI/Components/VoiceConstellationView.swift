//
//  VoiceConstellationView.swift
//  VoxExtension
//
//  SwiftUI wrapper for the Metal voice constellation circular display.
//  Shows 8 voices arranged in a ring — active voices glow, silent ones are dim.
//

import SwiftUI
import MetalKit

/// SwiftUI view wrapping a Metal-rendered voice constellation display.
///
/// Usage:
/// ```swift
/// VoiceConstellationView(buffer: voiceStateBuffer)
///     .frame(width: 200, height: 200)
/// ```
@available(macOS 15.0, *)
public struct VoiceConstellationView: NSViewRepresentable {

    /// Ring buffer of per-voice state from the audio thread.
    public let buffer: AtomicScopeBuffer<VoiceConstellationPoint>?

    /// Direct voice data for preview (bypasses ring buffer).
    public let directData: [VoiceConstellationPoint]?

    /// Preferred frames per second.
    public var preferredFPS: Int = 60

    public init(buffer: AtomicScopeBuffer<VoiceConstellationPoint>, preferredFPS: Int = 60) {
        self.buffer = buffer
        self.directData = nil
        self.preferredFPS = preferredFPS
    }

    public init(directData: [VoiceConstellationPoint], preferredFPS: Int = 60) {
        self.buffer = nil
        self.directData = directData
        self.preferredFPS = preferredFPS
    }

    public func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("VoiceConstellationView: Metal not supported")
        }

        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0.03, green: 0.03, blue: 0.06, alpha: 1.0)
        mtkView.preferredFramesPerSecond = preferredFPS
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false

        if let renderer = VoiceConstellationRenderer(device: device) {
            renderer.voiceBuffer = buffer
            renderer.directVoiceData = directData
            context.coordinator.renderer = renderer
            mtkView.delegate = renderer
        }

        return mtkView
    }

    public func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.preferredFramesPerSecond = preferredFPS
        context.coordinator.renderer?.voiceBuffer = buffer
        context.coordinator.renderer?.directVoiceData = directData
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public class Coordinator {
        var renderer: VoiceConstellationRenderer?
    }
}

// MARK: - Preview with Dummy Voice Data

@available(macOS 15.0, *)
public struct VoiceConstellationPreview: View {

    @State private var voices: [VoiceConstellationPoint] = {
        // 8 voices: some active, some silent, varying amplitudes
        return (0..<8).map { i in
            let isActive: Bool
            let amplitude: Float
            let pitch: Float

            switch i {
            case 0: isActive = true;  amplitude = 0.9;  pitch = 60  // C4 — loud
            case 1: isActive = true;  amplitude = 0.5;  pitch = 64  // E4 — medium
            case 2: isActive = true;  amplitude = 0.3;  pitch = 67  // G4 — soft
            case 3: isActive = false; amplitude = 0.0;  pitch = 0
            case 4: isActive = true;  amplitude = 0.7;  pitch = 72  // C5
            case 5: isActive = false; amplitude = 0.0;  pitch = 0
            case 6: isActive = false; amplitude = 0.0;  pitch = 0
            case 7: isActive = true;  amplitude = 0.15; pitch = 55  // G3 — very soft
            default: isActive = false; amplitude = 0.0;  pitch = 0
            }

            return VoiceConstellationPoint(
                pitch: pitch,
                amplitude: amplitude,
                active: isActive ? 1.0 : 0.0,
                voiceIndex: Float(i),
                pan: Float(i - 4) / 4.0,
                detuneCents: Float(i) * 5.0 - 17.5
            )
        }
    }()

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            VoiceConstellationView(directData: voices)
                .frame(width: 280, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )

            Text("Voice Constellation — 5 active / 3 silent")
                .font(.caption)
                .foregroundColor(.cyan.opacity(0.6))
        }
        .padding()
        .background(Color.black)
    }
}

@available(macOS 15.0, *)
#Preview("Voice Constellation") {
    VoiceConstellationPreview()
        .frame(width: 320, height: 340)
}