//
//  ChaosAttractorView.swift
//  VoxExtension
//
//  SwiftUI wrapper for the Metal chaos attractor phase-space visualization.
//  Uses MTKView via NSViewRepresentable, renders 2D attractor trails.
//

import SwiftUI
import MetalKit

/// SwiftUI view wrapping a Metal-rendered chaos attractor plot.
///
/// Usage:
/// ```swift
/// ChaosAttractorView(buffer: chaosPointBuffer)
///     .frame(width: 200, height: 200)
/// ```
@available(macOS 15.0, *)
public struct ChaosAttractorView: NSViewRepresentable {
    
    /// Ring buffer of ChaosPoint data from the audio thread.
    public let buffer: AtomicScopeBuffer<ChaosPoint>
    
    /// Preferred frames per second.
    public var preferredFPS: Int = 60
    
    public init(buffer: AtomicScopeBuffer<ChaosPoint>, preferredFPS: Int = 60) {
        self.buffer = buffer
        self.preferredFPS = preferredFPS
    }
    
    public func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("ChaosAttractorView: Metal not supported")
        }
        
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0)
        mtkView.preferredFramesPerSecond = preferredFPS
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        
        if let renderer = ChaosAttractorRenderer(device: device) {
            renderer.chaosBuffer = buffer
            context.coordinator.renderer = renderer
            mtkView.delegate = renderer
        }
        
        return mtkView
    }
    
    public func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.preferredFramesPerSecond = preferredFPS
        context.coordinator.renderer?.chaosBuffer = buffer
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator {
        var renderer: ChaosAttractorRenderer?
    }
}

// MARK: - Preview with Dummy Lorenz Attractor

/// Preview that generates a Lorenz attractor trajectory for visual verification.
@available(macOS 15.0, *)
public struct ChaosAttractorPreview: View {
    @State private var buffer = AtomicScopeBuffer<ChaosPoint>(capacity: 4096)
    @State private var timer: Timer?
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            ChaosAttractorView(buffer: buffer)
                .frame(width: 300, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
            
            Text("Chaos Attractor — Lorenz X vs Y")
                .font(.caption)
                .foregroundColor(.cyan.opacity(0.6))
                .padding(.top, 4)
        }
        .padding()
        .background(Color.black)
        .onAppear { startLorenzGenerator() }
        .onDisappear { timer?.invalidate() }
    }
    
    private func startLorenzGenerator() {
        // Lorenz attractor parameters
        let sigma: Double = 10.0
        let rho: Double = 28.0
        let beta: Double = 8.0 / 3.0
        let dt: Double = 0.005
        
        nonisolated(unsafe) var lx: Double = 0.1
        nonisolated(unsafe) var ly: Double = 0.0
        nonisolated(unsafe) var lz: Double = 0.0
        
        let pointsPerTick = 64
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            for _ in 0..<pointsPerTick {
                // RK4 integration
                let dx1 = sigma * (ly - lx)
                let dy1 = lx * (rho - lz) - ly
                let dz1 = lx * ly - beta * lz
                
                let x2 = lx + 0.5 * dt * dx1
                let y2 = ly + 0.5 * dt * dy1
                let z2 = lz + 0.5 * dt * dz1
                let dx2 = sigma * (y2 - x2)
                let dy2 = x2 * (rho - z2) - y2
                let dz2 = x2 * y2 - beta * z2
                
                let x3 = lx + 0.5 * dt * dx2
                let y3 = ly + 0.5 * dt * dy2
                let z3 = lz + 0.5 * dt * dz2
                let dx3 = sigma * (y3 - x3)
                let dy3 = x3 * (rho - z3) - y3
                let dz3 = x3 * y3 - beta * z3
                
                let x4 = lx + dt * dx3
                let y4 = ly + dt * dy3
                let z4 = lz + dt * dz3
                let dx4 = sigma * (y4 - x4)
                let dy4 = x4 * (rho - z4) - y4
                let dz4 = x4 * y4 - beta * z4
                
                lx += (dt / 6.0) * (dx1 + 2*dx2 + 2*dx3 + dx4)
                ly += (dt / 6.0) * (dy1 + 2*dy2 + 2*dy3 + dy4)
                lz += (dt / 6.0) * (dz1 + 2*dz2 + 2*dz3 + dz4)
                
                // Normalize to -1..1 (Lorenz x,y range ~ -20..20)
                let point = ChaosPoint(
                    x: Float(lx / 25.0),
                    y: Float(ly / 25.0),
                    age: 0
                )
                buffer.write(point)
            }
        }
    }
}

@available(macOS 15.0, *)
#Preview("Chaos Attractor") {
    ChaosAttractorPreview()
        .frame(width: 350, height: 380)
}
