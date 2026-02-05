//
//  SubOscillatorSection.swift
//  VoxExtension
//
//  Created by Claude on 7/6/25.
//

import SwiftUI

/// Sub-oscillator and noise section
struct SubOscillatorSection: View {
    @State var parameterTree: ObservableAUParameterGroup
    
    var body: some View {
        VStack(spacing: 12) {
            // Section title - left aligned (matching OSCILLATORS style)
            HStack {
                Text("SUB OSC")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.synthPrimary)
                Spacer()
            }
            
            SubOscillatorControls(
                octaveParam: parameterTree.subOscillator.subOscOctave,
                pulseWidthParam: parameterTree.subOscillator.subOscPulseWidth
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.3, green: 0.3, blue: 0.3), lineWidth: 1)
                )
        )
    }
}
