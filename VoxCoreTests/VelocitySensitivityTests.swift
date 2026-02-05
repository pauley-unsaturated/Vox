//
//  VelocitySensitivityTests.swift
//  VoxCoreTests
//
//  Tests for velocity sensitivity (Phase 2.4)
//

import Testing
@testable import VoxCore

@Suite("Velocity Sensitivity Tests")
struct VelocitySensitivityTests {
    let sampleRate = 44100.0
    
    // MARK: - Parameter Tests
    
    @Test("VoxVoice has velocity sensitivity parameter")
    func testVelocitySensitivityParam() {
        var params = VoxVoiceParameters()
        
        // Velocity sensitivity (0.0 = no effect, 1.0 = full velocity)
        params.velocitySensitivity = 0.5
        #expect(params.velocitySensitivity == 0.5)
        
        params.velocitySensitivity = 0.0
        #expect(params.velocitySensitivity == 0.0)
        
        params.velocitySensitivity = 1.0
        #expect(params.velocitySensitivity == 1.0)
    }
    
    @Test("Velocity to mod envelope amount parameter exists")
    func testVelocityToModEnvParam() {
        var params = VoxVoiceParameters()
        
        // Velocity can scale mod envelope amount
        params.velocityToModEnv = 0.5  // 50% velocity influence on mod env
        #expect(params.velocityToModEnv == 0.5)
    }
    
    @Test("Default velocity sensitivity is 1.0 (full)")
    func testDefaultVelocitySensitivity() {
        let params = VoxVoiceParameters()
        
        #expect(params.velocitySensitivity == 1.0, "Default should be full sensitivity")
        #expect(params.velocityToModEnv == 0.0, "Default mod env velocity should be 0")
    }
    
    // MARK: - Amplitude Velocity Tests
    
    @Test("At 100% sensitivity, velocity fully affects amplitude")
    func testFullVelocitySensitivity() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.velocitySensitivity = 1.0  // Full sensitivity
        pool.setParameters(params)
        
        // Play loud note
        _ = pool.noteOn(60, 1.0)  // Full velocity
        
        // Skip attack
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        var loudSamples: [Double] = []
        for _ in 0..<1000 {
            loudSamples.append(pool.process())
        }
        
        pool.allNotesOff()
        for _ in 0..<2000 { _ = pool.process() }
        
        // Play quiet note
        _ = pool.noteOn(60, 0.25)  // Quarter velocity
        
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        var quietSamples: [Double] = []
        for _ in 0..<1000 {
            quietSamples.append(pool.process())
        }
        
        let loudRMS = sqrt(loudSamples.map { $0 * $0 }.reduce(0, +) / Double(loudSamples.count))
        let quietRMS = sqrt(quietSamples.map { $0 * $0 }.reduce(0, +) / Double(quietSamples.count))
        
        // With full sensitivity, loud should be ~4x louder than quiet
        let ratio = loudRMS / quietRMS
        #expect(ratio > 3.0, "Loud (\(loudRMS)) should be ~4x louder than quiet (\(quietRMS)), ratio: \(ratio)")
    }
    
    @Test("At 0% sensitivity, velocity has no effect")
    func testZeroVelocitySensitivity() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.velocitySensitivity = 0.0  // No sensitivity
        pool.setParameters(params)
        
        // Play "loud" note
        _ = pool.noteOn(60, 1.0)
        
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        var loudSamples: [Double] = []
        for _ in 0..<1000 {
            loudSamples.append(pool.process())
        }
        
        pool.allNotesOff()
        for _ in 0..<2000 { _ = pool.process() }
        
        // Play "quiet" note
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
        
        // With zero sensitivity, both should be similar
        let ratio = loudRMS / quietRMS
        #expect(ratio > 0.8 && ratio < 1.2, "With 0% sensitivity, volumes should be similar, ratio: \(ratio)")
    }
    
    @Test("At 50% sensitivity, velocity has partial effect")
    func testPartialVelocitySensitivity() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.velocitySensitivity = 0.5  // Half sensitivity
        pool.setParameters(params)
        
        // Play loud note
        _ = pool.noteOn(60, 1.0)
        
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        var loudSamples: [Double] = []
        for _ in 0..<1000 {
            loudSamples.append(pool.process())
        }
        
        pool.allNotesOff()
        for _ in 0..<2000 { _ = pool.process() }
        
        // Play quiet note
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
        
        // With 50% sensitivity, ratio should be between 1 and 4
        let ratio = loudRMS / quietRMS
        #expect(ratio > 1.3 && ratio < 3.0, "With 50% sensitivity, ratio should be moderate, got: \(ratio)")
    }
    
    // MARK: - Velocity to Mod Envelope Tests
    
    @Test("Velocity can scale mod envelope amount")
    func testVelocityToModEnvelope() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.modAttack = 0.001
        params.modSustain = 1.0
        params.velocityToModEnv = 1.0  // Full velocity scaling of mod env
        params.modEnvToPitch = 12.0    // +12 semitones at peak
        pool.setParameters(params)
        
        // High velocity = full mod env amount
        let voice1 = pool.noteOn(60, 1.0)
        
        for _ in 0..<200 {
            _ = pool.process()
        }
        
        // Low velocity = reduced mod env amount
        let voice2 = pool.noteOn(64, 0.25)
        
        // Both voices should produce output
        #expect(voice1 >= 0)
        #expect(voice2 >= 0)
        #expect(pool.getActiveVoiceCount() == 2)
    }
    
    // MARK: - Edge Cases
    
    @Test("Very low velocity still produces sound")
    func testVeryLowVelocity() {
        var pool = VoicePool(4, sampleRate)
        
        var params = VoxVoiceParameters()
        params.ampAttack = 0.001
        params.ampSustain = 1.0
        params.velocitySensitivity = 1.0
        pool.setParameters(params)
        
        // Very quiet note
        _ = pool.noteOn(60, 0.1)  // 10% velocity
        
        for _ in 0..<500 {
            _ = pool.process()
        }
        
        var samples: [Double] = []
        for _ in 0..<1000 {
            samples.append(pool.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.001, "Very low velocity should still produce audible output")
    }
}
