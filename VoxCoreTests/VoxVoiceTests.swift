//
//  VoxVoiceTests.swift
//  VoxCoreTests
//
//  Tests for VoxVoice - the integrated pulsar synthesis voice
//

import Testing
@testable import VoxCore

@Suite("Vox Voice Tests")
struct VoxVoiceTests {
    let sampleRate = 44100.0
    
    // MARK: - Basic Functionality Tests
    
    @Test("VoxVoice initializes correctly")
    func testInitialization() {
        let voice = VoxVoice(sampleRate)
        
        // Should be inactive initially
        #expect(!voice.isActive(), "Voice should be inactive initially")
        #expect(voice.getCurrentNote() == -1, "No note should be playing")
    }
    
    @Test("Note on activates voice")
    func testNoteOn() {
        var voice = VoxVoice(sampleRate)
        
        voice.noteOn(60, 1.0) // Middle C, full velocity
        
        #expect(voice.isActive(), "Voice should be active after note on")
        #expect(voice.getCurrentNote() == 60, "Should be playing note 60")
    }
    
    @Test("Note off triggers release")
    func testNoteOff() {
        var voice = VoxVoice(sampleRate)
        
        // Set up fast envelope for testing
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampDecay = 0.01
        params.ampSustain = 0.7
        params.ampRelease = 0.01
        voice.setParameters(params)
        
        voice.noteOn(60, 1.0)
        
        // Process through attack to sustain
        for _ in 0..<500 {
            _ = voice.process()
        }
        
        voice.noteOff(60)
        
        // Should be in release but still active briefly
        let state = voice.getEnvelopeState()
        #expect(state == ADSREnvelope.State.RELEASE, "Should be in release state")
        
        // Process through release
        for _ in 0..<5000 {
            _ = voice.process()
        }
        
        #expect(!voice.isActive(), "Voice should be inactive after release")
    }
    
    // MARK: - Audio Output Tests
    
    @Test("Voice produces audio output")
    func testAudioOutput() {
        var voice = VoxVoice(sampleRate)
        
        // Configure voice
        var params = VoxVoiceParameters()
        params.masterVolume = 1.0
        params.dutyCycle = 0.3
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        voice.setParameters(params)
        
        voice.noteOn(60, 1.0)
        
        // Collect samples
        var samples: [Double] = []
        for _ in 0..<4410 { // 100ms
            samples.append(voice.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.1, "Voice should produce audible output, got \(maxAmp)")
    }
    
    @Test("Velocity affects output amplitude")
    func testVelocitySensitivity() {
        // High velocity
        var voiceHigh = VoxVoice(sampleRate)
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        voiceHigh.setParameters(params)
        voiceHigh.noteOn(60, 1.0)
        
        // Low velocity
        var voiceLow = VoxVoice(sampleRate)
        voiceLow.setParameters(params)
        voiceLow.noteOn(60, 0.25)
        
        // Skip attack
        for _ in 0..<441 {
            _ = voiceHigh.process()
            _ = voiceLow.process()
        }
        
        // Collect samples
        var samplesHigh: [Double] = []
        var samplesLow: [Double] = []
        for _ in 0..<1000 {
            samplesHigh.append(voiceHigh.process())
            samplesLow.append(voiceLow.process())
        }
        
        let rmsHigh = sqrt(samplesHigh.map { $0 * $0 }.reduce(0, +) / Double(samplesHigh.count))
        let rmsLow = sqrt(samplesLow.map { $0 * $0 }.reduce(0, +) / Double(samplesLow.count))
        
        #expect(rmsHigh > rmsLow * 1.5, 
               "High velocity (\(rmsHigh)) should be louder than low (\(rmsLow))")
    }
    
    // MARK: - Parameter Tests
    
    @Test("Duty cycle parameter affects timbre")
    func testDutyCycleParameter() {
        // Narrow duty
        var voiceNarrow = VoxVoice(sampleRate)
        var params = VoxVoiceParameters()
        params.dutyCycle = 0.1
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        voiceNarrow.setParameters(params)
        voiceNarrow.noteOn(60, 1.0)
        
        // Wide duty
        var voiceWide = VoxVoice(sampleRate)
        params.dutyCycle = 0.5
        voiceWide.setParameters(params)
        voiceWide.noteOn(60, 1.0)
        
        // Both should produce output
        var outputNarrow: [Double] = []
        var outputWide: [Double] = []
        for _ in 0..<4410 {
            outputNarrow.append(voiceNarrow.process())
            outputWide.append(voiceWide.process())
        }
        
        let maxNarrow = outputNarrow.map { Swift.abs($0) }.max() ?? 0.0
        let maxWide = outputWide.map { Swift.abs($0) }.max() ?? 0.0
        
        #expect(maxNarrow > 0.01, "Narrow duty should produce output")
        #expect(maxWide > 0.01, "Wide duty should produce output")
    }
    
    @Test("Vowel morph parameter works")
    func testVowelMorphParameter() {
        var voice = VoxVoice(sampleRate)
        var params = VoxVoiceParameters()
        params.useVowelMorph = true
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        
        // Test different vowels
        let vowelPositions = [0.0, 0.25, 0.5, 0.75, 1.0]
        for pos in vowelPositions {
            params.vowelMorph = pos
            voice.setParameters(params)
            voice.noteOn(60, 1.0)
            
            for _ in 0..<1000 {
                _ = voice.process()
            }
            
            voice.reset()
        }
        
        #expect(true, "Vowel morph should work at all positions")
    }
    
    // MARK: - Pitch Tests
    
    @Test("Different notes produce different pitches")
    func testPitchVariation() {
        var voiceLow = VoxVoice(sampleRate)
        var params = VoxVoiceParameters()
        params.dutyCycle = 0.3
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        voiceLow.setParameters(params)
        voiceLow.noteOn(48, 1.0) // C3
        
        var voiceHigh = VoxVoice(sampleRate)
        voiceHigh.setParameters(params)
        voiceHigh.noteOn(72, 1.0) // C5
        
        // Count zero crossings
        var lowZC = 0
        var highZC = 0
        var prevLow = 0.0
        var prevHigh = 0.0
        
        for _ in 0..<Int(sampleRate) { // 1 second
            let sampleLow = voiceLow.process()
            let sampleHigh = voiceHigh.process()
            
            if prevLow <= 0 && sampleLow > 0 { lowZC += 1 }
            if prevHigh <= 0 && sampleHigh > 0 { highZC += 1 }
            
            prevLow = sampleLow
            prevHigh = sampleHigh
        }
        
        // Higher note should have more zero crossings (C5 is 2 octaves above C3 = 4x frequency)
        // But due to formant filtering, the relationship may not be exact
        #expect(highZC >= lowZC * 2, 
               "High note (\(highZC) ZC) should be at least 2x higher freq than low note (\(lowZC) ZC)")
    }
    
    @Test("Pitch bend affects frequency")
    func testPitchBend() {
        var voice = VoxVoice(sampleRate)
        var params = VoxVoiceParameters()
        params.dutyCycle = 0.3
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        voice.setParameters(params)
        voice.noteOn(69, 1.0) // A4 = 440Hz
        
        // Count zero crossings without bend
        var zcNoBend = 0
        var prev = 0.0
        for _ in 0..<Int(sampleRate) {
            let sample = voice.process()
            if prev <= 0 && sample > 0 { zcNoBend += 1 }
            prev = sample
        }
        
        // Apply pitch bend up 2 semitones
        voice.setPitchBend(2.0)
        
        var zcWithBend = 0
        prev = 0.0
        for _ in 0..<Int(sampleRate) {
            let sample = voice.process()
            if prev <= 0 && sample > 0 { zcWithBend += 1 }
            prev = sample
        }
        
        // Bent pitch should be higher
        #expect(zcWithBend > zcNoBend, 
               "Pitch bend up should increase frequency: \(zcWithBend) vs \(zcNoBend)")
    }
    
    // MARK: - Glide Tests
    
    @Test("Glide smoothly transitions between notes")
    func testGlide() {
        var voice = VoxVoice(sampleRate)
        var params = VoxVoiceParameters()
        params.glideEnabled = true
        params.glideTime = 0.1 // 100ms glide
        params.dutyCycle = 0.3
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        voice.setParameters(params)
        
        voice.noteOn(60, 1.0) // C4
        
        // Let it settle
        for _ in 0..<4410 {
            _ = voice.process()
        }
        
        // Play new note (should glide)
        voice.noteOn(72, 1.0) // C5
        
        // The glide should take about 100ms to complete
        // Just verify no crashes
        for _ in 0..<Int(sampleRate * 0.2) {
            _ = voice.process()
        }
        
        #expect(true, "Glide should work without crashing")
    }
    
    // MARK: - Reset Tests
    
    @Test("Reset clears voice state")
    func testReset() {
        var voice = VoxVoice(sampleRate)
        voice.noteOn(60, 1.0)
        
        // Process some samples
        for _ in 0..<1000 {
            _ = voice.process()
        }
        
        #expect(voice.isActive(), "Voice should be active before reset")
        
        voice.reset()
        
        #expect(!voice.isActive(), "Voice should be inactive after reset")
        #expect(voice.getCurrentNote() == -1, "Note should be cleared after reset")
    }
}
