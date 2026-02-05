//
//  VoicePoolTests.swift
//  VoxCoreTests
//
//  Tests for VoicePool - manages polyphonic VoxVoice instances
//

import Testing
@testable import VoxCore

@Suite("Voice Pool Tests")
struct VoicePoolTests {
    let sampleRate = 44100.0
    
    // MARK: - Initialization Tests
    
    @Test("VoicePool initializes with correct voice count")
    func testInitialization() {
        let pool = VoicePool(8, sampleRate)
        
        #expect(pool.getVoiceCount() == 8, "Should have 8 voices")
        #expect(pool.getActiveVoiceCount() == 0, "No voices should be active initially")
    }
    
    @Test("VoicePool configures sample rate on all voices")
    func testSampleRateConfiguration() {
        let pool = VoicePool(4, 96000.0)
        
        // Trigger a note and verify it produces output
        var mutablePool = pool
        mutablePool.noteOn(60, 1.0)
        
        // Should produce audio at the configured sample rate
        var samples: [Double] = []
        for _ in 0..<1000 {
            samples.append(mutablePool.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.01, "Pool should produce audio output")
    }
    
    // MARK: - Note On/Off Tests
    
    @Test("noteOn activates a voice and returns voice index")
    func testNoteOn() {
        var pool = VoicePool(8, sampleRate)
        
        let voiceIndex = pool.noteOn(60, 1.0)
        
        #expect(voiceIndex >= 0, "Should return valid voice index")
        #expect(pool.getActiveVoiceCount() == 1, "Should have 1 active voice")
        
        let isActive = pool.isNoteActive(60)
        #expect(isActive, "Note 60 should be active")
    }
    
    @Test("noteOff releases the correct voice")
    func testNoteOff() {
        var pool = VoicePool(8, sampleRate)
        
        // Set up fast envelope for testing
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampDecay = 0.01
        params.ampSustain = 0.7
        params.ampRelease = 0.001  // Very fast release
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        let isActiveAfterNoteOn = pool.isNoteActive(60)
        #expect(isActiveAfterNoteOn, "Note should be active after noteOn")
        
        pool.noteOff(60)
        
        // Process through very fast release
        for _ in 0..<1000 {
            _ = pool.process()
        }
        
        let isActiveAfterRelease = pool.isNoteActive(60)
        #expect(!isActiveAfterRelease, "Note should be inactive after release completes")
    }
    
    @Test("Multiple notes can be active simultaneously")
    func testMultipleNotes() {
        var pool = VoicePool(8, sampleRate)
        
        _ = pool.noteOn(60, 1.0)  // C
        _ = pool.noteOn(64, 0.8)  // E
        _ = pool.noteOn(67, 0.6)  // G
        
        #expect(pool.getActiveVoiceCount() == 3, "Should have 3 active voices")
        
        let cActive = pool.isNoteActive(60)
        let eActive = pool.isNoteActive(64)
        let gActive = pool.isNoteActive(67)
        
        #expect(cActive, "C should be active")
        #expect(eActive, "E should be active")
        #expect(gActive, "G should be active")
    }
    
    @Test("noteOff only affects the specified note")
    func testSelectiveNoteOff() {
        var pool = VoicePool(8, sampleRate)
        
        // Very fast envelope
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampRelease = 0.001
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(64, 1.0)
        _ = pool.noteOn(67, 1.0)
        
        pool.noteOff(64)  // Release only E
        
        // Process through release
        for _ in 0..<1000 {
            _ = pool.process()
        }
        
        let cActive = pool.isNoteActive(60)
        let eActive = pool.isNoteActive(64)
        let gActive = pool.isNoteActive(67)
        
        #expect(cActive, "C should still be active")
        #expect(!eActive, "E should be released")
        #expect(gActive, "G should still be active")
    }
    
    // MARK: - Audio Processing Tests
    
    @Test("Pool produces audio when voices are active")
    func testAudioOutput() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.masterVolume = 1.0
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        
        var samples: [Double] = []
        for _ in 0..<4410 { // 100ms
            samples.append(pool.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.1, "Pool should produce audible output")
    }
    
    @Test("Multiple voices are summed together")
    func testVoiceMixing() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.masterVolume = 1.0
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        // Single note
        _ = pool.noteOn(60, 1.0)
        
        // Skip attack
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        var singleNoteSamples: [Double] = []
        for _ in 0..<1000 {
            singleNoteSamples.append(pool.process())
        }
        let singleRMS = sqrt(singleNoteSamples.map { $0 * $0 }.reduce(0, +) / Double(singleNoteSamples.count))
        
        // Add two more notes
        _ = pool.noteOn(64, 1.0)
        _ = pool.noteOn(67, 1.0)
        
        // Skip attack for new notes
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        var chordSamples: [Double] = []
        for _ in 0..<1000 {
            chordSamples.append(pool.process())
        }
        let chordRMS = sqrt(chordSamples.map { $0 * $0 }.reduce(0, +) / Double(chordSamples.count))
        
        // Chord should be louder than single note (more energy)
        #expect(chordRMS > singleRMS, "Chord (\(chordRMS)) should be louder than single note (\(singleRMS))")
    }
    
    @Test("Silence when no voices are active")
    func testSilenceWhenEmpty() {
        var pool = VoicePool(8, sampleRate)
        
        var samples: [Double] = []
        for _ in 0..<1000 {
            samples.append(pool.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp == 0.0, "Should produce silence when no notes playing")
    }
    
    // MARK: - Voice Recycling Tests
    
    @Test("Voice returns to pool when envelope reaches idle")
    func testVoiceRecycling() {
        var pool = VoicePool(4, sampleRate)  // Small pool
        
        // Very fast envelope
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampRelease = 0.001
        pool.setParameters(params)
        
        // Fill the pool
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(64, 1.0)
        _ = pool.noteOn(67, 1.0)
        _ = pool.noteOn(72, 1.0)
        
        #expect(pool.getActiveVoiceCount() == 4, "Pool should be full")
        
        // Release all notes
        pool.noteOff(60)
        pool.noteOff(64)
        pool.noteOff(67)
        pool.noteOff(72)
        
        // Process through release
        for _ in 0..<2000 {
            _ = pool.process()
        }
        
        #expect(pool.getActiveVoiceCount() == 0, "All voices should be returned to pool")
        
        // Should be able to play new notes
        let newVoice = pool.noteOn(48, 1.0)
        #expect(newVoice >= 0, "Should be able to allocate new voice after recycling")
    }
    
    // MARK: - Parameter Tests
    
    @Test("setParameters applies to all voices")
    func testParameterBroadcast() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.dutyCycle = 0.5
        params.vowelMorph = 0.75
        params.masterVolume = 0.8
        pool.setParameters(params)
        
        // Play multiple notes
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(64, 1.0)
        
        // Both voices should use same parameters (they should produce audio)
        var samples: [Double] = []
        for _ in 0..<1000 {
            samples.append(pool.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.01, "Voices should produce output with applied parameters")
    }
    
    // MARK: - MIDI Integration Tests
    
    @Test("Handles velocity correctly")
    func testVelocity() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        // Loud note
        _ = pool.noteOn(60, 1.0)
        
        // Skip attack
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        var loudSamples: [Double] = []
        for _ in 0..<1000 {
            loudSamples.append(pool.process())
        }
        
        pool.allNotesOff()
        for _ in 0..<2000 { _ = pool.process() } // Let it settle
        
        // Quiet note
        _ = pool.noteOn(60, 0.25)
        
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        var quietSamples: [Double] = []
        for _ in 0..<1000 {
            quietSamples.append(pool.process())
        }
        
        let loudRMS = sqrt(loudSamples.map { $0 * $0 }.reduce(0, +) / Double(loudSamples.count))
        let quietRMS = sqrt(quietSamples.map { $0 * $0 }.reduce(0, +) / Double(quietSamples.count))
        
        #expect(loudRMS > quietRMS * 1.5, "Loud note (\(loudRMS)) should be louder than quiet (\(quietRMS))")
    }
    
    @Test("allNotesOff releases all voices")
    func testAllNotesOff() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampRelease = 0.001
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(64, 1.0)
        _ = pool.noteOn(67, 1.0)
        
        pool.allNotesOff()
        
        // Process through release
        for _ in 0..<2000 {
            _ = pool.process()
        }
        
        #expect(pool.getActiveVoiceCount() == 0, "All voices should be released")
    }
    
    // MARK: - Reset Tests
    
    @Test("reset clears all voices immediately")
    func testReset() {
        var pool = VoicePool(8, sampleRate)
        
        _ = pool.noteOn(60, 1.0)
        _ = pool.noteOn(64, 1.0)
        
        pool.reset()
        
        #expect(pool.getActiveVoiceCount() == 0, "All voices should be cleared after reset")
        
        // Should produce silence immediately
        var samples: [Double] = []
        for _ in 0..<100 {
            samples.append(pool.process())
        }
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp == 0.0, "Should produce silence after reset")
    }
    
    // MARK: - Allocation Mode Tests
    
    @Test("Allocation mode can be changed")
    func testAllocationMode() {
        var pool = VoicePool(8, sampleRate)
        
        pool.setAllocationMode(.LowestNote)
        let mode1 = pool.getAllocationMode()
        #expect(mode1.rawValue == VoiceAllocator.Mode.LowestNote.rawValue)
        
        pool.setAllocationMode(.RoundRobin)
        let mode2 = pool.getAllocationMode()
        #expect(mode2.rawValue == VoiceAllocator.Mode.RoundRobin.rawValue)
    }
}
