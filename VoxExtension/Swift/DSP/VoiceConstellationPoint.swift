//
//  VoiceConstellationPoint.swift
//  VoxExtension
//
//  Per-voice state for constellation display visualization.
//  Written by audio thread into an atomic array, read by Metal renderer.
//  Layout matches the Metal shader's ConstellationPointIn struct.
//

/// A single voice's state for the constellation display.
/// Packed layout matches the Metal shader struct exactly.
public struct VoiceConstellationPoint {
    /// MIDI note number (0-127), used for angular position on the ring.
    public var pitch: Float
    /// Current amplitude (0..1), used for brightness/radius.
    public var amplitude: Float
    /// Whether this voice is currently active (gate on). 1.0 = active, 0.0 = silent.
    public var active: Float
    /// Voice index (0..7), used for base position on the ring.
    public var voiceIndex: Float
    /// Pan position (-1..1), could offset angular position.
    public var pan: Float
    /// Detune offset in cents, shown as slight radial displacement.
    public var detuneCents: Float
    /// Padding to align to 32 bytes (8 floats).
    public var _pad0: Float
    public var _pad1: Float

    public init(
        pitch: Float = 0,
        amplitude: Float = 0,
        active: Float = 0,
        voiceIndex: Float = 0,
        pan: Float = 0,
        detuneCents: Float = 0
    ) {
        self.pitch = pitch
        self.amplitude = amplitude
        self.active = active
        self.voiceIndex = voiceIndex
        self.pan = pan
        self.detuneCents = detuneCents
        self._pad0 = 0
        self._pad1 = 0
    }
}