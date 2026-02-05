//
//  VoxCoreTests.swift
//  VoxCoreTests
//
//  Tests for Vox Pulsar Synthesis core components
//

import Testing
@testable import VoxCore

struct VoxCoreTests {

    @Test func pulsarOscillatorBasicFunctionality() async throws {
        // Verify PulsarOscillator works correctly
        var osc = PulsarOscillator(44100.0)
        osc.setFrequency(440.0)
        osc.setDutyCycle(0.2)
        osc.setShape(PulsarOscillator.Shape.RAISED_COSINE)
        
        // Generate samples
        var samples: [Double] = []
        for _ in 0..<1000 {
            samples.append(osc.process())
        }
        
        // Should produce output
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.1, "PulsarOscillator should produce output")
        
        // Should be in valid range
        for sample in samples {
            #expect(sample >= -1.0 && sample <= 1.0, "Sample should be in [-1, 1] range")
        }
    }
    
    @Test func formantFilterBasicFunctionality() async throws {
        // Verify FormantFilter processes audio
        var filter = FormantFilter(44100.0)
        filter.setFormant1Frequency(800.0)
        filter.setFormant2Frequency(1200.0)
        filter.setFormant1Q(10.0)
        filter.setFormant2Q(10.0)
        
        // Process a simple sine wave
        var osc = SinOscillator(44100.0)
        osc.setFrequency(220.0)
        
        var output: [Double] = []
        for _ in 0..<1000 {
            let input = osc.process()
            output.append(filter.process(input))
        }
        
        // Should produce output (formant filtering)
        let maxAmp = output.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.01, "FormantFilter should produce output")
    }
    
    @Test func vowelMorphingFunctionality() async throws {
        // Test vowel morphing
        var filter = FormantFilter(44100.0)
        
        // Test different vowel positions
        filter.setVowelMorph(0.0)  // A
        filter.setVowelMorph(0.25) // E
        filter.setVowelMorph(0.5)  // I
        filter.setVowelMorph(0.75) // O
        filter.setVowelMorph(1.0)  // U
        
        // Should not crash
        #expect(true, "Vowel morphing should work without crashing")
    }
    
    @Test func adsrEnvelopeFunctionality() async throws {
        // Test ADSR envelope
        var env = ADSREnvelope(44100.0)
        env.setAttackTime(0.01)
        env.setDecayTime(0.1)
        env.setSustainLevel(0.7)
        env.setReleaseTime(0.3)
        
        // Trigger envelope
        env.noteOn()
        
        // Process through attack
        var attackSamples: [Double] = []
        for _ in 0..<441 { // 10ms at 44.1kHz
            attackSamples.append(env.process())
        }
        
        // Should rise during attack
        #expect(attackSamples.last! > attackSamples.first!, "Envelope should rise during attack")
        
        // Should eventually reach sustain level
        for _ in 0..<4410 { // Skip 100ms
            _ = env.process()
        }
        
        let sustainLevel = env.process()
        #expect(sustainLevel > 0.5, "Should be at or near sustain level")
        
        // Test note off
        env.noteOff()
        #expect(env.getState() == ADSREnvelope.State.RELEASE, "Should be in release state")
    }
    
    @Test func sinOscillatorFunctionality() async throws {
        // Verify SinOscillator (kept for LFO use)
        var osc = SinOscillator(44100.0)
        osc.setFrequency(440.0)
        
        // Generate samples
        var samples: [Double] = []
        for _ in 0..<1000 {
            samples.append(osc.process())
        }
        
        // Should produce sine output in range [-1, 1]
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.9, "SinOscillator should produce full amplitude")
        #expect(maxAmp <= 1.0, "SinOscillator should not exceed 1.0")
    }
}
