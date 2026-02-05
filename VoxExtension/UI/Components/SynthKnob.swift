//
//  SynthKnob.swift
//  VoxExtension
//
//  Created by Mark Pauley on 7/4/25.
//

import SwiftUI

/// A rotary knob control styled for synthesizer interfaces
struct SynthKnob: View {
    @State var param: ObservableAUParameter
    @State private var isDragging = false
    @State private var lastDragValue: CGFloat = 0
    
    let size: CGFloat
    let showValue: Bool
    let showLabel: Bool
    
    init(
        param: ObservableAUParameter,
        size: CGFloat = 60,
        showValue: Bool = true,
        showLabel: Bool = true
    ) {
        self._param = State(initialValue: param)
        self.size = size
        self.showValue = showValue
        self.showLabel = showLabel
    }
    
    private var normalizedValue: Double {
        guard param.max != param.min else { return 0 }
        return Double((param.value - param.min) / (param.max - param.min))
    }
    
    private var rotationAngle: Angle {
        let minAngle: Double = -135 // degrees
        let maxAngle: Double = 135  // degrees
        let angle = minAngle + (maxAngle - minAngle) * normalizedValue
        return .degrees(angle)
    }
    
    private var displayValue: String {
        switch param.unit {
        case .hertz:
            if param.value >= 1000 {
                return String(format: "%.1fk", param.value / 1000)
            } else {
                return String(format: "%.1f", param.value)
            }
        case .milliseconds:
            if param.value >= 1000 {
                return String(format: "%.1fs", param.value / 1000)
            } else {
                return String(format: "%.0fms", param.value)
            }
        case .decibels:
            if param.value <= -60 {
                return "-∞"
            } else {
                return String(format: "%.1f", param.value)
            }
        case .percent:
            // Special handling for filter cutoff (convert to Hz for display)
            if param.displayName.contains("Filter Cutoff") {
                let normalizedValue = param.value / 100.0
                let freqHz = 20.0 * pow(1000.0, normalizedValue)
                if freqHz >= 1000 {
                    return String(format: "%.1fk", freqHz / 1000)
                } else {
                    return String(format: "%.0f", freqHz)
                }
            } else {
                return String(format: "%.0f%%", param.value)
            }
        case .cents:
            return String(format: "%.0f¢", param.value)
        case .degrees:
            return String(format: "%.0f°", param.value)
        case .indexed:
            if let strings = param.valueStrings {
                let index = Int(param.value)
                if index >= 0 && index < strings.count {
                    return strings[index]
                }
            }
            return String(format: "%.0f", param.value)
        default:
            return String(format: "%.2f", param.value)
        }
    }
    
    private var knobBody: some View {
        ZStack {
            outerRing
            innerKnobFace
            valueIndicator
            centerDot
        }
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isDragging)
        .gesture(dragGesture)
    }
    
    private var outerRing: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.3, green: 0.3, blue: 0.3), Color(red: 0.1, green: 0.1, blue: 0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
    }
    
    private var innerKnobFace: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.6, green: 0.6, blue: 0.6), Color(red: 0.4, green: 0.4, blue: 0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size * 0.8, height: size * 0.8)
    }
    
    private var valueIndicator: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 2, height: size * 0.3)
            .offset(y: -size * 0.25)
            .rotationEffect(rotationAngle)
    }
    
    private var centerDot: some View {
        Circle()
            .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
            .frame(width: 6, height: 6)
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let translationY = value.translation.height
        if !isDragging {
            isDragging = true
            lastDragValue = translationY
            param.onEditingChanged(true)
        }
        
        let deltaY = lastDragValue - translationY
        let sensitivity: CGFloat = 0.5
        let change = deltaY * sensitivity
        
        let range: Double = Double(param.max - param.min)
        let scaledChange: Double = Double(change) * range / 100.0
        let newValue: Double = Double(param.value) + scaledChange
        param.value = max(param.min, min(param.max, Float(newValue)))
        
        lastDragValue = translationY
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        isDragging = false
        param.onEditingChanged(false)
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged(handleDragChanged)
            .onEnded(handleDragEnded)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            knobBody
            
            if showValue {
                Text(displayValue)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.synthPrimary)
                    .lineLimit(1)
                    .frame(height: 12)
            }
            
            if showLabel {
                Text(param.displayName)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.synthSecondary)
                    .lineLimit(1)
                    .frame(height: 12)
            }
        }
        .frame(width: size + 10)
    }
}

#Preview {
    VStack {
        HStack(spacing: 20) {
            // Mock different knob types
            SynthKnob(param: ObservableAUParameter(
                address: 0,
                parameterTree: nil,
                spec: ParameterSpec(
                    address: 0,
                    identifier: "test",
                    name: "Cutoff",
                    units: .percent,
                    valueRange: 0...100,
                    defaultValue: 50
                )
            ))
            
            SynthKnob(param: ObservableAUParameter(
                address: 1,
                parameterTree: nil,
                spec: ParameterSpec(
                    address: 1,
                    identifier: "test2",
                    name: "Resonance",
                    units: .percent,
                    valueRange: 0...120,
                    defaultValue: 30
                )
            ))
        }
    }
    .padding()
    .background(Color(red: 0.1, green: 0.1, blue: 0.1))
}
