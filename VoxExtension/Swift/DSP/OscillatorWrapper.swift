import Foundation
internal import VoxCore

/// Swift wrapper for oscillator classes
/// Note: PolyBLEPOscillator and DPWOscillator C++ implementations are stubbed
/// This wrapper uses SinOscillator for all types as a fallback
public class OscillatorWrapper {
    // Swift enum for oscillator types
    public enum OscillatorType {
        case sine
        case polyBLEPSaw
        case polyBLEPSquare
        case polyBLEPTriangle
        case dpwSaw
        case dpwSquare
        case noise
    }
    
    // Use SinOscillator for now (C++ class that exists)
    private var sinOscillator: SinOscillator
    private let oscillatorType: OscillatorType
    private let sampleRate: Double
    
    // For noise generation
    private var noiseState: UInt64 = 12345
    
    // Phase accumulator for non-sine waveforms (pure Swift fallback)
    private var phase: Double = 0.0
    private var phaseIncrement: Double = 0.0
    
    public var frequency: Double = 440.0 {
        didSet {
            updateFrequency()
        }
    }
    
    public var pulseWidth: Double = 0.5
    
    /// Factory method to create the proper oscillator type
    public static func oscillator(type: OscillatorType, sampleRate: Double) -> OscillatorWrapper {
        return OscillatorWrapper(type: type, sampleRate: sampleRate)
    }
    
    /// Initialize with type and sample rate
    public init(type: OscillatorType = .sine, sampleRate: Double) {
        self.oscillatorType = type
        self.sampleRate = sampleRate
        self.sinOscillator = SinOscillator(sampleRate)
        
        // Set initial frequency
        self.frequency = 440.0
        updateFrequency()
    }
    
    /// Process and generate a single audio sample
    public func process() -> Double {
        switch oscillatorType {
        case .sine:
            return sinOscillator.process()
            
        case .polyBLEPSaw, .dpwSaw:
            // Simple naive sawtooth (no anti-aliasing)
            let output = 2.0 * phase - 1.0
            updatePhase()
            return output
            
        case .polyBLEPSquare, .dpwSquare:
            // Simple naive square wave
            let output = phase < pulseWidth ? 1.0 : -1.0
            updatePhase()
            return output
            
        case .polyBLEPTriangle:
            // Simple naive triangle wave
            let output = phase < 0.5 ? (4.0 * phase - 1.0) : (3.0 - 4.0 * phase)
            updatePhase()
            return output
            
        case .noise:
            // Simple xorshift noise
            noiseState ^= noiseState << 13
            noiseState ^= noiseState >> 7
            noiseState ^= noiseState << 17
            return Double(Int64(bitPattern: noiseState) % 65536) / 32768.0 - 1.0
        }
    }
    
    /// Reset oscillator state
    public func reset() {
        sinOscillator.reset()
        phase = 0.0
    }
    
    // Private helper to update frequency on all oscillators
    private func updateFrequency() {
        sinOscillator.setFrequency(frequency)
        phaseIncrement = frequency / sampleRate
    }
    
    // Update phase for naive waveforms
    private func updatePhase() {
        phase += phaseIncrement
        if phase >= 1.0 {
            phase -= 1.0
        }
    }
}
