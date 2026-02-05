//
//  VoiceAllocatorTests.swift
//  VoxCoreTests
//
//  Tests for VoiceAllocator - tracks voice allocation for polyphony
//

import Testing
@testable import VoxCore

@Suite("Voice Allocator Tests")
struct VoiceAllocatorTests {
    
    // MARK: - Initialization Tests
    
    @Test("VoiceAllocator initializes with correct voice count")
    func testInitialization() {
        let allocator = VoiceAllocator(8)
        
        #expect(allocator.getVoiceCount() == 8, "Should have 8 voices")
        #expect(allocator.getActiveVoiceCount() == 0, "No voices should be active initially")
        #expect(allocator.getFreeVoiceCount() == 8, "All voices should be free initially")
    }
    
    @Test("VoiceAllocator defaults to RoundRobin mode")
    func testDefaultMode() {
        let allocator = VoiceAllocator(8)
        
        #expect(allocator.getAllocationMode() == VoiceAllocator.Mode.RoundRobin, 
               "Default mode should be RoundRobin")
    }
    
    // MARK: - Basic Allocation Tests
    
    @Test("Allocate returns sequential voice indices in RoundRobin mode")
    func testRoundRobinAllocation() {
        var allocator = VoiceAllocator(8)
        allocator.setAllocationMode(VoiceAllocator.Mode.RoundRobin)
        
        // Allocate first voice
        let voice0 = allocator.allocate(60) // Middle C
        #expect(voice0 == 0, "First allocation should be voice 0")
        #expect(allocator.getActiveVoiceCount() == 1, "Should have 1 active voice")
        
        // Allocate second voice
        let voice1 = allocator.allocate(62) // D
        #expect(voice1 == 1, "Second allocation should be voice 1")
        #expect(allocator.getActiveVoiceCount() == 2, "Should have 2 active voices")
        
        // Allocate third voice
        let voice2 = allocator.allocate(64) // E
        #expect(voice2 == 2, "Third allocation should be voice 2")
    }
    
    @Test("Deallocate frees a voice")
    func testDeallocation() {
        var allocator = VoiceAllocator(8)
        
        let voice = allocator.allocate(60)
        #expect(allocator.getActiveVoiceCount() == 1)
        
        allocator.deallocate(voice)
        #expect(allocator.getActiveVoiceCount() == 0, "Voice should be freed")
        #expect(allocator.getFreeVoiceCount() == 8, "All voices should be free")
    }
    
    @Test("Find voice by note returns correct voice index")
    func testFindVoiceByNote() {
        var allocator = VoiceAllocator(8)
        
        let voice0 = allocator.allocate(60) // C
        let voice1 = allocator.allocate(64) // E
        let voice2 = allocator.allocate(67) // G
        
        #expect(allocator.findVoicePlayingNote(60) == voice0, "Should find voice playing C")
        #expect(allocator.findVoicePlayingNote(64) == voice1, "Should find voice playing E")
        #expect(allocator.findVoicePlayingNote(67) == voice2, "Should find voice playing G")
        #expect(allocator.findVoicePlayingNote(72) == -1, "Should return -1 for unplayed note")
    }
    
    // MARK: - Allocation Mode Tests
    
    @Test("LowestNote mode allocates lowest available voice")
    func testLowestNoteMode() {
        var allocator = VoiceAllocator(8)
        allocator.setAllocationMode(VoiceAllocator.Mode.LowestNote)
        
        // Allocate some voices
        _ = allocator.allocate(60)
        _ = allocator.allocate(64)
        _ = allocator.allocate(67)
        
        // Free voice 1 (middle)
        allocator.deallocate(1)
        
        // Next allocation should get voice 1 (lowest free)
        let nextVoice = allocator.allocate(70)
        #expect(nextVoice == 1, "LowestNote should allocate lowest free voice index")
    }
    
    @Test("HighestNote mode allocates highest available voice")
    func testHighestNoteMode() {
        var allocator = VoiceAllocator(8)
        allocator.setAllocationMode(VoiceAllocator.Mode.HighestNote)
        
        // Allocate some voices (they'll get allocated from high end)
        let v0 = allocator.allocate(60)
        #expect(v0 == 7, "First allocation in HighestNote mode should be voice 7")
        
        let v1 = allocator.allocate(64)
        #expect(v1 == 6, "Second allocation should be voice 6")
    }
    
    @Test("LastPlayed mode reuses most recently released voice")
    func testLastPlayedMode() {
        var allocator = VoiceAllocator(8)
        allocator.setAllocationMode(VoiceAllocator.Mode.LastPlayed)
        
        // Allocate and release voices
        let v0 = allocator.allocate(60)
        let v1 = allocator.allocate(64)
        let v2 = allocator.allocate(67)
        
        // Release v1, then v2
        allocator.deallocate(v1)
        allocator.deallocate(v2)
        
        // Next allocation should get v2 (last played/released)
        let nextVoice = allocator.allocate(70)
        #expect(nextVoice == v2, "LastPlayed should allocate most recently released voice")
    }
    
    // MARK: - Pool Exhaustion Tests
    
    @Test("Allocation returns -1 when pool is exhausted")
    func testPoolExhaustion() {
        var allocator = VoiceAllocator(4) // Small pool for testing
        
        // Fill all voices
        for note in 60..<64 {
            _ = allocator.allocate(Int32(note))
        }
        
        #expect(allocator.getActiveVoiceCount() == 4, "Pool should be full")
        #expect(allocator.getFreeVoiceCount() == 0, "No free voices")
        
        // Try to allocate one more
        let overflow = allocator.allocate(70)
        #expect(overflow == -1, "Should return -1 when pool exhausted")
    }
    
    // MARK: - Voice State Tracking Tests
    
    @Test("isVoiceActive correctly reports voice state")
    func testIsVoiceActive() {
        var allocator = VoiceAllocator(8)
        
        #expect(!allocator.isVoiceActive(0), "Voice 0 should be inactive initially")
        
        _ = allocator.allocate(60)
        #expect(allocator.isVoiceActive(0), "Voice 0 should be active after allocation")
        
        allocator.deallocate(0)
        #expect(!allocator.isVoiceActive(0), "Voice 0 should be inactive after deallocation")
    }
    
    @Test("getNoteForVoice returns correct note")
    func testGetNoteForVoice() {
        var allocator = VoiceAllocator(8)
        
        _ = allocator.allocate(60)
        _ = allocator.allocate(72)
        
        #expect(allocator.getNoteForVoice(0) == 60, "Voice 0 should be playing note 60")
        #expect(allocator.getNoteForVoice(1) == 72, "Voice 1 should be playing note 72")
        #expect(allocator.getNoteForVoice(2) == -1, "Inactive voice should return -1")
    }
    
    // MARK: - Age Tracking Tests
    
    @Test("Voices track allocation age")
    func testAgeTracking() {
        var allocator = VoiceAllocator(8)
        
        _ = allocator.allocate(60)
        _ = allocator.allocate(64)
        _ = allocator.allocate(67)
        
        // Voice 0 should be oldest, voice 2 should be newest
        #expect(allocator.getOldestActiveVoice() == 0, "Voice 0 should be oldest")
        #expect(allocator.getNewestActiveVoice() == 2, "Voice 2 should be newest")
    }
    
    @Test("getOldestActiveVoice returns -1 when no active voices")
    func testOldestActiveVoiceEmpty() {
        let allocator = VoiceAllocator(8)
        
        #expect(allocator.getOldestActiveVoice() == -1, "Should return -1 with no active voices")
    }
    
    // MARK: - Reset Tests
    
    @Test("Reset clears all allocations")
    func testReset() {
        var allocator = VoiceAllocator(8)
        
        _ = allocator.allocate(60)
        _ = allocator.allocate(64)
        _ = allocator.allocate(67)
        
        allocator.reset()
        
        #expect(allocator.getActiveVoiceCount() == 0, "No voices should be active after reset")
        #expect(allocator.getFreeVoiceCount() == 8, "All voices should be free after reset")
    }
}
