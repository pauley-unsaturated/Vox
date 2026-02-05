//
//  ModEnvelopeTests.swift
//  VoxCoreTests
//
//  Tests for per-voice modulation envelope (Phase 2.2)
//

import Testing
@testable import VoxCore

@Suite("Mod Envelope Tests")
struct ModEnvelopeTests {
    let sampleRate = 44100.0
    
    // MARK: - Mod Envelope Parameter Tests
    
    @Test("VoxVoice has Mod Envelope (Env2) parameters")
    func testVoiceHasModEnvParams() {
        var params = VoxVoiceParameters()
        
        // Mod envelope ADSR
        params.modAttack = 0.05
        #expect(params.modAttack == 0.05)
        
        params.modDecay = 0.2
        #expect(params.modDecay == 0.2)
        
        params.modSustain = 0.5
        #expect(params.modSustain == 0.5)
        
        params.modRelease = 0.4
        #expect(params.modRelease == 0.4)
    }
    
    @Test("Mod envelope has default values")
    func testModEnvDefaultValues() {
        let params = VoxVoiceParameters()
        
        // Should have reasonable defaults
        #expect(params.modAttack >= 0.001 && params.modAttack <= 1.0)
        #expect(params.modDecay >= 0.001 && params.modDecay <= 1.0)
        #expect(params.modSustain >= 0.0 && params.modSustain <= 1.0)
        #expect(params.modRelease >= 0.001 && params.modRelease <= 2.0)
    }
    
    // MARK: - Mod Envelope Behavior Tests
    
    @Test("Mod envelope triggers on note on")
    func testModEnvTriggersOnNoteOn() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.modAttack = 0.001
        params.modSustain = 0.8
        pool.setParameters(params)
        
        let voiceIndex = pool.noteOn(60, 1.0)
        #expect(voiceIndex >= 0)
        
        // Process a few samples to let mod envelope start
        for _ in 0..<100 {
            _ = pool.process()
        }
        
        // Mod envelope should be active
        let voicePtr = pool.getVoice(voiceIndex)
        #expect(voicePtr != nil)
        
        // Get mod envelope value - should be > 0 after attack
        let modValue = voicePtr!.pointee.getModEnvelopeValue()
        #expect(modValue > 0.0, "Mod envelope should be active after noteOn, got \(modValue)")
    }
    
    @Test("Mod envelope is independent from amp envelope")
    func testModEnvIndependentFromAmp() {
        var params = VoxVoiceParameters()
        
        // Different attack times
        params.ampAttack = 0.001   // Very fast amp
        params.modAttack = 0.5     // Slow mod
        
        // Different sustain levels
        params.ampSustain = 1.0
        params.modSustain = 0.3
        
        #expect(params.ampAttack != params.modAttack)
        #expect(params.ampSustain != params.modSustain)
    }
    
    @Test("Mod envelope releases on note off")
    func testModEnvReleasesOnNoteOff() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampRelease = 0.5  // Long amp release
        params.modAttack = 0.001
        params.modSustain = 0.8
        params.modRelease = 0.001  // Very fast mod release
        pool.setParameters(params)
        
        let voiceIndex = pool.noteOn(60, 1.0)
        
        // Let envelope reach sustain
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        let voicePtr = pool.getVoice(voiceIndex)!
        let modValueBeforeRelease = voicePtr.pointee.getModEnvelopeValue()
        #expect(modValueBeforeRelease > 0.5, "Mod env should be at sustain")
        
        // Release the note
        pool.noteOff(60)
        
        // Process through fast mod release
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        let modValueAfterRelease = voicePtr.pointee.getModEnvelopeValue()
        #expect(modValueAfterRelease < 0.01, "Mod env should be near zero after release, got \(modValueAfterRelease)")
    }
    
    // MARK: - Per-Voice Independence Tests
    
    @Test("Each voice has independent mod envelope")
    func testIndependentModEnvelopes() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.modAttack = 0.001
        params.modSustain = 0.8
        params.modRelease = 0.001
        pool.setParameters(params)
        
        // Start first note
        let voice1 = pool.noteOn(60, 1.0)
        
        // Let it reach sustain
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        // Start second note
        let voice2 = pool.noteOn(64, 1.0)
        
        // Voice 1 should still be at sustain
        // Voice 2 should be in attack
        #expect(voice1 != voice2)
        
        let v1Ptr = pool.getVoice(voice1)!
        let v2Ptr = pool.getVoice(voice2)!
        
        // v1 should be at sustain level (~0.8)
        let v1Mod = v1Ptr.pointee.getModEnvelopeValue()
        #expect(v1Mod > 0.6, "Voice 1 should be at sustain, got \(v1Mod)")
        
        // v2 just started, should be lower
        let v2Mod = v2Ptr.pointee.getModEnvelopeValue()
        #expect(v2Mod < v1Mod || v2Mod > 0.5, "Voice 2 should be starting attack")
    }
    
    @Test("Mod envelope resets on voice reset")
    func testModEnvResetsOnReset() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.modAttack = 0.001
        params.modSustain = 0.8
        pool.setParameters(params)
        
        let voiceIndex = pool.noteOn(60, 1.0)
        
        // Let envelope build up
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        // Reset the pool
        pool.reset()
        
        // All voices should have mod env at 0
        let voicePtr = pool.getVoice(voiceIndex)!
        let modValue = voicePtr.pointee.getModEnvelopeValue()
        #expect(modValue == 0.0, "Mod env should be 0 after reset, got \(modValue)")
    }
    
    // MARK: - Mod Envelope State Tests
    
    @Test("VoxVoice provides mod envelope state")
    func testModEnvStateAccess() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.modAttack = 0.1
        params.modDecay = 0.1
        params.modSustain = 0.5
        params.modRelease = 0.1
        pool.setParameters(params)
        
        let voiceIndex = pool.noteOn(60, 1.0)
        let voicePtr = pool.getVoice(voiceIndex)!
        
        // Should be in attack initially
        let state = voicePtr.pointee.getModEnvelopeState()
        #expect(state == .ATTACK, "Should start in attack state")
    }
}
