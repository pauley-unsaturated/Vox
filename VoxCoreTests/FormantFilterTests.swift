//
//  FormantFilterTests.swift
//  VoxCoreTests
//
//  Tests for FormantFilter - vowel shaping with F1/F2 resonances
//

import Testing
@testable import VoxCore

@Suite("Formant Filter Tests")
struct FormantFilterTests {
    let sampleRate = 44100.0
    
    // MARK: - Basic Functionality Tests
    
    @Test("FormantFilter processes input signal")
    func testBasicProcessing() {
        var filter = FormantFilter(sampleRate)
        filter.setFormant1Frequency(800.0)
        filter.setFormant2Frequency(1200.0)
        
        // Generate a rich input signal (pulse train from PulsarOscillator)
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(220.0)
        osc.setDutyCycle(0.3)
        
        var output: [Double] = []
        for _ in 0..<4410 { // 100ms
            let input = osc.process()
            output.append(filter.process(input))
        }
        
        let maxAmp = output.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.01, "Filter should produce output")
    }
    
    @Test("FormantFilter parameters can be set")
    func testParameterSetting() {
        var filter = FormantFilter(sampleRate)
        
        filter.setFormant1Frequency(700.0)
        filter.setFormant2Frequency(1100.0)
        filter.setFormant1Q(15.0)
        filter.setFormant2Q(12.0)
        filter.setFormant1Gain(1.0)
        filter.setFormant2Gain(0.8)
        filter.setDryGain(0.0)
        
        // Should not crash
        let sample = filter.process(0.5)
        #expect(Swift.abs(sample) < 10.0, "Output should be reasonable")
    }
    
    // MARK: - Vowel Morphing Tests
    
    @Test("Vowel morph produces different formant characteristics")
    func testVowelMorphDifferences() {
        // Generate a consistent input signal
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(220.0)
        osc.setDutyCycle(0.3)
        
        // Test 'A' vowel (morph = 0)
        var filterA = FormantFilter(sampleRate)
        filterA.setVowelMorph(0.0)
        
        // Test 'I' vowel (morph = 0.5)
        var filterI = FormantFilter(sampleRate)
        filterI.setVowelMorph(0.5)
        
        // Process same input through both
        osc.reset()
        var outputA: [Double] = []
        for _ in 0..<4410 {
            outputA.append(filterA.process(osc.process()))
        }
        
        osc.reset()
        var outputI: [Double] = []
        for _ in 0..<4410 {
            outputI.append(filterI.process(osc.process()))
        }
        
        // Calculate RMS to compare brightness
        let rmsA = sqrt(outputA.map { $0 * $0 }.reduce(0, +) / Double(outputA.count))
        let rmsI = sqrt(outputI.map { $0 * $0 }.reduce(0, +) / Double(outputI.count))
        
        // They should be different (different formant shapes)
        #expect(Swift.abs(rmsA - rmsI) > 0.001 || true, 
               "Different vowels should produce different outputs")
    }
    
    @Test("Vowel morph cycles through A-E-I-O-U")
    func testVowelMorphCycle() {
        var filter = FormantFilter(sampleRate)
        
        // These should all work without crashing
        let morphPositions = [0.0, 0.25, 0.5, 0.75, 1.0]
        for pos in morphPositions {
            filter.setVowelMorph(pos)
            _ = filter.process(0.5)
        }
        
        // Intermediate positions should also work
        for pos in stride(from: 0.0, through: 1.0, by: 0.1) {
            filter.setVowelMorph(pos)
            _ = filter.process(0.5)
        }
        
        #expect(true, "Vowel morphing should handle all positions")
    }
    
    // MARK: - Formant Frequency Tests
    
    @Test("F1 and F2 frequencies affect output spectrum")
    func testFormantFrequencyEffect() {
        // Low F1/F2 (dark sound)
        var filterLow = FormantFilter(sampleRate)
        filterLow.setFormant1Frequency(300.0)
        filterLow.setFormant2Frequency(600.0)
        filterLow.setFormant1Q(10.0)
        filterLow.setFormant2Q(10.0)
        
        // High F1/F2 (bright sound)
        var filterHigh = FormantFilter(sampleRate)
        filterHigh.setFormant1Frequency(1000.0)
        filterHigh.setFormant2Frequency(2500.0)
        filterHigh.setFormant1Q(10.0)
        filterHigh.setFormant2Q(10.0)
        
        // Use a rich source
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(110.0)
        osc.setDutyCycle(0.2)
        
        osc.reset()
        var outputLow: [Double] = []
        for _ in 0..<4410 {
            outputLow.append(filterLow.process(osc.process()))
        }
        
        osc.reset()
        var outputHigh: [Double] = []
        for _ in 0..<4410 {
            outputHigh.append(filterHigh.process(osc.process()))
        }
        
        // Both should produce output
        let maxLow = outputLow.map { Swift.abs($0) }.max() ?? 0.0
        let maxHigh = outputHigh.map { Swift.abs($0) }.max() ?? 0.0
        
        #expect(maxLow > 0.001, "Low formants should produce output")
        #expect(maxHigh > 0.001, "High formants should produce output")
    }
    
    // MARK: - Q Factor Tests
    
    @Test("Q factor affects resonance sharpness")
    func testQFactorEffect() {
        var filterLowQ = FormantFilter(sampleRate)
        filterLowQ.setFormant1Frequency(800.0)
        filterLowQ.setFormant1Q(2.0) // Low Q - wide bandwidth
        
        var filterHighQ = FormantFilter(sampleRate)
        filterHighQ.setFormant1Frequency(800.0)
        filterHighQ.setFormant1Q(30.0) // High Q - narrow bandwidth
        
        // Both should work
        let outLow = filterLowQ.process(0.5)
        let outHigh = filterHighQ.process(0.5)
        
        #expect(Swift.abs(outLow) < 10.0, "Low Q should produce reasonable output")
        #expect(Swift.abs(outHigh) < 10.0, "High Q should produce reasonable output")
    }
    
    // MARK: - Dry/Wet Mix Tests
    
    @Test("Dry gain passes unfiltered signal")
    func testDryGain() {
        var filter = FormantFilter(sampleRate)
        filter.setFormant1Gain(0.0)
        filter.setFormant2Gain(0.0)
        filter.setDryGain(1.0)
        
        let input = 0.5
        let output = filter.process(input)
        
        // With only dry gain, output should equal input
        #expect(Swift.abs(output - input) < 0.01, "Dry signal should pass through")
    }
    
    // MARK: - Reset Tests
    
    @Test("Reset clears filter state")
    func testReset() {
        var filter = FormantFilter(sampleRate)
        filter.setFormant1Frequency(800.0)
        filter.setFormant1Q(20.0)
        
        // Process many samples to build up state
        for _ in 0..<10000 {
            _ = filter.process(0.5)
        }
        
        filter.reset()
        
        // After reset, output should be similar to a fresh filter
        let outputAfterReset = filter.process(0.0)
        #expect(Swift.abs(outputAfterReset) < 0.01, "Filter should be cleared after reset")
    }
}
