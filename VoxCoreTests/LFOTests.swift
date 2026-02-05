import Testing
import VoxCore

@Suite("LFO Tests")
struct LFOTests {
    let sampleRate = 44100.0
    
    @Test("Triangle waveform produces correct output")
    func testTriangleWaveform() {
        var lfo = LFO(sampleRate)
        lfo.setWaveform(LFO.Waveform.TRIANGLE)
        lfo.setFrequency(1.0) // 1 Hz
        lfo.setSmoothingCutoff(20000.0) // Disable smoothing for accurate test
        
        // Test one complete cycle
        let samplesPerCycle = Int(sampleRate)
        var minValue = Double.infinity
        var maxValue = -Double.infinity
        var values: [Double] = []
        
        for _ in 0..<samplesPerCycle {
            let value = lfo.process()
            values.append(value)
            minValue = min(minValue, value)
            maxValue = max(maxValue, value)
        }
        
        // Triangle should range from -1 to 1 (allow small tolerance)
        #expect(minValue < -0.95, "Triangle min should be near -1, got \(minValue)")
        #expect(maxValue > 0.95, "Triangle max should be near 1, got \(maxValue)")
    }
    
    @Test("Square waveform produces correct output")
    func testSquareWaveform() {
        var lfo = LFO(sampleRate)
        lfo.setWaveform(LFO.Waveform.SQUARE)
        lfo.setFrequency(1.0) // 1 Hz
        
        // Test one complete cycle
        let samplesPerCycle = Int(sampleRate)
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
    }
    
    @Test("Sine waveform produces correct output")
    func testSineWaveform() {
        var lfo = LFO(sampleRate)
        lfo.setWaveform(LFO.Waveform.SINE)
        lfo.setFrequency(1.0) // 1 Hz
        lfo.setSmoothingCutoff(20000.0) // Disable smoothing
        
        let samplesPerCycle = Int(sampleRate)
        var minValue = Double.infinity
        var maxValue = -Double.infinity
        
        for _ in 0..<samplesPerCycle {
            let value = lfo.process()
            minValue = min(minValue, value)
            maxValue = max(maxValue, value)
        }
        
        // Sine should range from -1 to 1
        #expect(minValue < -0.99, "Sine min should be near -1")
        #expect(maxValue > 0.99, "Sine max should be near 1")
    }
    
    @Test("Frequency control works correctly")
    func testFrequencyControl() {
        var lfo = LFO(sampleRate)
        lfo.setWaveform(LFO.Waveform.SAW)
        
        // Test different frequencies
        lfo.setFrequency(5.0)
        #expect(lfo.getFrequency() == 5.0)
        
        lfo.setFrequency(20.0)
        #expect(lfo.getFrequency() == 20.0)
    }
    
    @Test("Frequency limits are enforced")
    func testFrequencyLimits() {
        var lfo = LFO(sampleRate)
        
        // LFO clamps to 0.01-100 Hz range
        lfo.setFrequency(0.001) // Too low
        #expect(lfo.getFrequency() >= 0.01, "Should clamp to minimum")
        
        lfo.setFrequency(200.0) // Too high
        #expect(lfo.getFrequency() <= 100.0, "Should clamp to maximum")
    }
    
    @Test("Reset works correctly")
    func testReset() {
        var lfo = LFO(sampleRate)
        lfo.setWaveform(LFO.Waveform.SAW)
        lfo.setFrequency(10.0)
        lfo.setPhaseOffset(0.0)
        lfo.setSmoothingCutoff(20000.0) // Disable smoothing
        
        // Process some samples
        for _ in 0..<1000 {
            _ = lfo.process()
        }
        
        // Reset
        lfo.reset()
        
        // After reset, first value should be near the start of the waveform
        let firstValue = lfo.process()
        
        // Saw wave starts at -1 when phase is 0
        #expect(firstValue < -0.9, "Saw should start near -1 after reset, got \(firstValue)")
    }
    
    @Test("Tempo sync mode works")
    func testTempoSyncMode() {
        var lfo = LFO(sampleRate)
        
        // Set up tempo sync
        lfo.setSyncMode(LFO.SyncMode.BEAT_SYNC)
        lfo.setTempo(120.0)
        lfo.setBeatDivision(LFO.BeatDivision.QUARTER)
        
        #expect(lfo.getSyncMode() == LFO.SyncMode.BEAT_SYNC)
        #expect(lfo.getTempo() == 120.0)
        #expect(lfo.getBeatDivision() == LFO.BeatDivision.QUARTER)
    }
    
    @Test("Tempo limits are enforced")
    func testTempoLimits() {
        var lfo = LFO(sampleRate)
        
        lfo.setTempo(10.0) // Too low
        #expect(lfo.getTempo() >= 20.0, "Should clamp to minimum")
        
        lfo.setTempo(500.0) // Too high
        #expect(lfo.getTempo() <= 300.0, "Should clamp to maximum")
    }
    
    @Test("Beat sync produces correct frequencies")
    func testBeatSyncFrequencies() {
        var lfo = LFO(sampleRate)
        lfo.setSyncMode(LFO.SyncMode.BEAT_SYNC)
        lfo.setTempo(120.0) // 120 BPM = 2 beats per second
        lfo.setWaveform(LFO.Waveform.SAW)
        
        // At quarter note rate, should complete 2 cycles per second
        lfo.setBeatDivision(LFO.BeatDivision.QUARTER)
        
        // Count zero crossings over 1 second
        var zeroCrossings = 0
        var prevValue = lfo.process()
        
        for _ in 1..<Int(sampleRate) {
            let value = lfo.process()
            if prevValue < 0 && value >= 0 {
                zeroCrossings += 1
            }
            prevValue = value
        }
        
        // Should have approximately 2 zero crossings (1 per beat, 2 beats per second)
        #expect(zeroCrossings >= 1 && zeroCrossings <= 3, "Expected ~2 zero crossings at 120 BPM quarter notes, got \(zeroCrossings)")
    }
    
    @Test("Retrigger mode can be set")
    func testRetriggerMode() {
        var lfo = LFO(sampleRate)
        
        lfo.setRetriggerMode(LFO.RetriggerMode.NOTE_ON)
        #expect(lfo.getRetriggerMode() == LFO.RetriggerMode.NOTE_ON)
        
        lfo.setRetriggerMode(LFO.RetriggerMode.FREE)
        #expect(lfo.getRetriggerMode() == LFO.RetriggerMode.FREE)
    }
    
    @Test("Retrigger resets phase")
    func testRetrigger() {
        var lfo = LFO(sampleRate)
        lfo.setWaveform(LFO.Waveform.SAW)
        lfo.setFrequency(10.0)
        lfo.setPhaseOffset(0.0)
        lfo.setSmoothingCutoff(20000.0)
        
        // Process some samples to advance phase
        for _ in 0..<2205 { // ~0.05 seconds
            _ = lfo.process()
        }
        
        // Retrigger
        lfo.retrigger()
        
        // Should be back at start
        let value = lfo.process()
        #expect(value < -0.9, "Should be near start of saw wave after retrigger")
    }
    
    @Test("Phase offset can be set and retrieved")
    func testPhaseOffset() {
        var lfo = LFO(sampleRate)
        
        lfo.setPhaseOffset(0.25)
        #expect(lfo.getPhaseOffset() == 0.25, "Phase offset should be settable")
        
        lfo.setPhaseOffset(0.75)
        #expect(lfo.getPhaseOffset() == 0.75, "Phase offset should be settable")
        
        // Phase offset is normalized to 0-1 range
        lfo.setPhaseOffset(1.5)
        #expect(lfo.getPhaseOffset() >= 0.0 && lfo.getPhaseOffset() < 1.0, "Phase offset should be normalized")
    }
    
    @Test("Delay time can be set")
    func testDelayTime() {
        var lfo = LFO(sampleRate)
        
        lfo.setDelayTime(0.5) // 500ms
        #expect(lfo.getDelayTime() == 0.5)
        
        lfo.setDelayTime(0.0)
        #expect(lfo.getDelayTime() == 0.0)
    }
    
    @Test("LFO delay outputs zero during delay period")
    func testDelayOutputsZero() {
        var lfo = LFO(sampleRate)
        lfo.setWaveform(LFO.Waveform.SAW)
        lfo.setFrequency(10.0)
        lfo.setDelayTime(0.1) // 100ms delay = 4410 samples
        
        // During delay, should output 0
        for _ in 0..<4000 {
            let value = lfo.process()
            #expect(value == 0.0, "Should output 0 during delay period")
        }
    }
    
    @Test("Output smoothing reduces sudden changes")
    func testSmoothing() {
        var lfo = LFO(sampleRate)
        lfo.setWaveform(LFO.Waveform.SQUARE)
        lfo.setFrequency(10.0)
        lfo.setSmoothingCutoff(5.0) // Low cutoff = heavy smoothing
        
        var maxDiff = 0.0
        var prevValue = lfo.process()
        
        for _ in 0..<Int(sampleRate / 10) { // 1 cycle
            let value = lfo.process()
            maxDiff = max(maxDiff, Swift.abs(value - prevValue))
            prevValue = value
        }
        
        // With smoothing, transitions should be gradual, not instantaneous
        // Square wave without smoothing would have diff of 2.0 at transitions
        #expect(maxDiff < 0.5, "Smoothing should reduce transition sharpness, maxDiff = \(maxDiff)")
    }
    
    @Test("All waveforms produce output in valid range")
    func testAllWaveformsRange() {
        let waveforms: [LFO.Waveform] = [.SINE, .TRIANGLE, .SAW, .SQUARE]
        
        for waveform in waveforms {
            var lfo = LFO(sampleRate)
            lfo.setWaveform(waveform)
            lfo.setFrequency(5.0)
            
            for _ in 0..<1000 {
                let value = lfo.process()
                #expect(value >= -1.0 && value <= 1.0, "\(waveform) output out of range: \(value)")
            }
        }
    }
}
