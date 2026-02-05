//
//  VoiceStealingTests.swift
//  VoxCoreTests
//
//  Tests for voice stealing when pool is exhausted
//

import Testing
@testable import VoxCore

@Suite("Voice Stealing Tests")
struct VoiceStealingTests {
    let sampleRate = 44100.0
    
    // MARK: - Basic Stealing Tests
    
    @Test("Voice stealing is triggered when pool is full")
    func testStealingTriggered() {
        var pool = VoicePool(4, sampleRate)  // Small pool
        pool.setStealingEnabled(true)
        pool.setStealingMode(.Oldest)
        
        // Fill the pool
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(64, 1.0)
        _ = pool.noteOn(67, 1.0)
        _ = pool.noteOn(72, 1.0)
        
        #expect(pool.getActiveVoiceCount() == 4, "Pool should be full")
        
        // Try to play another note - should steal
        let stolenVoice = pool.noteOn(76, 1.0)
        
        #expect(stolenVoice >= 0, "Should successfully steal a voice")
        #expect(pool.getActiveVoiceCount() == 4, "Should still have 4 active voices")
        
        // New note should be active
        let isNewNoteActive = pool.isNoteActive(76)
        #expect(isNewNoteActive, "New note should be playing")
    }
    
    @Test("Oldest mode steals the oldest voice")
    func testOldestStealing() {
        var pool = VoicePool(4, sampleRate)
        pool.setStealingEnabled(true)
        pool.setStealingMode(.Oldest)
        
        // Fill pool sequentially
        _ = pool.noteOn(60, 1.0)  // First (oldest)
        _ = pool.noteOn(64, 1.0)
        _ = pool.noteOn(67, 1.0)
        _ = pool.noteOn(72, 1.0)  // Last (newest)
        
        // Process a bit to establish timing
        for _ in 0..<100 {
            _ = pool.process()
        }
        
        // Steal with new note
        _ = pool.noteOn(76, 1.0)
        
        // Note 60 (oldest) should be gone
        let is60Active = pool.isNoteActive(60)
        #expect(!is60Active, "Oldest note (60) should have been stolen")
        
        // Other notes should still be active
        let is64Active = pool.isNoteActive(64)
        let is67Active = pool.isNoteActive(67)
        let is72Active = pool.isNoteActive(72)
        let is76Active = pool.isNoteActive(76)
        
        #expect(is64Active, "Note 64 should still be active")
        #expect(is67Active, "Note 67 should still be active")
        #expect(is72Active, "Note 72 should still be active")
        #expect(is76Active, "New note 76 should be active")
    }
    
    @Test("Quietest mode steals the voice with lowest velocity")
    func testQuietestStealing() {
        var pool = VoicePool(4, sampleRate)
        pool.setStealingEnabled(true)
        pool.setStealingMode(.Quietest)
        
        // Fill pool with different velocities
        _ = pool.noteOn(60, 0.8)
        _ = pool.noteOn(64, 0.2)  // Quietest
        _ = pool.noteOn(67, 0.9)
        _ = pool.noteOn(72, 0.7)
        
        // Steal with new note
        _ = pool.noteOn(76, 1.0)
        
        // Note 64 (quietest) should be gone
        let is64Active = pool.isNoteActive(64)
        #expect(!is64Active, "Quietest note (64) should have been stolen")
        
        // Other notes should still be active
        let is60Active = pool.isNoteActive(60)
        let is67Active = pool.isNoteActive(67)
        let is72Active = pool.isNoteActive(72)
        let is76Active = pool.isNoteActive(76)
        
        #expect(is60Active, "Note 60 should still be active")
        #expect(is67Active, "Note 67 should still be active")
        #expect(is72Active, "Note 72 should still be active")
        #expect(is76Active, "New note 76 should be active")
    }
    
    // MARK: - Stealing Disabled Tests
    
    @Test("No stealing when disabled")
    func testStealingDisabled() {
        var pool = VoicePool(4, sampleRate)
        pool.setStealingEnabled(false)  // Disabled
        
        // Fill the pool
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(64, 1.0)
        _ = pool.noteOn(67, 1.0)
        _ = pool.noteOn(72, 1.0)
        
        // Try to play another note - should fail
        let result = pool.noteOn(76, 1.0)
        
        #expect(result == -1, "Should return -1 when stealing disabled and pool full")
        
        let is76Active = pool.isNoteActive(76)
        #expect(!is76Active, "Note 76 should not be playing")
    }
    
    // MARK: - Releasing Voice Stealing Tests
    
    @Test("Stealing prefers voices in release phase")
    func testStealReleasingVoice() {
        var pool = VoicePool(4, sampleRate)
        pool.setStealingEnabled(true)
        pool.setStealingMode(.Oldest)
        
        var params = VoxVoiceParameters()
        params.ampRelease = 1.0  // Long release so voice stays in release
        pool.setParameters(params)
        
        // Fill pool
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(64, 1.0)
        _ = pool.noteOn(67, 1.0)  // This one will go into release
        _ = pool.noteOn(72, 1.0)
        
        // Release note 67
        pool.noteOff(67)
        
        // Process a tiny bit so it enters release
        for _ in 0..<10 {
            _ = pool.process()
        }
        
        // Steal with new note - should prefer the releasing voice
        _ = pool.noteOn(76, 1.0)
        
        // Note 67 (releasing) should be gone
        // Note: the allocator tracks this via the note mapping, not envelope state
        let is67Active = pool.isNoteActive(67)
        #expect(!is67Active, "Releasing note should have been stolen")
    }
    
    // MARK: - Multiple Stealing Tests
    
    @Test("Multiple notes can be stolen in sequence")
    func testMultipleSteals() {
        var pool = VoicePool(4, sampleRate)
        pool.setStealingEnabled(true)
        pool.setStealingMode(.Oldest)
        
        // Fill pool
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(64, 1.0)
        _ = pool.noteOn(67, 1.0)
        _ = pool.noteOn(72, 1.0)
        
        // Steal multiple times
        _ = pool.noteOn(76, 1.0)  // Steals 60
        _ = pool.noteOn(79, 1.0)  // Steals 64
        _ = pool.noteOn(84, 1.0)  // Steals 67
        
        // Original oldest notes should be gone
        let is60Active = pool.isNoteActive(60)
        let is64Active = pool.isNoteActive(64)
        let is67Active = pool.isNoteActive(67)
        
        #expect(!is60Active, "Note 60 should be stolen")
        #expect(!is64Active, "Note 64 should be stolen")
        #expect(!is67Active, "Note 67 should be stolen")
        
        // Newest notes should be active
        let is72Active = pool.isNoteActive(72)
        let is76Active = pool.isNoteActive(76)
        let is79Active = pool.isNoteActive(79)
        let is84Active = pool.isNoteActive(84)
        
        #expect(is72Active, "Note 72 should still be active")
        #expect(is76Active, "Note 76 should be active")
        #expect(is79Active, "Note 79 should be active")
        #expect(is84Active, "Note 84 should be active")
    }
    
    // MARK: - Stealing Mode Configuration Tests
    
    @Test("Stealing mode can be changed at runtime")
    func testStealingModeChange() {
        var pool = VoicePool(4, sampleRate)
        pool.setStealingEnabled(true)
        
        pool.setStealingMode(.Oldest)
        #expect(pool.getStealingMode().rawValue == VoicePool.StealingMode.Oldest.rawValue)
        
        pool.setStealingMode(.Quietest)
        #expect(pool.getStealingMode().rawValue == VoicePool.StealingMode.Quietest.rawValue)
    }
    
    @Test("Stealing enabled state can be queried")
    func testStealingEnabledQuery() {
        var pool = VoicePool(4, sampleRate)
        
        pool.setStealingEnabled(true)
        let enabled1 = pool.isStealingEnabled()
        #expect(enabled1, "Stealing should be enabled")
        
        pool.setStealingEnabled(false)
        let enabled2 = pool.isStealingEnabled()
        #expect(!enabled2, "Stealing should be disabled")
    }
}
