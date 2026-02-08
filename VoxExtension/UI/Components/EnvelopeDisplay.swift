//
//  EnvelopeDisplay.swift
//  VoxExtension
//
//  Phase 8.8: Visual ADSR envelope curve display
//  Shows the envelope shape and optionally the current position
//

import SwiftUI

/// Visual display of an ADSR envelope curve
struct EnvelopeDisplay: View {
    // ADSR parameters (normalized 0-1)
    let attack: Double   // Attack time (0-1 normalized)
    let decay: Double    // Decay time (0-1 normalized)
    let sustain: Double  // Sustain level (0-1)
    let release: Double  // Release time (0-1 normalized)
    
    // Optional: current envelope position (0-1, nil = not playing)
    var currentPosition: Double? = nil
    
    // Display options
    var showGrid: Bool = true
    var curveColor: Color = .cyan
    var positionColor: Color = .orange
    var gridColor: Color = .gray.opacity(0.2)
    var backgroundColor: Color = Color(red: 0.08, green: 0.08, blue: 0.08)
    
    // Layout
    private let sustainWidth: Double = 0.15  // Sustain phase takes 15% of width
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor)
                
                // Grid lines
                if showGrid {
                    EnvelopeGrid(width: width, height: height)
                        .stroke(gridColor, lineWidth: 0.5)
                }
                
                // Envelope curve
                EnvelopeCurve(
                    attack: attack,
                    decay: decay,
                    sustain: sustain,
                    release: release,
                    sustainWidth: sustainWidth,
                    width: width,
                    height: height
                )
                .stroke(curveColor, lineWidth: 2)
                
                // Current position indicator
                if let position = currentPosition {
                    let point = curvePoint(at: position, width: width, height: height)
                    Circle()
                        .fill(positionColor)
                        .frame(width: 8, height: 8)
                        .position(point)
                    
                    // Vertical line at current position
                    Path { path in
                        path.move(to: CGPoint(x: point.x, y: height))
                        path.addLine(to: CGPoint(x: point.x, y: point.y))
                    }
                    .stroke(positionColor.opacity(0.5), lineWidth: 1)
                }
            }
        }
        .aspectRatio(2.5, contentMode: .fit)
    }
    
    // Calculate point on envelope curve at normalized position (0-1)
    private func curvePoint(at position: Double, width: Double, height: Double) -> CGPoint {
        // Distribute width: attack | decay | sustain | release
        let attackEnd = attack * (1 - sustainWidth - release) / (attack + decay + release + 0.001)
        let decayEnd = attackEnd + decay * (1 - sustainWidth) / (attack + decay + release + 0.001)
        let sustainEnd = decayEnd + sustainWidth
        // releaseEnd = 1.0
        
        let x: Double
        let y: Double
        
        if position <= attackEnd {
            // Attack phase: 0 to 1
            let t = attackEnd > 0 ? position / attackEnd : 0
            x = position
            y = 1.0 - exponentialCurve(t)  // Flip for drawing
        } else if position <= decayEnd {
            // Decay phase: 1 to sustain
            let t = (decayEnd - attackEnd) > 0 ? (position - attackEnd) / (decayEnd - attackEnd) : 0
            x = position
            y = 1.0 - (1.0 - (1.0 - sustain) * exponentialCurve(t))
        } else if position <= sustainEnd {
            // Sustain phase: constant
            x = position
            y = 1.0 - sustain
        } else {
            // Release phase: sustain to 0
            let t = (1.0 - sustainEnd) > 0 ? (position - sustainEnd) / (1.0 - sustainEnd) : 0
            x = position
            y = 1.0 - (sustain * (1.0 - exponentialCurve(t)))
        }
        
        return CGPoint(x: x * width, y: y * height)
    }
    
    // Exponential curve for analog-style ADSR
    private func exponentialCurve(_ t: Double) -> Double {
        1.0 - exp(-5.0 * t)
    }
}

/// Grid lines for envelope display
struct EnvelopeGrid: Shape {
    let width: Double
    let height: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Horizontal lines at 25%, 50%, 75%
        for y in [0.25, 0.5, 0.75] {
            path.move(to: CGPoint(x: 0, y: height * y))
            path.addLine(to: CGPoint(x: width, y: height * y))
        }
        
        // Vertical lines at 25%, 50%, 75%
        for x in [0.25, 0.5, 0.75] {
            path.move(to: CGPoint(x: width * x, y: 0))
            path.addLine(to: CGPoint(x: width * x, y: height))
        }
        
        return path
    }
}

/// The actual ADSR curve shape
struct EnvelopeCurve: Shape {
    let attack: Double
    let decay: Double
    let sustain: Double
    let release: Double
    let sustainWidth: Double
    let width: Double
    let height: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Normalize times for display
        let totalTime = attack + decay + release + 0.001
        let attackWidth = attack / totalTime * (1 - sustainWidth)
        let decayWidth = decay / totalTime * (1 - sustainWidth)
        let releaseWidth = release / totalTime * (1 - sustainWidth)
        
        // Starting point (bottom left)
        path.move(to: CGPoint(x: 0, y: height))
        
        // Attack: exponential rise to peak
        let attackEnd = attackWidth * width
        addExponentialSegment(
            to: &path,
            from: CGPoint(x: 0, y: height),
            to: CGPoint(x: attackEnd, y: 0),
            isRising: true
        )
        
        // Decay: exponential fall to sustain
        let decayEnd = attackEnd + decayWidth * width
        let sustainY = height * (1 - sustain)
        addExponentialSegment(
            to: &path,
            from: CGPoint(x: attackEnd, y: 0),
            to: CGPoint(x: decayEnd, y: sustainY),
            isRising: false
        )
        
        // Sustain: horizontal line
        let sustainEnd = decayEnd + sustainWidth * width
        path.addLine(to: CGPoint(x: sustainEnd, y: sustainY))
        
        // Release: exponential fall to zero
        addExponentialSegment(
            to: &path,
            from: CGPoint(x: sustainEnd, y: sustainY),
            to: CGPoint(x: width, y: height),
            isRising: false
        )
        
        return path
    }
    
    // Add exponential curve segment using quadratic bezier
    private func addExponentialSegment(to path: inout Path, from: CGPoint, to: CGPoint, isRising: Bool) {
        // Control point for exponential-like curve
        // For rising: control point below the midpoint (fast start, slow end)
        // For falling: control point above the midpoint (fast start, slow end)
        let dx = to.x - from.x
        let dy = to.y - from.y
        
        let controlX = from.x + dx * 0.3
        let controlY: CGFloat
        
        if isRising {
            // Fast rise at start
            controlY = from.y + dy * 0.7
        } else {
            // Fast fall at start
            controlY = from.y + dy * 0.3
        }
        
        path.addQuadCurve(to: to, control: CGPoint(x: controlX, y: controlY))
    }
}

// MARK: - Preview

#Preview("ADSR Variations") {
    VStack(spacing: 20) {
        Text("Envelope Display Variations")
            .font(.headline)
            .foregroundColor(.white)
        
        // Short attack, long decay
        VStack(alignment: .leading) {
            Text("Fast Attack, Long Decay")
                .font(.caption)
                .foregroundColor(.gray)
            EnvelopeDisplay(attack: 0.05, decay: 0.6, sustain: 0.5, release: 0.35)
                .frame(height: 60)
        }
        
        // Slow attack
        VStack(alignment: .leading) {
            Text("Slow Attack (Pad)")
                .font(.caption)
                .foregroundColor(.gray)
            EnvelopeDisplay(attack: 0.5, decay: 0.2, sustain: 0.8, release: 0.3)
                .frame(height: 60)
        }
        
        // Percussive
        VStack(alignment: .leading) {
            Text("Percussive")
                .font(.caption)
                .foregroundColor(.gray)
            EnvelopeDisplay(attack: 0.01, decay: 0.3, sustain: 0.0, release: 0.2)
                .frame(height: 60)
        }
        
        // With position indicator
        VStack(alignment: .leading) {
            Text("With Position Indicator")
                .font(.caption)
                .foregroundColor(.gray)
            EnvelopeDisplay(
                attack: 0.15,
                decay: 0.25,
                sustain: 0.6,
                release: 0.3,
                currentPosition: 0.35  // In decay phase
            )
            .frame(height: 60)
        }
        
        // Full sustain
        VStack(alignment: .leading) {
            Text("Organ (Full Sustain)")
                .font(.caption)
                .foregroundColor(.gray)
            EnvelopeDisplay(attack: 0.01, decay: 0.01, sustain: 1.0, release: 0.1)
                .frame(height: 60)
        }
    }
    .padding()
    .background(Color(red: 0.05, green: 0.05, blue: 0.05))
}

#Preview("Single Envelope") {
    EnvelopeDisplay(
        attack: 0.1,
        decay: 0.3,
        sustain: 0.7,
        release: 0.4,
        currentPosition: 0.5
    )
    .frame(width: 200, height: 80)
    .padding()
    .background(Color.black)
}
