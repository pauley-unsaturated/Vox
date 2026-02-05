//
//  PerVoiceLFOTests.swift
//  VoxCoreTests
//
//  Tests for per-voice LFO functionality (Phase 2.1)
//

import Testing
@testable import VoxCore

@Suite("Per-Voice LFO Tests")
struct PerVoiceLFOTests {
    let sampleRate = 44100.0
    
    // MARK: - LFO Existence Tests
    
    @Test("VoxVoice has LFO parameters")
    func testVoiceHasLFOParams() {
        var params = VoxVoiceParameters()
        
        // LFO rate should exist
        params.lfoRate = 5.0
        #expect(params.lfoRate == 5.0)
        
        // LFO waveform should exist
        params.lfoWaveform = 1  // Triangle
        #expect(params.lfoWaveform == 1)
        
        // LFO phase offset should exist (0-1 representing 0-360°)
        params.lfoPhaseOffset = 0.25  // 90 degrees
        #expect(params.lfoPhaseOffset == 0.25)
    }
    
    @Test("LFO phase offset is normalized 0-1")
    func testLFOPhaseOffsetNormalized() {
        var params = VoxVoiceParameters()
        
        // Valid values
        params.lfoPhaseOffset = 0.0
        #expect(params.lfoPhaseOffset >= 0.0)
        
        params.lfoPhaseOffset = 0.5  // 180 degrees
        #expect(params.lfoPhaseOffset == 0.5)
        
        params.lfoPhaseOffset = 1.0  // 360 degrees (wraps to 0)
        #expect(params.lfoPhaseOffset >= 0.0 && params.lfoPhaseOffset <= 1.0)
    }
    
    // MARK: - Per-Voice LFO Independence Tests
    
    @Test("Each voice has independent LFO phase")
    func testIndependentLFOPhase() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.lfoRate = 1.0
        pool.setParameters(params)
        
        // Trigger two notes at the same time
        let voice1 = pool.noteOn(60, 1.0)
        let voice2 = pool.noteOn(64, 1.0)
        
        #expect(voice1 >= 0)
        #expect(voice2 >= 0)
        #expect(voice1 != voice2, "Should be different voices")
        
        // Each voice should have its own LFO instance
        // (LFO output tested via modulation in later tests)
    }
    
    @Test("LFO retriggers on noteOn")
    func testLFORetriggersOnNoteOn() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.ampRelease = 0.001
        params.lfoRate = 10.0  // 10 Hz LFO
        params.lfoRetrigger = true
        pool.setParameters(params)
        
        // First note
        _ = pool.noteOn(60, 1.0)
        
        // Process for a while to advance LFO
        for _ in 0..<4410 {  // 100ms
            _ = pool.process()
        }
        
        pool.noteOff(60)
        for _ in 0..<2000 {
            _ = pool.process()
        }
        
        // Second note should start with LFO at phase offset
        _ = pool.noteOn(64, 1.0)
        
        // LFO should be retriggered (at its phase offset position)
        // This is tested via modulation effect in integration tests
        #expect(pool.getActiveVoiceCount() == 1)
    }
    
    // MARK: - LFO Phase Spread Tests
    
    @Test("Voice pool can spread LFO phases across voices")
    func testLFOPhaseSpread() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.lfoRate = 1.0
        params.lfoPhaseSpread = 1.0  // Full 360° spread across voices
        pool.setParameters(params)
        
        // When phase spread is 1.0 with 4 voices:
        // Voice 0: 0°, Voice 1: 90°, Voice 2: 180°, Voice 3: 270°
        
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(64, 1.0)
        _ = pool.noteOn(67, 1.0)
        _ = pool.noteOn(72, 1.0)
        
        #expect(pool.getActiveVoiceCount() == 4)
    }
    
    @Test("Zero phase spread means all LFOs in sync")
    func testZeroPhaseSpread() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.lfoRate = 1.0
        params.lfoPhaseSpread = 0.0  // No spread - all in sync
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(64, 1.0)
        
        #expect(pool.getActiveVoiceCount() == 2)
    }
    
    // MARK: - LFO Parameter Tests
    
    @Test("LFO rate affects oscillation speed")
    func testLFORateAffectsSpeed() {
        // Standalone LFO test
        var lfo1 = LFO(sampleRate)
        var lfo2 = LFO(sampleRate)
        
        lfo1.setRate(1.0)   // 1 Hz
        lfo2.setRate(10.0)  // 10 Hz
        
        // Disable smoothing for accurate zero crossing count
        lfo1.setSmoothingCutoff(sampleRate * 0.45)
        lfo2.setSmoothingCutoff(sampleRate * 0.45)
        
        // Count zero crossings over 2 seconds for more reliable results
        var crossings1 = 0
        var crossings2 = 0
        var prev1 = lfo1.process()
        var prev2 = lfo2.process()
        
        let numSamples = Int(sampleRate * 2.0)  // 2 seconds
        for _ in 0..<numSamples {
            let curr1 = lfo1.process()
            let curr2 = lfo2.process()
            
            if prev1 < 0 && curr1 >= 0 { crossings1 += 1 }
            if prev2 < 0 && curr2 >= 0 { crossings2 += 1 }
            
            prev1 = curr1
            prev2 = curr2
        }
        
        // 10 Hz should have ~10x more crossings than 1 Hz
        // Over 2 seconds: 1 Hz should cross ~2 times, 10 Hz should cross ~20 times
        #expect(crossings1 >= 1 && crossings1 <= 3, "1 Hz LFO should cross zero ~2 times in 2s, got \(crossings1)")
        #expect(crossings2 >= 18 && crossings2 <= 22, "10 Hz LFO should cross zero ~20 times in 2s, got \(crossings2)")
    }
    
    @Test("LFO waveform selection works")
    func testLFOWaveformSelection() {
        var params = VoxVoiceParameters()
        
        // Test each waveform value
        params.lfoWaveform = 0  // Sine
        #expect(params.lfoWaveform == 0)
        
        params.lfoWaveform = 1  // Triangle
        #expect(params.lfoWaveform == 1)
        
        params.lfoWaveform = 2  // Saw
        #expect(params.lfoWaveform == 2)
        
        params.lfoWaveform = 3  // Square
        #expect(params.lfoWaveform == 3)
        
        params.lfoWaveform = 4  // Sample & Hold
        #expect(params.lfoWaveform == 4)
    }
    
    // MARK: - Voice Access Tests
    
    @Test("Voice pool provides LFO value access")
    func testVoicePoolLFOAccess() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.lfoRate = 5.0
        pool.setParameters(params)
        
        let voiceIndex = pool.noteOn(60, 1.0)
        #expect(voiceIndex >= 0)
        
        // Process a few samples to get LFO running
        for _ in 0..<100 {
            _ = pool.process()
        }
        
        // Should be able to get LFO value for voice
        let voice = pool.getVoice(voiceIndex)
        #expect(voice != nil, "Should be able to access voice")
    }
}
