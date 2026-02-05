//
//  VoxExtensionMainView.swift
//  VoxExtension
//
//  Main UI for Vox Pulsar Synthesizer
//

import SwiftUI
import AudioToolbox

struct VoxExtensionMainView: View {
    var parameterTree: ObservableAUParameterGroup?
    var audioUnit: VoxExtensionAudioUnit?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text("VOX")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Pulsar Synthesizer")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Main sections
                VStack(spacing: 16) {
                    PulsarSection(parameterTree: parameterTree)
                    FormantSection(parameterTree: parameterTree)
                    EnvelopeSection(parameterTree: parameterTree)
                    MasterSection(parameterTree: parameterTree)
                }
                .padding()
            }
            .padding()
        }
        .background(Color.black)
    }
}

// MARK: - Pulsar Oscillator Section
struct PulsarSection: View {
    var parameterTree: ObservableAUParameterGroup?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PULSAR")
                .font(.headline)
                .foregroundColor(.cyan)
            
            HStack(spacing: 20) {
                // Pulsaret Shape
                VStack {
                    Text("Shape")
                        .font(.caption)
                        .foregroundColor(.gray)
                    // Shape selector would go here
                    Picker("Shape", selection: .constant(1)) {
                        Text("Gauss").tag(0)
                        Text("R.Cos").tag(1)
                        Text("Sine").tag(2)
                        Text("Tri").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                Spacer()
                
                // Duty Cycle
                VStack {
                    Text("Duty Cycle")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("20%")
                        .font(.title2)
                        .foregroundColor(.white)
                    // Slider would be connected to parameter
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Formant Filter Section
struct FormantSection: View {
    var parameterTree: ObservableAUParameterGroup?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FORMANT")
                .font(.headline)
                .foregroundColor(.orange)
            
            // Vowel display
            HStack {
                ForEach(["A", "E", "I", "O", "U"], id: \.self) { vowel in
                    Text(vowel)
                        .font(.title)
                        .foregroundColor(vowel == "A" ? .orange : .gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Vowel Morph slider would go here
            HStack {
                Text("Vowel")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("Mix: 100%")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}



struct EnvelopeKnob: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.3), lineWidth: 4)
                    .frame(width: 50, height: 50)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.green, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            Text(value)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Master Section
struct MasterSection: View {
    var parameterTree: ObservableAUParameterGroup?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MASTER")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Text("Volume")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("-6 dB")
                    .font(.title3)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    VoxExtensionMainView(parameterTree: nil, audioUnit: nil)
}
