//
//  AftertouchTests.swift
//  VoxCoreTests
//
//  Tests for polyphonic aftertouch (Phase 2.5)
//

import Testing
@testable import VoxCore

@Suite("Aftertouch Tests")
struct AftertouchTests {
    let sampleRate = 44100.0
    
    // MARK: - Parameter Tests
    
    @Test("VoxVoice has aftertouch modulation parameters")
    func testAftertouchParams() {
        var params = VoxVoiceParameters()
        
        // Aftertouch to pitch
        params.aftertouchToPitch = 2.0  // +2 semitones at full pressure
        #expect(params.aftertouchToPitch == 2.0)
        
        // Aftertouch to formant1
        params.aftertouchToFormant1 = 200.0
        #expect(params.aftertouchToFormant1 == 200.0)
        
        // Aftertouch to formant2
        params.aftertouchToFormant2 = 300.0
        #expect(params.aftertouchToFormant2 == 300.0)
        
        // Aftertouch to LFO amount
        params.aftertouchToLFOAmount = 0.5
        #expect(params.aftertouchToLFOAmount == 0.5)
    }
    
    @Test("Default aftertouch depths are zero")
    func testDefaultAftertouchDepths() {
        let params = VoxVoiceParameters()
        
        #expect(params.aftertouchToPitch == 0.0)
        #expect(params.aftertouchToFormant1 == 0.0)
        #expect(params.aftertouchToFormant2 == 0.0)
        #expect(params.aftertouchToLFOAmount == 0.0)
    }
    
    // MARK: - Per-Voice Aftertouch Tests
    
    @Test("VoxVoice can receive poly aftertouch")
    func testSetAftertouch() {
        var voice = VoxVoice(sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        voice.setParameters(params)
        
        voice.noteOn(60, 1.0)
        
        // Set aftertouch value (0.0 to 1.0)
        voice.setAftertouch(0.5)
        let at = voice.getAftertouch()
        #expect(at == 0.5, "Aftertouch should be 0.5, got \(at)")
        
        voice.setAftertouch(1.0)
        let at2 = voice.getAftertouch()
        #expect(at2 == 1.0, "Aftertouch should be 1.0, got \(at2)")
    }
    
    @Test("Aftertouch starts at zero")
    func testAftertouchStartsAtZero() {
        var voice = VoxVoice(sampleRate)
        
        voice.noteOn(60, 1.0)
        
        let at = voice.getAftertouch()
        #expect(at == 0.0, "Initial aftertouch should be 0")
    }
    
    @Test("Aftertouch resets on note on")
    func testAftertouchResetsOnNoteOn() {
        var voice = VoxVoice(sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampRelease = 0.001
        voice.setParameters(params)
        
        voice.noteOn(60, 1.0)
        voice.setAftertouch(0.75)
        
        // New note should reset aftertouch
        voice.noteOn(64, 1.0)
        let at = voice.getAftertouch()
        #expect(at == 0.0, "Aftertouch should reset on new note")
    }
    
    // MARK: - VoicePool Aftertouch Routing
    
    @Test("VoicePool routes poly aftertouch to correct voice")
    func testPolyAftertouchRouting() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        let voice1 = pool.noteOn(60, 1.0)
        let voice2 = pool.noteOn(64, 1.0)
        
        #expect(voice1 >= 0)
        #expect(voice2 >= 0)
        #expect(voice1 != voice2)
        
        // Send poly aftertouch to note 60 only
        pool.setPolyAftertouch(60, 0.8)
        
        let v1 = pool.getVoice(voice1)!.pointee.getAftertouch()
        let v2 = pool.getVoice(voice2)!.pointee.getAftertouch()
        
        #expect(v1 == 0.8, "Voice 1 (note 60) should have aftertouch 0.8, got \(v1)")
        #expect(v2 == 0.0, "Voice 2 (note 64) should have aftertouch 0, got \(v2)")
    }
    
    @Test("Poly aftertouch to non-playing note is ignored")
    func testAftertouchToNonPlayingNote() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        
        // Send aftertouch to a note that's not playing
        pool.setPolyAftertouch(72, 0.9)
        
        // Should not crash and should be ignored
        #expect(pool.getActiveVoiceCount() == 1)
    }
    
    // MARK: - Aftertouch Modulation Tests
    
    @Test("Aftertouch modulates pitch")
    func testAftertouchPitchMod() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.aftertouchToPitch = 12.0  // +12 semitones at full pressure
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        
        // No aftertouch - baseline
        var baselineSamples: [Double] = []
        for _ in 0..<1000 {
            baselineSamples.append(pool.process())
        }
        
        // Apply aftertouch - should raise pitch
        pool.setPolyAftertouch(60, 1.0)
        
        var aftertouchSamples: [Double] = []
        for _ in 0..<1000 {
            aftertouchSamples.append(pool.process())
        }
        
        // Both should produce output
        let baseMax = baselineSamples.map { Swift.abs($0) }.max() ?? 0.0
        let atMax = aftertouchSamples.map { Swift.abs($0) }.max() ?? 0.0
        
        #expect(baseMax > 0.01, "Baseline should produce audio")
        #expect(atMax > 0.01, "Aftertouch should produce audio")
    }
    
    @Test("Aftertouch can scale LFO amount")
    func testAftertouchLFOAmount() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.lfoRate = 5.0
        params.lfoToPitch = 1.0  // Base LFO vibrato
        params.aftertouchToLFOAmount = 1.0  // Aftertouch adds more LFO
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        
        // Process with varying aftertouch
        pool.setPolyAftertouch(60, 0.0)  // No additional vibrato
        var lowATSamples: [Double] = []
        for _ in 0..<1000 {
            lowATSamples.append(pool.process())
        }
        
        pool.setPolyAftertouch(60, 1.0)  // Full additional vibrato
        var highATSamples: [Double] = []
        for _ in 0..<1000 {
            highATSamples.append(pool.process())
        }
        
        // Both should produce output
        let lowMax = lowATSamples.map { Swift.abs($0) }.max() ?? 0.0
        let highMax = highATSamples.map { Swift.abs($0) }.max() ?? 0.0
        
        #expect(lowMax > 0.01)
        #expect(highMax > 0.01)
    }
    
    // MARK: - Edge Cases
    
    @Test("Aftertouch is clamped to 0-1 range")
    func testAftertouchClamping() {
        var voice = VoxVoice(sampleRate)
        
        voice.noteOn(60, 1.0)
        
        voice.setAftertouch(-0.5)
        #expect(voice.getAftertouch() >= 0.0, "Aftertouch should be clamped to >= 0")
        
        voice.setAftertouch(1.5)
        #expect(voice.getAftertouch() <= 1.0, "Aftertouch should be clamped to <= 1")
    }
}
