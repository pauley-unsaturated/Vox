//
//  ChaosPoint.swift
//  VoxExtension
//
//  Data type for chaos attractor 2D phase-space points.
//  Written by audio thread into AtomicScopeBuffer<ChaosPoint>,
//  read by Metal renderer for trail visualization.
//

/// A single point in 2D phase space for chaos attractor visualization.
/// Packed layout matches the Metal shader's ChaosPointIn struct.
public struct ChaosPoint {
    /// Attractor x coordinate, normalized to approximately -1..1.
    public var x: Float
    /// Attractor y coordinate, normalized to approximately -1..1.
    public var y: Float
    /// Age of this point: 0 = newest, 1 = oldest. Set by renderer, not audio thread.
    public var age: Float
    
    public init(x: Float = 0, y: Float = 0, age: Float = 0) {
        self.x = x
        self.y = y
        self.age = age
    }
}
