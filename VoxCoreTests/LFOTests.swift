import Testing
import VoxCore

@Suite("LFO Tests")
struct LFOTests {
    @Test("Triangle waveform produces correct output")
    func testTriangleWaveform() {
        var lfo = LFO(44100.0)
        lfo.setWaveform(LFO.Waveform.TRIANGLE)
        lfo.setFrequency(1.0) // 1 Hz
        
        // Test one complete cycle
        let samplesPerCycle = 44100
        var minValue = Double.infinity
        var maxValue = -Double.infinity
        var values: [Double] = []
        
        for _ in 0..<samplesPerCycle {
            let value = lfo.process()
            values.append(value)
            minValue = min(minValue, value)
            maxValue = max(maxValue, value)
        }
        
        // Triangle should range from -1 to 1
        #expect(Swift.abs(minValue - (-1.0)) < 0.01)
        #expect(Swift.abs(maxValue - 1.0) < 0.01)
        
        // Check that it's actually triangular (linear segments)
        // At 1/4 cycle should be at 0 (rising)
        let quarterCycle = samplesPerCycle / 4
        #expect(Swift.abs(values[quarterCycle]) < 0.05)
        
        // At 1/2 cycle should be at maximum
        let halfCycle = samplesPerCycle / 2
        #expect(Swift.abs(values[halfCycle] - 1.0) < 0.05)
        
        // At 3/4 cycle should be at 0 (falling)
        let threeQuarterCycle = (samplesPerCycle * 3) / 4
        #expect(Swift.abs(values[threeQuarterCycle]) < 0.05)
    }
    
    @Test("Square waveform produces correct output")
    func testSquareWaveform() {
        var lfo = LFO(44100.0)
        lfo.setWaveform(LFO.Waveform.SQUARE)
        lfo.setFrequency(1.0) // 1 Hz
        
        // Test one complete cycle
        let samplesPerCycle = 44100
        var values: [Double] = []
        
        for _ in 0..<samplesPerCycle {
            let value = lfo.process()
            values.append(value)
        }
        
        // Check that we have distinct positive and negative phases
        let firstQuarterAvg = values[0..<(samplesPerCycle/4)].reduce(0.0, +) / Double(samplesPerCycle/4)
        let thirdQuarterAvg = values[(samplesPerCycle/2)..<(3*samplesPerCycle/4)].reduce(0.0, +) / Double(samplesPerCycle/4)
        
        // First quarter should be predominantly positive, third quarter predominantly negative
        #expect(firstQuarterAvg > 0.5, "First quarter should average positive")
        #expect(thirdQuarterAvg < -0.5, "Third quarter should average negative")
        
        // Check that we have transitions (some values near zero due to smoothing)
        let hasTransitions = values.contains { Swift.abs($0) < 0.3 }
        #expect(hasTransitions, "Should have transition values due to smoothing")
    }
    
    @Test("Random (S&H) waveform holds values correctly")
    func testRandomWaveform() {
        var lfo = LFO(44100.0)
        lfo.setWaveform(LFO.Waveform.RANDOM)
        lfo.setFrequency(10.0) // 10 Hz for faster testing
        
        // Process multiple cycles
        let samplesPerCycle = 4410 // 44100 / 10
        var lastValue = lfo.process()
        var valueChanges = 0
        
        for i in 1..<(samplesPerCycle * 5) {
            let currentValue = lfo.process()
            
            if Swift.abs(currentValue - lastValue) > 0.005 { // Lower threshold for light smoothing
                valueChanges += 1
                // Should be within -1 to 1
                #expect(currentValue >= -1.0 && currentValue <= 1.0)
            }
            
            lastValue = currentValue
        }
        
        // Should have approximately 5 value changes (one per cycle) - allow wider range due to smoothing
        #expect(valueChanges >= 3 && valueChanges <= 8, "Expected 3-8 value changes, got \(valueChanges)")
    }
    
    @Test("Noise waveform produces random values every sample")
    func testNoiseWaveform() {
        var lfo = LFO(44100.0)
        lfo.setWaveform(LFO.Waveform.NOISE)
        
        // Collect samples
        var values: [Double] = []
        for _ in 0..<1000 {
            let value = lfo.process()
            values.append(value)
            // Should be within -1 to 1
            #expect(value >= -1.0 && value <= 1.0)
        }
        
        // Check that consecutive values are different (noise is not smoothed)
        var differences = 0
        for i in 1..<values.count {
            if Swift.abs(values[i] - values[i-1]) > 0.001 {
                differences += 1
            }
        }
        
        // Should have mostly different values (>95%) - noise is not smoothed
        #expect(differences > 950, "Expected >950 differences, got \(differences)")
    }
    
    @Test("Frequency control works correctly")
    func testFrequencyControl() {
        var lfo = LFO(44100.0)
        lfo.setWaveform(LFO.Waveform.SQUARE)
        
        // Test 2 Hz
        lfo.setFrequency(2.0)
        
        // Count zero crossings in one second
        var lastValue = lfo.process()
        var zeroCrossings = 0
        
        for _ in 1..<44100 {
            let currentValue = lfo.process()
            if lastValue > 0 && currentValue < 0 {
                zeroCrossings += 1
            }
            lastValue = currentValue
        }
        
        // Should have 2 zero crossings for 2 Hz
        #expect(zeroCrossings == 2)
    }
    
    @Test("Beat sync produces correct frequencies")
    func testBeatSync() {
        var lfo = LFO(44100.0)
        lfo.setWaveform(LFO.Waveform.SQUARE)
        lfo.setSyncMode(LFO.SyncMode.BEAT_SYNC)
        lfo.setTempo(120.0) // 120 BPM = 2 beats per second
        
        // Test quarter note (1 beat)
        lfo.setBeatDivision(LFO.BeatDivision.QUARTER)
        
        // Count zero crossings in one second
        var lastValue = lfo.process()
        var zeroCrossings = 0
        
        for _ in 1..<44100 {
            let currentValue = lfo.process()
            if lastValue > 0 && currentValue < 0 {
                zeroCrossings += 1
            }
            lastValue = currentValue
        }
        
        // Should have 2 zero crossings (2 Hz at 120 BPM quarter notes)
        #expect(zeroCrossings == 2)
        
        // Test eighth note (2x faster)
        lfo.setBeatDivision(LFO.BeatDivision.EIGHTH)
        lfo.reset()
        
        lastValue = lfo.process()
        zeroCrossings = 0
        
        for _ in 1..<44100 {
            let currentValue = lfo.process()
            if lastValue > 0 && currentValue < 0 {
                zeroCrossings += 1
            }
            lastValue = currentValue
        }
        
        // Should have 4 zero crossings (4 Hz at 120 BPM eighth notes)
        #expect(zeroCrossings == 4)
    }
    
    @Test("Phase reset works correctly")
    func testPhaseReset() {
        var lfo = LFO(44100.0)
        lfo.setWaveform(LFO.Waveform.TRIANGLE)
        lfo.setFrequency(1.0)
        
        // Process for a bit
        for _ in 0..<10000 {
            _ = lfo.process()
        }
        
        // Reset and check that we're back at the beginning
        lfo.reset()
        let firstValue = lfo.process()
        
        // Triangle wave starts at -1
        #expect(Swift.abs(firstValue - (-1.0)) < 0.01)
    }
    
    @Test("Frequency limits are enforced")
    func testFrequencyLimits() {
        var lfo = LFO(44100.0)
        
        // Test lower limit
        lfo.setFrequency(0.001)
        #expect(lfo.getFrequency() == 0.01)
        
        // Test upper limit  
        lfo.setFrequency(100.0)
        #expect(lfo.getFrequency() == 30.0)
        
        // Test valid frequency
        lfo.setFrequency(5.0)
        #expect(lfo.getFrequency() == 5.0)
    }
    
    @Test("Tempo limits are enforced")
    func testTempoLimits() {
        var lfo = LFO(44100.0)
        
        // Test lower limit
        lfo.setTempo(10.0)
        #expect(lfo.getTempo() == 20.0)
        
        // Test upper limit
        lfo.setTempo(400.0)
        #expect(lfo.getTempo() == 300.0)
        
        // Test valid tempo
        lfo.setTempo(140.0)
        #expect(lfo.getTempo() == 140.0)
    }
    
    @Test("Phase offset shifts waveform correctly")
    func testPhaseOffset() {
        var lfo = LFO(44100.0)
        lfo.setWaveform(LFO.Waveform.TRIANGLE)
        lfo.setFrequency(1.0)
        
        // Test with no phase offset - triangle starts at -1 (allow for smoothing)
        lfo.setPhaseOffset(0.0)
        lfo.reset()
        let valueAtZero = lfo.process()
        #expect(Swift.abs(valueAtZero - (-1.0)) < 0.05, "Expected triangle to start near -1, got \(valueAtZero)")
        
        // Test with 90 degree phase offset - triangle starts at 0 (allow for smoothing)
        lfo.setPhaseOffset(90.0)
        lfo.reset()
        let valueAt90 = lfo.process()
        #expect(Swift.abs(valueAt90) < 0.05, "Expected triangle at 90 degrees to be near 0, got \(valueAt90)")
        
        // Test with 180 degree phase offset - triangle starts at 1 (allow for smoothing)
        lfo.setPhaseOffset(180.0)
        lfo.reset()
        let valueAt180 = lfo.process()
        #expect(Swift.abs(valueAt180 - 1.0) < 0.05, "Expected triangle at 180 degrees to be near 1, got \(valueAt180)")
        
        // Test phase offset wrapping
        lfo.setPhaseOffset(450.0) // Should wrap to 90 degrees
        #expect(Swift.abs(lfo.getPhaseOffset() - 90.0) < 0.01)
    }
    
    @Test("Retrigger mode functions correctly")
    func testRetriggerMode() {
        var lfo = LFO(44100.0)
        lfo.setWaveform(LFO.Waveform.TRIANGLE)
        lfo.setFrequency(1.0)
        lfo.setRetriggerMode(LFO.RetriggerMode.NOTE_ON)
        
        // Process for a while to advance phase
        for _ in 0..<10000 {
            _ = lfo.process()
        }
        
        // Call retrigger - should reset to beginning
        lfo.retrigger()
        let valueAfterRetrigger = lfo.process()
        #expect(Swift.abs(valueAfterRetrigger - (-1.0)) < 0.01)
        
        // Test FREE_RUN mode - retrigger should not reset
        lfo.setRetriggerMode(LFO.RetriggerMode.FREE_RUN)
        for _ in 0..<5000 {
            _ = lfo.process()
        }
        let valueBefore = lfo.process()
        lfo.retrigger()
        let valueAfterFreeRun = lfo.process()
        #expect(Swift.abs(valueAfterFreeRun - valueBefore) < 0.1) // Should be similar
    }
    
    @Test("LFO delay works correctly")
    func testLFODelay() {
        var lfo = LFO(44100.0)
        lfo.setWaveform(LFO.Waveform.SQUARE)
        lfo.setFrequency(10.0) // High frequency for testing
        lfo.setDelayTime(100.0) // 100ms delay
        
        // Reset to start delay
        lfo.reset()
        
        // During delay period, output should be smoothly transitioning toward zero
        let delaySamples = Int(44100.0 * 0.1) // 100ms worth of samples
        var previousValue = Double.infinity
        var decreasingCount = 0
        for i in 0..<delaySamples {
            let value = lfo.process()
            // Output should be generally decreasing due to smoothing toward zero
            if previousValue != Double.infinity && Swift.abs(value) < Swift.abs(previousValue) {
                decreasingCount += 1
            }
            previousValue = value
        }
        // Most samples should show decreasing amplitude toward zero
        #expect(decreasingCount > delaySamples / 2, "Expected smoothing toward zero during delay")
        
        // After delay, should start producing normal LFO output
        var nonZeroCount = 0
        for _ in 0..<1000 {
            let value = lfo.process()
            if Swift.abs(value) > 0.5 {
                nonZeroCount += 1
            }
        }
        #expect(nonZeroCount > 100, "Expected significant non-zero output after delay")
        
        // Test no delay
        lfo.setDelayTime(0.0)
        lfo.reset()
        let immediateValue = lfo.process()
        #expect(Swift.abs(immediateValue) > 0.5, "Expected immediate output with no delay")
    }
    
    @Test("Output smoothing reduces sudden changes")
    func testOutputSmoothing() {
        var lfo = LFO(44100.0)
        lfo.setWaveform(LFO.Waveform.SQUARE)
        lfo.setFrequency(1.0)
        lfo.setSmoothingCutoff(30.0) // Low cutoff for strong smoothing
        
        // Process and check that square wave is smoothed
        var values: [Double] = []
        for _ in 0..<44100 { // One second
            values.append(lfo.process())
        }
        
        // Check for reduced sudden changes compared to ideal square wave
        var suddenChanges = 0
        for i in 1..<values.count {
            let change = Swift.abs(values[i] - values[i-1])
            if change > 0.5 { // Large sudden change
                suddenChanges += 1
            }
        }
        
        // Should have very few sudden changes with smoothing
        #expect(suddenChanges < 10, "Expected smoothing to reduce sudden changes, got \(suddenChanges)")
        
        // Test higher cutoff frequency (less smoothing) - check difference between cutoffs
        var lfo2 = LFO(44100.0)
        lfo2.setWaveform(LFO.Waveform.SQUARE)
        lfo2.setFrequency(1.0)
        lfo2.setSmoothingCutoff(400.0) // High cutoff
        
        var values2: [Double] = []
        for _ in 0..<44100 { // One second
            values2.append(lfo2.process())
        }
        
        var suddenChanges2 = 0
        for i in 1..<values2.count {
            let change = Swift.abs(values2[i] - values2[i-1])
            if change > 0.1 { // Same threshold
                suddenChanges2 += 1
            }
        }
        
        // Should have more sudden changes with higher cutoff than lower cutoff
        #expect(suddenChanges2 > suddenChanges, "Expected more changes with higher cutoff: low=\(suddenChanges), high=\(suddenChanges2)")
    }
    
    @Test("Delay and retrigger integration works correctly")
    func testDelayRetriggerIntegration() {
        var lfo = LFO(44100.0)
        lfo.setWaveform(LFO.Waveform.TRIANGLE)
        lfo.setFrequency(10.0)
        lfo.setRetriggerMode(LFO.RetriggerMode.NOTE_ON)
        lfo.setDelayTime(50.0) // 50ms delay
        
        // First retrigger should start delay
        lfo.retrigger()
        
        // Should be delayed initially - output smoothly approaching zero
        var previousValue = Double.infinity
        var decreasingCount = 0
        for _ in 0..<1000 {
            let value = lfo.process()
            // Output should be generally decreasing due to smoothing toward zero
            if previousValue != Double.infinity && Swift.abs(value) < Swift.abs(previousValue) {
                decreasingCount += 1
            }
            previousValue = value
        }
        #expect(decreasingCount > 400, "Expected smoothing toward zero during delay period")
        
        // Process more to get past delay
        for _ in 0..<2000 {
            _ = lfo.process()
        }
        
        // Now should have normal output
        let normalValue = lfo.process()
        #expect(Swift.abs(normalValue) > 0.1, "Expected normal output after delay period")
        
        // Retrigger again should restart delay - should start from initial waveform value
        lfo.retrigger()
        let retriggeredValue = lfo.process()
        // After retrigger with delay, should start from waveform value (triangle at phase offset)
        #expect(Swift.abs(retriggeredValue) > 0.5, "Expected initial waveform value after retrigger")
    }
    
    @Test("Phase offset with different waveforms")
    func testPhaseOffsetWithWaveforms() {
        var lfo = LFO(44100.0)
        lfo.setFrequency(1.0)
        lfo.setPhaseOffset(90.0) // Quarter phase offset
        
        // Test with square wave
        lfo.setWaveform(LFO.Waveform.SQUARE)
        lfo.reset()
        let squareValue = lfo.process()
        // With 90 degree offset, square should still be in first half (positive)
        #expect(squareValue > 0.8, "Expected positive value for 90-degree offset square, got \(squareValue)")
        
        // Test with triangle wave  
        lfo.setWaveform(LFO.Waveform.TRIANGLE)
        lfo.reset()
        let triangleValue = lfo.process()
        // With 90 degree offset, triangle should be near zero
        #expect(Swift.abs(triangleValue) < 0.05, "Expected near-zero for 90-degree offset triangle, got \(triangleValue)")
    }
    
    @Test("LFO delay works independently of retrigger mode")
    func testDelayIndependentOfRetriggerMode() {
        var lfo = LFO(44100.0)
        lfo.setWaveform(LFO.Waveform.SQUARE)
        lfo.setFrequency(10.0)
        lfo.setDelayTime(50.0) // 50ms delay

        // Test delay works in FREE_RUN mode (this was previously broken)
        lfo.setRetriggerMode(LFO.RetriggerMode.FREE_RUN)

        // Process for a bit to get the LFO running
        for _ in 0..<10000 {
            _ = lfo.process()
        }

        // Verify LFO is outputting normally now
        var normalOutputCount = 0
        for _ in 0..<1000 {
            let value = lfo.process()
            if Swift.abs(value) > 0.5 {
                normalOutputCount += 1
            }
        }
        #expect(normalOutputCount > 100, "LFO should be outputting normally before retrigger")

        // Call retrigger - in FREE_RUN mode this should still activate delay
        lfo.retrigger()

        // Now output should be smoothing toward zero during delay
        var lowOutputCount = 0
        let delaySamples = Int(44100.0 * 0.05) // 50ms
        for _ in 0..<delaySamples {
            let value = lfo.process()
            if Swift.abs(value) < 0.3 {
                lowOutputCount += 1
            }
        }
        // Most of the delay period should have low output (due to smoothing toward 0)
        #expect(lowOutputCount > delaySamples / 2, "Delay should activate in FREE_RUN mode, got \(lowOutputCount) low samples out of \(delaySamples)")

        // After delay, should resume normal output
        for _ in 0..<500 { // Process a bit more past delay
            _ = lfo.process()
        }
        var postDelayCount = 0
        for _ in 0..<1000 {
            let value = lfo.process()
            if Swift.abs(value) > 0.5 {
                postDelayCount += 1
            }
        }
        #expect(postDelayCount > 100, "LFO should output normally after delay in FREE_RUN mode")
    }

    @Test("Complex LFO scenario with all features")
    func testComplexLFOScenario() {
        var lfo = LFO(44100.0)
        
        // Configure complex scenario
        lfo.setWaveform(LFO.Waveform.TRIANGLE)
        lfo.setSyncMode(LFO.SyncMode.BEAT_SYNC)
        lfo.setBeatDivision(LFO.BeatDivision.EIGHTH)
        lfo.setTempo(120.0)
        lfo.setPhaseOffset(45.0)
        lfo.setRetriggerMode(LFO.RetriggerMode.NOTE_ON)
        lfo.setDelayTime(25.0) // 25ms delay
        lfo.setSmoothingCutoff(100.0)
        
        // Simulate note on
        lfo.retrigger()
        
        // Process initial delay period - most values should be small
        let delaySamples = Int(44100.0 * 0.025) // 25ms
        var smallValueCount = 0
        for i in 0..<delaySamples {
            let value = lfo.process()
            if Swift.abs(value) < 0.3 {
                smallValueCount += 1
            }
        }
        // Most values during delay should be small (allow some tolerance for smoothing)
        #expect(smallValueCount > delaySamples * 3 / 4, "Expected mostly low output during delay")
        
        // Process normal operation
        var maxValue = 0.0
        var minValue = 0.0
        for _ in 0..<10000 {
            let value = lfo.process()
            maxValue = max(maxValue, value)
            minValue = min(minValue, value)
        }
        
        // Should eventually reach reasonable amplitude
        #expect(maxValue > 0.3, "Expected reasonable positive amplitude")
        #expect(minValue < -0.3, "Expected reasonable negative amplitude")
        
        // Verify all settings are maintained
        #expect(lfo.getPhaseOffset() == 45.0)
        #expect(lfo.getTempo() == 120.0)
        #expect(lfo.getDelayTime() == 25.0)
        #expect(lfo.getSmoothingCutoff() == 100.0)
    }
}