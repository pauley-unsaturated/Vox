//
//  LevelMeter.swift
//  VoxExtension
//
//  Created by Mark Pauley on 7/4/25.
//

import SwiftUI

/// A level meter display for audio visualization
/// Level is passed in externally (from OutputLevelObserver)
struct LevelMeter: View {
    let level: Double
    
    let orientation: Orientation
    let segmentCount: Int
    let width: CGFloat
    let height: CGFloat
    
    enum Orientation: Equatable {
        case vertical
        case horizontal
    }
    
    init(
        level: Double = 0.0,
        orientation: Orientation = .vertical,
        segmentCount: Int = 12,
        width: CGFloat = 20,
        height: CGFloat = 120
    ) {
        self.level = max(0.0, min(1.0, level))
        self.orientation = orientation
        self.segmentCount = segmentCount
        self.width = width
        self.height = height
    }
    
    private func segmentColor(for index: Int) -> Color {
        // Match professional meter standards (like Logic Pro):
        // - Green: bottom ~85% (up to about -6dB)
        // - Yellow: next ~10% (-6dB to -3dB)
        // - Red: top ~5% (-3dB to 0dB)
        let normalizedIndex = Double(index) / Double(segmentCount - 1)
        
        switch normalizedIndex {
        case 0.0..<0.85:
            return .green
        case 0.85..<0.95:
            return .yellow
        default:
            return .red
        }
    }
    
    private func shouldShowSegment(at index: Int) -> Bool {
        let segmentThreshold = Double(index) / Double(segmentCount - 1)
        return level >= segmentThreshold
    }
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black)
            
            if orientation == .vertical {
                // Vertical meter - segments stacked vertically
                VStack(spacing: 1) {
                    ForEach((0..<segmentCount).reversed(), id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                shouldShowSegment(at: index) ?
                                segmentColor(for: index) :
                                segmentColor(for: index).opacity(0.15)
                            )
                    }
                }
                .padding(2)
            } else {
                // Horizontal meter - segments stacked horizontally
                HStack(spacing: 1) {
                    ForEach(0..<segmentCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                shouldShowSegment(at: index) ?
                                segmentColor(for: index) :
                                segmentColor(for: index).opacity(0.15)
                            )
                    }
                }
                .padding(2)
            }
        }
        .frame(width: width, height: height)
        // Use drawingGroup to render to Metal texture, isolating from layout system
        .drawingGroup()
    }
}



/// A simple peak level indicator (single LED style)
/// Active state is controlled externally via the `isActive` parameter
struct PeakIndicator: View {
    let isActive: Bool
    let size: CGFloat
    let color: Color
    
    init(isActive: Bool = false, size: CGFloat = 12, color: Color = .red) {
        self.isActive = isActive
        self.size = size
        self.color = color
    }
    
    var body: some View {
        Circle()
            .fill(
                isActive ?
                    RadialGradient(
                        colors: [color, color.opacity(0.3)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    ) :
                    RadialGradient(
                        colors: [color.opacity(0.15), color.opacity(0.05)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.1), value: isActive)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var level: Double = 0.5
        @State private var isPeaking: Bool = false
        
        var body: some View {
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("OUT")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.gray)
                    
                    LevelMeter(level: level, orientation: .vertical, segmentCount: 10, width: 12, height: 60)
                    
                    PeakIndicator(isActive: isPeaking, size: 10, color: .red)
                }
                
                LevelMeter(level: level, orientation: .horizontal, width: 100, height: 16)
                
                VStack(spacing: 8) {
                    PeakIndicator(isActive: false, color: .green)
                    PeakIndicator(isActive: true, color: .orange)
                    PeakIndicator(isActive: true, color: .red)
                }
                
                VStack {
                    Slider(value: $level, in: 0...1)
                        .frame(width: 100)
                    Toggle("Peak", isOn: $isPeaking)
                }
            }
            .padding()
            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        }
    }
    
    return PreviewWrapper()
}
