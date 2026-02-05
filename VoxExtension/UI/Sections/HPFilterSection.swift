//
//  HPFilterSection.swift
//  VoxExtension
//
//  Created by Gemini on 7/6/25.
//

import SwiftUI

struct HPFilterSection: View {
    @State var parameterTree: ObservableAUParameterGroup

    var body: some View {
        VStack(spacing: 12) {
            FilterSliders(
                title: "HP FILTER",
                cutoffParam: parameterTree.filter.hpFilterCutoff,
                resonanceParam: parameterTree.filter.hpFilterResonance,
                driveParam: parameterTree.filter.hpFilterDrive,
                keyAmtParam: parameterTree.filter.hpFilterKeyAmt
            )
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text("Poles")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.synthSecondary)
                    SynthButtonGroup(param: parameterTree.filter.hpFilterPoles)
                }
                
                VStack(spacing: 4) {
                    Text("Saturate")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.synthSecondary)
                    SynthButton(param: parameterTree.filter.hpFilterSat, style: .toggle)
                }
            }
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