//
//  SpectrumView.swift
//  VoxExtension
//
//  SwiftUI wrapper for the Metal formant spectrum display.
//  Shows FFT spectrum with F1/F2 formant frequency markers.
//

import SwiftUI
import MetalKit

/// SwiftUI view wrapping a Metal-rendered FFT spectrum display with formant markers.
///
/// Usage:
/// ```swift
/// SpectrumView(buffer: myAtomicScopeBuffer, f1Frequency: 800, f2Frequency: 2400)
///     .frame(height: 120)
/// ```
@available(macOS 15.0, *)
public struct SpectrumView: NSViewRepresentable {
    
    /// Ring buffer to read audio samples from.
    public let buffer: AtomicScopeBuffer<Float>
    
    /// Sample rate for frequency axis mapping.
    public var sampleRate: Float = 44100.0
    
    /// Formant 1 frequency in Hz.
    public var f1Frequency: Float = 0.0
    
    /// Formant 2 frequency in Hz.
    public var f2Frequency: Float = 0.0
    
    /// Preferred frames per second.
    public var preferredFPS: Int = 60
    
    public init(
        buffer: AtomicScopeBuffer<Float>,
        sampleRate: Float = 44100.0,
        f1Frequency: Float = 0.0,
        f2Frequency: Float = 0.0,
        preferredFPS: Int = 60
    ) {
        self.buffer = buffer
        self.sampleRate = sampleRate
        self.f1Frequency = f1Frequency
        self.f2Frequency = f2Frequency
        self.preferredFPS = preferredFPS
    }
    
    public func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("SpectrumView: Metal is not supported on this device")
        }
        
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        mtkView.preferredFramesPerSecond = preferredFPS
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        
        if let renderer = SpectrumRenderer(device: device) {
            renderer.scopeBuffer = buffer
            renderer.sampleRate = sampleRate
            renderer.f1Frequency = f1Frequency
            renderer.f2Frequency = f2Frequency
            context.coordinator.renderer = renderer
            mtkView.delegate = renderer
        }
        
        return mtkView
    }
    
    public func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.preferredFramesPerSecond = preferredFPS
        if let renderer = context.coordinator.renderer {
            renderer.scopeBuffer = buffer
            renderer.sampleRate = sampleRate
            renderer.f1Frequency = f1Frequency
            renderer.f2Frequency = f2Frequency
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator {
        var renderer: SpectrumRenderer?
    }
}

// MARK: - Preview with Dummy Spectrum Data

/// Preview that generates a synthetic signal with two formant peaks for visual verification.
@available(macOS 15.0, *)
public struct SpectrumPreview: View {
    @State private var buffer = AtomicScopeBuffer<Float>(capacity: 4096)
    @State private var timer: Timer?
    
    /// Simulated formant frequencies.
    private let f1: Float = 800.0
    private let f2: Float = 2400.0
    private let sampleRate: Float = 44100.0
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            SpectrumView(
                buffer: buffer,
                sampleRate: sampleRate,
                f1Frequency: f1,
                f2Frequency: f2
            )
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
            )
            
            HStack {
                Label("F1: \(Int(f1)) Hz", systemImage: "waveform")
                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.1))
                Spacer()
                Label("F2: \(Int(f2)) Hz", systemImage: "waveform")
                    .foregroundColor(Color(red: 1.0, green: 0.3, blue: 0.7))
            }
            .font(.caption)
            .padding(.top, 4)
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color.black)
        .onAppear { startSignalGenerator() }
        .onDisappear { timer?.invalidate() }
    }
    
    /// Generate a synthetic signal with energy at F1 and F2 frequencies.
    private func startSignalGenerator() {
        nonisolated(unsafe) var phase1: Float = 0.0
        nonisolated(unsafe) var phase2: Float = 0.0
        nonisolated(unsafe) var noisePhase: Float = 0.0
        let samplesPerTick = 512
        
        let phaseInc1 = f1 * 2.0 * .pi / sampleRate
        let phaseInc2 = f2 * 2.0 * .pi / sampleRate
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            for _ in 0..<samplesPerTick {
                // Mix two formant frequencies plus a bit of noise
                let s1 = sin(phase1) * 0.5
                let s2 = sin(phase2) * 0.3
                // Simple noise via phase accumulation
                noisePhase += 0.1
                let noise = sin(noisePhase * 137.0) * 0.05
                
                buffer.write(s1 + s2 + noise)
                
                phase1 += phaseInc1
                phase2 += phaseInc2
                if phase1 > 2.0 * .pi { phase1 -= 2.0 * .pi }
                if phase2 > 2.0 * .pi { phase2 -= 2.0 * .pi }
            }
        }
    }
}

@available(macOS 15.0, *)
#Preview("Formant Spectrum") {
    SpectrumPreview()
        .frame(width: 600, height: 220)
}
