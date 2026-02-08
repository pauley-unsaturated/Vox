//
//  GrainPoint.swift
//  VoxExtension
//
//  Data type for grain cloud scatter plot visualization.
//  Written by audio thread into AtomicScopeBuffer<GrainPoint>,
//  read by Metal renderer for particle cloud rendering.
//

/// A single grain in 2D space for grain cloud scatter plot visualization.
/// Packed layout matches the Metal shader's GrainPointIn struct.
public struct GrainPoint {
    /// X position: normalized time/frequency position (-1..1).
    public var x: Float
    /// Y position: normalized amplitude/density (-1..1).
    public var y: Float
    /// Point size: proportional to grain duration (0..1).
    public var size: Float
    /// Age of this grain: 0 = newest, 1 = oldest. Set by renderer for fade.
    public var age: Float
    /// Amplitude of the grain (0..1), controls brightness.
    public var amplitude: Float

    public init(x: Float = 0, y: Float = 0, size: Float = 0.5, age: Float = 0, amplitude: Float = 1.0) {
        self.x = x
        self.y = y
        self.size = size
        self.age = age
        self.amplitude = amplitude
    }
}