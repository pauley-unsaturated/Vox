//
//  ParameterSpaceNavigatorView.swift
//  VoxExtension
//
//  Parameter Space Navigator — Paradigm 2
//  An XY exploration surface for traveling through timbral space.
//  "Don't adjust parameters. Travel through sound."
//

import SwiftUI

// MARK: - Data Models

/// A snapshot position storing a complete parameter state at an XY location.
struct NavigatorSnapshot: Identifiable {
    let id: String  // "A", "B", "C", "D"
    var position: CGPoint  // normalized 0...1
    var color: Color
    
    /// Parameter values this snapshot represents (param name → value 0...1)
    var parameterValues: [String: Float] = [:]
}

/// A recorded cursor trail point with timestamp.
struct GesturePoint {
    var position: CGPoint
    var timestamp: TimeInterval
}

/// Axis mapping preset.
enum AxisMappingPreset: String, CaseIterable, Identifiable {
    case timbral = "Timbral"
    case vowelSpace = "Vowel Space"
    case texture = "Texture"
    case energy = "Energy"
    
    var id: String { rawValue }
    
    var xLabel: String {
        switch self {
        case .timbral:   return "Brightness"
        case .vowelSpace: return "Front ↔ Back"
        case .texture:   return "Sparse ↔ Dense"
        case .energy:    return "Calm ↔ Aggressive"
        }
    }
    
    var yLabel: String {
        switch self {
        case .timbral:   return "Density"
        case .vowelSpace: return "Open ↔ Closed"
        case .texture:   return "Static ↔ Moving"
        case .energy:    return "Smooth ↔ Rough"
        }
    }
    
    var xParams: [(String, Int)] {
        switch self {
        case .timbral:   return [("Vowel Morph", 40), ("F1/F2 Ratio", 30), ("Harmonics", 30)]
        case .vowelSpace: return [("F1 Frequency", 80), ("Formant Mix", 20)]
        case .texture:   return [("Grain Density", 60), ("Stoch Scatter", 40)]
        case .energy:    return [("Chaos Amount", 50), ("Stoch Scatter", 30), ("Duty Cycle", 20)]
        }
    }
    
    var yParams: [(String, Int)] {
        switch self {
        case .timbral:   return [("Grain Density", 50), ("Chaos Amount", 30), ("Stoch Scatter", 20)]
        case .vowelSpace: return [("F2 Frequency", 80), ("Formant Mix", 20)]
        case .texture:   return [("LFO Rate", 40), ("Drift Amount", 30), ("Chaos Amount", 30)]
        case .energy:    return [("Duty Cycle", 50), ("Grain Density", 30), ("Harmonics", 20)]
        }
    }
    
    var xAxisNeg: String {
        switch self {
        case .timbral:   return "DARK"
        case .vowelSpace: return "FRONT"
        case .texture:   return "SPARSE"
        case .energy:    return "CALM"
        }
    }
    
    var xAxisPos: String {
        switch self {
        case .timbral:   return "BRIGHT"
        case .vowelSpace: return "BACK"
        case .texture:   return "DENSE"
        case .energy:    return "AGGRESSIVE"
        }
    }
    
    var yAxisNeg: String {
        switch self {
        case .timbral:   return "SPARSE"
        case .vowelSpace: return "CLOSED"
        case .texture:   return "STATIC"
        case .energy:    return "SMOOTH"
        }
    }
    
    var yAxisPos: String {
        switch self {
        case .timbral:   return "DENSE"
        case .vowelSpace: return "OPEN"
        case .texture:   return "MOVING"
        case .energy:    return "ROUGH"
        }
    }
}

// MARK: - Navigator State

/// Observable state for the parameter space navigator.
@Observable
class NavigatorState {
    /// Current cursor position (normalized 0...1).
    var cursorPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    
    /// Trail of recent cursor positions (newest last).
    var trail: [CGPoint] = []
    let maxTrailLength = 200
    
    /// Snapshot positions.
    var snapshots: [NavigatorSnapshot] = [
        NavigatorSnapshot(id: "A", position: CGPoint(x: 0.15, y: 0.15), color: .red),
        NavigatorSnapshot(id: "B", position: CGPoint(x: 0.85, y: 0.15), color: .green),
        NavigatorSnapshot(id: "C", position: CGPoint(x: 0.15, y: 0.85), color: .blue),
        NavigatorSnapshot(id: "D", position: CGPoint(x: 0.85, y: 0.85), color: .yellow),
    ]
    
    /// Current axis mapping preset.
    var mappingPreset: AxisMappingPreset = .timbral
    
    /// Gesture recording state.
    var isRecording = false
    var isPlaying = false
    var isLooping = false
    var playbackSpeed: Double = 1.0
    var recordedGesture: [GesturePoint] = []
    
    /// Secondary navigator positions.
    var modXY: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var spaceXY: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var chaosXY: CGPoint = CGPoint(x: 0.5, y: 0.5)
    
    /// Playback timer.
    var playbackStartTime: Date?
    
    func moveCursor(to pos: CGPoint) {
        let clamped = CGPoint(
            x: min(max(pos.x, 0), 1),
            y: min(max(pos.y, 0), 1)
        )
        cursorPosition = clamped
        trail.append(clamped)
        if trail.count > maxTrailLength {
            trail.removeFirst(trail.count - maxTrailLength)
        }
        
        if isRecording {
            recordedGesture.append(GesturePoint(
                position: clamped,
                timestamp: Date().timeIntervalSinceReferenceDate
            ))
        }
    }
    
    func jumpToSnapshot(_ id: String) {
        if let snap = snapshots.first(where: { $0.id == id }) {
            moveCursor(to: snap.position)
        }
    }
    
    func toggleRecording() {
        if isRecording {
            isRecording = false
        } else {
            recordedGesture = []
            isRecording = true
        }
    }
}

// MARK: - Primary XY Pad

struct PrimaryNavigatorPad: View {
    @Bindable var state: NavigatorState
    var parameterTree: ObservableAUParameterGroup?
    
    @State private var isDragging = false
    @State private var draggingSnapshot: String? = nil
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            
            ZStack {
                // Background
                Rectangle()
                    .fill(Color(white: 0.03))
                
                // Grid lines
                gridLines(size: size)
                
                // Snapshot connecting lines
                snapshotConnections(size: size)
                
                // Trail
                trailPath(size: size)
                
                // Snapshot dots
                ForEach(state.snapshots) { snap in
                    snapshotDot(snap: snap, size: size)
                }
                
                // Cursor
                cursorView(size: size)
                
                // Axis labels
                axisLabels(size: size)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let normalized = CGPoint(
                            x: value.location.x / size.width,
                            y: value.location.y / size.height
                        )
                        
                        // Check if we're dragging a snapshot
                        if !isDragging {
                            isDragging = true
                            for snap in state.snapshots {
                                let snapPx = CGPoint(x: snap.position.x * size.width, y: snap.position.y * size.height)
                                let dist = hypot(value.location.x - snapPx.x, value.location.y - snapPx.y)
                                if dist < 20 {
                                    draggingSnapshot = snap.id
                                    break
                                }
                            }
                        }
                        
                        if let snapId = draggingSnapshot {
                            if let idx = state.snapshots.firstIndex(where: { $0.id == snapId }) {
                                state.snapshots[idx].position = CGPoint(
                                    x: min(max(normalized.x, 0), 1),
                                    y: min(max(normalized.y, 0), 1)
                                )
                            }
                        } else {
                            state.moveCursor(to: normalized)
                            updateParameters()
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        draggingSnapshot = nil
                    }
            )
        }
    }
    
    private func updateParameters() {
        // Map cursor position to actual AU parameters based on mapping preset
        guard let tree = parameterTree else { return }
        let x = Float(state.cursorPosition.x)
        let y = Float(state.cursorPosition.y)
        
        switch state.mappingPreset {
        case .timbral:
            tree.formantFilter.vowelMorph.value = x * (tree.formantFilter.vowelMorph.max - tree.formantFilter.vowelMorph.min) + tree.formantFilter.vowelMorph.min
        case .vowelSpace:
            tree.formantFilter.formant1Freq.value = x * (tree.formantFilter.formant1Freq.max - tree.formantFilter.formant1Freq.min) + tree.formantFilter.formant1Freq.min
            tree.formantFilter.formant2Freq.value = y * (tree.formantFilter.formant2Freq.max - tree.formantFilter.formant2Freq.min) + tree.formantFilter.formant2Freq.min
        case .texture, .energy:
            tree.formantFilter.vowelMorph.value = x * (tree.formantFilter.vowelMorph.max - tree.formantFilter.vowelMorph.min) + tree.formantFilter.vowelMorph.min
        }
    }
    
    @ViewBuilder
    private func gridLines(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let gridCount = 8
            for i in 1..<gridCount {
                let xFrac = CGFloat(i) / CGFloat(gridCount)
                let yFrac = CGFloat(i) / CGFloat(gridCount)
                
                // Vertical line
                var vPath = Path()
                vPath.move(to: CGPoint(x: xFrac * canvasSize.width, y: 0))
                vPath.addLine(to: CGPoint(x: xFrac * canvasSize.width, y: canvasSize.height))
                context.stroke(vPath, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
                
                // Horizontal line
                var hPath = Path()
                hPath.move(to: CGPoint(x: 0, y: yFrac * canvasSize.height))
                hPath.addLine(to: CGPoint(x: canvasSize.width, y: yFrac * canvasSize.height))
                context.stroke(hPath, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
            }
            
            // Center crosshair
            var cx = Path()
            cx.move(to: CGPoint(x: canvasSize.width / 2, y: 0))
            cx.addLine(to: CGPoint(x: canvasSize.width / 2, y: canvasSize.height))
            context.stroke(cx, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
            
            var cy = Path()
            cy.move(to: CGPoint(x: 0, y: canvasSize.height / 2))
            cy.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height / 2))
            context.stroke(cy, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
        }
    }
    
    @ViewBuilder
    private func snapshotConnections(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let positions = state.snapshots.map { CGPoint(x: $0.position.x * canvasSize.width, y: $0.position.y * canvasSize.height) }
            guard positions.count == 4 else { return }
            
            // Draw edges: A-B, B-D, D-C, C-A, A-D, B-C
            let edges = [(0,1), (1,3), (3,2), (2,0), (0,3), (1,2)]
            for (i, j) in edges {
                var path = Path()
                path.move(to: positions[i])
                path.addLine(to: positions[j])
                context.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 0.5)
            }
        }
    }
    
    @ViewBuilder
    private func trailPath(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let points = state.trail
            guard points.count > 1 else { return }
            
            let total = points.count
            for i in 1..<total {
                let age = CGFloat(i) / CGFloat(total)
                let from = CGPoint(x: points[i-1].x * canvasSize.width, y: points[i-1].y * canvasSize.height)
                let to = CGPoint(x: points[i].x * canvasSize.width, y: points[i].y * canvasSize.height)
                
                var seg = Path()
                seg.move(to: from)
                seg.addLine(to: to)
                context.stroke(seg, with: .color(.cyan.opacity(Double(age) * 0.6)), lineWidth: 1.5 * age)
            }
        }
    }
    
    @ViewBuilder
    private func snapshotDot(snap: NavigatorSnapshot, size: CGSize) -> some View {
        let pos = CGPoint(x: snap.position.x * size.width, y: snap.position.y * size.height)
        
        ZStack {
            // Glow
            Circle()
                .fill(snap.color.opacity(0.15))
                .frame(width: 28, height: 28)
            
            // Ring
            Circle()
                .stroke(snap.color, lineWidth: 2)
                .frame(width: 18, height: 18)
            
            // Label
            Text(snap.id)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(snap.color)
        }
        .position(pos)
    }
    
    @ViewBuilder
    private func cursorView(size: CGSize) -> some View {
        let pos = CGPoint(x: state.cursorPosition.x * size.width, y: state.cursorPosition.y * size.height)
        
        ZStack {
            // Outer glow
            Circle()
                .fill(Color.cyan.opacity(0.15))
                .frame(width: 36, height: 36)
            
            // Mid glow
            Circle()
                .fill(Color.cyan.opacity(0.3))
                .frame(width: 18, height: 18)
            
            // Core
            Circle()
                .fill(Color.cyan)
                .frame(width: 8, height: 8)
        }
        .position(pos)
        .animation(.interactiveSpring(response: 0.05), value: state.cursorPosition.x)
        .animation(.interactiveSpring(response: 0.05), value: state.cursorPosition.y)
    }
    
    @ViewBuilder
    private func axisLabels(size: CGSize) -> some View {
        let preset = state.mappingPreset
        
        // Left label
        Text(preset.xAxisNeg)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.25))
            .position(x: 30, y: size.height / 2)
        
        // Right label
        Text(preset.xAxisPos)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.25))
            .position(x: size.width - 30, y: size.height / 2)
        
        // Top label
        Text(preset.yAxisNeg)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.25))
            .position(x: size.width / 2, y: 12)
        
        // Bottom label
        Text(preset.yAxisPos)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.25))
            .position(x: size.width / 2, y: size.height - 12)
    }
}

// MARK: - Mini XY Pad

struct MiniXYPad: View {
    let title: String
    let xLabel: String
    let yLabel: String
    let accentColor: Color
    @Binding var position: CGPoint
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(accentColor)
            
            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(white: 0.04))
                    
                    // Grid
                    Path { path in
                        path.move(to: CGPoint(x: size.width / 2, y: 0))
                        path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                        path.move(to: CGPoint(x: 0, y: size.height / 2))
                        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    }
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    
                    // Cursor
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.2))
                            .frame(width: 20, height: 20)
                        Circle()
                            .fill(accentColor)
                            .frame(width: 6, height: 6)
                    }
                    .position(x: position.x * size.width, y: position.y * size.height)
                    
                    // Border
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            position = CGPoint(
                                x: min(max(value.location.x / size.width, 0), 1),
                                y: min(max(value.location.y / size.height, 0), 1)
                            )
                        }
                )
            }
            .aspectRatio(1, contentMode: .fit)
            
            HStack {
                Text(xLabel)
                    .font(.system(size: 6, weight: .medium, design: .monospaced))
                    .foregroundColor(.synthTertiary)
                Spacer()
                Text(yLabel)
                    .font(.system(size: 6, weight: .medium, design: .monospaced))
                    .foregroundColor(.synthTertiary)
            }
        }
    }
}

// MARK: - Axis Config Sidebar

struct AxisConfigSidebar: View {
    @Bindable var state: NavigatorState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Mapping preset picker
            VStack(alignment: .leading, spacing: 4) {
                Text("MAPPING")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Picker("", selection: $state.mappingPreset) {
                    ForEach(AxisMappingPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(.cyan)
            }
            
            Divider().background(Color.cyan.opacity(0.2))
            
            // X-Axis
            VStack(alignment: .leading, spacing: 4) {
                Text("X-AXIS: \(state.mappingPreset.xLabel.uppercased())")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                
                ForEach(state.mappingPreset.xParams, id: \.0) { param, weight in
                    HStack {
                        Text(param)
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(.synthSecondary)
                        Spacer()
                        Text("[\(weight)%]")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.7))
                    }
                }
            }
            
            Divider().background(Color.cyan.opacity(0.1))
            
            // Y-Axis
            VStack(alignment: .leading, spacing: 4) {
                Text("Y-AXIS: \(state.mappingPreset.yLabel.uppercased())")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                
                ForEach(state.mappingPreset.yParams, id: \.0) { param, weight in
                    HStack {
                        Text(param)
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(.synthSecondary)
                        Spacer()
                        Text("[\(weight)%]")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.7))
                    }
                }
            }
            
            Divider().background(Color.cyan.opacity(0.1))
            
            // Snapshots
            VStack(alignment: .leading, spacing: 4) {
                Text("SNAPSHOTS")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                ForEach(state.snapshots) { snap in
                    Button(action: { state.jumpToSnapshot(snap.id) }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(snap.color)
                                .frame(width: 8, height: 8)
                            Text(snap.id)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.0f, %.0f", snap.position.x * 100, snap.position.y * 100))
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundColor(.synthTertiary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Divider().background(Color.cyan.opacity(0.1))
            
            // Cursor readout
            VStack(alignment: .leading, spacing: 2) {
                Text("POSITION")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.synthTertiary)
                Text(String(format: "X: %.1f%%  Y: %.1f%%",
                            state.cursorPosition.x * 100,
                            state.cursorPosition.y * 100))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            
            Spacer()
        }
        .padding(10)
        .frame(width: 160)
        .background(Color(white: 0.05))
    }
}

// MARK: - Gesture Controls

struct GestureControlBar: View {
    @Bindable var state: NavigatorState
    
    var body: some View {
        HStack(spacing: 12) {
            // Record
            Button(action: { state.toggleRecording() }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(state.isRecording ? Color.red : Color.red.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text("REC")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(state.isRecording ? .red : .synthSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(state.isRecording ? Color.red.opacity(0.15) : Color(white: 0.08))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Play
            Button(action: { startPlayback() }) {
                HStack(spacing: 4) {
                    Image(systemName: state.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 8))
                        .foregroundColor(state.recordedGesture.isEmpty ? .synthTertiary : .green)
                    Text(state.isPlaying ? "STOP" : "PLAY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(state.recordedGesture.isEmpty ? .synthTertiary : .synthSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.08))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(state.recordedGesture.isEmpty)
            
            // Loop
            Button(action: { state.isLooping.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "repeat")
                        .font(.system(size: 8))
                        .foregroundColor(state.isLooping ? .cyan : .synthTertiary)
                    Text("LOOP")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(state.isLooping ? .cyan : .synthSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(state.isLooping ? Color.cyan.opacity(0.1) : Color(white: 0.08))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Speed
            HStack(spacing: 4) {
                Text("SPEED")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundColor(.synthTertiary)
                Text(String(format: "%.1fx", state.playbackSpeed))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            
            Slider(value: $state.playbackSpeed, in: 0.25...4.0, step: 0.25)
                .frame(width: 80)
                .tint(.cyan)
            
            Spacer()
            
            // Gesture count
            if !state.recordedGesture.isEmpty {
                Text("\(state.recordedGesture.count) pts")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.synthTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(white: 0.04))
    }
    
    private func startPlayback() {
        if state.isPlaying {
            state.isPlaying = false
            return
        }
        guard !state.recordedGesture.isEmpty else { return }
        state.isPlaying = true
        
        // Simple playback using async
        let gesture = state.recordedGesture
        let speed = state.playbackSpeed
        let looping = state.isLooping
        
        Task { @MainActor in
            repeat {
                guard let firstTime = gesture.first?.timestamp else { break }
                for point in gesture {
                    guard state.isPlaying else { return }
                    let delay = (point.timestamp - firstTime) / speed
                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    guard state.isPlaying else { return }
                    state.moveCursor(to: point.position)
                }
            } while looping && state.isPlaying
            state.isPlaying = false
        }
    }
}

// MARK: - Main Navigator View

struct ParameterSpaceNavigatorView: View {
    var parameterTree: ObservableAUParameterGroup?
    var audioUnit: VoxExtensionAudioUnit?
    
    @State private var state = NavigatorState()
    @State private var chaosBuffer: AnyObject? = nil
    @State private var chaosTimer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Gesture control bar
            GestureControlBar(state: state)
            
            // Main content
            HStack(spacing: 0) {
                // Left: Primary navigator + secondary navigators
                VStack(spacing: 8) {
                    // Primary XY pad with chaos attractor background
                    ZStack {
                        if #available(macOS 15.0, *), let buf = chaosBuffer as? AtomicScopeBuffer<ChaosPoint> {
                            ChaosAttractorView(buffer: buf, preferredFPS: 30)
                                .opacity(0.3)
                                .allowsHitTesting(false)
                        }
                        PrimaryNavigatorPad(state: state, parameterTree: parameterTree)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Secondary navigators row
                    HStack(spacing: 8) {
                        MiniXYPad(
                            title: "MODULATION",
                            xLabel: "LFO Rate",
                            yLabel: "LFO Depth",
                            accentColor: .purple,
                            position: $state.modXY
                        )
                        
                        MiniXYPad(
                            title: "SPACE",
                            xLabel: "Width",
                            yLabel: "Movement",
                            accentColor: .orange,
                            position: $state.spaceXY
                        )
                        
                        MiniXYPad(
                            title: "CHAOS",
                            xLabel: "Lorenz",
                            yLabel: "Hénon",
                            accentColor: .green,
                            position: $state.chaosXY
                        )
                    }
                    .frame(height: 100)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                
                // Right sidebar
                AxisConfigSidebar(state: state)
            }
        }
        .onAppear { startChaosGenerator() }
        .onDisappear { chaosTimer?.invalidate(); chaosTimer = nil }
    }
    
    private func startChaosGenerator() {
        guard #available(macOS 15.0, *) else { return }
        let buf = AtomicScopeBuffer<ChaosPoint>(capacity: 4096)
        chaosBuffer = buf
        
        let sigma: Double = 10.0, rho: Double = 28.0, beta: Double = 8.0 / 3.0, dt: Double = 0.005
        nonisolated(unsafe) var lx: Double = 0.1, ly: Double = 0.0, lz: Double = 0.0
        
        chaosTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            for _ in 0..<64 {
                let dx = sigma * (ly - lx), dy = lx * (rho - lz) - ly, dz = lx * ly - beta * lz
                lx += dt * dx; ly += dt * dy; lz += dt * dz
                buf.write(ChaosPoint(x: Float(lx / 25.0), y: Float(ly / 25.0), age: 0))
            }
        }
    }
}

// MARK: - Preview

#Preview("Parameter Space Navigator") {
    ParameterSpaceNavigatorView(parameterTree: nil, audioUnit: nil)
        .frame(width: 700, height: 550)
        .background(Color.black)
}
