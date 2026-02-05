//
//  EnvelopeSection.swift
//  VoxExtension
//
//  Created by Mark Pauley on 7/4/25.
//

import SwiftUI

/// Envelope section with SH-101 style layout showing both AMP and FILTER envelopes
struct EnvelopeSection: View {
    var parameterTree: ObservableAUParameterGroup?
    
    // Match the SynthSlider width (trackWidth + 4 = 10) for consistent alignment
    private let sliderColumnWidth: CGFloat = 20
    private let sliderSpacing: CGFloat = 8
    
    var body: some View {
        if let tree = parameterTree {
            VStack(alignment: .leading, spacing: 8) {
                // Section title - left aligned
                Text("ENVELOPE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.synthPrimary)
                    .fixedSize()
                
                VStack {
                    HStack(alignment: .top, spacing: 16) {
                        // AMP Envelope (left side)
                        envelopeGroup(
                            title: "AMP",
                            params: [
                                (tree.ampEnvelope.ampAttack, "A"),
                                (tree.ampEnvelope.ampDecay, "D"),
                                (tree.ampEnvelope.ampSustain, "S"),
                                (tree.ampEnvelope.ampRelease, "R")
                            ]
                        )
                        
                        // FILTER Envelope (right side) - includes ENV amount slider
                        envelopeGroup(
                            title: "FILTER",
                            params: [
                                (tree.filterEnvelope.filterAttack, "A"),
                                (tree.filterEnvelope.filterDecay, "D"),
                                (tree.filterEnvelope.filterSustain, "S"),
                                (tree.filterEnvelope.filterRelease, "R"),
                                (tree.envelopeModulation.lpFilterEnvAmount, "ENV")
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
    
    @ViewBuilder
    private func envelopeGroup(title: String, params: [(ObservableAUParameter, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
                Spacer()
            }
            
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
