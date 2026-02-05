//
//  FilterSection.swift
//  VoxExtension
//

import SwiftUI

struct FilterSection: View {
    @State var parameterTree: ObservableAUParameterGroup
    
    var body: some View {
        VStack(spacing: 12) {
            // Section title
            HStack {
                Text("FILTER")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.synthPrimary)
                Spacer()
            }
            
            // LP and HP side-by-side
            HStack(alignment: .top, spacing: 12) {
                filterSubGroup(
                    title: "LP",
                    cutoffParam: parameterTree.filter.lpFilterCutoff,
                    resonanceParam: parameterTree.filter.lpFilterResonance,
                    driveParam: parameterTree.filter.lpFilterDrive,
                    keyAmtParam: parameterTree.filter.lpFilterKeyAmt,
                    polesParam: parameterTree.filter.lpFilterPoles,
                    satParam: parameterTree.filter.lpFilterSat
                )

                filterSubGroup(
                    title: "HP",
                    cutoffParam: parameterTree.filter.hpFilterCutoff,
                    resonanceParam: parameterTree.filter.hpFilterResonance,
                    driveParam: parameterTree.filter.hpFilterDrive,
                    keyAmtParam: parameterTree.filter.hpFilterKeyAmt,
                    polesParam: parameterTree.filter.hpFilterPoles,
                    satParam: parameterTree.filter.hpFilterSat
                )
            }
            
            Spacer(minLength: 0)
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
    
    @ViewBuilder
    private func filterSubGroup(
        title: String,
        cutoffParam: ObservableAUParameter,
        resonanceParam: ObservableAUParameter,
        driveParam: ObservableAUParameter,
        keyAmtParam: ObservableAUParameter,
        polesParam: ObservableAUParameter,
        satParam: ObservableAUParameter
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
                Spacer()
            }
            
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    SynthSlider(param: cutoffParam, trackLength: 100, showLabel: false)
                    Text("Freq").font(.system(size: 8, weight: .medium)).frame(width: 24)
                        .foregroundColor(.synthSecondary)
                }
                VStack(spacing: 4) {
                    SynthSlider(param: resonanceParam, trackLength: 100, showLabel: false)
                    Text("Res").font(.system(size: 8, weight: .medium)).frame(width: 24)
                        .foregroundColor(.synthSecondary)
                }
                VStack(spacing: 4) {
                    SynthSlider(param: driveParam, trackLength: 100, showLabel: false)
                    Text("Drive").font(.system(size: 8, weight: .medium)).frame(width: 24)
                        .foregroundColor(.synthSecondary)
                }
                VStack(spacing: 4) {
                    SynthSlider(param: keyAmtParam, trackLength: 100, showLabel: false)
                    Text("Key").font(.system(size: 8, weight: .medium)).frame(width: 24)
                        .foregroundColor(.synthSecondary)
                }
            }
            
            Spacer(minLength: 0)
            
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text("Poles")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.synthSecondary)
                    SynthButtonGroup(param: polesParam)
                }
                
                VStack(spacing: 4) {
                    Text("Saturate")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.synthSecondary)
                    SynthButton(param: satParam, style: .toggle)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
        )
    }
}
