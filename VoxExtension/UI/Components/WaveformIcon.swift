//
//  WaveformIcon.swift
//  VoxExtension
//
//  Created by Mark Pauley on 7/20/25.
//

import SwiftUI

/// Visual representation of different waveform types using SwiftUI shapes
struct WaveformIcon: View {
    let waveform: Waveform
    let size: CGSize
    let strokeWidth: CGFloat
    
    enum Waveform: String, CaseIterable {
        case sine = "Sin"
        case sawtooth = "Saw"
        case square = "Sqr"
        case triangle = "Tri"
        case sampleHold = "S+H"
        case noise = "NOISE"
        
        init?(from string: String) {
            switch string.lowercased() {
            case "sin", "sine":
                self = .sine
            case "saw", "sawtooth":
                self = .sawtooth
            case "sqr", "square":
                self = .square
            case "tri", "triangle":
                self = .triangle
            case "s+h", "sample hold", "samplehold":
                self = .sampleHold
            case "noise":
                self = .noise
            default:
                return nil
            }
        }
    }
    
    init(waveform: Waveform, size: CGSize = CGSize(width: 20, height: 12), strokeWidth: CGFloat = 1.5) {
        self.waveform = waveform
        self.size = size
        self.strokeWidth = strokeWidth
    }
    
    var body: some View {
        switch waveform {
        case .sine:
            SineWave()
        case .sawtooth:
            SawtoothWave()
        case .square:
            SquareWave()
        case .triangle:
            TriangleWave()
        case .sampleHold:
            SampleHoldWave()
        case .noise:
            NoiseWave()
        }
    }
}

// MARK: - Individual Waveform Shapes

struct SineWave: View {
    var body: some View {
        Path { path in
            let points = 50
            let width: CGFloat = 18
            let height: CGFloat = 12
            
            for i in 0..<points {
                let x = (CGFloat(i) / CGFloat(points - 1)) * width
                let angle = (CGFloat(i) / CGFloat(points - 1)) * .pi * 2
                let y = height * 0.5 + (sin(angle) * height * 0.4)
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(Color.white, lineWidth: 1.2)
        .frame(width: 18, height: 12)
    }
}

struct SawtoothWave: View {
    var body: some View {
        Path { path in
            let width: CGFloat = 18
            let height: CGFloat = 12
            let cycles = 2
            
            for cycle in 0..<cycles {
                let startX = (CGFloat(cycle) / CGFloat(cycles)) * width
                let endX = (CGFloat(cycle + 1) / CGFloat(cycles)) * width
                
                // Rising edge
                if cycle == 0 && startX == 0 {
                    path.move(to: CGPoint(x: startX, y: height * 0.9))
                }
                path.addLine(to: CGPoint(x: endX - 1, y: height * 0.1))
                
                // Falling edge (vertical drop)
                if cycle < cycles - 1 {
                    path.addLine(to: CGPoint(x: endX, y: height * 0.9))
                }
            }
        }
        .stroke(Color.white, lineWidth: 1.2)
        .frame(width: 18, height: 12)
    }
}

struct SquareWave: View {
    var body: some View {
        Path { path in
            let width: CGFloat = 18
            let height: CGFloat = 12
            let cycles = 2
            
            path.move(to: CGPoint(x: 0, y: height * 0.1))
            
            for cycle in 0..<cycles {
                let startX = (CGFloat(cycle) / CGFloat(cycles)) * width
                let midX = startX + (width / CGFloat(cycles)) * 0.5
                let endX = (CGFloat(cycle + 1) / CGFloat(cycles)) * width
                
                // High portion
                path.addLine(to: CGPoint(x: midX, y: height * 0.1))
                // Vertical drop
                path.addLine(to: CGPoint(x: midX, y: height * 0.9))
                // Low portion
                path.addLine(to: CGPoint(x: endX, y: height * 0.9))
                
                // Vertical rise for next cycle
                if cycle < cycles - 1 {
                    path.addLine(to: CGPoint(x: endX, y: height * 0.1))
                }
            }
        }
        .stroke(Color.white, lineWidth: 1.2)
        .frame(width: 18, height: 12)
    }
}

struct TriangleWave: View {
    var body: some View {
        Path { path in
            let width: CGFloat = 18
            let height: CGFloat = 12
            let cycles = 2
            
            // Start at the bottom of the first cycle
            path.move(to: CGPoint(x: 0, y: height * 0.9))
            
            for cycle in 0..<cycles {
                let startX = (CGFloat(cycle) / CGFloat(cycles)) * width
                let midX = startX + (width / CGFloat(cycles)) * 0.5
                let endX = (CGFloat(cycle + 1) / CGFloat(cycles)) * width
                
                // Rising edge to peak
                path.addLine(to: CGPoint(x: midX, y: height * 0.1))
                // Falling edge to bottom
                path.addLine(to: CGPoint(x: endX, y: height * 0.9))
            }
        }
        .stroke(Color.white, lineWidth: 1.2)
        .frame(width: 18, height: 12)
    }
}

struct SampleHoldWave: View {
    var body: some View {
        Path { path in
            let width: CGFloat = 18
            let height: CGFloat = 12
            
            // Sample & Hold - stepped random values with equal step lengths
            let steps = 5
            let stepWidth = width / CGFloat(steps)
            let values: [CGFloat] = [0.2, 0.5, 0.0, 0.4, 0.9, 0.1, 0.1, 0.6]
            
            path.move(to: CGPoint(x: 0, y: height * 0.2 + (values[0] * height * 0.6)))
            
            for i in 0..<steps {
                let startX = CGFloat(i) * stepWidth
                let endX = CGFloat(i + 1) * stepWidth
                let y = height * 0.2 + (values[i] * height * 0.6)
                
                // Horizontal line (hold value)
                path.addLine(to: CGPoint(x: endX, y: y))
                
                // Vertical line to next value (except for last step)
                if i < steps - 1 {
                    let nextY = height * 0.2 + (values[i + 1] * height * 0.6)
                    path.addLine(to: CGPoint(x: endX, y: nextY))
                }
            }
        }
        .stroke(Color.white, lineWidth: 1.2)
        .frame(width: 18, height: 12)
    }
}

struct NoiseWave: View {
    var body: some View {
        Path { path in
            let points = 25
            let width: CGFloat = 18
            let height: CGFloat = 12
            
            // Simple deterministic pattern for noise
            let values: [CGFloat] = [0.3, 0.8, 0.2, 0.9, 0.1, 0.7, 0.4, 0.6, 0.5, 0.8, 0.2, 0.9, 0.3, 0.7, 0.1, 0.6, 0.4, 0.8, 0.5, 0.3, 0.9, 0.2, 0.7, 0.4, 0.6]
            
            for i in 0..<min(points, values.count) {
                let x = (CGFloat(i) / CGFloat(points - 1)) * width
                let y = height * 0.2 + (values[i] * height * 0.6)
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(Color.white, lineWidth: 1.2)
        .frame(width: 18, height: 12)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 15) {
            ForEach(WaveformIcon.Waveform.allCases, id: \.self) { waveform in
                VStack(spacing: 4) {
                    WaveformIcon(waveform: waveform)
                        .foregroundColor(.white)
                    Text(waveform.rawValue)
                        .font(.system(size: 8))
                        .foregroundColor(.synthSecondary)
                }
                .frame(width: 30, height: 30)
                .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                .cornerRadius(4)
            }
        }
    }
    .padding()
    .background(Color(red: 0.1, green: 0.1, blue: 0.1))
}
