//
//  SynthSlider.swift
//  VoxExtension
//
//  Created by Mark Pauley on 7/4/25.
//

import SwiftUI

/// A vertical or horizontal slider control styled for synthesizer interfaces
struct SynthSlider: View {
    @State var param: ObservableAUParameter
    @State private var isDragging = false
    
    let orientation: Orientation
    let trackWidth: CGFloat
    let trackLength: CGFloat
    let showValue: Bool
    let showLabel: Bool
    
    /// Determines if this parameter should use logarithmic time scaling (SH-101 style log pot behavior)
    private var isLogTimeParameter: Bool {
        guard param.unit == .milliseconds else { return false }
        let name = param.displayName
        return name.contains("Attack")
            || name.contains("Decay")
            || name.contains("Release")
    }
    
    /// Convert parameter value to slider position using log-time mapping for envelope params
    /// This gives SH-101-like "log pot" feel: snappy times in bottom half, slow times at top
    private func sliderPosition(for value: Float) -> Double {
        let v = Double(value)
        let minV = Double(param.min)
        let maxV = Double(param.max)
        
        guard isLogTimeParameter,
              minV > 0,
              maxV > minV else {
            // Linear fallback
            return max(0.0, min(1.0, (v - minV) / (maxV - minV)))
        }
        
        // Log mapping: x = log(v/min) / log(max/min)
        // At 50% slider: ~10-15% of time range (snappy times easy to dial)
        // At 67% slider: ~500-600ms (most musical times in lower 2/3)
        let ratio = maxV / minV
        let pos = log(v / minV) / log(ratio)
        return max(0.0, min(1.0, pos))
    }
    
    /// Convert slider position to parameter value using log-time mapping
    private func parameterValue(for sliderPosition: Double) -> Float {
        let x = max(0.0, min(1.0, sliderPosition))
        let minV = Double(param.min)
        let maxV = Double(param.max)
        
        guard isLogTimeParameter,
              minV > 0,
              maxV > minV else {
            // Linear fallback
            let v = minV + (maxV - minV) * x
            return Float(v)
        }
        
        // Log mapping: t = t_min * (t_max/t_min)^x
        let ratio = maxV / minV
        let v = minV * pow(ratio, x)
        return Float(v)
    }
    
    enum Orientation {
        case vertical
        case horizontal
    }
    
    init(
        param: ObservableAUParameter,
        orientation: Orientation = .vertical,
        trackWidth: CGFloat = 6,
        trackLength: CGFloat = 80,
        showValue: Bool = true,
        showLabel: Bool = true
    ) {
        self._param = State(initialValue: param)
        self.orientation = orientation
        self.trackWidth = trackWidth
        self.trackLength = trackLength
        self.showValue = showValue
        self.showLabel = showLabel
    }
    
    private var normalizedValue: Double {
        guard param.max != param.min else { return 0 }
        return sliderPosition(for: param.value)
    }
    
    private var displayValue: String {
        switch param.unit {
        case .milliseconds:
            if param.value >= 1000 {
                return String(format: "%.1fs", param.value / 1000)
            } else {
                return String(format: "%.0f", param.value)
            }
        case .percent:
            return String(format: "%.0f", param.value)
        case .decibels:
            if param.value <= -60 {
                return "-∞"
            } else {
                return String(format: "%.1f", param.value)
            }
        default:
            // For MIDI velocity-style parameters (1-127 or 0-127), display as integers
            if param.min >= 0 && param.max <= 127 && param.max >= 100 {
                return String(format: "%.0f", param.value)
            }
            return String(format: "%.2f", param.value)
        }
    }
    
    private var sliderContent: some View {
        ZStack {
            if orientation == .vertical {
                verticalSlider
            } else {
                horizontalSlider
            }
        }
    }
    
    private var verticalSlider: some View {
        ZStack {
            // Background track - rectangular with dark gradient
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.15, blue: 0.15), Color(red: 0.08, green: 0.08, blue: 0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: trackWidth, height: trackLength)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
                )
            
            // Active level fill (from bottom up)
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.9, green: 0.4, blue: 0.1), Color(red: 0.7, green: 0.3, blue: 0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: trackWidth - 2, height: max(2, trackLength * CGFloat(normalizedValue)))
            }
            .frame(width: trackWidth, height: trackLength)
            
            // Rectangular drag handle with red level indicator line
            VStack {
                Spacer(minLength: 0)
                    .frame(height: trackLength * CGFloat(1.0 - normalizedValue) - 4)
                
                ZStack {
                    // Main drag handle - rectangular
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.9, green: 0.9, blue: 0.9), Color(red: 0.7, green: 0.7, blue: 0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: trackWidth + 4, height: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .stroke(Color.black.opacity(0.4), lineWidth: 0.5)
                        )
                    
                    // Red level indicator line through the middle (SH-101 style)
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: trackWidth + 2, height: 1)
                }
                .scaleEffect(isDragging ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isDragging)
                
                Spacer(minLength: 0)
            }
        }
        .frame(width: trackWidth + 4, height: trackLength)
        .contentShape(Rectangle())
        .gesture(verticalDragGesture)
    }
    
    private var verticalDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    param.onEditingChanged(true)
                }
                
                // Convert drag position to slider position (0-1)
                let yPos = value.location.y
                let clampedY = max(0, min(trackLength, yPos))
                // Fix y-axis inversion: bottom = 0, top = 1
                let sliderPos = 1.0 - (clampedY / trackLength)
                
                // Use log-time mapping for envelope params (SH-101 style)
                param.value = parameterValue(for: Double(sliderPos))
            }
            .onEnded { _ in
                isDragging = false
                param.onEditingChanged(false)
            }
    }
    
    private var horizontalSlider: some View {
        HStack(spacing: 0) {
            // Track background
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.1, blue: 0.1), Color(red: 0.2, green: 0.2, blue: 0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: trackLength, height: trackWidth)
                .cornerRadius(trackWidth / 2)
            
            // Active track (filled portion)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.orange, Color.red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: trackLength * normalizedValue, height: trackWidth - 2)
                .cornerRadius((trackWidth - 2) / 2)
                .offset(x: -trackLength * (1 - normalizedValue) / 2)
            
            // Thumb (slider handle)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.8, green: 0.8, blue: 0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: trackWidth + 6, height: trackWidth + 6)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                )
                .offset(x: -trackLength / 2 + trackLength * normalizedValue)
                .scaleEffect(isDragging ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isDragging)
        }
        .gesture(horizontalDragGesture)
    }
    
    private var horizontalDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    param.onEditingChanged(true)
                }
                
                let dragPosition = value.translation.width
                let normalizedDrag = dragPosition / trackLength
                let startPos = normalizedValue
                let sliderPos = max(0.0, min(1.0, startPos + normalizedDrag))
                
                // Use log-time mapping for envelope params (SH-101 style)
                param.value = parameterValue(for: Double(sliderPos))
            }
            .onEnded { _ in
                isDragging = false
                param.onEditingChanged(false)
            }
    }
    
    var body: some View {
        // Wrap with labels based on orientation
        if orientation == .vertical {
            VStack(spacing: 4) {
                sliderContent
                
                if showValue {
                    Text(displayValue)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.synthPrimary)
                        .lineLimit(1)
                        .frame(width: 30, height: 12)  // Fixed width prevents layout shift
                }
                
                if showLabel {
                    Text(param.displayName)
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(.synthSecondary)
                        .lineLimit(1)
                        .frame(height: 10)
                }
            }
        } else {
            HStack(spacing: 6) {
                if showLabel {
                    Text(param.displayName)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.synthSecondary)
                        .lineLimit(1)
                        .frame(width: 60, alignment: .trailing)
                }
                
                sliderContent
                
                if showValue {
                    Text(displayValue)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.synthPrimary)
                        .lineLimit(1)
                        .frame(width: 50, alignment: .leading)
                }
            }
        }
    }
}

/// ADSR Envelope display with four vertical sliders
struct ADSRSliders: View {
    @State var attackParam: ObservableAUParameter
    @State var decayParam: ObservableAUParameter
    @State var sustainParam: ObservableAUParameter
    @State var releaseParam: ObservableAUParameter
    
    let title: String
    
    init(
        title: String = "ADSR",
        attackParam: ObservableAUParameter,
        decayParam: ObservableAUParameter,
        sustainParam: ObservableAUParameter,
        releaseParam: ObservableAUParameter
    ) {
        self.title = title
        self._attackParam = State(initialValue: attackParam)
        self._decayParam = State(initialValue: decayParam)
        self._sustainParam = State(initialValue: sustainParam)
        self._releaseParam = State(initialValue: releaseParam)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.synthPrimary)
            
            HStack(spacing: 12) {
                SynthSlider(param: attackParam, trackLength: 60, showLabel: false)
                SynthSlider(param: decayParam, trackLength: 60, showLabel: false)
                SynthSlider(param: sustainParam, trackLength: 60, showLabel: false)
                SynthSlider(param: releaseParam, trackLength: 60, showLabel: false)
            }
            
            HStack(spacing: 12) {
                Text("A").font(.system(size: 8, weight: .medium)).frame(width: 20)
                Text("D").font(.system(size: 8, weight: .medium)).frame(width: 20)
                Text("S").font(.system(size: 8, weight: .medium)).frame(width: 20)
                Text("R").font(.system(size: 8, weight: .medium)).frame(width: 20)
            }
            .foregroundColor(.synthSecondary)
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        HStack(spacing: 20) {
            SynthSlider(
                param: ObservableAUParameter(
                    address: 0,
                    parameterTree: nil,
                    spec: ParameterSpec(
                        address: 0,
                        identifier: "attack",
                        name: "Attack",
                        units: .milliseconds,
                        valueRange: 1...4000,
                        defaultValue: 10
                    )
                ),
                orientation: .vertical
            )
            
            SynthSlider(
                param: ObservableAUParameter(
                    address: 1,
                    parameterTree: nil,
                    spec: ParameterSpec(
                        address: 1,
                        identifier: "cutoff",
                        name: "Cutoff",
                        units: .hertz,
                        valueRange: 20...20000,
                        defaultValue: 1000
                    )
                ),
                orientation: .horizontal,
                trackLength: 120
            )
        }
    }
    .padding()
    .background(Color(red: 0.1, green: 0.1, blue: 0.1))
}
