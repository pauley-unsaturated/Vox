//
//  VoiceMixingTests.swift
//  VoxCoreTests
//
//  Tests for voice mixing (summing all active voices to stereo output)
//

import Testing
@testable import VoxCore

@Suite("Voice Mixing Tests")
struct VoiceMixingTests {
    let sampleRate = 44100.0
    
    // MARK: - Basic Mixing Tests
    
    @Test("Single voice outputs correctly")
    func testSingleVoiceOutput() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.masterVolume = 1.0
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        
        // Skip attack
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        // Collect output
        var samples: [Double] = []
        for _ in 0..<4410 {
            samples.append(pool.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Double(samples.count))
        
        #expect(maxAmp > 0.1, "Single voice should produce significant output")
        #expect(rms > 0.05, "RMS should be reasonable for single voice")
    }
    
    @Test("Multiple voices sum correctly")
    func testMultipleVoiceSum() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.masterVolume = 0.5  // Half volume per voice to avoid clipping
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        // Single voice
        _ = pool.noteOn(60, 1.0)
        for _ in 0..<500 { _ = pool.process() }
        
        var singleSamples: [Double] = []
        for _ in 0..<1000 {
            singleSamples.append(pool.process())
        }
        let singleRMS = sqrt(singleSamples.map { $0 * $0 }.reduce(0, +) / Double(singleSamples.count))
        
        // Add second voice at same velocity
        _ = pool.noteOn(72, 1.0)
        for _ in 0..<500 { _ = pool.process() }
        
        var doubleSamples: [Double] = []
        for _ in 0..<1000 {
            doubleSamples.append(pool.process())
        }
        let doubleRMS = sqrt(doubleSamples.map { $0 * $0 }.reduce(0, +) / Double(doubleSamples.count))
        
        // Two voices should produce more energy (not exactly 2x due to phase relationships)
        #expect(doubleRMS > singleRMS, "Two voices should be louder than one: \(doubleRMS) vs \(singleRMS)")
    }
    
    @Test("Chord produces complex waveform")
    func testChordMixing() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.masterVolume = 0.3
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.dutyCycle = 0.3
        pool.setParameters(params)
        
        // Play C major chord
        _ = pool.noteOn(60, 1.0)  // C4
        _ = pool.noteOn(64, 1.0)  // E4
        _ = pool.noteOn(67, 1.0)  // G4
        
        // Skip attack
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        // Collect samples
        var samples: [Double] = []
        for _ in 0..<Int(sampleRate) {  // 1 second
            samples.append(pool.process())
        }
        
        // Analyze frequency content via zero crossings
        var zeroCrossings = 0
        var prev = samples[0]
        for sample in samples.dropFirst() {
            if prev <= 0 && sample > 0 {
                zeroCrossings += 1
            }
            prev = sample
        }
        
        // A chord should produce a complex pattern - not just the fundamental
        // C4 = 262Hz, so 1 second should have ~262 zero crossings minimum
        #expect(zeroCrossings > 200, "Chord should produce reasonable activity: \(zeroCrossings) ZC")
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.1, "Chord should produce significant output")
    }
    
    // MARK: - Master Volume Tests
    
    @Test("Master volume scales all voices")
    func testMasterVolumeScaling() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.masterVolume = 1.0
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        // Full volume
        _ = pool.noteOn(60, 1.0)
        for _ in 0..<500 { _ = pool.process() }
        
        var fullVolumeSamples: [Double] = []
        for _ in 0..<1000 {
            fullVolumeSamples.append(pool.process())
        }
        let fullRMS = sqrt(fullVolumeSamples.map { $0 * $0 }.reduce(0, +) / Double(fullVolumeSamples.count))
        
        // Half volume
        pool.reset()
        params.masterVolume = 0.5
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        for _ in 0..<500 { _ = pool.process() }
        
        var halfVolumeSamples: [Double] = []
        for _ in 0..<1000 {
            halfVolumeSamples.append(pool.process())
        }
        let halfRMS = sqrt(halfVolumeSamples.map { $0 * $0 }.reduce(0, +) / Double(halfVolumeSamples.count))
        
        // Half master volume should produce roughly half the RMS
        let ratio = halfRMS / fullRMS
        #expect(ratio > 0.3 && ratio < 0.7, "Half volume should be roughly half RMS: ratio=\(ratio)")
    }
    
    // MARK: - Stereo Output Tests
    
    @Test("processBlockStereo outputs to both channels")
    func testStereoOutput() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.masterVolume = 1.0
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        
        // Skip attack
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        // Create stereo buffers
        var leftChannel = [Double](repeating: 0.0, count: 1000)
        var rightChannel = [Double](repeating: 0.0, count: 1000)
        
        pool.processBlockStereo(&leftChannel, &rightChannel, 1000)
        
        let leftMax = leftChannel.map { Swift.abs($0) }.max() ?? 0.0
        let rightMax = rightChannel.map { Swift.abs($0) }.max() ?? 0.0
        
        #expect(leftMax > 0.1, "Left channel should have output")
        #expect(rightMax > 0.1, "Right channel should have output")
        
        // For mono source, left and right should be identical
        var identical = true
        for i in 0..<1000 {
            let diff = leftChannel[i] - rightChannel[i]
            if Swift.abs(diff) > 0.0001 {
                identical = false
                break
            }
        }
        #expect(identical, "Mono source should produce identical L/R")
    }
    
    // MARK: - Release Mixing Tests
    
    @Test("Voices in release still contribute to mix")
    func testReleaseMixing() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.masterVolume = 1.0
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.ampRelease = 0.5  // Long release
        pool.setParameters(params)
        
        _ = pool.noteOn(60, 1.0)
        
        // Skip attack into sustain
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        // Release the note
        pool.noteOff(60)
        
        // Immediately collect samples - voice should still be making sound
        var releaseSamples: [Double] = []
        for _ in 0..<1000 {
            releaseSamples.append(pool.process())
        }
        
        let releaseRMS = sqrt(releaseSamples.map { $0 * $0 }.reduce(0, +) / Double(releaseSamples.count))
        
        #expect(releaseRMS > 0.01, "Voice in release should still contribute: RMS=\(releaseRMS)")
    }
    
    // MARK: - Velocity Mix Tests
    
    @Test("Voices with different velocities mix correctly")
    func testVelocityMixing() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.masterVolume = 0.5
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        // Play two notes at different velocities
        _ = pool.noteOn(60, 1.0)   // Full velocity
        _ = pool.noteOn(72, 0.3)   // Quiet velocity
        
        // Skip attack
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        var samples: [Double] = []
        for _ in 0..<1000 {
            samples.append(pool.process())
        }
        
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Double(samples.count))
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        
        #expect(rms > 0.05, "Mixed velocities should produce output: RMS=\(rms)")
        #expect(maxAmp > 0.1, "Mixed velocities should have peaks: max=\(maxAmp)")
    }
    
    // MARK: - Full Polyphony Test
    
    @Test("All 8 voices can play simultaneously")
    func testFullPolyphony() {
        var pool = VoicePool(8, sampleRate)
        
        var params = VoxVoiceParameters()
        params.masterVolume = 0.125  // 1/8 per voice to avoid clipping
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        pool.setParameters(params)
        
        // Play all 8 voices
        for i: Int32 in 0..<8 {
            _ = pool.noteOn(60 + i * 2, 1.0)  // C, D, E, F#, G#, A#, C, D
        }
        
        #expect(pool.getActiveVoiceCount() == 8, "All 8 voices should be active")
        
        // Skip attack
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        var samples: [Double] = []
        for _ in 0..<1000 {
            samples.append(pool.process())
        }
        
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Double(samples.count))
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        
        #expect(rms > 0.05, "8 voices should produce substantial output: RMS=\(rms)")
        #expect(maxAmp > 0.1, "8 voices should have peaks: max=\(maxAmp)")
        #expect(maxAmp < 2.0, "Output shouldn't clip dramatically: max=\(maxAmp)")
    }
}
