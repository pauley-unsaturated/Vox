//
//  SynthColors.swift
//  VoxExtension
//
//  Fixed color palette that works in both light and dark mode.
//  The synth UI always uses a dark theme regardless of system settings.
//

import SwiftUI

extension Color {
    /// Primary text color - always white for synth UI
    static let synthPrimary = Color.white
    
    /// Secondary text color - always light gray for synth UI
    static let synthSecondary = Color(white: 0.6)
    
    /// Tertiary text color - dimmer gray
    static let synthTertiary = Color(white: 0.4)
}
