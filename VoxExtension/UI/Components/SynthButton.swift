//
//  SynthButton.swift
//  VoxExtension
//
//  Created by Mark Pauley on 7/4/25.
//

import SwiftUI

/// A button control styled for synthesizer interfaces with LED-style indicators
struct SynthButton: View {
    @State var param: ObservableAUParameter
    @State private var isPressed = false
    
    let style: ButtonStyle
    let size: ButtonSize
    
    enum ButtonStyle {
        case toggle        // For boolean parameters
        case momentary     // For triggers
        case selector      // For indexed parameters with multiple values
    }
    
    enum ButtonSize {
        case small
        case medium
        case large
        
        var dimensions: CGSize {
            switch self {
            case .small: return CGSize(width: 30, height: 20)
            case .medium: return CGSize(width: 45, height: 25)
            case .large: return CGSize(width: 60, height: 30)
            }
        }
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            }
        }
    }
    
    init(
        param: ObservableAUParameter,
        style: ButtonStyle = .toggle,
        size: ButtonSize = .medium
    ) {
        self._param = State(initialValue: param)
        self.style = style
        self.size = size
    }
    
    private var isActive: Bool {
        switch style {
        case .toggle:
            return param.value > 0.5
        case .momentary:
            return isPressed
        case .selector:
            return param.value > 0.5
        }
    }
    
    private var displayText: String {
        if let strings = param.valueStrings {
            let index = Int(param.value)
            if index >= 0 && index < strings.count {
                return strings[index]
            }
        }
        
        // Use shortened version of parameter name
        let name = param.displayName
            .replacingOccurrences(of: "Filter ", with: "")
            .replacingOccurrences(of: "Osc ", with: "")
            .replacingOccurrences(of: "LFO ", with: "")
        
        return name
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Button(action: {
                switch style {
                case .toggle:
                    param.onEditingChanged(true)
                    param.value = param.value > 0.5 ? param.min : param.max
                    param.onEditingChanged(false)
                    
                case .momentary:
                    // Momentary buttons could trigger specific actions
                    param.onEditingChanged(true)
                    param.value = param.max
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        param.value = param.min
                        param.onEditingChanged(false)
                    }
                    
                case .selector:
                    param.onEditingChanged(true)
                    let currentIndex = Int(param.value)
                    let maxIndex = Int(param.max)
                    let nextIndex = (currentIndex + 1) % (maxIndex + 1)
                    param.value = AUValue(nextIndex)
                    param.onEditingChanged(false)
                }
            }) {
                ZStack {
                    // Button background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: isActive ? 
                                    [Color.orange.opacity(0.8), Color.red.opacity(0.6)] :
                                    [Color(red: 0.3, green: 0.3, blue: 0.3), Color(red: 0.2, green: 0.2, blue: 0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size.dimensions.width, height: size.dimensions.height)
                    
                    // Button border
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            Color.black.opacity(0.3),
                            lineWidth: 1
                        )
                        .frame(width: size.dimensions.width, height: size.dimensions.height)
                    
                    // LED indicator (small dot in corner for active state)
                    if isActive {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 4, height: 4)
                            .offset(x: size.dimensions.width * 0.3, y: -size.dimensions.height * 0.2)
                    }
                    
                    // Button text - only show for non-toggle styles (toggle buttons rely on external labels)
                    if style != .toggle {
                        Text(displayText)
                            .font(.system(size: size.fontSize, weight: .medium))
                            .foregroundColor(isActive ? .white : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: .infinity,
                pressing: { pressing in
                    isPressed = pressing
                },
                perform: {}
            )
        }
    }
}

/// A group of selector buttons for parameters with multiple discrete values
struct SynthButtonGroup: View {
    @State var param: ObservableAUParameter
    let orientation: Orientation
    let showWaveformIcons: Bool
    
    enum Orientation {
        case horizontal
        case vertical
    }
    
    init(param: ObservableAUParameter, orientation: Orientation = .horizontal, showWaveformIcons: Bool = false) {
        self._param = State(initialValue: param)
        self.orientation = orientation
        self.showWaveformIcons = showWaveformIcons
    }
    
    var body: some View {
        let buttons = (0...Int(param.max)).map { index in
            Button(action: {
                param.onEditingChanged(true)
                param.value = AUValue(index)
                param.onEditingChanged(false)
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            Int(param.value) == index ?
                                LinearGradient(colors: [Color.orange, Color.red], startPoint: .top, endPoint: .bottom) :
                                LinearGradient(colors: [Color(red: 0.3, green: 0.3, blue: 0.3), Color(red: 0.2, green: 0.2, blue: 0.2)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 25, height: 20)
                    
                    if showWaveformIcons, let valueString = param.valueStrings?[index], let waveform = WaveformIcon.Waveform(from: valueString) {
                        WaveformIcon(waveform: waveform)
                            .foregroundColor(Int(param.value) == index ? .white : .primary)
                    } else {
                        Text(param.valueStrings?[index] ?? "\(index)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Int(param.value) == index ? .white : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        
        Group {
            if orientation == .horizontal {
                HStack(spacing: 2) {
                    ForEach(0..<buttons.count, id: \.self) { index in
                        buttons[index]
                    }
                }
            } else {
                VStack(spacing: 2) {
                    ForEach(0..<buttons.count, id: \.self) { index in
                        buttons[index]
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 15) {
            SynthButton(
                param: ObservableAUParameter(
                    address: 0,
                    parameterTree: nil,
                    spec: ParameterSpec(
                        address: 0,
                        identifier: "sync",
                        name: "Sync",
                        units: .boolean,
                        valueRange: 0...1,
                        defaultValue: 0
                    )
                ),
                style: .toggle,
                size: .medium
            )
            
            SynthButton(
                param: ObservableAUParameter(
                    address: 1,
                    parameterTree: nil,
                    spec: ParameterSpec(
                        address: 1,
                        identifier: "retrig",
                        name: "Retrig",
                        units: .boolean,
                        valueRange: 0...1,
                        defaultValue: 1
                    )
                ),
                style: .toggle,
                size: .small
            )
        }
        
        SynthButtonGroup(
            param: ObservableAUParameter(
                address: 2,
                parameterTree: nil,
                spec: ParameterSpec(
                    address: 2,
                    identifier: "wave",
                    name: "Wave",
                    units: .indexed,
                    valueRange: 0...3,
                    defaultValue: 0,
                    valueStrings: ["Sin", "Saw", "Sqr", "Tri"]
                )
            )
        )
    }
    .padding()
    .background(Color(red: 0.1, green: 0.1, blue: 0.1))
}