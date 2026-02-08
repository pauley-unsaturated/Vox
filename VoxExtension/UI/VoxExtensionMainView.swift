//
//  VoxExtensionMainView.swift
//  VoxExtension
//
//  Main UI for Vox Pulsar Synthesizer
//  Tab-based interface supporting 5 interaction paradigms.
//

import SwiftUI
import AudioToolbox

// MARK: - Tab Definition

enum VoxTab: Int, CaseIterable, Identifiable {
    case panel = 0
    case navigator
    case cloud
    case trajectory
    case conductor

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .panel:      return "🎛️"
        case .navigator:  return "🧭"
        case .cloud:      return "☁️"
        case .trajectory: return "📐"
        case .conductor:  return "🎭"
        }
    }

    var label: String {
        switch self {
        case .panel:      return "Panel"
        case .navigator:  return "Navigator"
        case .cloud:      return "Cloud"
        case .trajectory: return "Trajectory"
        case .conductor:  return "Conductor"
        }
    }
}

// MARK: - Tab Bar

struct VoxTabBar: View {
    @Binding var selectedTab: VoxTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(VoxTab.allCases) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 2) {
                        Text(tab.icon)
                            .font(.system(size: 14))
                        Text(tab.label.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(selectedTab == tab ? .white : .synthTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        selectedTab == tab
                            ? Color.white.opacity(0.08)
                            : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab {
                            Rectangle()
                                .fill(Color.cyan)
                                .frame(height: 2)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(white: 0.06))
    }
}

// MARK: - Traditional Panel (existing layout)

struct TraditionalPanelView: View {
    var parameterTree: ObservableAUParameterGroup?
    var audioUnit: VoxExtensionAudioUnit?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PulsarSection(parameterTree: parameterTree)
                FormantSection(parameterTree: parameterTree)
                EnvelopeSection(parameterTree: parameterTree)
                MasterSection(parameterTree: parameterTree)
            }
            .padding()
        }
    }
}

// MARK: - Main View

struct VoxExtensionMainView: View {
    var parameterTree: ObservableAUParameterGroup?
    var audioUnit: VoxExtensionAudioUnit?

    @State private var selectedTab: VoxTab = .panel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("VOX")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Pulsar Synthesizer")
                    .font(.system(size: 10))
                    .foregroundColor(.synthSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.04))

            // Tab bar
            VoxTabBar(selectedTab: $selectedTab)

            // Tab content
            Group {
                switch selectedTab {
                case .panel:
                    TraditionalPanelView(parameterTree: parameterTree, audioUnit: audioUnit)
                case .navigator:
                    NavigatorPlaceholderView()
                case .cloud:
                    CloudSculptorPlaceholderView()
                case .trajectory:
                    TrajectoryPlaceholderView()
                case .conductor:
                    MacroConductorView(parameterTree: parameterTree, audioUnit: audioUnit)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                VStack {
                    Text("Shape")
                        .font(.caption)
                        .foregroundColor(.gray)
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

                VStack {
                    Text("Duty Cycle")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("20%")
                        .font(.title2)
                        .foregroundColor(.white)
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

            HStack {
                ForEach(["A", "E", "I", "O", "U"], id: \.self) { vowel in
                    Text(vowel)
                        .font(.title)
                        .foregroundColor(vowel == "A" ? .orange : .gray)
                        .frame(maxWidth: .infinity)
                }
            }

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
        .frame(width: 500, height: 600)
}