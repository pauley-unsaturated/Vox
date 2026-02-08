//
//  DriftTimelineView.swift
//  VoxExtension
//
//  SwiftUI wrapper for the Metal drift timeline view.
//  Shows drift parameter evolution as a horizontal scrolling timeline.
//

import SwiftUI
import MetalKit

/// SwiftUI view wrapping a Metal-rendered drift timeline.
///
/// Usage:
/// ```swift
/// DriftTimelineView(buffer: driftScopeBuffer)
///     .frame(height: 100)
/// ```
@available(macOS 15.0, *)
public struct DriftTimelineView: NSViewRepresentable {
    
    /// The ring buffer to read drift values from.
    public let buffer: AtomicScopeBuffer<Float>
    
    /// Number of history points to display.
    public var historySize: Int = 512
    
    /// Preferred frames per second.
    public var preferredFPS: Int = 60
    
    public init(buffer: AtomicScopeBuffer<Float>, historySize: Int = 512, preferredFPS: Int = 60) {
        self.buffer = buffer
        self.historySize = historySize
        self.preferredFPS = preferredFPS
    }
    
    public func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("DriftTimelineView: Metal is not supported on this device")
        }
        
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1.0)
        mtkView.preferredFramesPerSecond = preferredFPS
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        
        if let renderer = DriftTimelineRenderer(device: device, historySize: historySize) {
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
        var renderer: DriftTimelineRenderer?
    }
}

// MARK: - Preview with Dummy Drift Data

/// A preview/demo view that generates slow drift-like data for visual verification.
@available(macOS 15.0, *)
public struct DriftTimelinePreview: View {
    @State private var buffer = AtomicScopeBuffer<Float>(capacity: 4096)
    @State private var timer: Timer?
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            DriftTimelineView(buffer: buffer)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
            
            Text("Drift Timeline — Slow Evolution")
                .font(.caption)
                .foregroundColor(.cyan.opacity(0.6))
                .padding(.top, 4)
        }
        .padding()
        .background(Color.black)
        .onAppear { startDriftGenerator() }
        .onDisappear { timer?.invalidate() }
    }
    
    private func startDriftGenerator() {
        // Simulate drift: slow sine + perlin-like noise
        nonisolated(unsafe) var phase1: Float = 0.0
        nonisolated(unsafe) var phase2: Float = 0.0
        nonisolated(unsafe) var brownian: Float = 0.0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            // Generate a few samples per frame (simulating audio thread writing at reduced rate)
            for _ in 0..<4 {
                // Slow sine (primary drift)
                let sine = sin(phase1) * 0.6
                // Faster secondary oscillation
                let secondary = sin(phase2) * 0.2
                // Brownian noise component
                brownian += Float.random(in: -0.02...0.02)
                brownian *= 0.98 // decay toward zero
                brownian = max(-0.3, min(0.3, brownian))
                
                let value = max(-1.0, min(1.0, sine + secondary + brownian))
                buffer.write(value)
                
                phase1 += 0.003  // very slow
                phase2 += 0.017  // slightly faster
            }
        }
    }
}

@available(macOS 15.0, *)
#Preview("Drift Timeline") {
    DriftTimelinePreview()
        .frame(width: 600, height: 180)
}