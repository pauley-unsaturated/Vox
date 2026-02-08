//
//  CloudSculptorView.swift
//  VoxExtension
//
//  Cloud Sculptor — Paradigm 3: Direct grain cloud sculpting with physics-based tools.
//  Visualizes grains as particles and provides 5 interaction tools:
//  Magnet, Flock, Heat, Grain Planet, and Grain Emitter.
//

import SwiftUI
import MetalKit

// MARK: - Tool Types

enum SculptorTool: Int, CaseIterable, Identifiable {
    case magnet = 0
    case flock
    case heat
    case planet
    case emitter

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .magnet:  return "🧲"
        case .flock:   return "🐝"
        case .heat:    return "🔥"
        case .planet:  return "🪐"
        case .emitter: return "💫"
        }
    }

    var label: String {
        switch self {
        case .magnet:  return "Magnet"
        case .flock:   return "Flock"
        case .heat:    return "Heat"
        case .planet:  return "Planet"
        case .emitter: return "Emitter"
        }
    }
}

// MARK: - Distribution Shape

enum DistributionShape: String, CaseIterable {
    case gaussian = "Gaussian"
    case uniform  = "Uniform"
    case cauchy   = "Cauchy"
    case poisson  = "Poisson"
}

// MARK: - Placed Tool Models

struct PlacedMagnet: Identifiable {
    let id = UUID()
    var position: CGPoint
    var strength: Float = 1.0
    var isRepulsor: Bool = false
}

struct PlacedPlanet: Identifiable {
    let id = UUID()
    var position: CGPoint
    var mass: Float = 0.5  // 0..1 range
    var spinDirection: Float = 1.0  // 1 = CCW, -1 = CW
}

struct PlacedEmitter: Identifiable {
    let id = UUID()
    var position: CGPoint
    var direction: CGVector = CGVector(dx: 0, dy: -1)
    var spreadAngle: Float = 0.3
    var emissionRate: Float = 5.0   // grains per frame
    var grainVelocity: Float = 0.5
}

struct HeatZone: Identifiable {
    let id = UUID()
    var position: CGPoint
    var radius: Float = 0.1
    var temperature: Float = 1.0  // positive = hot, negative = cold
}

struct FlockGroup: Identifiable {
    let id = UUID()
    var grainIndices: [Int] = []
    var leaderPosition: CGPoint = .zero
    var cohesion: Float = 0.5
}

// MARK: - Sculpt Grain (physics particle)

struct SculptGrain {
    var x: Float
    var y: Float
    var vx: Float = 0
    var vy: Float = 0
    var size: Float = 0.5
    var amplitude: Float = 1.0
    var lifetime: Float = 0       // age in seconds
    var maxLifetime: Float = 5.0  // max age before respawn
    var flockId: UUID? = nil
}

// MARK: - Cloud Sculptor Engine


@Observable
final class CloudSculptorEngine {
    var grains: [SculptGrain] = []
    var magnets: [PlacedMagnet] = []
    var planets: [PlacedPlanet] = []
    var emitters: [PlacedEmitter] = []
    var heatZones: [HeatZone] = []
    var flocks: [FlockGroup] = []

    var grainCount: Int = 256
    var scatterRadius: Float = 0.6
    var turbulence: Float = 0.1
    var particleLifetime: Float = 5.0
    var distribution: DistributionShape = .gaussian
    var isPaused: Bool = false

    // Temporary magnet for click+hold
    var activeMagnet: PlacedMagnet? = nil

    private var frameCount: Int = 0

    init() {
        resetGrains()
    }

    func resetGrains() {
        grains = (0..<grainCount).map { _ in
            makeGrain()
        }
    }

    private func makeGrain(at position: CGPoint? = nil) -> SculptGrain {
        let pos = position.map { CGPoint(x: $0.x, y: $0.y) }
        let (rx, ry) = distributedRandom()
        return SculptGrain(
            x: pos.map { Float($0.x) } ?? rx * scatterRadius,
            y: pos.map { Float($0.y) } ?? ry * scatterRadius,
            vx: Float.random(in: -0.01...0.01),
            vy: Float.random(in: -0.01...0.01),
            size: Float.random(in: 0.2...0.8),
            amplitude: Float.random(in: 0.3...1.0),
            lifetime: 0,
            maxLifetime: particleLifetime * Float.random(in: 0.5...1.5)
        )
    }

    private func distributedRandom() -> (Float, Float) {
        switch distribution {
        case .gaussian:
            return (gaussianRandom(), gaussianRandom())
        case .uniform:
            return (Float.random(in: -1...1), Float.random(in: -1...1))
        case .cauchy:
            return (cauchyRandom(), cauchyRandom())
        case .poisson:
            // Approximate as clustered gaussian
            let cx = Float.random(in: -0.5...0.5)
            let cy = Float.random(in: -0.5...0.5)
            return (cx + gaussianRandom() * 0.2, cy + gaussianRandom() * 0.2)
        }
    }

    private func gaussianRandom() -> Float {
        // Box-Muller
        let u1 = max(Float.random(in: 0...1), 1e-10)
        let u2 = Float.random(in: 0...1)
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2) * 0.33
    }

    private func cauchyRandom() -> Float {
        let u = Float.random(in: 0.05...0.95)
        return tan(.pi * (u - 0.5)) * 0.15
    }

    // MARK: - Physics Step

    func step(dt: Float = 1.0 / 60.0) {
        guard !isPaused else { return }
        frameCount += 1

        // Emit new grains from emitters
        for emitter in emitters {
            let count = Int(emitter.emissionRate)
            let frac = emitter.emissionRate - Float(count)
            let actualCount = count + (Float.random(in: 0...1) < frac ? 1 : 0)
            for _ in 0..<actualCount {
                if grains.count >= 512 { break }
                let angle = atan2(Float(emitter.direction.dy), Float(emitter.direction.dx))
                let spread = Float.random(in: -emitter.spreadAngle...emitter.spreadAngle)
                let finalAngle = angle + spread
                var g = SculptGrain(
                    x: Float(emitter.position.x),
                    y: Float(emitter.position.y),
                    vx: cos(finalAngle) * emitter.grainVelocity * 0.02,
                    vy: sin(finalAngle) * emitter.grainVelocity * 0.02,
                    size: Float.random(in: 0.2...0.6),
                    amplitude: Float.random(in: 0.5...1.0),
                    lifetime: 0,
                    maxLifetime: particleLifetime * Float.random(in: 0.5...1.5)
                )
                _ = g // suppress warning
                grains.append(g)
            }
        }

        // Update each grain
        for i in grains.indices {
            var g = grains[i]

            // Age
            g.lifetime += dt
            if g.lifetime > g.maxLifetime {
                // Respawn
                let new = makeGrain()
                grains[i] = new
                continue
            }

            var fx: Float = 0
            var fy: Float = 0

            // Magnet forces (placed + active)
            let allMagnets: [PlacedMagnet] = magnets + (activeMagnet.map { [$0] } ?? [])
            for mag in allMagnets {
                let dx = Float(mag.position.x) - g.x
                let dy = Float(mag.position.y) - g.y
                let distSq = max(dx * dx + dy * dy, 0.001)
                let dist = sqrt(distSq)
                let force = mag.strength / distSq * (mag.isRepulsor ? -1 : 1) * 0.001
                fx += dx / dist * force
                fy += dy / dist * force
            }

            // Planet forces (gravity + orbital)
            for planet in planets {
                let dx = Float(planet.position.x) - g.x
                let dy = Float(planet.position.y) - g.y
                let distSq = max(dx * dx + dy * dy, 0.0005)
                let dist = sqrt(distSq)
                let gravForce = planet.mass * 0.0005 / distSq

                // Radial (toward planet)
                fx += dx / dist * gravForce
                fy += dy / dist * gravForce

                // Tangential (orbital spin)
                let tangentX = -dy / dist * planet.spinDirection
                let tangentY = dx / dist * planet.spinDirection
                let orbitalForce = planet.mass * 0.0002 / dist
                fx += tangentX * orbitalForce
                fy += tangentY * orbitalForce

                // High mass consumption: if very close, kill grain
                if planet.mass > 0.8 && dist < 0.02 {
                    g.lifetime = g.maxLifetime // will respawn next frame
                }
            }

            // Heat zones: brownian noise
            for zone in heatZones {
                let dx = Float(zone.position.x) - g.x
                let dy = Float(zone.position.y) - g.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist < zone.radius {
                    let influence = (1.0 - dist / zone.radius) * zone.temperature
                    if influence > 0 {
                        // Hot: brownian
                        fx += Float.random(in: -1...1) * influence * 0.003
                        fy += Float.random(in: -1...1) * influence * 0.003
                    } else {
                        // Cold: damping
                        g.vx *= 1.0 + influence * 0.1  // influence is negative, so this damps
                        g.vy *= 1.0 + influence * 0.1
                    }
                }
            }

            // Flock behavior
            if let flockId = g.flockId,
               let flock = flocks.first(where: { $0.id == flockId }) {
                // Pull toward leader
                let dx = Float(flock.leaderPosition.x) - g.x
                let dy = Float(flock.leaderPosition.y) - g.y
                fx += dx * flock.cohesion * 0.01
                fy += dy * flock.cohesion * 0.01

                // Separation from other flock members
                for j in flock.grainIndices where j != i && j < grains.count {
                    let other = grains[j]
                    let sx = g.x - other.x
                    let sy = g.y - other.y
                    let sd = max(sx * sx + sy * sy, 0.0001)
                    if sd < 0.01 {
                        fx += sx / sd * 0.0001
                        fy += sy / sd * 0.0001
                    }
                }
            }

            // Turbulence
            fx += Float.random(in: -1...1) * turbulence * 0.001
            fy += Float.random(in: -1...1) * turbulence * 0.001

            // Integrate
            g.vx += fx
            g.vy += fy

            // Damping
            g.vx *= 0.98
            g.vy *= 0.98

            // Velocity clamp
            let speed = sqrt(g.vx * g.vx + g.vy * g.vy)
            if speed > 0.05 {
                g.vx = g.vx / speed * 0.05
                g.vy = g.vy / speed * 0.05
            }

            g.x += g.vx
            g.y += g.vy

            // Boundary: wrap
            if g.x < -1.2 { g.x += 2.4 }
            if g.x > 1.2 { g.x -= 2.4 }
            if g.y < -1.2 { g.y += 2.4 }
            if g.y > 1.2 { g.y -= 2.4 }

            grains[i] = g
        }

        // Heat diffusion (slow decay)
        for i in heatZones.indices {
            heatZones[i].temperature *= 0.998
        }
        heatZones.removeAll { abs($0.temperature) < 0.01 }

        // Trim excess grains
        if grains.count > 512 {
            grains.removeLast(grains.count - 512)
        }
    }
}

// MARK: - Cloud Sculptor Canvas (SwiftUI + Metal)


struct CloudSculptorCanvas: NSViewRepresentable {
    let engine: CloudSculptorEngine

    func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal not supported")
        }
        let view = MTKView(frame: .zero, device: device)
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.01, green: 0.02, blue: 0.06, alpha: 1.0)
        view.preferredFramesPerSecond = 60
        view.isPaused = false
        view.enableSetNeedsDisplay = false

        if let renderer = SculptorCanvasRenderer(device: device, engine: engine) {
            context.coordinator.renderer = renderer
            view.delegate = renderer
        }
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.renderer?.engine = engine
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var renderer: SculptorCanvasRenderer?
    }
}

// MARK: - Sculptor Canvas Renderer


final class SculptorCanvasRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let pointBuffers: [MTLBuffer]
    private let uniformBuffers: [MTLBuffer]
    private var currentBufferIndex = 0
    private let inflightSemaphore = DispatchSemaphore(value: 3)
    var engine: CloudSculptorEngine

    private struct Uniforms {
        var pointCount: Float
        var aspectRatio: Float
        var time: Float
        var padding: Float
    }

    private var animationTime: Float = 0

    init?(device: MTLDevice, engine: CloudSculptorEngine) {
        self.device = device
        self.engine = engine
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue

        guard let library = device.makeDefaultLibrary(),
              let vertexFunc = library.makeFunction(name: "grain_cloud_vertex"),
              let fragmentFunc = library.makeFunction(name: "grain_cloud_fragment")
        else { return nil }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertexFunc
        desc.fragmentFunction = fragmentFunc
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        desc.colorAttachments[0].destinationRGBBlendFactor = .one
        desc.colorAttachments[0].sourceAlphaBlendFactor = .one
        desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: desc)
        } catch { return nil }

        let stride = MemoryLayout<GrainPoint>.stride
        var pBufs: [MTLBuffer] = []
        var uBufs: [MTLBuffer] = []
        for _ in 0..<3 {
            guard let pb = device.makeBuffer(length: stride * 512, options: .storageModeShared),
                  let ub = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: .storageModeShared)
            else { return nil }
            pBufs.append(pb)
            uBufs.append(ub)
        }
        self.pointBuffers = pBufs
        self.uniformBuffers = uBufs

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        _ = inflightSemaphore.wait(timeout: .now() + 0.016)
        let idx = currentBufferIndex
        currentBufferIndex = (currentBufferIndex + 1) % 3
        animationTime += 1.0 / 60.0

        // Step physics
        engine.step()

        let grains = engine.grains
        let count = min(grains.count, 512)
        guard count > 0 else {
            inflightSemaphore.signal()
            return
        }

        // Copy to GPU buffer
        let ptr = pointBuffers[idx].contents().assumingMemoryBound(to: GrainPoint.self)
        for i in 0..<count {
            let g = grains[i]
            let ageFrac = min(g.lifetime / g.maxLifetime, 1.0)
            ptr[i] = GrainPoint(
                x: g.x,
                y: g.y,
                size: g.size,
                age: ageFrac,
                amplitude: g.amplitude * (1.0 - ageFrac * 0.5)
            )
        }

        let drawableSize = view.drawableSize
        let aspect = Float(drawableSize.width / drawableSize.height)
        let uPtr = uniformBuffers[idx].contents().assumingMemoryBound(to: Uniforms.self)
        uPtr.pointee = Uniforms(pointCount: Float(count), aspectRatio: aspect, time: animationTime, padding: 0)

        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let cmdBuf = commandQueue.makeCommandBuffer()
        else { inflightSemaphore.signal(); return }

        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.01, green: 0.02, blue: 0.06, alpha: 1.0)
        descriptor.colorAttachments[0].loadAction = .clear

        guard let enc = cmdBuf.makeRenderCommandEncoder(descriptor: descriptor) else {
            inflightSemaphore.signal(); return
        }
        enc.setRenderPipelineState(pipelineState)
        enc.setVertexBuffer(pointBuffers[idx], offset: 0, index: 0)
        enc.setVertexBuffer(uniformBuffers[idx], offset: 0, index: 1)
        enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: count)
        enc.endEncoding()

        cmdBuf.addCompletedHandler { [weak self] _ in self?.inflightSemaphore.signal() }
        cmdBuf.present(drawable)
        cmdBuf.commit()
    }
}

// MARK: - Tool Toolbar


struct SculptorToolbar: View {
    @Binding var selectedTool: SculptorTool

    var body: some View {
        VStack(spacing: 6) {
            ForEach(SculptorTool.allCases) { tool in
                Button(action: { selectedTool = tool }) {
                    Text(tool.icon)
                        .font(.system(size: 20))
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTool == tool ? Color.cyan.opacity(0.15) : Color(white: 0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selectedTool == tool ? Color.cyan : Color(white: 0.15), lineWidth: selectedTool == tool ? 2 : 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help(tool.label)
            }

            Spacer()

            // Tool label
            Text(selectedTool.label.uppercased())
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan.opacity(0.7))
                .rotationEffect(.degrees(-90))
                .fixedSize()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(width: 48)
        .background(Color(white: 0.04))
    }
}

// MARK: - Cloud Properties Panel


struct CloudPropertiesPanel: View {
    @Bindable var engine: CloudSculptorEngine

    var body: some View {
        HStack(spacing: 16) {
            // Grain count
            VStack(spacing: 2) {
                Text("GRAINS")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.synthSecondary)
                HStack(spacing: 4) {
                    Slider(value: Binding(
                        get: { Double(engine.grainCount) },
                        set: { engine.grainCount = Int($0); engine.resetGrains() }
                    ), in: 16...512, step: 16)
                    .frame(width: 80)
                    .tint(.cyan)
                    Text("\(engine.grainCount)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 28, alignment: .trailing)
                }
            }

            // Scatter radius
            VStack(spacing: 2) {
                Text("SCATTER")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.synthSecondary)
                HStack(spacing: 4) {
                    Slider(value: Binding(
                        get: { Double(engine.scatterRadius) },
                        set: { engine.scatterRadius = Float($0) }
                    ), in: 0.1...1.0)
                    .frame(width: 70)
                    .tint(.cyan)
                    Text(String(format: "%.0f%%", engine.scatterRadius * 100))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 32, alignment: .trailing)
                }
            }

            // Turbulence
            VStack(spacing: 2) {
                Text("TURB")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.synthSecondary)
                HStack(spacing: 4) {
                    Slider(value: Binding(
                        get: { Double(engine.turbulence) },
                        set: { engine.turbulence = Float($0) }
                    ), in: 0...1.0)
                    .frame(width: 70)
                    .tint(.cyan)
                    Text(String(format: "%.0f%%", engine.turbulence * 100))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 32, alignment: .trailing)
                }
            }

            // Lifetime
            VStack(spacing: 2) {
                Text("LIFE")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.synthSecondary)
                HStack(spacing: 4) {
                    Slider(value: Binding(
                        get: { Double(engine.particleLifetime) },
                        set: { engine.particleLifetime = Float($0) }
                    ), in: 0.5...20.0)
                    .frame(width: 70)
                    .tint(.cyan)
                    Text(String(format: "%.1fs", engine.particleLifetime))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 32, alignment: .trailing)
                }
            }

            // Distribution
            VStack(spacing: 2) {
                Text("DIST")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.synthSecondary)
                HStack(spacing: 3) {
                    ForEach(DistributionShape.allCases, id: \.rawValue) { shape in
                        Button(action: {
                            engine.distribution = shape
                            engine.resetGrains()
                        }) {
                            Text(String(shape.rawValue.prefix(4)))
                                .font(.system(size: 7, weight: .medium, design: .monospaced))
                                .foregroundColor(engine.distribution == shape ? .white : .synthTertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(engine.distribution == shape ? Color.cyan.opacity(0.2) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(engine.distribution == shape ? Color.cyan.opacity(0.5) : Color(white: 0.15), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            Spacer()

            // Pause button
            Button(action: { engine.isPaused.toggle() }) {
                HStack(spacing: 3) {
                    Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 9))
                    Text(engine.isPaused ? "PLAY" : "PAUSE")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                }
                .foregroundColor(engine.isPaused ? .orange : .synthSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.08)))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(engine.isPaused ? Color.orange.opacity(0.5) : Color(white: 0.15), lineWidth: 0.5)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(white: 0.04))
    }
}

// MARK: - Tool Overlay (visualizes placed tools on the canvas)


struct ToolOverlayView: View {
    let engine: CloudSculptorEngine
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            // Magnets
            ForEach(engine.magnets) { mag in
                let pos = normalizedToCanvas(mag.position, size: canvasSize)
                Circle()
                    .stroke(mag.isRepulsor ? Color.red.opacity(0.4) : Color.cyan.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Text("🧲")
                            .font(.system(size: 10))
                    )
                    .position(pos)
            }

            // Planets
            ForEach(engine.planets) { planet in
                let pos = normalizedToCanvas(planet.position, size: canvasSize)
                let radius = CGFloat(planet.mass) * 30 + 10
                Circle()
                    .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                    .frame(width: radius, height: radius)
                    .overlay(
                        Circle()
                            .stroke(Color.purple.opacity(0.15), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .frame(width: radius * 2, height: radius * 2)
                    )
                    .overlay(
                        Text("🪐")
                            .font(.system(size: CGFloat(planet.mass) * 8 + 8))
                    )
                    .position(pos)
            }

            // Emitters
            ForEach(engine.emitters) { emitter in
                let pos = normalizedToCanvas(emitter.position, size: canvasSize)
                let angle = Angle(radians: atan2(emitter.direction.dy, emitter.direction.dx))
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green.opacity(0.6))
                    .rotationEffect(angle + .degrees(-90))
                    .position(pos)
            }

            // Heat zones
            ForEach(engine.heatZones) { zone in
                let pos = normalizedToCanvas(zone.position, size: canvasSize)
                let r = CGFloat(zone.radius) * min(canvasSize.width, canvasSize.height) / 2
                Circle()
                    .fill(
                        zone.temperature > 0
                            ? Color.red.opacity(Double(min(abs(zone.temperature), 1.0)) * 0.15)
                            : Color.blue.opacity(Double(min(abs(zone.temperature), 1.0)) * 0.15)
                    )
                    .frame(width: r * 2, height: r * 2)
                    .position(pos)
            }

            // Active magnet
            if let mag = engine.activeMagnet {
                let pos = normalizedToCanvas(mag.position, size: canvasSize)
                Circle()
                    .stroke(mag.isRepulsor ? Color.red.opacity(0.6) : Color.cyan.opacity(0.6), lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .position(pos)
            }
        }
    }

    private func normalizedToCanvas(_ point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(
            x: (point.x + 1) / 2 * size.width,
            y: (1 - (point.y + 1) / 2) * size.height
        )
    }
}

// MARK: - Main Cloud Sculptor View


struct CloudSculptorView: View {
    var parameterTree: ObservableAUParameterGroup?
    var audioUnit: VoxExtensionAudioUnit?

    @State private var engine = CloudSculptorEngine()
    @State private var selectedTool: SculptorTool = .magnet
    @State private var canvasSize: CGSize = .zero
    @State private var zoom: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var lassoPoints: [CGPoint] = []

    var body: some View {
        VStack(spacing: 0) {
            // Main area: toolbar + canvas
            HStack(spacing: 0) {
                // Left toolbar
                SculptorToolbar(selectedTool: $selectedTool)

                // Canvas
                ZStack {
                    GeometryReader { geo in
                        CloudSculptorCanvas(engine: engine)
                            .scaleEffect(zoom)
                            .offset(panOffset)
                            .onAppear { canvasSize = geo.size }
                            .onChange(of: geo.size) { _, newSize in canvasSize = newSize }

                        // Tool overlays
                        ToolOverlayView(engine: engine, canvasSize: geo.size)
                            .scaleEffect(zoom)
                            .offset(panOffset)

                        // Lasso path for flock tool
                        if selectedTool == .flock && !lassoPoints.isEmpty {
                            Path { path in
                                path.addLines(lassoPoints)
                                if lassoPoints.count > 2 {
                                    path.closeSubpath()
                                }
                            }
                            .stroke(Color.yellow.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }

                        // Invisible interaction layer
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(dragGesture(in: geo.size))
                            .gesture(scrollGesture())
                            .onTapGesture(count: 2) { location in
                                handleDoubleTap(at: location, in: geo.size)
                            }
                            .onTapGesture { location in
                                handleTap(at: location, in: geo.size)
                            }
                    }
                }
                .clipShape(Rectangle())
                .background(Color(white: 0.02))
            }

            // Bottom panel
            CloudPropertiesPanel(engine: engine)
        }
        .background(Color.black)
        .onAppear {
            // Listen for spacebar
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 49 { // spacebar
                    engine.isPaused.toggle()
                    return nil
                }
                return event
            }
        }
    }

    // MARK: - Gesture Helpers

    private func canvasToNormalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (point.x / size.width) * 2 - 1,
            y: -((point.y / size.height) * 2 - 1)
        )
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let norm = canvasToNormalized(value.location, in: size)
                let optionDown = NSEvent.modifierFlags.contains(.option)

                switch selectedTool {
                case .magnet:
                    // Active magnet follows cursor
                    engine.activeMagnet = PlacedMagnet(
                        position: norm,
                        strength: 1.0,
                        isRepulsor: optionDown
                    )
                case .flock:
                    lassoPoints.append(value.location)
                case .heat:
                    let temp: Float = optionDown ? -1.0 : 1.0
                    engine.heatZones.append(HeatZone(
                        position: norm,
                        radius: 0.15,
                        temperature: temp
                    ))
                case .planet:
                    // If dragging on existing planet, adjust mass
                    if let idx = engine.planets.indices.first(where: { planetIdx in
                        let p = engine.planets[planetIdx]
                        let dx = p.position.x - norm.x
                        let dy = p.position.y - norm.y
                        return sqrt(dx * dx + dy * dy) < 0.1
                    }) {
                        if optionDown {
                            // Set spin from drag direction
                            let dx = value.translation.width
                            engine.planets[idx].spinDirection = dx > 0 ? 1.0 : -1.0
                        } else {
                            let dy = Float(-value.translation.height / 200)
                            engine.planets[idx].mass = max(0.1, min(1.0, engine.planets[idx].mass + dy))
                        }
                    }
                case .emitter:
                    // If dragging from emitter, set direction
                    if let idx = engine.emitters.indices.first(where: { emIdx in
                        let e = engine.emitters[emIdx]
                        let startNorm = canvasToNormalized(value.startLocation, in: size)
                        let dx = e.position.x - startNorm.x
                        let dy = e.position.y - startNorm.y
                        return sqrt(dx * dx + dy * dy) < 0.1
                    }) {
                        let dx = norm.x - engine.emitters[idx].position.x
                        let dy = norm.y - engine.emitters[idx].position.y
                        engine.emitters[idx].direction = CGVector(dx: dx, dy: dy)
                    }
                }
            }
            .onEnded { value in
                switch selectedTool {
                case .magnet:
                    engine.activeMagnet = nil
                case .flock:
                    // Create flock from lassoed grains
                    if lassoPoints.count > 2 {
                        var flock = FlockGroup()
                        flock.leaderPosition = canvasToNormalized(lassoPoints[0], in: size)
                        for (i, g) in engine.grains.enumerated() {
                            let canvasPos = CGPoint(
                                x: CGFloat((g.x + 1) / 2) * size.width,
                                y: CGFloat((1 - (g.y + 1) / 2)) * size.height
                            )
                            if pointInPolygon(canvasPos, polygon: lassoPoints) {
                                flock.grainIndices.append(i)
                                engine.grains[i].flockId = flock.id
                            }
                        }
                        if !flock.grainIndices.isEmpty {
                            engine.flocks.append(flock)
                        }
                    }
                    lassoPoints = []
                default:
                    break
                }
            }
    }

    private func scrollGesture() -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = max(0.5, min(3.0, value.magnification))
            }
    }

    private func handleTap(at location: CGPoint, in size: CGSize) {
        let norm = canvasToNormalized(location, in: size)
        switch selectedTool {
        case .planet:
            engine.planets.append(PlacedPlanet(position: norm))
        case .emitter:
            engine.emitters.append(PlacedEmitter(position: norm))
        default:
            break
        }
    }

    private func handleDoubleTap(at location: CGPoint, in size: CGSize) {
        let norm = canvasToNormalized(location, in: size)
        switch selectedTool {
        case .magnet:
            // Anchor magnet permanently
            let optionDown = NSEvent.modifierFlags.contains(.option)
            engine.magnets.append(PlacedMagnet(
                position: norm,
                strength: 1.0,
                isRepulsor: optionDown
            ))
        case .planet:
            // Remove planet if double-clicking on one
            engine.planets.removeAll { planet in
                let dx = planet.position.x - norm.x
                let dy = planet.position.y - norm.y
                return sqrt(dx * dx + dy * dy) < 0.1
            }
        default:
            break
        }
    }

    // Point-in-polygon test
    private func pointInPolygon(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count > 2 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let pi = polygon[i], pj = polygon[j]
            if (pi.y > point.y) != (pj.y > point.y) &&
               point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
