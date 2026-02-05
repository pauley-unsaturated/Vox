//
//  FilterSliders.swift
//  VoxExtension
//
//  Created by Gemini on 7/6/25.
//

import SwiftUI

struct FilterSliders: View {
    @State var cutoffParam: ObservableAUParameter
    @State var resonanceParam: ObservableAUParameter
    @State var driveParam: ObservableAUParameter
    @State var keyAmtParam: ObservableAUParameter
    
    let title: String
    
    init(
        title: String,
        cutoffParam: ObservableAUParameter,
        resonanceParam: ObservableAUParameter,
        driveParam: ObservableAUParameter,
        keyAmtParam: ObservableAUParameter
    ) {
        self.title = title
        self._cutoffParam = State(initialValue: cutoffParam)
        self._resonanceParam = State(initialValue: resonanceParam)
        self._driveParam = State(initialValue: driveParam)
        self._keyAmtParam = State(initialValue: keyAmtParam)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Section title - left aligned, white (matching OSCILLATORS style)
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.synthPrimary)
                Spacer()
            }
            
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    SynthSlider(param: cutoffParam, trackLength: 60, showLabel: false)
                    Text("Freq").font(.system(size: 8, weight: .medium)).frame(width: 24)
                        .foregroundColor(.synthSecondary)
                }
                VStack(spacing: 4) {
                    SynthSlider(param: resonanceParam, trackLength: 60, showLabel: false)
                    Text("Res").font(.system(size: 8, weight: .medium)).frame(width: 24)
                        .foregroundColor(.synthSecondary)
                }
                VStack(spacing: 4) {
                    SynthSlider(param: driveParam, trackLength: 60, showLabel: false)
                    Text("Drive").font(.system(size: 8, weight: .medium)).frame(width: 24)
                        .foregroundColor(.synthSecondary)
                }
                VStack(spacing: 4) {
                    SynthSlider(param: keyAmtParam, trackLength: 60, showLabel: false)
                    Text("Key").font(.system(size: 8, weight: .medium)).frame(width: 24)
                        .foregroundColor(.synthSecondary)
                }
            }
        }
    }
}