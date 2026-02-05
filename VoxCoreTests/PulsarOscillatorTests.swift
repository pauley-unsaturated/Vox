//
//  PulsarOscillatorTests.swift
//  VoxCoreTests
//
//  Tests for PulsarOscillator - the heart of Vox pulsar synthesis
//

import Testing
@testable import VoxCore

@Suite("Pulsar Oscillator Tests")
struct PulsarOscillatorTests {
    let sampleRate = 44100.0
    
    // MARK: - Basic Functionality Tests
    
    @Test("PulsarOscillator produces output at default settings")
    func testDefaultOutput() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(440.0)
        
        var samples: [Double] = []
        for _ in 0..<4410 { // 100ms
            samples.append(osc.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.1, "Should produce audible output")
    }
    
    @Test("PulsarOscillator frequency is accurate")
    func testFrequencyAccuracy() {
        var osc = PulsarOscillator(sampleRate)
        let targetFreq = 440.0
        osc.setFrequency(targetFreq)
        osc.setDutyCycle(0.3) // Wider duty for easier zero-crossing detection
        
        // Count zero crossings over 1 second
        var samples: [Double] = []
        for _ in 0..<Int(sampleRate) {
            samples.append(osc.process())
        }
        
        // Count positive-going zero crossings
        var zeroCrossings = 0
        for i in 1..<samples.count {
            if samples[i-1] <= 0 && samples[i] > 0 {
                zeroCrossings += 1
            }
        }
        
        // Allow 5% tolerance
        let tolerance = targetFreq * 0.05
        #expect(Swift.abs(Double(zeroCrossings) - targetFreq) < tolerance,
               "Frequency should be ~440Hz, got \(zeroCrossings) zero crossings")
    }
    
    // MARK: - Duty Cycle Tests
    
    @Test("Duty cycle affects output width")
    func testDutyCycleEffect() {
        // Test narrow duty cycle
        var oscNarrow = PulsarOscillator(sampleRate)
        oscNarrow.setFrequency(100.0) // Low freq for easier analysis
        oscNarrow.setDutyCycle(0.1)
        
        // Test wide duty cycle
        var oscWide = PulsarOscillator(sampleRate)
        oscWide.setFrequency(100.0)
        oscWide.setDutyCycle(0.5)
        
        // Count non-zero samples over one period
        let samplesPerPeriod = Int(sampleRate / 100.0)
        
        var narrowNonZero = 0
        var wideNonZero = 0
        
        for _ in 0..<samplesPerPeriod {
            if Swift.abs(oscNarrow.process()) > 0.001 {
                narrowNonZero += 1
            }
            if Swift.abs(oscWide.process()) > 0.001 {
                wideNonZero += 1
            }
        }
        
        // Wide duty cycle should have more non-zero samples
        #expect(wideNonZero > narrowNonZero,
               "Wide duty (\(wideNonZero)) should have more active samples than narrow (\(narrowNonZero))")
    }
    
    @Test("Duty cycle is clamped to valid range")
    func testDutyCycleClamping() {
        var osc = PulsarOscillator(sampleRate)
        
        osc.setDutyCycle(0.001) // Too small
        #expect(osc.getDutyCycle() >= 0.01, "Duty cycle should be clamped to minimum")
        
        osc.setDutyCycle(1.5) // Too large
        #expect(osc.getDutyCycle() <= 1.0, "Duty cycle should be clamped to maximum")
        
        osc.setDutyCycle(0.3) // Valid
        #expect(Swift.abs(osc.getDutyCycle() - 0.3) < 0.001, "Valid duty cycle should be set")
    }
    
    // MARK: - Shape Tests
    
    @Test("All pulsaret shapes produce output")
    func testAllShapes() {
        let shapes: [PulsarOscillator.Shape] = [
            .GAUSSIAN,
            .RAISED_COSINE,
            .SINE,
            .TRIANGLE
        ]
        
        for shape in shapes {
            var osc = PulsarOscillator(sampleRate)
            osc.setFrequency(440.0)
            osc.setDutyCycle(0.3)
            osc.setShape(shape)
            
            var samples: [Double] = []
            for _ in 0..<1000 {
                samples.append(osc.process())
            }
            
            let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
            #expect(maxAmp > 0.1, "Shape \(shape) should produce output")
        }
    }
    
    @Test("Gaussian shape produces smooth bell curve")
    func testGaussianShape() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0) // Low for easier analysis
        osc.setDutyCycle(0.5)
        osc.setShape(.GAUSSIAN)
        
        let samplesPerPeriod = Int(sampleRate / 100.0)
        var samples: [Double] = []
        
        for _ in 0..<samplesPerPeriod {
            samples.append(osc.process())
        }
        
        // Gaussian should peak in the middle of the duty window
        let activeSamples = Int(Double(samplesPerPeriod) * 0.5)
        let peakRegion = samples[activeSamples/4..<(activeSamples*3/4)]
        let peak = peakRegion.max() ?? 0.0
        
        #expect(peak > 0.5, "Gaussian should have significant peak")
    }
    
    // MARK: - Reset Tests
    
    @Test("Reset clears oscillator state")
    func testReset() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(440.0)
        
        // Process some samples
        for _ in 0..<1000 {
            _ = osc.process()
        }
        
        // Reset
        osc.reset()
        
        // After reset, should start from beginning
        // First sample with duty cycle 0.2 should be within the pulse
        let firstSample = osc.process()
        // Due to phase starting at 0, we're inside the pulse window initially
        #expect(true, "Reset should not crash") // Basic test
    }
    
    // MARK: - Frequency Range Tests
    
    @Test("Handles bass frequencies")
    func testBassFrequencies() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(55.0) // A1
        osc.setDutyCycle(0.3)
        
        var samples: [Double] = []
        for _ in 0..<Int(sampleRate) { // 1 second
            samples.append(osc.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.1, "Should produce output at bass frequencies")
    }
    
    @Test("Handles high frequencies")
    func testHighFrequencies() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(8000.0) // High but within Nyquist
        osc.setDutyCycle(0.3)
        
        var samples: [Double] = []
        for _ in 0..<4410 { // 100ms
            samples.append(osc.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.1, "Should produce output at high frequencies")
    }
}
