//
//  VoxTests.swift
//  VoxTests
//
//  Created by Mark Pauley on 5/16/25.
//

import Testing
import CoreMIDI
import AVFoundation
import AudioToolbox

struct VoxTests {

    @Test("MonophonicVoice Same Note Retriggering with Legato Disabled")
    func testMonophonicVoiceSameNoteRetriggering() throws {
        // This test verifies that playing the same note repeatedly (noteOn/noteOff/noteOn/noteOff)
        // properly retriggers the envelope each time when legato is disabled
        
        var voice = MonophonicVoice(44100.0, MonophonicVoice.OscillatorType.POLYBLEP)
        
        // Configure for fast envelope to make testing quicker
        var params = MonophonicVoice.VoiceParameters()
        params.osc1Level = 1.0
        params.ampAttack = 0.005  // 5ms attack
        params.ampDecay = 0.01    // 10ms decay
        params.ampSustain = 0.7   // 70% sustain
        params.ampRelease = 0.02  // 20ms release
        params.legatoMode = false // Disable legato mode to ensure retriggering
        voice.setParameters(params)
        
        // Test sequence: Note On 60 -> Note Off 60 -> Note On 60 -> Note Off 60
        
        // 1. Play note 60
        voice.noteOn(60, 1.0)
        
        // Process some audio to let envelope start
        var firstNoteLevel1 = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            firstNoteLevel1 = max(firstNoteLevel1, Swift.abs(sample))
        }
        
        // Process more to let envelope develop
        var firstNoteLevel2 = 0.0
        for _ in 0..<500 {
            let sample = voice.process()
            firstNoteLevel2 = max(firstNoteLevel2, Swift.abs(sample))
        }
        
        // Should see envelope development (increasing amplitude)
        #expect(firstNoteLevel2 > firstNoteLevel1)
        
        // 2. Release note 60
        voice.noteOff(60)
        
        // Process through release phase
        for _ in 0..<1000 {
            _ = voice.process()
        }
        var afterReleaseLevel = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            afterReleaseLevel = max(afterReleaseLevel, Swift.abs(sample))
        }
        
        // Should be much quieter after release
        #expect(afterReleaseLevel < firstNoteLevel2 * 0.5)
        
        // 3. Play note 60 again - should retrigger envelope
        voice.noteOn(60, 1.0)
        
        // Process audio to capture retrigger
        var retriggeredLevel1 = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            retriggeredLevel1 = max(retriggeredLevel1, Swift.abs(sample))
        }
        
        // Process more to see envelope development
        var retriggeredLevel2 = 0.0
        for _ in 0..<500 {
            let sample = voice.process()
            retriggeredLevel2 = max(retriggeredLevel2, Swift.abs(sample))
        }
        
        // Should see envelope development again (proving retrigger worked)
        #expect(retriggeredLevel2 > retriggeredLevel1)
        #expect(retriggeredLevel2 > afterReleaseLevel * 2) // Should be much louder than release level
        
        // 4. Release note 60 again
        voice.noteOff(60)
        
        // Verify voice can be properly deactivated
        for _ in 0..<2000 {
            _ = voice.process()
        }
        let finalActive = voice.isActive()
        #expect(!finalActive)
    }
    
    @Test("MonophonicVoice Cross Note Interference")
    func testMonophonicVoiceCrossNoteInterference() throws {
        // Test that note off events for different notes don't interfere with current note
        
        var voice = MonophonicVoice(44100.0, MonophonicVoice.OscillatorType.POLYBLEP)
        
        // Standard envelope settings
        var params = MonophonicVoice.VoiceParameters()
        params.osc1Level = 1.0
        params.ampAttack = 0.01   // 10ms attack
        params.ampDecay = 0.02    // 20ms decay
        params.ampSustain = 0.8   // 80% sustain
        params.ampRelease = 0.05  // 50ms release
        params.legatoMode = false // Disable legato for this test
        voice.setParameters(params)
        
        // Test: Play note 60, then send note off for different notes, ensure 60 keeps playing
        
        // 1. Play note 60
        voice.noteOn(60, 1.0)
        
        // Let envelope develop
        for _ in 0..<1000 {
            _ = voice.process()
        }
        var sustainLevel = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            sustainLevel = max(sustainLevel, Swift.abs(sample))
        }
        #expect(sustainLevel > 0.2) // Should be playing
        
        // 2. Send note off for different notes (should not affect note 60)
        voice.noteOff(64) // Note off for E4
        var levelAfterWrongNoteOff1 = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            levelAfterWrongNoteOff1 = max(levelAfterWrongNoteOff1, Swift.abs(sample))
        }
        
        voice.noteOff(48) // Note off for C3
        var levelAfterWrongNoteOff2 = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            levelAfterWrongNoteOff2 = max(levelAfterWrongNoteOff2, Swift.abs(sample))
        }
        
        voice.noteOff(72) // Note off for C5
        var levelAfterWrongNoteOff3 = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            levelAfterWrongNoteOff3 = max(levelAfterWrongNoteOff3, Swift.abs(sample))
        }
        
        // Note 60 should still be playing at sustain level
        #expect(Swift.abs(levelAfterWrongNoteOff1 - sustainLevel) / sustainLevel < 0.2)
        #expect(Swift.abs(levelAfterWrongNoteOff2 - sustainLevel) / sustainLevel < 0.2)
        #expect(Swift.abs(levelAfterWrongNoteOff3 - sustainLevel) / sustainLevel < 0.2)
        
        // 3. Send correct note off for note 60 - should trigger release
        voice.noteOff(60)
        
        // Process through release
        for _ in 0..<2000 {
            _ = voice.process()
        }
        var levelAfterCorrectNoteOff = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            levelAfterCorrectNoteOff = max(levelAfterCorrectNoteOff, Swift.abs(sample))
        }
        
        // Should be much quieter after correct note off
        #expect(levelAfterCorrectNoteOff < sustainLevel * 0.5)
    }
    
    @Test("MonophonicVoice Rapid Same Note Retriggering")
    func testMonophonicVoiceRapidSameNoteRetriggering() throws {
        // Test rapid same note retriggering that should work with the fixed DSP kernel integration
        
        var voice = MonophonicVoice(44100.0, MonophonicVoice.OscillatorType.POLYBLEP)
        
        // Configure fast envelope for rapid testing
        var params = MonophonicVoice.VoiceParameters()
        params.osc1Level = 1.0
        params.ampAttack = 0.005  // 5ms attack (minimum 1ms gets clamped)
        params.ampDecay = 0.01    // 10ms decay
        params.ampSustain = 0.9   // 90% sustain
        params.ampRelease = 0.01  // 10ms release
        params.legatoMode = false // Disable legato to ensure every note triggers
        voice.setParameters(params)
        
        var triggerLevels: [Double] = []
        
        // Rapid sequence: multiple quick note 60 on/off cycles
        for _ in 0..<5 {
            // Note On 60
            voice.noteOn(60, 1.0)
            
            // Process through attack - exponential envelope needs more samples
            var attackLevel = 0.0
            for _ in 0..<441 { // ~10ms - allow attack to develop
                let sample = voice.process()
                attackLevel = max(attackLevel, Swift.abs(sample))
            }
            triggerLevels.append(attackLevel)
            
            // Note Off 60
            voice.noteOff(60)
            
            // Process through release - exponential release needs more time
            for _ in 0..<882 { // ~20ms
                _ = voice.process()
            }
        }
        
        // Each trigger should produce significant output (proving envelope retriggered)
        for (index, level) in triggerLevels.enumerated() {
            #expect(level > 0.1, "Trigger \(index + 1) should produce significant output: \(level)")
        }
        
        // All triggers should be roughly similar (proving consistent retriggering)
        let avgLevel = triggerLevels.reduce(0.0, +) / Double(triggerLevels.count)
        for (index, level) in triggerLevels.enumerated() {
            let deviation = Swift.abs(level - avgLevel) / avgLevel
            #expect(deviation < 0.5, "Trigger \(index + 1) should be consistent with average: \(deviation)")
        }
    }
    
    @Test("MonophonicVoice Note Off Edge Cases")
    func testMonophonicVoiceNoteOffEdgeCases() throws {
        // Test edge cases around note off behavior that the DSP kernel fix addresses
        
        var voice = MonophonicVoice(44100.0, MonophonicVoice.OscillatorType.POLYBLEP)
        
        // Standard envelope settings
        var params = MonophonicVoice.VoiceParameters()
        params.osc1Level = 1.0
        params.ampAttack = 0.01   // 10ms attack
        params.ampDecay = 0.02    // 20ms decay
        params.ampSustain = 0.8   // 80% sustain
        params.ampRelease = 0.05  // 50ms release
        params.legatoMode = false // Disable legato for this test
        voice.setParameters(params)
        
        // Test 1: Multiple rapid note off calls shouldn't cause issues
        voice.noteOn(60, 1.0)
        
        // Let envelope develop
        for _ in 0..<1000 {
            _ = voice.process()
        }
        var sustainLevel = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            sustainLevel = max(sustainLevel, Swift.abs(sample))
        }
        #expect(sustainLevel > 0.2) // Should be playing
        
        // Call noteOff multiple times - should be safe
        voice.noteOff(60)
        voice.noteOff(60)
        voice.noteOff(60)
        
        // Test 2: Note off without parameters should still work
        voice.noteOn(64, 0.8)
        for _ in 0..<500 {
            _ = voice.process()
        }
        
        var beforeNoteOff = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            beforeNoteOff = max(beforeNoteOff, Swift.abs(sample))
        }
        
        voice.noteOff() // Parameterless note off
        
        // Process through release
        for _ in 0..<2000 {
            _ = voice.process()
        }
        var afterNoteOff = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            afterNoteOff = max(afterNoteOff, Swift.abs(sample))
        }
        
        // Should be much quieter after note off
        #expect(afterNoteOff < beforeNoteOff * 0.5)
    }
    
    // MARK: - Legato Mode Envelope Phase Tests
    
    @Test("Legato Mode - Note Trigger During Attack Phase")
    func testLegatoModeNoteOnDuringAttack() throws {
        var voice = MonophonicVoice(44100.0, MonophonicVoice.OscillatorType.POLYBLEP)
        
        // Configure with slow attack to test triggering during attack
        var params = MonophonicVoice.VoiceParameters()
        params.osc1Level = 1.0
        params.ampAttack = 0.1    // 100ms attack - slow enough to catch
        params.ampDecay = 0.02    // 20ms decay
        params.ampSustain = 0.7   // 70% sustain
        params.ampRelease = 0.05  // 50ms release
        params.legatoMode = true  // Enable legato mode
        params.masterVolume = 1.0 // Set to 1.0 for easier testing
        params.lpFilterCutoff = 1.0 // Full open (normalized 0-1)
        voice.setParameters(params)
        
        // 1. Start first note (C4)
        voice.noteOn(60, 1.0)
        
        // Process through part of attack phase
        for _ in 0..<2000 { // About 45ms at 44.1kHz - mid-attack
            _ = voice.process()
        }
        
        var attackLevel = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            attackLevel = max(attackLevel, Swift.abs(sample))
        }
        #expect(attackLevel > 0.1) // Should be audible but not at full level
        #expect(attackLevel < 0.8) // Should not be at sustain level yet
        
        // 2. Trigger new note during attack (D4) - legato should NOT retrigger envelope
        voice.noteOn(62, 1.0) // Same velocity to avoid level drop from velocity scaling
        
        // Process a bit more - exponential attack needs time
        for _ in 0..<2000 {
            _ = voice.process()
        }
        
        var afterLegatoLevel = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            afterLegatoLevel = max(afterLegatoLevel, Swift.abs(sample))
        }
        
        // In legato mode, envelope should continue smoothly, not restart
        // Level should be at least as high (continuing attack, not restarting)
        #expect(afterLegatoLevel >= attackLevel * 0.6) // Should not drop significantly
        
        // Process to full sustain - exponential envelopes need more time to settle
        for _ in 0..<10000 {
            _ = voice.process()
        }
        
        var sustainLevel = 0.0
        for _ in 0..<200 {
            let sample = voice.process()
            sustainLevel = max(sustainLevel, Swift.abs(sample))
        }
        
        // Should reach sustain level (accounting for exponential undershoot)
        #expect(sustainLevel > 0.45) // Close to 70% sustain, with margin for exp envelope
    }
    
    @Test("Legato Mode - Note Trigger During Decay Phase")
    func testLegatoModeNoteOnDuringDecay() throws {
        var voice = MonophonicVoice(44100.0, MonophonicVoice.OscillatorType.POLYBLEP)
        
        // Configure with fast attack, slow decay
        var params = MonophonicVoice.VoiceParameters()
        params.osc1Level = 1.0
        params.ampAttack = 0.005  // 5ms attack - fast
        params.ampDecay = 0.1     // 100ms decay - slow enough to catch
        params.ampSustain = 0.6   // 60% sustain
        params.ampRelease = 0.05  // 50ms release
        params.legatoMode = true  // Enable legato mode
        params.masterVolume = 1.0 // Set to 1.0 for easier testing
        params.lpFilterCutoff = 1.0 // Full open (normalized 0-1)
        voice.setParameters(params)
        
        // 1. Start first note and let it reach decay phase
        voice.noteOn(60, 1.0)
        
        // Process through attack into decay
        for _ in 0..<1000 { // Past attack, into decay
            _ = voice.process()
        }
        
        var decayLevel = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            decayLevel = max(decayLevel, Swift.abs(sample))
        }
        #expect(decayLevel > 0.6) // Should be in decay, above sustain but below peak
        #expect(decayLevel < 0.95) // Should be past peak
        
        // 2. Trigger new note during decay - legato should NOT retrigger envelope
        voice.noteOn(64, 0.9) // E4
        
        // Process more
        for _ in 0..<2000 {
            _ = voice.process()
        }
        
        var afterLegatoLevel = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            afterLegatoLevel = max(afterLegatoLevel, Swift.abs(sample))
        }
        
        // Should continue decay smoothly toward new sustain level
        #expect(afterLegatoLevel < decayLevel * 1.1) // Shouldn't jump up significantly
        #expect(afterLegatoLevel > 0.4) // Should be settling toward sustain (exp envelope settling)
    }
    
    @Test("Legato Mode - Note Trigger During Sustain Phase")
    func testLegatoModeNoteOnDuringSustain() throws {
        var voice = MonophonicVoice(44100.0, MonophonicVoice.OscillatorType.POLYBLEP)
        
        // Standard envelope settings
        var params = MonophonicVoice.VoiceParameters()
        params.osc1Level = 1.0
        params.ampAttack = 0.01   // 10ms attack
        params.ampDecay = 0.02    // 20ms decay
        params.ampSustain = 0.7   // 70% sustain
        params.ampRelease = 0.05  // 50ms release
        params.legatoMode = true  // Enable legato mode
        params.masterVolume = 1.0 // Set to 1.0 for easier testing
        params.lpFilterCutoff = 1.0 // Full open (normalized 0-1)
        voice.setParameters(params)
        
        // 1. Start first note and let it reach sustain
        voice.noteOn(60, 1.0)
        
        // Process to sustain phase - exponential envelopes need more time
        for _ in 0..<6000 { // Well into sustain
            _ = voice.process()
        }
        
        var sustainLevel = 0.0
        for _ in 0..<200 {
            let sample = voice.process()
            sustainLevel = max(sustainLevel, Swift.abs(sample))
        }
        #expect(sustainLevel > 0.55) // Should be at/near sustain level (exp envelope settling)
        #expect(sustainLevel < 0.80) // Should be stable
        
        // 2. Trigger new note during sustain - legato should NOT retrigger envelope
        voice.noteOn(67, 0.8) // G4
        
        // Process and verify smooth continuation
        for _ in 0..<1000 {
            _ = voice.process()
        }
        
        var afterLegatoLevel = 0.0
        for _ in 0..<200 {
            let sample = voice.process()
            afterLegatoLevel = max(afterLegatoLevel, Swift.abs(sample))
        }
        
        // Should maintain sustain level smoothly (no envelope retrigger)
        #expect(Swift.abs(afterLegatoLevel - sustainLevel) / sustainLevel < 0.25) // Should be very similar
    }
    
    @Test("Legato Mode - Note Trigger During Release Phase") 
    func testLegatoModeNoteOnDuringRelease() throws {
        // This test specifically addresses the bug you found in Logic!
        var voice = MonophonicVoice(44100.0, MonophonicVoice.OscillatorType.POLYBLEP)
        
        // Configure with slow release to catch the bug
        var params = MonophonicVoice.VoiceParameters()
        params.osc1Level = 1.0
        params.ampAttack = 0.01   // 10ms attack
        params.ampDecay = 0.02    // 20ms decay  
        params.ampSustain = 0.7   // 70% sustain
        params.ampRelease = 0.15  // 150ms release - slow enough to trigger new note during
        params.legatoMode = true  // Enable legato mode
        params.masterVolume = 1.0 // Set to 1.0 for easier testing
        params.lpFilterCutoff = 1.0 // Full open (normalized 0-1)
        voice.setParameters(params)
        
        // 1. Start first note and let it reach sustain
        voice.noteOn(60, 1.0)
        
        // Process to sustain - exponential envelopes need more time
        for _ in 0..<5000 {
            _ = voice.process()
        }
        
        var sustainLevel = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            sustainLevel = max(sustainLevel, Swift.abs(sample))
        }
        #expect(sustainLevel > 0.55) // Should be at/near sustain (70% target, exp settling)
        
        // 2. Release the note (start release phase)
        voice.noteOff(60)
        
        // Process into release phase
        for _ in 0..<3000 { // About 68ms - mid-release
            _ = voice.process()
        }
        
        var releaseLevel = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            releaseLevel = max(releaseLevel, Swift.abs(sample))
        }
        #expect(releaseLevel < sustainLevel * 0.9) // Should be releasing
        #expect(releaseLevel > 0.05) // But still audible (exp release has long tail)
        
        // 3. THIS IS THE KEY TEST: Trigger new note during release in legato mode
        voice.noteOn(64, 0.9) // E4
        
        // Process after new note trigger
        for _ in 0..<1000 {
            _ = voice.process()
        }
        
        var afterNewNoteLevel = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            afterNewNoteLevel = max(afterNewNoteLevel, Swift.abs(sample))
        }
        
        // CRITICAL: In legato mode during release, new note should cause envelope to:
        // 1. Stop releasing and start moving toward sustain again
        // 2. NOT retrigger from zero (that would be non-legato behavior)
        // 3. Smoothly transition from current release level to new sustain level
        
        #expect(afterNewNoteLevel > releaseLevel * 1.2) // Should start growing from release level
        
        // Process more to see if it reaches new sustain level
        // Exponential envelopes need more time to settle
        for _ in 0..<8000 {
            _ = voice.process()
        }
        
        var finalLevel = 0.0
        for _ in 0..<200 {
            let sample = voice.process()
            finalLevel = max(finalLevel, Swift.abs(sample))
        }
        
        // Should reach sustain level for new note (accounting for exp envelope settling)
        #expect(finalLevel > 0.50) // Should reach sustain level
    }
    
    @Test("Non-Legato Mode - Note Trigger During Release Phase")
    func testNonLegatoModeNoteOnDuringRelease() throws {
        // Compare with non-legato behavior to ensure legato is different
        var voice = MonophonicVoice(44100.0, MonophonicVoice.OscillatorType.POLYBLEP)
        
        // Same envelope as legato test but non-legato mode
        var params = MonophonicVoice.VoiceParameters()
        params.osc1Level = 1.0
        params.ampAttack = 0.01   // 10ms attack
        params.ampDecay = 0.02    // 20ms decay
        params.ampSustain = 0.7   // 70% sustain
        params.ampRelease = 0.15  // 150ms release
        params.legatoMode = false // Disable legato mode
        params.masterVolume = 1.0 // Set to 1.0 for easier testing
        params.lpFilterCutoff = 1.0 // Full open (normalized 0-1)
        voice.setParameters(params)
        
        // 1. Start first note and let it reach sustain, then release
        voice.noteOn(60, 1.0)
        
        // Process to sustain
        for _ in 0..<3000 {
            _ = voice.process()
        }
        
        // Release and get into release phase
        voice.noteOff(60)
        for _ in 0..<3000 { // Mid-release
            _ = voice.process()
        }
        
        var releaseLevel = 0.0
        for _ in 0..<100 {
            let sample = voice.process()
            releaseLevel = max(releaseLevel, Swift.abs(sample))
        }
        #expect(releaseLevel > 0.01) // Should still be releasing (exp release decays fast initially)
        
        // 2. Trigger new note during release in NON-legato mode
        voice.noteOn(64, 0.9)
        
        // In non-legato mode, envelope resets to zero and starts fresh attack
        // Process through the attack phase
        for _ in 0..<1000 {
            _ = voice.process()
        }
        
        var afterAttackLevel = 0.0
        for _ in 0..<200 {
            let sample = voice.process()
            afterAttackLevel = max(afterAttackLevel, Swift.abs(sample))
        }
        
        // Should reach sustain level after retriggering (accounting for exp envelope)
        #expect(afterAttackLevel > 0.50)
    }
}
