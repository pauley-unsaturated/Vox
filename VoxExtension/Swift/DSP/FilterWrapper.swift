import Foundation

/// Swift-only filter wrapper for testing and development
/// Note: MoogLadderFilter C++ implementation is stubbed - this is a pure Swift fallback
public class FilterWrapper {
    // Swift enum for filter modes
    public enum Mode {
        case lowpass
        case bandpass
        case highpass
    }
    
    private var _cutoff: Float = 1000.0
    private var _resonance: Float = 0.5
    private var _mode: Mode = .lowpass
    private var _poles: Int = 4
    private let sampleRate: Double
    
    // Simple IIR filter state
    private var y1: Float = 0.0
    private var y2: Float = 0.0
    
    /// Initialize with sample rate
    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }
    
    /// Set the filter cutoff frequency
    public func setCutoff(_ cutoff: Double) {
        _cutoff = Float(max(20.0, min(cutoff, sampleRate * 0.49)))
    }
    
    /// Get the current cutoff frequency
    public func cutoff() -> Double {
        return Double(_cutoff)
    }
    
    /// Set the filter resonance (0.0 to 1.0)
    public func setResonance(_ resonance: Double) {
        _resonance = Float(max(0.0, min(resonance, 1.0)))
    }
    
    /// Get the current resonance value
    public func resonance() -> Double {
        return Double(_resonance)
    }
    
    /// Set the filter mode (lowpass, bandpass, highpass)
    public func setMode(_ mode: Mode) {
        _mode = mode
    }
    
    /// Get the current filter mode
    public func mode() -> Mode {
        return _mode
    }
    
    /// Set the number of filter poles
    public func setPoles(_ poles: Int) {
        _poles = max(1, min(poles, 4))
    }
    
    /// Get the current number of filter poles
    public func poles() -> Int {
        return _poles
    }
    
    /// Process a single audio sample (simple one-pole lowpass approximation)
    public func process(withInput input: Double) -> Double {
        // Simple one-pole lowpass filter coefficient
        let omega = 2.0 * Float.pi * _cutoff / Float(sampleRate)
        let alpha = omega / (1.0 + omega)
        
        // Apply filter based on mode
        switch _mode {
        case .lowpass:
            y1 = y1 + alpha * (Float(input) - y1)
            return Double(y1)
        case .highpass:
            y1 = y1 + alpha * (Float(input) - y1)
            return input - Double(y1)
        case .bandpass:
            // Simple bandpass approximation
            y1 = y1 + alpha * (Float(input) - y1)
            y2 = y2 + alpha * (y1 - y2)
            return Double(y1 - y2)
        }
    }
    
    /// Reset the filter state
    public func reset() {
        y1 = 0.0
        y2 = 0.0
    }
}
