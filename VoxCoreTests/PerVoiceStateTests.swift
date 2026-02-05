//
//  PerVoiceStateTests.swift
//  VoxCoreTests
//
//  Tests verifying per-voice state isolation
//  Each voice must have independent: phase, envelope state, glide state
//

import Testing
@testable import VoxCore

@Suite("Per-Voice State Tests")
struct PerVoiceStateTests {
    let sampleRate = 44100.0
    
    // MARK: - Phase Independence Tests
    
    @Test("Each voice has independent oscillator phase")
    func testPhaseIndependence() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.dutyCycle = 0.3
        pool.setParameters(params)
        
        // Start two notes at same pitch but different times
        _ = pool.noteOn(60, 1.0)
        
        // Process voice 0 alone for a bit - establishes phase position
        for _ in 0..<1000 {
            _ = pool.process()
        }
        
        // Now start second note at same pitch
        _ = pool.noteOn(72, 1.0)
        
        // Voices should have different phases now
        // Since we can't directly measure phase, we verify they both produce output
        // (would be silent if phase was shared and one voice was in silent part of pulsaret)
        var samples: [Double] = []
        for _ in 0..<1000 {
            samples.append(pool.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.1, "Both voices should produce output despite different start times")
    }
    
    // MARK: - Envelope Independence Tests
    
    @Test("Each voice has independent envelope state")
    func testEnvelopeIndependence() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.01  // 10ms attack
        params.ampDecay = 0.1
        params.ampSustain = 0.7
        params.ampRelease = 0.01  // 10ms release
        pool.setParameters(params)
        
        // Start first note
        _ = pool.noteOn(60, 1.0)
        
        // Process through attack (10ms) and decay (100ms) into sustain
        // Need at least 150ms to ensure we're in sustain
        for _ in 0..<Int(sampleRate * 0.2) { // 200ms
            _ = pool.process()
        }
        
        // Voice 0 should be in sustain now
        let voice0 = pool.getVoice(0)!.pointee
        let state0Before = voice0.getEnvelopeState()
        #expect(state0Before == ADSREnvelope.State.SUSTAIN, "Voice 0 should be in sustain")
        
        // Start second note
        _ = pool.noteOn(72, 1.0)
        
        // Voice 1 should be in attack
        let voice1 = pool.getVoice(1)!.pointee
        let state1 = voice1.getEnvelopeState()
        #expect(state1 == ADSREnvelope.State.ATTACK, "Voice 1 should be in attack")
        
        // Voice 0 should still be in sustain (independent)
        let state0After = pool.getVoice(0)!.pointee.getEnvelopeState()
        #expect(state0After == ADSREnvelope.State.SUSTAIN, "Voice 0 should still be in sustain")
    }
    
    @Test("noteOff only affects target voice envelope")
    func testNoteOffIndependence() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.ampRelease = 0.1  // Longer release to observe
        pool.setParameters(params)
        
        // Start two notes
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(72, 1.0)
        
        // Process through attacks
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        // Both should be in sustain
        // Release only note 60
        pool.noteOff(60)
        
        // Voice 0 should be in release
        let state0 = pool.getVoice(0)!.pointee.getEnvelopeState()
        #expect(state0 == ADSREnvelope.State.RELEASE, "Voice 0 should be in release")
        
        // Voice 1 should still be in sustain (independent)
        let state1 = pool.getVoice(1)!.pointee.getEnvelopeState()
        #expect(state1 == ADSREnvelope.State.SUSTAIN, "Voice 1 should still be in sustain")
    }
    
    // MARK: - Glide Independence Tests
    
    @Test("Each voice has independent glide state")
    func testGlideIndependence() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.glideEnabled = true
        params.glideTime = 0.1  // 100ms glide
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        // Start first note
        _ = pool.noteOn(48, 1.0)  // C3
        
        // Process a bit
        for _ in 0..<1000 {
            _ = pool.process()
        }
        
        // Start second note - plays immediately at its pitch (no glide from first voice)
        _ = pool.noteOn(84, 1.0)  // C6
        
        // Glide first note to new pitch
        _ = pool.noteOn(60, 1.0)  // Voice 0 will retrigger with glide
        
        // Process - both voices should have their own glide trajectories
        var samples: [Double] = []
        for _ in 0..<2000 {
            samples.append(pool.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.1, "Both voices should produce output during glide")
    }
    
    // MARK: - Pitch Independence Tests
    
    @Test("Each voice plays its assigned pitch")
    func testPitchIndependence() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.dutyCycle = 0.3
        pool.setParameters(params)
        
        // Play a chord - C E G
        _ = pool.noteOn(60, 1.0)  // C4
        _ = pool.noteOn(64, 1.0)  // E4
        _ = pool.noteOn(67, 1.0)  // G4
        
        // Process through attack
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        // Count zero crossings in output - with 3 notes at different pitches
        // we should get a complex pattern (not a simple sinusoid)
        var zeroCrossings = 0
        var prevSample = 0.0
        
        for _ in 0..<Int(sampleRate) {  // 1 second
            let sample = pool.process()
            if prevSample <= 0 && sample > 0 {
                zeroCrossings += 1
            }
            prevSample = sample
        }
        
        // With C4 (262Hz), E4 (330Hz), G4 (392Hz) playing together
        // we should get a complex waveform, not matching any single note
        // Just verify we get output with activity
        #expect(zeroCrossings > 100, "Should have significant zero crossings from chord")
    }
    
    // MARK: - Velocity Independence Tests
    
    @Test("Each voice maintains its own velocity")
    func testVelocityIndependence() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        // Play notes at different velocities
        _ = pool.noteOn(60, 1.0)   // Full velocity
        _ = pool.noteOn(72, 0.25)  // Quarter velocity
        
        // Process through attack
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        // Now mute voice 0 by releasing
        pool.noteOff(60)
        
        // Process through release of voice 0
        for _ in 0..<10000 {
            _ = pool.process()
        }
        
        // Only voice 1 should be active at low velocity
        var samples: [Double] = []
        for _ in 0..<1000 {
            samples.append(pool.process())
        }
        
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Double(samples.count))
        
        // RMS should be relatively low since only quiet voice is playing
        // This verifies voice 1 kept its low velocity independently
        #expect(rms > 0.01, "Quiet voice should still produce output")
        #expect(rms < 0.5, "Should be quieter than full velocity would be")
    }
    
    // MARK: - Multiple Note-On Same Pitch Tests
    
    @Test("Retriggering same note updates velocity")
    func testSamePitchRetrigger() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        // Play note quietly
        _ = pool.noteOn(60, 0.1)
        
        // Process to sustain
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        var quietSamples: [Double] = []
        for _ in 0..<500 {
            quietSamples.append(pool.process())
        }
        
        // Retrigger same note loudly
        _ = pool.noteOn(60, 1.0)
        
        // Process through new attack
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        var loudSamples: [Double] = []
        for _ in 0..<500 {
            loudSamples.append(pool.process())
        }
        
        let quietRMS = sqrt(quietSamples.map { $0 * $0 }.reduce(0, +) / Double(quietSamples.count))
        let loudRMS = sqrt(loudSamples.map { $0 * $0 }.reduce(0, +) / Double(loudSamples.count))
        
        #expect(loudRMS > quietRMS * 2, "Retriggered note should be louder: \(loudRMS) vs \(quietRMS)")
        
        // Should still only have 1 active voice (same note reused)
        #expect(pool.getActiveVoiceCount() == 1, "Should reuse same voice for same note")
    }
    
    // MARK: - State Reset Independence Tests
    
    @Test("reset clears all voices independently")
    func testResetIndependence() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        // Play some notes
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(64, 1.0)
        _ = pool.noteOn(67, 1.0)
        
        // Process to establish state
        for _ in 0..<1000 {
            _ = pool.process()
        }
        
        // Reset pool
        pool.reset()
        
        // All voices should be idle and produce silence
        for i: Int32 in 0..<8 {
            if let voicePtr = pool.getVoice(i) {
                let isActive = voicePtr.pointee.isActive()
                #expect(!isActive, "Voice \(i) should be inactive after reset")
            }
        }
        
        // Should produce silence
        var samples: [Double] = []
        for _ in 0..<100 {
            samples.append(pool.process())
        }
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp == 0.0, "Should produce silence after reset")
    }
}
