import Testing
import VoxCore

struct ADSREnvelopeTests {
    
    @Test func envelopeInitialization() async throws {
        // Test that ADSREnvelope initializes correctly
        let envelope = ADSREnvelope(44100.0)
        
        // Check default values
        #expect(envelope.getAttackTime() == 0.01)    // 10ms
        #expect(envelope.getDecayTime() == 0.1)      // 100ms
        #expect(envelope.getSustainLevel() == 0.7)   // 70%
        #expect(envelope.getReleaseTime() == 0.3)    // 300ms
        
        // Check initial state
        #expect(envelope.getState() == ADSREnvelope.State.IDLE)
        #expect(envelope.getCurrentLevel() == 0.0)
    }
    
    @Test func envelopeParameterSetters() async throws {
        // Test parameter setters and getters
        var envelope = ADSREnvelope(44100.0)
        
        // Set new values
        envelope.setAttackTime(0.05)
        envelope.setDecayTime(0.2)
        envelope.setSustainLevel(0.5)
        envelope.setReleaseTime(0.4)
        
        // Verify values were set
        #expect(envelope.getAttackTime() == 0.05)
        #expect(envelope.getDecayTime() == 0.2)
        #expect(envelope.getSustainLevel() == 0.5)
        #expect(envelope.getReleaseTime() == 0.4)
    }
    
    @Test func envelopeAttackStage() async throws {
        // Test attack stage behavior
        var envelope = ADSREnvelope(44100.0) // 44.1kHz sample rate
        envelope.setAttackTime(0.01) // 10ms attack
        
        envelope.noteOn()
        #expect(envelope.getState() == ADSREnvelope.State.ATTACK)
        
        // Process samples during attack - exponential envelopes need more time
        // to reach full level due to RC-style curve targeting above 1.0
        var maxLevel = 0.0
        for _ in 0..<882 { // ~20ms - allow exponential attack to complete
            let level = envelope.process()
            maxLevel = max(maxLevel, level)
        }
        
        // Should reach close to 1.0 and transition to decay
        #expect(maxLevel >= 0.96) // Allow tolerance for exponential envelope
        #expect(envelope.getState() == ADSREnvelope.State.DECAY)
    }
    
    @Test func envelopeDecayStage() async throws {
        // Test decay stage behavior
        var envelope = ADSREnvelope(44100.0)
        envelope.setAttackTime(0.001)   // 1ms attack (fast)
        envelope.setDecayTime(0.01)     // 10ms decay = 441 samples
        envelope.setSustainLevel(0.5)   // 50% sustain
        
        envelope.noteOn()
        
        // Process through attack (1ms = ~44 samples)
        for _ in 0..<50 {
            _ = envelope.process()
        }
        
        // Should be in decay now
        #expect(envelope.getState() == ADSREnvelope.State.DECAY)
        
        // Process through decay (need to ensure we're past attack+decay time)
        var finalLevel = 0.0
        for _ in 0..<1000 {
            finalLevel = envelope.process()
        }
        
        // Should reach sustain level
        #expect(envelope.getState() == ADSREnvelope.State.SUSTAIN)
        #expect(Swift.abs(finalLevel - 0.5) < 0.01) // Close to sustain level
    }
    
    @Test func envelopeSustainStage() async throws {
        // Test sustain stage behavior
        var envelope = ADSREnvelope(44100.0)
        envelope.setAttackTime(0.001)
        envelope.setDecayTime(0.001)
        envelope.setSustainLevel(0.6)
        
        envelope.noteOn()
        
        // Process through attack and decay - exponential envelopes need more time
        for _ in 0..<500 {
            _ = envelope.process()
        }
        
        // Should be in sustain
        #expect(envelope.getState() == ADSREnvelope.State.SUSTAIN)
        
        // Level should remain roughly constant at sustain level
        // (smoothing filter causes tiny variations between consecutive samples)
        let level1 = envelope.process()
        let level2 = envelope.process()
        let level3 = envelope.process()
        
        #expect(Swift.abs(level1 - 0.6) < 0.02) // Sustain level with tolerance
        #expect(Swift.abs(level1 - level2) < 0.001) // Nearly equal
        #expect(Swift.abs(level2 - level3) < 0.001) // Nearly equal
    }
    
    @Test func envelopeReleaseStage() async throws {
        // Test release stage behavior
        var envelope = ADSREnvelope(44100.0)
        envelope.setAttackTime(0.001)
        envelope.setDecayTime(0.001)
        envelope.setSustainLevel(0.5)
        envelope.setReleaseTime(0.01) // 10ms release
        
        envelope.noteOn()
        
        // Process to sustain stage
        for _ in 0..<200 {
            _ = envelope.process()
        }
        
        // Trigger release
        envelope.noteOff()
        #expect(envelope.getState() == ADSREnvelope.State.RELEASE)
        
        // Process through release
        var finalLevel = 1.0
        for _ in 0..<1000 { // More than enough samples
            finalLevel = envelope.process()
            if envelope.getState() == ADSREnvelope.State.IDLE {
                break
            }
        }
        
        // Should return to idle with near-zero level (smoothing filter may leave tiny residual)
        #expect(envelope.getState() == ADSREnvelope.State.IDLE)
        #expect(finalLevel < 0.001)
    }
    
    @Test func envelopeCompleteADSRCycle() async throws {
        // Test complete ADSR cycle
        var envelope = ADSREnvelope(1000.0) // 1kHz for easier counting
        envelope.setAttackTime(0.1)    // 100 samples
        envelope.setDecayTime(0.1)     // 100 samples
        envelope.setSustainLevel(0.7)
        envelope.setReleaseTime(0.1)   // 100 samples
        
        // Start envelope
        envelope.noteOn()
        
        var peakLevel = 0.0
        var sustainReached = false
        
        // Process through attack and decay (200 samples)
        for i in 0..<200 {
            let level = envelope.process()
            peakLevel = max(peakLevel, level)
            
            if i == 199 && envelope.getState() == ADSREnvelope.State.SUSTAIN {
                sustainReached = true
            }
        }
        
        #expect(peakLevel >= 0.99)
        #expect(sustainReached)
        
        // Hold sustain for a bit
        let sustainLevel = envelope.process()
        #expect(Swift.abs(sustainLevel - 0.7) < 0.01)
        
        // Release
        envelope.noteOff()
        
        // Process through release
        for _ in 0..<200 {
            _ = envelope.process()
        }
        
        #expect(envelope.getState() == ADSREnvelope.State.IDLE)
        #expect(envelope.getCurrentLevel() == 0.0)
    }
    
    @Test func envelopeReset() async throws {
        // Test reset functionality
        var envelope = ADSREnvelope(44100.0)
        
        // Start envelope
        envelope.noteOn()
        
        // Process some samples
        for _ in 0..<100 {
            _ = envelope.process()
        }
        
        // Reset
        envelope.reset()
        
        #expect(envelope.getState() == ADSREnvelope.State.IDLE)
        #expect(envelope.getCurrentLevel() == 0.0)
    }
    
    @Test func envelopeLegatoBehavior() async throws {
        // Test legato behavior (retriggering during a note)
        var envelope = ADSREnvelope(44100.0)
        envelope.setAttackTime(0.01)
        envelope.setDecayTime(0.01)
        envelope.setSustainLevel(0.5)
        
        // Start first note
        envelope.noteOn()
        
        // Process to sustain (attack + decay = 20ms = ~882 samples, so 1500 is plenty)
        for _ in 0..<1500 {
            _ = envelope.process()
        }
        
        let levelBeforeRetrigger = envelope.getCurrentLevel()
        #expect(Swift.abs(levelBeforeRetrigger - 0.5) < 0.01)
        
        // Retrigger without note off (legato)
        envelope.noteOn()
        
        // Should go back to attack from current level
        #expect(envelope.getState() == ADSREnvelope.State.ATTACK)
        
        // Level should continue from where it was (not reset to 0)
        let levelAfterRetrigger = envelope.process()
        #expect(levelAfterRetrigger >= levelBeforeRetrigger)
    }
    
    @Test func envelopeBlockProcessing() async throws {
        // Test block processing
        var envelope = ADSREnvelope(44100.0)
        envelope.setAttackTime(0.001)
        envelope.setDecayTime(0.001)
        envelope.setSustainLevel(0.8)
        
        var output = [Double](repeating: 0.0, count: 512)
        
        envelope.noteOn()
        envelope.processBlock(&output, 512)
        
        // Check that output was filled
        let nonZeroSamples = output.filter { $0 > 0 }.count
        #expect(nonZeroSamples > 0)
        
        // Last samples should be near sustain level
        let lastSamples = Array(output.suffix(10))
        for sample in lastSamples {
            #expect(Swift.abs(sample - 0.8) < 0.1)
        }
    }
    
    @Test func envelopeParameterValidation() async throws {
        // Test parameter clamping
        var envelope = ADSREnvelope(44100.0)
        
        // Test minimum times (should clamp to 1ms)
        envelope.setAttackTime(0.0)
        envelope.setDecayTime(-1.0)
        envelope.setReleaseTime(0.0001)
        
        #expect(envelope.getAttackTime() >= 0.001)
        #expect(envelope.getDecayTime() >= 0.001)
        #expect(envelope.getReleaseTime() >= 0.001)
        
        // Test sustain level clamping
        envelope.setSustainLevel(1.5)
        #expect(envelope.getSustainLevel() == 1.0)
        
        envelope.setSustainLevel(-0.5)
        #expect(envelope.getSustainLevel() == 0.0)
    }
}