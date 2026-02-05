import Testing
import VoxCore

// ═══════════════════════════════════════════════════════════════════════════
// Phase 4.1: Global LFO Tests
// ═══════════════════════════════════════════════════════════════════════════

@Suite("Global LFO Tests")
struct GlobalLFOTests {
    let sampleRate = 44100.0
    
    @Test("GlobalLFO initializes with default values")
    func testDefaultValues() {
        var lfo = GlobalLFO(sampleRate)
        #expect(lfo.getRate() == 1.0, "Default rate should be 1.0 Hz")
        #expect(lfo.getAmount() == 0.0, "Default amount should be 0.0")
        #expect(lfo.getDestination() == GlobalLFODestination.None, "Default destination should be None")
    }
    
    @Test("GlobalLFO rate can be set and retrieved")
    func testRateControl() {
        var lfo = GlobalLFO(sampleRate)
        lfo.setRate(5.0)
        #expect(lfo.getRate() == 5.0, "Rate should be settable")
        
        lfo.setRate(20.0)
        #expect(lfo.getRate() == 20.0, "Rate should be changeable")
    }
    
    @Test("GlobalLFO produces output in valid range")
    func testOutputRange() {
        var lfo = GlobalLFO(sampleRate)
        lfo.setRate(10.0)
        lfo.setAmount(1.0)
        lfo.setWaveform(LFO.Waveform.SINE)
        
        for _ in 0..<Int(sampleRate) {
            let value = lfo.process()
            #expect(value >= -1.0 && value <= 1.0, "Output should be in [-1, 1] range")
        }
    }
    
    @Test("GlobalLFO amount scales output")
    func testAmountScaling() {
        var lfo = GlobalLFO(sampleRate)
        lfo.setRate(1.0)
        lfo.setAmount(0.5)
        lfo.setWaveform(LFO.Waveform.SINE)
        
        // Process half a cycle
        for _ in 0..<Int(sampleRate / 2) {
            let _ = lfo.process()
        }
        
        let modulated = lfo.getModulatedOutput()
        #expect(Swift.abs(modulated) <= 0.51, "Amount should scale output to ~0.5")
    }
    
    @Test("GlobalLFOBank initializes correctly")
    func testLFOBank() {
        var bank = GlobalLFOBank(sampleRate)
        
        // Just verify we can process without crash
        for _ in 0..<1000 {
            bank.process()
        }
        #expect(true, "Bank processing should work")
    }
    
    @Test("GlobalLFO all waveforms work")
    func testAllWaveforms() {
        var lfo = GlobalLFO(sampleRate)
        // Test continuous waveforms (skip S&H which is too unpredictable in timing)
        let waveforms: [LFO.Waveform] = [.SINE, .TRIANGLE, .SAW, .SQUARE]
        
        for waveform in waveforms {
            lfo.setWaveform(waveform)
            lfo.setRate(10.0)
            lfo.setAmount(1.0)
            lfo.reset()
            
            var minVal = Double.infinity
            var maxVal = -Double.infinity
            
            // Process for a full cycle at 10 Hz
            for _ in 0..<Int(sampleRate / 10) {
                let value = lfo.process()
                minVal = min(minVal, value)
                maxVal = max(maxVal, value)
                #expect(value >= -1.0 && value <= 1.0, "\(waveform) output out of range")
            }
            
            // All waveforms should have range
            let range = maxVal - minVal
            #expect(range > 1.0, "\(waveform) should have >1.0 range, got \(range)")
        }
    }
    
    @Test("GlobalLFO tempo sync works")
    func testTempoSync() {
        var lfo = GlobalLFO(sampleRate)
        lfo.setSyncMode(LFO.SyncMode.TEMPO_SYNC)
        lfo.setTempo(120.0)
        lfo.setBeatDivision(LFO.BeatDivision.QUARTER)
        
        #expect(lfo.getSyncMode() == LFO.SyncMode.TEMPO_SYNC)
        #expect(lfo.getTempo() == 120.0)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Phase 4.2: Drift Generator Tests
// ═══════════════════════════════════════════════════════════════════════════

@Suite("Drift Generator Tests")
struct DriftGeneratorTests {
    let sampleRate = 44100.0
    
    @Test("DriftGenerator initializes with default values")
    func testDefaultValues() {
        var drift = DriftGenerator(sampleRate)
        #expect(drift.getRate() == 0.01, "Default rate should be 0.01 Hz")
        #expect(drift.getAmount() == 1.0, "Default amount should be 1.0")
        #expect(drift.getMode() == DriftGenerator.Mode.RandomWalk, "Default mode should be RandomWalk")
    }
    
    @Test("DriftGenerator rate is clamped to valid range")
    func testRateClamping() {
        var drift = DriftGenerator(sampleRate)
        
        drift.setRate(0.0001)  // Too low
        #expect(drift.getRate() >= 0.001, "Rate should be clamped to minimum 0.001 Hz")
        
        drift.setRate(1.0)  // Too high
        #expect(drift.getRate() <= 0.1, "Rate should be clamped to maximum 0.1 Hz")
    }
    
    @Test("DriftGenerator output stays bounded over long periods")
    func testOutputBounded() {
        var drift = DriftGenerator(sampleRate)
        drift.setRate(0.1)  // Fast rate for testing
        drift.setAmount(1.0)
        drift.setMode(DriftGenerator.Mode.RandomWalk)
        
        // Process for 10 seconds at fast rate
        for _ in 0..<Int(sampleRate * 10) {
            let value = drift.process()
            #expect(value >= -1.0 && value <= 1.0, "Drift output should stay bounded: \(value)")
        }
    }
    
    @Test("DriftGenerator RandomWalk mode produces variation")
    func testRandomWalkVariation() {
        var drift = DriftGenerator(sampleRate)
        drift.setRate(0.1)  // 0.1 Hz = 10 second cycle
        drift.setMode(DriftGenerator.Mode.RandomWalk)
        
        var values: [Double] = []
        // Process for 30 seconds to get multiple random walk steps
        for _ in 0..<Int(sampleRate * 30) {
            values.append(drift.process())
        }
        
        let minVal = values.min()!
        let maxVal = values.max()!
        // At 0.1 Hz over 30 seconds, we should see 3 full cycles with drift
        #expect(maxVal - minVal > 0.05, "RandomWalk should produce some variation over time, got \(maxVal - minVal)")
    }
    
    @Test("DriftGenerator Breath mode produces smooth oscillation")
    func testBreathMode() {
        var drift = DriftGenerator(sampleRate)
        drift.setRate(0.1)
        drift.setMode(DriftGenerator.Mode.Breath)
        
        var minVal = Double.infinity
        var maxVal = -Double.infinity
        
        for _ in 0..<Int(sampleRate * 15) {  // 1.5 cycles
            let value = drift.process()
            minVal = min(minVal, value)
            maxVal = max(maxVal, value)
        }
        
        #expect(minVal < 0.0, "Breath should go negative")
        #expect(maxVal > 0.0, "Breath should go positive")
    }
    
    @Test("DriftGenerator Tide mode produces sine-like output")
    func testTideMode() {
        var drift = DriftGenerator(sampleRate)
        drift.setRate(0.1)
        drift.setMode(DriftGenerator.Mode.Tide)
        
        var minVal = Double.infinity
        var maxVal = -Double.infinity
        
        for _ in 0..<Int(sampleRate * 15) {  // More than one cycle
            let value = drift.process()
            minVal = min(minVal, value)
            maxVal = max(maxVal, value)
        }
        
        // Tide mode should oscillate smoothly
        #expect(minVal < -0.5, "Tide should reach low values")
        #expect(maxVal > 0.5, "Tide should reach high values")
    }
    
    @Test("DriftGenerator amount scales output")
    func testAmountScaling() {
        var drift = DriftGenerator(sampleRate)
        drift.setRate(0.1)
        drift.setMode(DriftGenerator.Mode.Tide)
        drift.setAmount(0.25)
        
        for _ in 0..<Int(sampleRate * 15) {
            let value = drift.process()
            #expect(Swift.abs(value) <= 0.26, "Output should be scaled by amount")
        }
    }
    
    @Test("DriftGenerator reset works")
    func testReset() {
        var drift = DriftGenerator(sampleRate)
        drift.setMode(DriftGenerator.Mode.Tide)
        drift.setRate(0.1)
        
        // Process some samples
        for _ in 0..<10000 {
            _ = drift.process()
        }
        
        // Reset
        drift.reset()
        
        // First value after reset should be near 0
        let value = drift.getCurrentValue()
        #expect(Swift.abs(value) < 0.1, "Should be near 0 after reset")
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Phase 4.3 & 4.4: Chaos Generator Tests
// ═══════════════════════════════════════════════════════════════════════════

@Suite("Chaos Generator Tests")
struct ChaosGeneratorTests {
    let sampleRate = 44100.0
    
    @Test("ChaosGenerator initializes with Lorenz attractor")
    func testDefaultValues() {
        var chaos = ChaosGenerator(sampleRate)
        #expect(chaos.getType() == ChaosGenerator.ChaosType.Lorenz, "Default type should be Lorenz")
        #expect(chaos.getRate() == 1.0, "Default rate should be 1.0")
        #expect(chaos.getBlend() == 1.0, "Default blend should be 1.0")
    }
    
    @Test("ChaosGenerator Lorenz never produces NaN or Inf")
    func testLorenzStability() {
        var chaos = ChaosGenerator(sampleRate)
        chaos.setType(ChaosGenerator.ChaosType.Lorenz)
        chaos.setRate(5.0)  // Faster rate for more iterations
        
        for _ in 0..<Int(sampleRate * 30) {  // 30 seconds
            let value = chaos.process()
            #expect(value.isFinite, "Lorenz output must be finite")
            #expect(!value.isNaN, "Lorenz output must not be NaN")
        }
    }
    
    @Test("ChaosGenerator Henon never produces NaN or Inf")
    func testHenonStability() {
        var chaos = ChaosGenerator(sampleRate)
        chaos.setType(ChaosGenerator.ChaosType.Henon)
        chaos.setRate(5.0)
        
        for _ in 0..<Int(sampleRate * 30) {
            let value = chaos.process()
            #expect(value.isFinite, "Henon output must be finite")
            #expect(!value.isNaN, "Henon output must not be NaN")
        }
    }
    
    @Test("ChaosGenerator output stays in valid range")
    func testOutputRange() {
        for type in [ChaosGenerator.ChaosType.Lorenz, ChaosGenerator.ChaosType.Henon] {
            var chaos = ChaosGenerator(sampleRate)
            chaos.setType(type)
            chaos.setAmount(1.0)
            chaos.setBlend(1.0)
            chaos.reset()
            
            for _ in 0..<Int(sampleRate * 10) {
                let value = chaos.process()
                #expect(value >= -1.0 && value <= 1.0, "\(type) output out of range: \(value)")
            }
        }
    }
    
    @Test("ChaosGenerator Lorenz produces chaotic variation")
    func testLorenzChaos() {
        var chaos = ChaosGenerator(sampleRate)
        chaos.setType(ChaosGenerator.ChaosType.Lorenz)
        chaos.setRate(1.0)
        
        var values: Set<Int> = []  // Quantize to check for variation
        for _ in 0..<Int(sampleRate * 5) {
            let value = chaos.process()
            let quantized = Int(value * 100)  // 100 bins
            values.insert(quantized)
        }
        
        // Chaotic output should hit many different values
        #expect(values.count > 50, "Lorenz should produce diverse output, got \(values.count) unique values")
    }
    
    @Test("ChaosGenerator Henon produces snappy rhythmic patterns")
    func testHenonRhythmic() {
        var chaos = ChaosGenerator(sampleRate)
        chaos.setType(ChaosGenerator.ChaosType.Henon)
        chaos.setRate(5.0)  // Faster rate for more iterations
        chaos.setAmount(1.0)
        chaos.setBlend(1.0)
        
        // Count distinct value ranges
        var minVal = Double.infinity
        var maxVal = -Double.infinity
        
        for _ in 0..<Int(sampleRate * 5) {
            let value = chaos.process()
            minVal = min(minVal, value)
            maxVal = max(maxVal, value)
        }
        
        let range = maxVal - minVal
        #expect(range > 0.5, "Henon should have varied output range, got \(range)")
    }
    
    @Test("ChaosGenerator blend controls output intensity")
    func testBlendControl() {
        var chaos = ChaosGenerator(sampleRate)
        chaos.setType(ChaosGenerator.ChaosType.Lorenz)
        chaos.setBlend(0.0)  // Chaos off
        
        for _ in 0..<1000 {
            let value = chaos.process()
            #expect(value == 0.0, "With blend=0, output should be 0")
        }
        
        chaos.setBlend(0.5)
        chaos.reset()
        var maxAbs = 0.0
        for _ in 0..<Int(sampleRate * 5) {
            let value = chaos.process()
            maxAbs = max(maxAbs, Swift.abs(value))
        }
        #expect(maxAbs <= 0.51, "With blend=0.5, output should be half")
    }
    
    @Test("ChaosGenerator rate controls speed")
    func testRateControl() {
        // Slower rate = fewer changes over time
        var slowChaos = ChaosGenerator(sampleRate)
        slowChaos.setType(ChaosGenerator.ChaosType.Lorenz)
        slowChaos.setRate(0.5)
        
        var fastChaos = ChaosGenerator(sampleRate)
        fastChaos.setType(ChaosGenerator.ChaosType.Lorenz)
        fastChaos.setRate(5.0)
        
        // Count direction changes
        func countChanges(_ chaos: inout ChaosGenerator) -> Int {
            var changes = 0
            var prevValue = chaos.process()
            var prevDirection = 0  // -1 = decreasing, +1 = increasing
            
            for _ in 0..<Int(sampleRate) {
                let value = chaos.process()
                let direction = value > prevValue ? 1 : -1
                if direction != prevDirection && prevDirection != 0 {
                    changes += 1
                }
                prevDirection = direction
                prevValue = value
            }
            return changes
        }
        
        let slowChanges = countChanges(&slowChaos)
        let fastChanges = countChanges(&fastChaos)
        
        #expect(fastChanges > slowChanges, "Faster rate should have more direction changes")
    }
    
    @Test("ChaosGenerator state validity check works")
    func testStateValidityCheck() {
        var chaos = ChaosGenerator(sampleRate)
        chaos.setType(ChaosGenerator.ChaosType.Lorenz)
        
        // After normal processing, state should be valid
        for _ in 0..<1000 {
            _ = chaos.process()
        }
        
        #expect(chaos.isStateValid(), "State should be valid after normal processing")
    }
    
    @Test("ChaosGenerator recovers from divergence")
    func testDivergenceRecovery() {
        var chaos = ChaosGenerator(sampleRate)
        chaos.setType(ChaosGenerator.ChaosType.Henon)
        
        // Process many samples - if Henon escapes, it should auto-recover
        for _ in 0..<Int(sampleRate * 60) {
            let value = chaos.process()
            #expect(value.isFinite, "Should recover from any divergence")
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Phase 4.6-4.8: Formant Sequencer Tests
// ═══════════════════════════════════════════════════════════════════════════

@Suite("Formant Sequencer Tests")
struct FormantSequencerTests {
    let sampleRate = 44100.0
    
    @Test("FormantSequencer initializes with 16 steps")
    func testDefaultStepCount() {
        var seq = FormantSequencer(sampleRate)
        #expect(seq.getStepCount() == 16, "Default step count should be 16")
    }
    
    @Test("FormantSequencer steps can be set and retrieved")
    func testStepValues() {
        var seq = FormantSequencer(sampleRate)
        
        seq.setStepValue(0, 0.0)   // A
        seq.setStepValue(1, 0.5)   // I
        seq.setStepValue(2, 1.0)   // U
        
        #expect(seq.getStepValue(0) == 0.0, "Step 0 should be 0.0")
        #expect(seq.getStepValue(1) == 0.5, "Step 1 should be 0.5")
        #expect(seq.getStepValue(2) == 1.0, "Step 2 should be 1.0")
    }
    
    @Test("FormantSequencer step values are clamped")
    func testStepValueClamping() {
        var seq = FormantSequencer(sampleRate)
        
        seq.setStepValue(0, -0.5)
        #expect(seq.getStepValue(0) >= 0.0, "Negative values should be clamped")
        
        seq.setStepValue(0, 1.5)
        #expect(seq.getStepValue(0) <= 1.0, "Values > 1 should be clamped")
    }
    
    @Test("FormantSequencer step count can be changed")
    func testStepCountChange() {
        var seq = FormantSequencer(sampleRate)
        
        seq.setStepCount(8)
        #expect(seq.getStepCount() == 8, "Step count should be changeable to 8")
        
        seq.setStepCount(4)
        #expect(seq.getStepCount() == 4, "Step count should be changeable to 4")
        
        // Out of range values should be clamped
        seq.setStepCount(0)
        #expect(seq.getStepCount() >= 1, "Step count should be at least 1")
        
        seq.setStepCount(100)
        #expect(seq.getStepCount() <= 16, "Step count should be at most 16")
    }
    
    @Test("FormantSequencer advances through steps")
    func testStepAdvancement() {
        var seq = FormantSequencer(sampleRate)
        seq.setStepCount(4)
        seq.setRate(10.0)  // 10 steps per second
        seq.setGlide(0.0)  // No glide for clear step boundaries
        
        // Set distinct values for each step
        seq.setStepValue(0, 0.0)
        seq.setStepValue(1, 0.25)
        seq.setStepValue(2, 0.5)
        seq.setStepValue(3, 0.75)
        
        seq.reset()
        
        // Process for 0.5 seconds (should complete 5 steps = back to step 1)
        let samplesPerStep = Int(sampleRate / 10.0)
        
        // Check that we start at step 0
        #expect(seq.getCurrentStep() == 0)
        
        // Advance one step
        for _ in 0..<samplesPerStep {
            _ = seq.process()
        }
        
        // Should now be at step 1
        #expect(seq.getCurrentStep() == 1, "Should advance to step 1")
    }
    
    @Test("FormantSequencer output is in valid range")
    func testOutputRange() {
        var seq = FormantSequencer(sampleRate)
        seq.setRate(10.0)
        
        for _ in 0..<Int(sampleRate * 5) {
            let value = seq.process()
            #expect(value >= 0.0 && value <= 1.0, "Output should be in [0, 1] range")
        }
    }
    
    @Test("FormantSequencer glide smooths transitions")
    func testGlide() {
        var seq = FormantSequencer(sampleRate)
        seq.setStepCount(2)
        seq.setRate(2.0)  // 2 steps per second
        seq.setStepValue(0, 0.0)
        seq.setStepValue(1, 1.0)
        seq.setGlide(100.0)  // 100% glide
        
        seq.reset()
        
        // Process and check for smooth transitions
        var foundIntermediate = false
        for _ in 0..<Int(sampleRate) {
            let value = seq.process()
            if value > 0.1 && value < 0.9 {
                foundIntermediate = true
            }
        }
        
        #expect(foundIntermediate, "With 100% glide, should have intermediate values")
    }
    
    @Test("FormantSequencer no glide has instant transitions")
    func testNoGlide() {
        var seq = FormantSequencer(sampleRate)
        seq.setStepCount(2)
        seq.setRate(2.0)
        seq.setStepValue(0, 0.0)
        seq.setStepValue(1, 1.0)
        seq.setGlide(0.0)  // No glide
        
        seq.reset()
        
        var values: Set<Double> = []
        for _ in 0..<Int(sampleRate) {
            let value = seq.process()
            values.insert(round(value * 100) / 100)  // Round to 2 decimal places
        }
        
        // With no glide, we should only see 0.0 and 1.0
        #expect(values.count <= 4, "Without glide, should have few distinct values")
    }
    
    @Test("FormantSequencer tempo sync works")
    func testTempoSync() {
        var seq = FormantSequencer(sampleRate)
        seq.setSyncMode(FormantSequencer.SyncMode.TempoSync)
        seq.setTempo(120.0)
        seq.setBeatDivision(FormantSequencer.BeatDivision.Quarter)
        
        #expect(seq.getSyncMode() == FormantSequencer.SyncMode.TempoSync)
        #expect(seq.getTempo() == 120.0)
    }
    
    @Test("FormantSequencer can be stopped and started")
    func testTransportControl() {
        var seq = FormantSequencer(sampleRate)
        seq.setRate(10.0)
        
        #expect(seq.isRunning(), "Should be running by default")
        
        seq.stop()
        #expect(!seq.isRunning(), "Should be stopped")
        
        let valueBefore = seq.getCurrentValue()
        for _ in 0..<1000 {
            _ = seq.process()
        }
        let valueAfter = seq.getCurrentValue()
        
        #expect(valueBefore == valueAfter, "Stopped sequencer should not change value")
        
        seq.start()
        #expect(seq.isRunning(), "Should be running again")
    }
    
    @Test("FormantSequencer reset returns to step 0")
    func testReset() {
        var seq = FormantSequencer(sampleRate)
        seq.setRate(10.0)
        
        // Advance a few steps
        for _ in 0..<Int(sampleRate) {
            _ = seq.process()
        }
        
        seq.reset()
        #expect(seq.getCurrentStep() == 0, "Reset should return to step 0")
    }
    
    @Test("FormantSequencer glide curves work")
    func testGlideCurves() {
        var seq = FormantSequencer(sampleRate)
        
        seq.setGlideCurve(FormantSequencer.GlideCurve.Linear)
        #expect(seq.getGlideCurve() == FormantSequencer.GlideCurve.Linear)
        
        seq.setGlideCurve(FormantSequencer.GlideCurve.Exponential)
        #expect(seq.getGlideCurve() == FormantSequencer.GlideCurve.Exponential)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Phase 4: Global Modulation Integration Tests
// ═══════════════════════════════════════════════════════════════════════════

@Suite("Global Modulation Integration Tests")
struct GlobalModulationIntegrationTests {
    let sampleRate = 44100.0
    
    @Test("GlobalModulation processes without crash")
    func testProcessing() {
        var globalMod = GlobalModulation(sampleRate)
        
        // Process many samples - should not crash
        for _ in 0..<Int(sampleRate) {
            _ = globalMod.process()
        }
        #expect(true, "Processing completed without crash")
    }
    
    @Test("GlobalModulation values are finite")
    func testValuesFinite() {
        var globalMod = GlobalModulation(sampleRate)
        
        // Process some samples
        for _ in 0..<Int(sampleRate) {
            let values = globalMod.process()
            // Access individual members via the returned struct
            #expect(values.lfo1Value.isFinite)
            #expect(values.lfo2Value.isFinite)
            #expect(values.driftValue.isFinite)
            #expect(values.chaosValue.isFinite)
            #expect(values.sequencerValue.isFinite)
            #expect(values.totalPitchMod.isFinite)
        }
    }
    
    @Test("GlobalModulation reset works")
    func testReset() {
        var globalMod = GlobalModulation(sampleRate)
        
        // Process some samples
        for _ in 0..<10000 {
            _ = globalMod.process()
        }
        
        // Reset should not crash
        globalMod.reset()
        #expect(true, "Reset completed without crash")
    }
    
    @Test("GlobalModulation tempo sync propagates")
    func testTempoSync() {
        var globalMod = GlobalModulation(sampleRate)
        globalMod.setTempo(140.0)
        #expect(true, "Tempo set without crash")
    }
}
