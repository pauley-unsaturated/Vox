//
//  TrajectoryComposerView.swift
//  VoxExtension
//
//  Trajectory Composer — Paradigm 4: Multi-track timeline for pre-designing
//  parameter evolution over time. DAW-style automation lanes with transport,
//  curve editing, trajectory presets, and via modulation.
//

import SwiftUI

// MARK: - Enums & Models

enum PlayheadMode: String, CaseIterable {
    case free = "Free"
    case noteSync = "Note-Sync"
    case loop = "Loop"
    case scrub = "Scrub"
}

enum CurveType: String, CaseIterable {
    case linear = "Linear"
    case exponential = "Exponential"
    case logarithmic = "Logarithmic"
    case sCurve = "S-Curve"
    case stepped = "Stepped"
    case stochastic = "Stochastic"
}

enum ViaSource: String, CaseIterable {
    case none = "None"
    case velocity = "Velocity"
    case aftertouch = "Aftertouch"
    case modWheel = "Mod Wheel"
    case lfo = "LFO"
    case chaos = "Chaos"
}

enum TrajectoryParameterKind: String, CaseIterable, Identifiable {
    case vowelMorph = "Vowel Morph"
    case grainDensity = "Grain Density"
    case chaosAmount = "Chaos Amount"
    case formantSweep = "Formant Sweep"
    case driftRate = "Drift Rate"
    case scatter = "Scatter"
    case pan = "Pan"
    case dutyCycle = "Duty Cycle"
    case filterQ = "Filter Q"
    case formantMix = "Formant Mix"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .vowelMorph:    return .orange
        case .grainDensity:  return .cyan
        case .chaosAmount:   return .red
        case .formantSweep:  return .purple
        case .driftRate:     return .green
        case .scatter:       return .yellow
        case .pan:           return .blue
        case .dutyCycle:     return .mint
        case .filterQ:       return .pink
        case .formantMix:    return .indigo
        }
    }
}

struct AutomationPoint: Identifiable, Equatable {
    let id: UUID
    var time: Double   // 0..1 normalized within total duration
    var value: Double  // 0..1
    var curveType: CurveType

    init(time: Double, value: Double, curveType: CurveType = .linear) {
        self.id = UUID()
        self.time = time
        self.value = value
        self.curveType = curveType
    }
}

struct TrajectoryPreset: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let lanes: [(TrajectoryParameterKind, [AutomationPoint])]
}

// MARK: - Automation Lane Model

@Observable
final class AutomationLane: Identifiable {
    let id = UUID()
    var parameter: TrajectoryParameterKind
    var points: [AutomationPoint]
    var isMuted: Bool = false
    var isSoloed: Bool = false
    var isEditing: Bool = true
    var curveType: CurveType = .linear
    var viaSource: ViaSource = .none

    init(parameter: TrajectoryParameterKind, points: [AutomationPoint] = []) {
        self.parameter = parameter
        self.points = points.isEmpty ? Self.defaultPoints() : points
    }

    static func defaultPoints() -> [AutomationPoint] {
        [
            AutomationPoint(time: 0.0, value: 0.3),
            AutomationPoint(time: 0.25, value: 0.7),
            AutomationPoint(time: 0.5, value: 0.4),
            AutomationPoint(time: 0.75, value: 0.8),
            AutomationPoint(time: 1.0, value: 0.5),
        ]
    }

    func valueAt(_ t: Double) -> Double {
        let sorted = points.sorted { $0.time < $1.time }
        guard !sorted.isEmpty else { return 0.5 }
        if t <= sorted.first!.time { return sorted.first!.value }
        if t >= sorted.last!.time { return sorted.last!.value }

        for i in 0..<(sorted.count - 1) {
            let p0 = sorted[i]
            let p1 = sorted[i + 1]
            if t >= p0.time && t <= p1.time {
                let frac = (t - p0.time) / max(p1.time - p0.time, 0.0001)
                return interpolate(from: p0.value, to: p1.value, frac: frac, curve: p0.curveType)
            }
        }
        return sorted.last!.value
    }

    private func interpolate(from a: Double, to b: Double, frac t: Double, curve: CurveType) -> Double {
        let mapped: Double
        switch curve {
        case .linear:
            mapped = t
        case .exponential:
            mapped = t * t
        case .logarithmic:
            mapped = sqrt(t)
        case .sCurve:
            mapped = t * t * (3 - 2 * t)
        case .stepped:
            mapped = t < 1.0 ? 0.0 : 1.0
        case .stochastic:
            mapped = t + Double.random(in: -0.05...0.05)
        }
        return a + (b - a) * min(max(mapped, 0), 1)
    }
}

// MARK: - Trajectory Engine

@Observable
final class TrajectoryEngine {
    var lanes: [AutomationLane] = []
    var isPlaying: Bool = false
    var playheadPosition: Double = 0.0  // 0..1
    var bpm: Double = 120.0
    var totalBars: Int = 8
    var isLooping: Bool = false
    var playheadMode: PlayheadMode = .free
    var showLibrary: Bool = false

    private var timer: Timer?

    var totalDurationSeconds: Double {
        let beatsPerBar = 4.0
        let totalBeats = Double(totalBars) * beatsPerBar
        return totalBeats / bpm * 60.0
    }

    var currentTimeString: String {
        let seconds = playheadPosition * totalDurationSeconds
        let mins = Int(seconds) / 60
        let secs = seconds - Double(mins * 60)
        return String(format: "%d:%05.2f", mins, secs)
    }

    var totalTimeString: String {
        let seconds = totalDurationSeconds
        let mins = Int(seconds) / 60
        let secs = seconds - Double(mins * 60)
        return String(format: "%d:%05.2f", mins, secs)
    }

    init() {
        lanes = [
            AutomationLane(parameter: .vowelMorph),
            AutomationLane(parameter: .grainDensity),
            AutomationLane(parameter: .chaosAmount),
            AutomationLane(parameter: .formantSweep),
        ]
    }

    func play() {
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let increment = (1.0 / 60.0) / self.totalDurationSeconds
            self.playheadPosition += increment
            if self.playheadPosition >= 1.0 {
                if self.isLooping {
                    self.playheadPosition = 0.0
                } else {
                    self.stop()
                }
            }
        }
    }

    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        playheadPosition = 0.0
    }

    func rewind() {
        playheadPosition = 0.0
    }

    func addLane(_ param: TrajectoryParameterKind) {
        guard !lanes.contains(where: { $0.parameter == param }) else { return }
        lanes.append(AutomationLane(parameter: param))
    }

    func removeLane(_ lane: AutomationLane) {
        lanes.removeAll { $0.id == lane.id }
    }

    func loadPreset(_ preset: TrajectoryPreset) {
        lanes.removeAll()
        for (param, points) in preset.lanes {
            lanes.append(AutomationLane(parameter: param, points: points))
        }
    }
}

// MARK: - Factory Presets

extension TrajectoryEngine {
    static let factoryPresets: [TrajectoryPreset] = [
        TrajectoryPreset(
            name: "Dawn Rise",
            icon: "🌅",
            description: "Slow brightening over time",
            lanes: [
                (.vowelMorph, [
                    AutomationPoint(time: 0, value: 0.0),
                    AutomationPoint(time: 0.5, value: 0.3, curveType: .logarithmic),
                    AutomationPoint(time: 1.0, value: 0.9, curveType: .exponential),
                ]),
                (.grainDensity, [
                    AutomationPoint(time: 0, value: 0.1),
                    AutomationPoint(time: 0.7, value: 0.5, curveType: .sCurve),
                    AutomationPoint(time: 1.0, value: 0.95, curveType: .sCurve),
                ]),
                (.formantSweep, [
                    AutomationPoint(time: 0, value: 0.2),
                    AutomationPoint(time: 1.0, value: 0.8, curveType: .logarithmic),
                ]),
            ]
        ),
        TrajectoryPreset(
            name: "Wave Cycle",
            icon: "🌊",
            description: "Periodic oscillation",
            lanes: [
                (.vowelMorph, (0..<9).map { i in
                    let t = Double(i) / 8.0
                    return AutomationPoint(time: t, value: i % 2 == 0 ? 0.2 : 0.8, curveType: .sCurve)
                }),
                (.chaosAmount, (0..<9).map { i in
                    let t = Double(i) / 8.0
                    return AutomationPoint(time: t, value: i % 2 == 0 ? 0.8 : 0.2, curveType: .sCurve)
                }),
            ]
        ),
        TrajectoryPreset(
            name: "Starburst",
            icon: "💫",
            description: "Explosive texture buildup",
            lanes: [
                (.chaosAmount, [
                    AutomationPoint(time: 0, value: 0.0),
                    AutomationPoint(time: 0.3, value: 0.1, curveType: .linear),
                    AutomationPoint(time: 0.5, value: 1.0, curveType: .exponential),
                    AutomationPoint(time: 0.7, value: 0.3, curveType: .logarithmic),
                    AutomationPoint(time: 1.0, value: 0.0, curveType: .exponential),
                ]),
                (.grainDensity, [
                    AutomationPoint(time: 0, value: 0.2),
                    AutomationPoint(time: 0.5, value: 1.0, curveType: .exponential),
                    AutomationPoint(time: 1.0, value: 0.1, curveType: .logarithmic),
                ]),
            ]
        ),
        TrajectoryPreset(
            name: "Vowel Phrase",
            icon: "🎭",
            description: "A → E → I → O → U morph",
            lanes: [
                (.vowelMorph, [
                    AutomationPoint(time: 0.0, value: 0.0),
                    AutomationPoint(time: 0.2, value: 0.25, curveType: .sCurve),
                    AutomationPoint(time: 0.4, value: 0.5, curveType: .sCurve),
                    AutomationPoint(time: 0.6, value: 0.75, curveType: .sCurve),
                    AutomationPoint(time: 0.8, value: 1.0, curveType: .sCurve),
                    AutomationPoint(time: 1.0, value: 0.0, curveType: .sCurve),
                ]),
            ]
        ),
    ]
}

// MARK: - Transport Bar

struct TransportBar: View {
    @Bindable var engine: TrajectoryEngine

    var body: some View {
        HStack(spacing: 0) {
            // Transport buttons
            HStack(spacing: 4) {
                transportButton("backward.end.fill") { engine.rewind() }
                transportButton(engine.isPlaying ? "pause.fill" : "play.fill") {
                    engine.isPlaying ? engine.pause() : engine.play()
                }
                transportButton("stop.fill") { engine.stop() }
            }
            .padding(.horizontal, 8)

            // Time display
            HStack(spacing: 2) {
                Text(engine.currentTimeString)
                    .foregroundColor(.white)
                Text("/")
                    .foregroundColor(.synthTertiary)
                Text(engine.totalTimeString)
                    .foregroundColor(.synthSecondary)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .padding(.horizontal, 8)

            Divider().frame(height: 20).background(Color(white: 0.2))

            // BPM
            HStack(spacing: 4) {
                Text("BPM")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.synthSecondary)
                TextField("", value: $engine.bpm, format: .number)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 40)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .background(Color(white: 0.08))
                    .cornerRadius(3)
            }
            .padding(.horizontal, 8)

            Divider().frame(height: 20).background(Color(white: 0.2))

            // Loop toggle
            Button(action: { engine.isLooping.toggle() }) {
                Image(systemName: "repeat")
                    .font(.system(size: 11, weight: engine.isLooping ? .bold : .regular))
                    .foregroundColor(engine.isLooping ? .cyan : .synthTertiary)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 8)

            Divider().frame(height: 20).background(Color(white: 0.2))

            // Playhead mode
            HStack(spacing: 3) {
                ForEach(PlayheadMode.allCases, id: \.rawValue) { mode in
                    Button(action: { engine.playheadMode = mode }) {
                        Text(mode.rawValue)
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(engine.playheadMode == mode ? .white : .synthTertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(engine.playheadMode == mode ? Color.cyan.opacity(0.2) : Color.clear)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // Library toggle
            Button(action: { engine.showLibrary.toggle() }) {
                HStack(spacing: 3) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 10))
                    Text("LIBRARY")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                }
                .foregroundColor(engine.showLibrary ? .cyan : .synthTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(engine.showLibrary ? Color.cyan.opacity(0.1) : Color.clear)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 8)
        }
        .frame(height: 32)
        .background(Color(white: 0.05))
    }

    @ViewBuilder
    private func transportButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.12))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Time Ruler

struct TimeRuler: View {
    let totalBars: Int
    let playheadPosition: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                // Bar markers
                ForEach(0...totalBars, id: \.self) { bar in
                    let x = (CGFloat(bar) / CGFloat(totalBars)) * w
                    Rectangle()
                        .fill(Color(white: 0.25))
                        .frame(width: 1)
                        .offset(x: x)

                    if bar < totalBars {
                        Text("\(bar + 1)")
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundColor(.synthTertiary)
                            .offset(x: x + 3, y: 0)
                    }

                    // Beat subdivisions
                    if bar < totalBars {
                        ForEach(1..<4, id: \.self) { beat in
                            let bx = x + (CGFloat(beat) / 4.0) * (w / CGFloat(totalBars))
                            Rectangle()
                                .fill(Color(white: 0.12))
                                .frame(width: 0.5)
                                .offset(x: bx)
                        }
                    }
                }
            }
        }
        .frame(height: 16)
        .background(Color(white: 0.04))
        .clipped()
    }
}

// MARK: - Automation Lane View

struct AutomationLaneView: View {
    @Bindable var lane: AutomationLane
    let laneHeight: CGFloat
    @Binding var selectedPointId: UUID?
    var onDelete: () -> Void

    @State private var dragPointId: UUID?
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 0) {
            // Lane header
            laneHeader
                .frame(width: 130)

            // Curve area
            GeometryReader { geo in
                ZStack {
                    // Background grid
                    laneGrid(size: geo.size)

                    // Automation curve
                    automationCurve(size: geo.size)

                    // Control points
                    controlPoints(size: geo.size)
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { location in
                    // Double-click to add point
                    let t = Double(location.x / geo.size.width)
                    let v = 1.0 - Double(location.y / geo.size.height)
                    let point = AutomationPoint(time: max(0, min(1, t)), value: max(0, min(1, v)), curveType: lane.curveType)
                    lane.points.append(point)
                    lane.points.sort { $0.time < $1.time }
                }
            }
            .frame(height: laneHeight)
            .background(Color(white: 0.03))
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .background(Color(white: 0.04))
    }

    // MARK: Lane Header

    @ViewBuilder
    private var laneHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Parameter name
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(lane.parameter.color)
                    .frame(width: 4, height: 12)
                Text(lane.parameter.rawValue.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(lane.parameter.color)
                    .lineLimit(1)
            }

            // Controls row
            HStack(spacing: 3) {
                laneButton("S", isActive: lane.isSoloed, color: .yellow) { lane.isSoloed.toggle() }
                laneButton("M", isActive: lane.isMuted, color: .red) { lane.isMuted.toggle() }
                laneButton("✎", isActive: lane.isEditing, color: .cyan) { lane.isEditing.toggle() }
                laneButton("×", isActive: false, color: .gray, action: onDelete)
            }

            // Curve type
            Menu {
                ForEach(CurveType.allCases, id: \.rawValue) { curve in
                    Button(curve.rawValue) { lane.curveType = curve }
                }
            } label: {
                HStack(spacing: 2) {
                    Text("Curve:")
                        .font(.system(size: 6, design: .monospaced))
                        .foregroundColor(.synthTertiary)
                    Text(lane.curveType.rawValue)
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 5))
                        .foregroundColor(.synthTertiary)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Via modulation
            Menu {
                ForEach(ViaSource.allCases, id: \.rawValue) { via in
                    Button(via.rawValue) { lane.viaSource = via }
                }
            } label: {
                HStack(spacing: 2) {
                    Text("Via:")
                        .font(.system(size: 6, design: .monospaced))
                        .foregroundColor(.synthTertiary)
                    Text(lane.viaSource.rawValue)
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(lane.viaSource == .none ? .synthTertiary : .cyan)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 5))
                        .foregroundColor(.synthTertiary)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color(white: 0.06))
    }

    @ViewBuilder
    private func laneButton(_ label: String, isActive: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(isActive ? color : .synthTertiary)
                .frame(width: 18, height: 14)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActive ? color.opacity(0.15) : Color(white: 0.08))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Grid

    @ViewBuilder
    private func laneGrid(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            // Horizontal value lines
            for i in 1..<4 {
                let y = canvasSize.height * CGFloat(i) / 4.0
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: canvasSize.width, y: y))
                }
                context.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
            }
        }
    }

    // MARK: Automation Curve

    @ViewBuilder
    private func automationCurve(size: CGSize) -> some View {
        let sorted = lane.points.sorted { $0.time < $1.time }
        let color = lane.isMuted ? Color.gray.opacity(0.3) : lane.parameter.color

        Canvas { context, canvasSize in
            guard sorted.count >= 2 else { return }

            // Draw filled area
            var fillPath = Path()
            fillPath.move(to: CGPoint(x: sorted[0].time * canvasSize.width, y: canvasSize.height))
            for i in 0..<sorted.count {
                let pt = sorted[i]
                fillPath.addLine(to: CGPoint(x: pt.time * canvasSize.width, y: (1 - pt.value) * canvasSize.height))
            }
            fillPath.addLine(to: CGPoint(x: sorted.last!.time * canvasSize.width, y: canvasSize.height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(color.opacity(0.08)))

            // Draw curve line with many segments for smooth interpolation
            var linePath = Path()
            let steps = Int(canvasSize.width)
            for step in 0...steps {
                let t = Double(step) / Double(steps)
                let clampedT = max(sorted.first!.time, min(sorted.last!.time, t))
                let val = lane.valueAt(clampedT)
                let pt = CGPoint(x: t * canvasSize.width, y: (1 - val) * canvasSize.height)
                if step == 0 {
                    linePath.move(to: pt)
                } else {
                    linePath.addLine(to: pt)
                }
            }
            context.stroke(linePath, with: .color(color), lineWidth: 1.5)
        }
    }

    // MARK: Control Points

    @ViewBuilder
    private func controlPoints(size: CGSize) -> some View {
        let sorted = lane.points.sorted { $0.time < $1.time }
        ForEach(sorted) { point in
            let x = point.time * size.width
            let y = (1 - point.value) * size.height
            let isSelected = selectedPointId == point.id
            let pointSize: CGFloat = isSelected ? 8 : 6

            Circle()
                .fill(lane.parameter.color)
                .frame(width: pointSize, height: pointSize)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1.5)
                )
                .position(x: x, y: y)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { drag in
                            guard lane.isEditing else { return }
                            selectedPointId = point.id
                            if let idx = lane.points.firstIndex(where: { $0.id == point.id }) {
                                let newT = max(0, min(1, Double(drag.location.x / size.width)))
                                let newV = max(0, min(1, 1.0 - Double(drag.location.y / size.height)))
                                lane.points[idx].time = newT
                                lane.points[idx].value = newV
                            }
                        }
                        .onEnded { _ in
                            lane.points.sort { $0.time < $1.time }
                        }
                )
                .onTapGesture {
                    selectedPointId = point.id
                }
        }
    }
}

// MARK: - Trajectory Library Panel

struct TrajectoryLibraryPanel: View {
    @Bindable var engine: TrajectoryEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRAJECTORY LIBRARY")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            // Factory presets
            VStack(alignment: .leading, spacing: 2) {
                Text("📁 Factory")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.synthSecondary)

                ForEach(TrajectoryEngine.factoryPresets) { preset in
                    Button(action: { engine.loadPreset(preset) }) {
                        HStack(spacing: 4) {
                            Text(preset.icon)
                                .font(.system(size: 12))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(preset.name)
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text(preset.description)
                                    .font(.system(size: 6, design: .monospaced))
                                    .foregroundColor(.synthTertiary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(white: 0.06))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Divider().background(Color(white: 0.15))

            // User presets placeholder
            VStack(alignment: .leading, spacing: 2) {
                Text("📁 User")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.synthSecondary)

                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan.opacity(0.5))
                        Text("Save Current...")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.cyan.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3]))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()
        }
        .padding(8)
        .frame(width: 160)
        .background(Color(white: 0.04))
    }
}

// MARK: - Main Trajectory Composer View

struct TrajectoryComposerView: View {
    var parameterTree: ObservableAUParameterGroup?
    var audioUnit: VoxExtensionAudioUnit?

    @State private var engine = TrajectoryEngine()
    @State private var selectedPointId: UUID?
    @State private var showAddLane = false

    private let laneHeight: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            // Transport bar
            TransportBar(engine: engine)

            // Main content
            HStack(spacing: 0) {
                // Timeline area
                VStack(spacing: 0) {
                    // Time ruler + playhead
                    ZStack(alignment: .leading) {
                        HStack(spacing: 0) {
                            Color(white: 0.06).frame(width: 130)
                            TimeRuler(totalBars: engine.totalBars, playheadPosition: engine.playheadPosition)
                        }
                        // Playhead on ruler
                        GeometryReader { geo in
                            let offset = 130 + (geo.size.width - 130) * engine.playheadPosition
                            Rectangle()
                                .fill(Color.cyan)
                                .frame(width: 1.5)
                                .offset(x: offset)
                        }
                    }
                    .frame(height: 16)

                    // Lanes
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 1) {
                            ForEach(engine.lanes) { lane in
                                ZStack {
                                    AutomationLaneView(
                                        lane: lane,
                                        laneHeight: laneHeight,
                                        selectedPointId: $selectedPointId,
                                        onDelete: { engine.removeLane(lane) }
                                    )

                                    // Playhead overlay
                                    GeometryReader { geo in
                                        let headerWidth: CGFloat = 130
                                        let curveWidth = geo.size.width - headerWidth
                                        let x = headerWidth + curveWidth * engine.playheadPosition
                                        Rectangle()
                                            .fill(Color.cyan.opacity(0.7))
                                            .frame(width: 1)
                                            .offset(x: x)

                                        // Current value indicator
                                        let currentVal = lane.valueAt(engine.playheadPosition)
                                        let dotY = (1 - currentVal) * Double(laneHeight)
                                        Circle()
                                            .fill(Color.cyan)
                                            .frame(width: 5, height: 5)
                                            .position(x: x, y: dotY)
                                    }
                                }
                            }

                            // Add lane button
                            addLaneBar
                        }
                    }
                }

                // Library sidebar
                if engine.showLibrary {
                    Divider().background(Color(white: 0.15))
                    TrajectoryLibraryPanel(engine: engine)
                }
            }
        }
        .background(Color.black)
    }

    @ViewBuilder
    private var addLaneBar: some View {
        HStack {
            Menu {
                let availableParams = TrajectoryParameterKind.allCases.filter { param in
                    !engine.lanes.contains { $0.parameter == param }
                }
                ForEach(availableParams) { param in
                    Button(action: { engine.addLane(param) }) {
                        HStack {
                            Circle()
                                .fill(param.color)
                                .frame(width: 8, height: 8)
                            Text(param.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11))
                    Text("ADD LANE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.cyan.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .menuStyle(.borderlessButton)

            Spacer()
        }
        .frame(height: 28)
        .background(Color(white: 0.03))
    }
}

// MARK: - Preview

#Preview {
    TrajectoryComposerView(parameterTree: nil, audioUnit: nil)
        .frame(width: 800, height: 500)
}
