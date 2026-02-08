//
//  EnvelopeSection.swift
//  VoxExtension
//
//  Vox Pulsar Synthesizer - Amplitude Envelope Section
//  Phase 8.8: Added visual envelope curve display
//

import SwiftUI

/// Envelope section for the Vox pulsar synth - shows AMP envelope (ADSR)
struct EnvelopeSection: View {
    var parameterTree: ObservableAUParameterGroup?
    
    // Match the SynthSlider width (trackWidth + 4 = 10) for consistent alignment
    private let sliderColumnWidth: CGFloat = 20
    private let sliderSpacing: CGFloat = 8
    
    var body: some View {
        if let tree = parameterTree {
            let attackParam: ObservableAUParameter = tree.ampEnvelope.ampAttack
            let decayParam: ObservableAUParameter = tree.ampEnvelope.ampDecay
            let sustainParam: ObservableAUParameter = tree.ampEnvelope.ampSustain
            let releaseParam: ObservableAUParameter = tree.ampEnvelope.ampRelease
            
            VStack(alignment: .leading, spacing: 8) {
                // Section title - left aligned
                Text("AMP ENVELOPE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.synthPrimary)
                    .fixedSize()
                
                VStack(spacing: 12) {
                    // Phase 8.8: Visual envelope curve display
                    EnvelopeDisplay(
                        attack: normalizeTime(attackParam),
                        decay: normalizeTime(decayParam),
                        sustain: Double(sustainParam.value),
                        release: normalizeTime(releaseParam),
                        showGrid: true,
                        curveColor: .synthPrimary
                    )
                    .frame(height: 50)
                    .padding(.horizontal, 4)
                    
                    HStack(alignment: .top, spacing: 16) {
                        // AMP Envelope ADSR sliders
                        envelopeGroup(
                            params: [
                                (attackParam, "A"),
                                (decayParam, "D"),
                                (sustainParam, "S"),
                                (releaseParam, "R")
                            ]
                        )
                    }
                    
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity, alignment: .top)
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
    
    /// Normalize time parameter (0-4000ms) to 0-1 range for display
    private func normalizeTime(_ param: ObservableAUParameter) -> Double {
        // Most ADSR times are in seconds (0.001 to 4.0 or similar)
        // Use logarithmic scaling for better visual representation
        let value = Double(param.value)
        let minVal = Double(param.min)
        let maxVal = Double(param.max)
        
        if maxVal <= minVal { return 0.5 }
        
        // Linear normalization (could be made logarithmic for better UX)
        return (value - minVal) / (maxVal - minVal)
    }
    
    @ViewBuilder
    private func envelopeGroup(params: [(ObservableAUParameter, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: sliderSpacing) {
                ForEach(Array(params.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        SynthSlider(param: item.0, trackLength: 60, showLabel: false)
                        
                        Text(item.1)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.synthSecondary)
                    }
                    .frame(width: sliderColumnWidth)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
        )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Envelope Section Preview")
                .font(.title2)
                .foregroundColor(.white)
            
            // Note: Actual preview requires mock parameter tree
        }
        .padding()
    }
    .background(Color(red: 0.05, green: 0.05, blue: 0.05))
}
