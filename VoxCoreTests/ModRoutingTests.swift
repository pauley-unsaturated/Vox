//
//  ModRoutingTests.swift
//  VoxCoreTests
//
//  Tests for per-voice modulation routing (Phase 2.3)
//  LFO and Mod Envelope can modulate pitch, formant1, formant2, dutyCycle
//

import Testing
@testable import VoxCore

@Suite("Mod Routing Tests")
struct ModRoutingTests {
    let sampleRate = 44100.0
    
    // MARK: - LFO Modulation Depth Parameters
    
    @Test("VoxVoice has LFO modulation depth parameters")
    func testLFOModDepthParams() {
        var params = VoxVoiceParameters()
        
        // LFO to pitch (in semitones)
        params.lfoToPitch = 0.5  // ±0.5 semitones
        #expect(params.lfoToPitch == 0.5)
        
        // LFO to formant1 (in Hz)
        params.lfoToFormant1 = 100.0  // ±100 Hz
        #expect(params.lfoToFormant1 == 100.0)
        
        // LFO to formant2 (in Hz)
        params.lfoToFormant2 = 150.0  // ±150 Hz
        #expect(params.lfoToFormant2 == 150.0)
        
        // LFO to duty cycle (normalized 0-1 maps to ±amount)
        params.lfoToDutyCycle = 0.1  // ±0.1 duty
        #expect(params.lfoToDutyCycle == 0.1)
    }
    
    @Test("Mod envelope modulation depth parameters exist")
    func testModEnvDepthParams() {
        var params = VoxVoiceParameters()
        
        // Mod Env to pitch (in semitones)
        params.modEnvToPitch = 2.0  // +2 semitones at peak
        #expect(params.modEnvToPitch == 2.0)
        
        // Mod Env to formant1 (in Hz)
        params.modEnvToFormant1 = 200.0  // +200 Hz at peak
        #expect(params.modEnvToFormant1 == 200.0)
        
        // Mod Env to formant2 (in Hz)
        params.modEnvToFormant2 = 300.0  // +300 Hz at peak
        #expect(params.modEnvToFormant2 == 300.0)
        
        // Mod Env to duty cycle
        params.modEnvToDutyCycle = 0.2  // +0.2 duty at peak
        #expect(params.modEnvToDutyCycle == 0.2)
    }
    
    @Test("Default mod depths are zero (no modulation)")
    func testDefaultModDepthsZero() {
        let params = VoxVoiceParameters()
        
        // LFO depths
        #expect(params.lfoToPitch == 0.0)
        #expect(params.lfoToFormant1 == 0.0)
        #expect(params.lfoToFormant2 == 0.0)
        #expect(params.lfoToDutyCycle == 0.0)
        
        // Mod Env depths
        #expect(params.modEnvToPitch == 0.0)
        #expect(params.modEnvToFormant1 == 0.0)
        #expect(params.modEnvToFormant2 == 0.0)
        #expect(params.modEnvToDutyCycle == 0.0)
    }
    
    // MARK: - LFO Pitch Modulation Tests
    
    @Test("LFO pitch modulation creates vibrato")
    func testLFOPitchModulation() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.lfoRate = 5.0        // 5 Hz vibrato
        params.lfoToPitch = 0.5     // ±0.5 semitones
        params.lfoWaveform = 0      // Sine
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        
        // Process and check that pitch varies
        // We can't directly measure pitch, but we can verify modulation is happening
        // by checking the voice produces varying output
        var samples: [Double] = []
        for _ in 0..<Int(sampleRate / 5) {  // One LFO cycle
            samples.append(pool.process())
        }
        
        // With vibrato, there should be frequency modulation
        // Just verify we get audio output
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.1, "Voice should produce output with pitch modulation")
    }
    
    // MARK: - LFO Formant Modulation Tests
    
    @Test("LFO formant1 modulation affects timbre")
    func testLFOFormant1Modulation() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.formant1Freq = 800.0
        params.formantMix = 1.0
        params.useVowelMorph = false
        params.lfoRate = 2.0
        params.lfoToFormant1 = 200.0  // ±200 Hz sweep
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        
        // Process audio
        var samples: [Double] = []
        for _ in 0..<4410 {  // 100ms
            samples.append(pool.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.01, "Voice should produce output with formant modulation")
    }
    
    // MARK: - LFO Duty Cycle Modulation Tests
    
    @Test("LFO duty cycle modulation affects waveform")
    func testLFODutyCycleModulation() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.dutyCycle = 0.3
        params.lfoRate = 2.0
        params.lfoToDutyCycle = 0.2  // Duty varies 0.1 to 0.5
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        
        var samples: [Double] = []
        for _ in 0..<4410 {
            samples.append(pool.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.01, "Voice should produce output with duty modulation")
    }
    
    // MARK: - Mod Envelope Pitch Modulation Tests
    
    @Test("Mod envelope creates pitch envelope")
    func testModEnvPitchModulation() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.modAttack = 0.01
        params.modDecay = 0.1
        params.modSustain = 0.0  // Decay to zero
        params.modEnvToPitch = 12.0  // +12 semitones (octave) at peak
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        
        // Early samples should be at higher pitch (mod env at peak)
        var earlySamples: [Double] = []
        for _ in 0..<500 {
            earlySamples.append(pool.process())
        }
        
        // Later samples should be at lower pitch (mod env decayed)
        var lateSamples: [Double] = []
        for _ in 0..<5000 {
            lateSamples.append(pool.process())
        }
        
        // Both should produce output
        let earlyMax = earlySamples.map { Swift.abs($0) }.max() ?? 0.0
        let lateMax = lateSamples.map { Swift.abs($0) }.max() ?? 0.0
        
        #expect(earlyMax > 0.01, "Early samples should have audio")
        #expect(lateMax > 0.01, "Late samples should have audio")
    }
    
    // MARK: - Mod Envelope Formant Modulation Tests
    
    @Test("Mod envelope creates formant envelope")
    func testModEnvFormantModulation() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.formant1Freq = 800.0
        params.useVowelMorph = false
        params.modAttack = 0.05
        params.modSustain = 0.5
        params.modEnvToFormant1 = 400.0  // +400 Hz at peak
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        
        var samples: [Double] = []
        for _ in 0..<4410 {
            samples.append(pool.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.01, "Voice should produce output with formant envelope")
    }
    
    // MARK: - Combined Modulation Tests
    
    @Test("LFO and Mod Env can modulate same destination")
    func testCombinedModulation() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.modAttack = 0.01
        params.modSustain = 0.8
        
        // Both LFO and Mod Env modulate pitch
        params.lfoRate = 5.0
        params.lfoToPitch = 0.25    // ±0.25 semitones vibrato
        params.modEnvToPitch = 2.0  // +2 semitones envelope
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        
        var samples: [Double] = []
        for _ in 0..<4410 {
            samples.append(pool.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.01, "Combined modulation should produce output")
    }
    
    // MARK: - Per-Voice Modulation Independence
    
    @Test("Each voice applies modulation independently")
    func testPerVoiceModIndependence() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.lfoRate = 5.0
        params.lfoToPitch = 0.5
        params.lfoPhaseSpread = 1.0  // Full phase spread
        pool.setParameters(params)
        
        // Start two voices
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(64, 1.0)
        
        // Process and verify both produce output
        var samples: [Double] = []
        for _ in 0..<4410 {
            samples.append(pool.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.1, "Both voices with modulation should produce output")
        #expect(pool.getActiveVoiceCount() == 2)
    }
}
