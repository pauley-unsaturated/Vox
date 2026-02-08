//
//  ScopeView.swift
//  VoxExtension
//
//  SwiftUI wrapper for the Metal oscilloscope view.
//  Uses MTKView via NSViewRepresentable, driven by MTKViewDelegate callbacks.
//

import SwiftUI
import MetalKit

/// SwiftUI view wrapping a Metal-rendered oscilloscope.
///
/// Usage:
/// ```swift
/// ScopeView(buffer: myAtomicScopeBuffer)
///     .frame(height: 120)
/// ```
@available(macOS 15.0, *)
public struct ScopeView: NSViewRepresentable {
    
    /// The ring buffer to read audio samples from.
    public let buffer: AtomicScopeBuffer<Float>
    
    /// Preferred frames per second (default: display refresh rate).
    public var preferredFPS: Int = 60
    
    public init(buffer: AtomicScopeBuffer<Float>, preferredFPS: Int = 60) {
        self.buffer = buffer
        self.preferredFPS = preferredFPS
    }
    
    public func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("ScopeView: Metal is not supported on this device")
        }
        
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        mtkView.preferredFramesPerSecond = preferredFPS
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false // Timer-driven, not event-driven
        
        if let renderer = ScopeRenderer(device: device) {
            renderer.scopeBuffer = buffer
            context.coordinator.renderer = renderer
            mtkView.delegate = renderer
        }
        
        return mtkView
    }
    
    public func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.preferredFramesPerSecond = preferredFPS
        context.coordinator.renderer?.scopeBuffer = buffer
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator {
        var renderer: ScopeRenderer?
    }
}

// MARK: - Preview with Dummy Sine Wave

/// A preview/demo scope that generates a sine wave for visual verification.
@available(macOS 15.0, *)
public struct ScopePreview: View {
    @State private var buffer = AtomicScopeBuffer<Float>(capacity: 4096)
    @State private var timer: Timer?
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            ScopeView(buffer: buffer)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            
            Text("Scope Preview — Sine Wave")
                .font(.caption)
                .foregroundColor(.green.opacity(0.6))
                .padding(.top, 4)
        }
        .padding()
        .background(Color.black)
        .onAppear { startSineGenerator() }
        .onDisappear { timer?.invalidate() }
    }
    
    private func startSineGenerator() {
        // Use nonisolated(unsafe) to avoid Sendable warnings with Timer
        nonisolated(unsafe) var phase: Float = 0.0
        let frequency: Float = 2.0 // cycles per buffer fill
        let samplesPerTick = 256
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            let phaseInc = frequency * 2.0 * .pi / Float(4096)
            for _ in 0..<samplesPerTick {
                buffer.write(sin(phase))
                phase += phaseInc
                if phase > 2.0 * .pi { phase -= 2.0 * .pi }
            }
        }
    }
}

@available(macOS 15.0, *)
#Preview("Oscilloscope") {
    ScopePreview()
        .frame(width: 500, height: 200)
}
