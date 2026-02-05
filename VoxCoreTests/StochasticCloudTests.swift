//
//  StochasticCloudTests.swift
//  VoxCoreTests
//
//  Tests for Phase 5: Stochastic Cloud Engine
//  Per-grain randomization inspired by Xenakis
//

import Testing
@testable import VoxCore

@Suite("Stochastic Cloud Engine Tests")
struct StochasticCloudTests {
    let sampleRate = 44100.0
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Phase 5.1: Per-Grain Pitch Scatter Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("Pitch scatter defaults to zero")
    func testPitchScatterDefault() {
        let osc = PulsarOscillator(sampleRate)
        #expect(osc.getPitchScatterAmount() == 0.0, "Default pitch scatter should be 0")
        #expect(osc.getPitchScatterDistribution() == .GAUSSIAN, "Default distribution should be Gaussian")
    }
    
    @Test("Pitch scatter can be set and clamped")
    func testPitchScatterSetAndClamp() {
        var osc = PulsarOscillator(sampleRate)
        
        osc.setPitchScatter(50.0, .UNIFORM)
        #expect(osc.getPitchScatterAmount() == 50.0, "Should accept valid value")
        #expect(osc.getPitchScatterDistribution() == .UNIFORM, "Should accept distribution type")
        
        osc.setPitchScatter(150.0)  // Over max
        #expect(osc.getPitchScatterAmount() == 100.0, "Should clamp to max 100 cents")
        
        osc.setPitchScatter(-10.0)  // Under min
        #expect(osc.getPitchScatterAmount() == 0.0, "Should clamp to min 0")
    }
    
    @Test("Pitch scatter produces variation between grains")
    func testPitchScatterVariation() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)  // Low freq for easier grain detection
        osc.setDutyCycle(0.3)
        osc.setPitchScatter(50.0, .GAUSSIAN)
        osc.seedRNG(42)
        
        // Collect pitch offsets from multiple grains
        var grainPitchOffsets: [Double] = []
        var lastPhaseWasHigh = false
        
        for _ in 0..<Int(sampleRate) {  // 1 second
            _ = osc.process()
            let state = osc.getCurrentGrainState()
            
            // Detect grain start (simple: when we get a new non-zero offset after zero period)
            if grainPitchOffsets.isEmpty || state.pitchOffsetCents != grainPitchOffsets.last {
                if state.pitchOffsetCents != 0.0 || grainPitchOffsets.count < 5 {
                    grainPitchOffsets.append(state.pitchOffsetCents)
                }
            }
        }
        
        // Should have collected multiple different values
        let uniqueValues = Set(grainPitchOffsets)
        #expect(uniqueValues.count > 5, "Should have variation between grains, got \(uniqueValues.count) unique values")
        
        // Values should be roughly within expected range (±3 sigma for Gaussian)
        let maxOffset = grainPitchOffsets.map { Swift.abs($0) }.max() ?? 0
        #expect(maxOffset > 0, "Should have non-zero pitch offsets")
        #expect(maxOffset <= 150, "Pitch offsets should be within ~3 sigma of 50 cents")
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Phase 5.2: Per-Grain Timing Jitter Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("Timing jitter defaults to zero")
    func testTimingJitterDefault() {
        let osc = PulsarOscillator(sampleRate)
        #expect(osc.getTimingJitter() == 0.0, "Default timing jitter should be 0")
        #expect(osc.getTimingDistribution() == .GAUSSIAN, "Default timing distribution should be Gaussian")
    }
    
    @Test("Timing jitter can be set and clamped")
    func testTimingJitterSetAndClamp() {
        var osc = PulsarOscillator(sampleRate)
        
        osc.setTimingJitter(25.0, .POISSON)
        #expect(osc.getTimingJitter() == 25.0, "Should accept valid value")
        #expect(osc.getTimingDistribution() == .POISSON, "Should accept Poisson distribution")
        
        osc.setTimingJitter(100.0)  // Over max
        #expect(osc.getTimingJitter() == 50.0, "Should clamp to max 50ms")
        
        osc.setTimingJitter(-5.0)  // Under min
        #expect(osc.getTimingJitter() == 0.0, "Should clamp to min 0")
    }
    
    @Test("Timing jitter affects grain timing")
    func testTimingJitterEffect() {
        var oscNoJitter = PulsarOscillator(sampleRate)
        oscNoJitter.setFrequency(100.0)  // 10ms period
        oscNoJitter.setDutyCycle(0.2)
        oscNoJitter.seedRNG(42)
        
        var oscWithJitter = PulsarOscillator(sampleRate)
        oscWithJitter.setFrequency(100.0)
        oscWithJitter.setDutyCycle(0.2)
        oscWithJitter.setTimingJitter(5.0, .GAUSSIAN)  // 5ms jitter
        oscWithJitter.seedRNG(42)
        
        // Generate samples and compare
        var noJitterSamples: [Double] = []
        var jitterSamples: [Double] = []
        
        for _ in 0..<4410 {  // 100ms
            noJitterSamples.append(oscNoJitter.process())
            jitterSamples.append(oscWithJitter.process())
        }
        
        // Count differences (with jitter, samples should differ)
        var differences = 0
        for i in 0..<noJitterSamples.count {
            if Swift.abs(noJitterSamples[i] - jitterSamples[i]) > 0.01 {
                differences += 1
            }
        }
        
        #expect(differences > 100, "Timing jitter should cause differences in output timing")
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Phase 5.3: Per-Grain Formant Scatter Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("Formant scatter defaults to zero")
    func testFormantScatterDefault() {
        let osc = PulsarOscillator(sampleRate)
        #expect(osc.getFormantScatter() == 0.0, "Default formant scatter should be 0")
    }
    
    @Test("Formant scatter can be set and clamped")
    func testFormantScatterSetAndClamp() {
        var osc = PulsarOscillator(sampleRate)
        
        osc.setFormantScatter(100.0, .GAUSSIAN)
        #expect(osc.getFormantScatter() == 100.0, "Should accept valid value")
        
        osc.setFormantScatter(300.0)  // Over max
        #expect(osc.getFormantScatter() == 200.0, "Should clamp to max 200 Hz")
        
        osc.setFormantScatter(-50.0)  // Under min
        #expect(osc.getFormantScatter() == 0.0, "Should clamp to min 0")
    }
    
    @Test("Formant scatter produces variation in grain state")
    func testFormantScatterVariation() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)
        osc.setDutyCycle(0.3)
        osc.setFormantScatter(100.0, .GAUSSIAN)
        osc.seedRNG(42)
        
        var formantOffsets: [Double] = []
        
        for _ in 0..<Int(sampleRate / 2) {  // 0.5 second
            _ = osc.process()
            let state = osc.getCurrentGrainState()
            if state.formantOffsetHz != 0.0 && (formantOffsets.isEmpty || state.formantOffsetHz != formantOffsets.last) {
                formantOffsets.append(state.formantOffsetHz)
            }
        }
        
        let uniqueValues = Set(formantOffsets)
        #expect(uniqueValues.count > 3, "Should have multiple unique formant offsets")
        
        // Check values are within expected range
        let maxOffset = formantOffsets.map { Swift.abs($0) }.max() ?? 0
        #expect(maxOffset > 0, "Should have non-zero formant offsets")
        #expect(maxOffset < 400, "Formant offsets should be reasonable (within ~4 sigma)")
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Phase 5.4: Per-Grain Pan Scatter Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("Pan scatter defaults to zero")
    func testPanScatterDefault() {
        let osc = PulsarOscillator(sampleRate)
        #expect(osc.getPanScatter() == 0.0, "Default pan scatter should be 0")
        #expect(osc.getPanDistribution() == .UNIFORM, "Default pan distribution should be Uniform")
    }
    
    @Test("Pan scatter can be set and clamped")
    func testPanScatterSetAndClamp() {
        var osc = PulsarOscillator(sampleRate)
        
        osc.setPanScatter(0.5, .UNIFORM)
        #expect(Swift.abs(osc.getPanScatter() - 0.5) < 0.001, "Should accept valid value")
        
        osc.setPanScatter(1.5)  // Over max
        #expect(osc.getPanScatter() == 1.0, "Should clamp to max 1.0")
        
        osc.setPanScatter(-0.5)  // Under min
        #expect(osc.getPanScatter() == 0.0, "Should clamp to min 0")
    }
    
    @Test("Pan scatter produces spatial variation")
    func testPanScatterSpatialVariation() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)
        osc.setDutyCycle(0.3)
        osc.setPanScatter(1.0, .UNIFORM)  // Full stereo spread
        osc.seedRNG(42)
        
        var panOffsets: [Double] = []
        var hasLeft = false
        var hasRight = false
        
        for _ in 0..<Int(sampleRate / 2) {
            _ = osc.process()
            let state = osc.getCurrentGrainState()
            if panOffsets.isEmpty || state.panOffset != panOffsets.last {
                panOffsets.append(state.panOffset)
                if state.panOffset < -0.3 { hasLeft = true }
                if state.panOffset > 0.3 { hasRight = true }
            }
        }
        
        #expect(hasLeft && hasRight, "Pan scatter should produce both left and right positions")
        
        // All values should be clamped to valid range
        for offset in panOffsets {
            #expect(offset >= -1.0 && offset <= 1.0, "Pan offset \(offset) should be in [-1, 1]")
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Phase 5.5: Per-Grain Amplitude Scatter Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("Amplitude scatter defaults to zero")
    func testAmpScatterDefault() {
        let osc = PulsarOscillator(sampleRate)
        #expect(osc.getAmpScatter() == 0.0, "Default amp scatter should be 0")
        #expect(osc.getAmpDistribution() == .GAUSSIAN, "Default amp distribution should be Gaussian")
    }
    
    @Test("Amplitude scatter can be set and clamped")
    func testAmpScatterSetAndClamp() {
        var osc = PulsarOscillator(sampleRate)
        
        osc.setAmpScatter(6.0, .GAUSSIAN)
        #expect(osc.getAmpScatter() == 6.0, "Should accept valid value")
        
        osc.setAmpScatter(20.0)  // Over max
        #expect(osc.getAmpScatter() == 12.0, "Should clamp to max 12 dB")
        
        osc.setAmpScatter(-3.0)  // Under min
        #expect(osc.getAmpScatter() == 0.0, "Should clamp to min 0")
    }
    
    @Test("Amplitude scatter affects output level")
    func testAmpScatterAffectsOutput() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)
        osc.setDutyCycle(0.5)
        osc.setAmpScatter(6.0, .GAUSSIAN)  // ±6dB variation
        osc.seedRNG(42)
        
        // Collect peak amplitudes from multiple grains
        var grainPeaks: [Double] = []
        var currentPeak = 0.0
        var samplesInGrain = 0
        let samplesPerPeriod = Int(sampleRate / 100.0)
        
        for _ in 0..<Int(sampleRate) {
            let sample = osc.process()
            currentPeak = max(currentPeak, Swift.abs(sample))
            samplesInGrain += 1
            
            // After one period, record the peak and reset
            if samplesInGrain >= samplesPerPeriod {
                if currentPeak > 0.1 {  // Only count actual grains
                    grainPeaks.append(currentPeak)
                }
                currentPeak = 0.0
                samplesInGrain = 0
            }
        }
        
        // Check for variation in peaks
        guard grainPeaks.count > 5 else {
            Issue.record("Not enough grains detected")
            return
        }
        
        let minPeak = grainPeaks.min()!
        let maxPeak = grainPeaks.max()!
        let ratio = maxPeak / minPeak
        
        // 6dB = factor of 2, so we expect at least 1.5x variation
        #expect(ratio > 1.3, "Amplitude scatter should cause peak variation, ratio: \(ratio)")
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Phase 5.7: Global Scatter Amount Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("Cloud scatter defaults to 1.0 (100%)")
    func testCloudScatterDefault() {
        let osc = PulsarOscillator(sampleRate)
        #expect(osc.getCloudScatter() == 1.0, "Default cloud scatter should be 1.0")
    }
    
    @Test("Cloud scatter can be set and clamped")
    func testCloudScatterSetAndClamp() {
        var osc = PulsarOscillator(sampleRate)
        
        osc.setCloudScatter(0.5)
        #expect(Swift.abs(osc.getCloudScatter() - 0.5) < 0.001, "Should accept valid value")
        
        osc.setCloudScatter(1.5)
        #expect(osc.getCloudScatter() == 1.0, "Should clamp to max 1.0")
        
        osc.setCloudScatter(-0.3)
        #expect(osc.getCloudScatter() == 0.0, "Should clamp to min 0")
    }
    
    @Test("Cloud scatter at zero disables all scatter")
    func testCloudScatterZeroDisables() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)
        osc.setDutyCycle(0.3)
        osc.setPitchScatter(50.0)
        osc.setAmpScatter(6.0)
        osc.setPanScatter(1.0)
        osc.setCloudScatter(0.0)  // Master disable
        osc.seedRNG(42)
        
        for _ in 0..<Int(sampleRate / 2) {
            _ = osc.process()
            let state = osc.getCurrentGrainState()
            
            #expect(state.pitchOffsetCents == 0.0, "Pitch should be 0 when cloud scatter is 0")
            #expect(state.panOffset == 0.0, "Pan should be 0 when cloud scatter is 0")
            #expect(state.ampMultiplier == 1.0, "Amp multiplier should be 1.0 when cloud scatter is 0")
        }
    }
    
    @Test("Cloud scatter scales all scatter amounts")
    func testCloudScatterScales() {
        // Full scatter
        var oscFull = PulsarOscillator(sampleRate)
        oscFull.setFrequency(100.0)
        oscFull.setDutyCycle(0.3)
        oscFull.setPitchScatter(100.0)
        oscFull.setCloudScatter(1.0)
        oscFull.seedRNG(42)
        
        // Half scatter
        var oscHalf = PulsarOscillator(sampleRate)
        oscHalf.setFrequency(100.0)
        oscHalf.setDutyCycle(0.3)
        oscHalf.setPitchScatter(100.0)
        oscHalf.setCloudScatter(0.5)
        oscHalf.seedRNG(42)
        
        var fullPitchVariance = 0.0
        var halfPitchVariance = 0.0
        var count = 0
        
        for _ in 0..<Int(sampleRate) {
            _ = oscFull.process()
            _ = oscHalf.process()
            
            let fullOffset = oscFull.getCurrentGrainState().pitchOffsetCents
            let halfOffset = oscHalf.getCurrentGrainState().pitchOffsetCents
            
            fullPitchVariance += fullOffset * fullOffset
            halfPitchVariance += halfOffset * halfOffset
            count += 1
        }
        
        // Variance should roughly scale with cloud scatter squared
        // (because scatter affects the stddev, variance ~ stddev^2)
        let fullRMS = sqrt(fullPitchVariance / Double(count))
        let halfRMS = sqrt(halfPitchVariance / Double(count))
        
        // Half cloud scatter should result in roughly half the RMS
        if fullRMS > 1.0 {
            let ratio = halfRMS / fullRMS
            #expect(ratio < 0.7, "Half cloud scatter should reduce RMS, ratio: \(ratio)")
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Phase 5.8: Grain Density Control Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("Async mode defaults to off")
    func testAsyncModeDefault() {
        let osc = PulsarOscillator(sampleRate)
        #expect(osc.getAsyncMode() == false, "Async mode should default to off")
    }
    
    @Test("Grain density defaults to 100/sec")
    func testGrainDensityDefault() {
        let osc = PulsarOscillator(sampleRate)
        #expect(osc.getGrainDensity() == 100.0, "Default grain density should be 100")
    }
    
    @Test("Grain density can be set and clamped")
    func testGrainDensitySetAndClamp() {
        var osc = PulsarOscillator(sampleRate)
        
        osc.setGrainDensity(500.0)
        #expect(osc.getGrainDensity() == 500.0, "Should accept valid value")
        
        osc.setGrainDensity(3000.0)  // Over max
        #expect(osc.getGrainDensity() == 2000.0, "Should clamp to max 2000")
        
        osc.setGrainDensity(5.0)  // Under min
        #expect(osc.getGrainDensity() == 20.0, "Should clamp to min 20")
    }
    
    @Test("Async mode produces output")
    func testAsyncModeProducesOutput() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)
        osc.setDutyCycle(0.3)
        osc.setAsyncMode(true)
        osc.setGrainDensity(200.0)
        
        var maxSample = 0.0
        var nonZeroCount = 0
        var above03Count = 0
        
        for _ in 0..<Int(sampleRate) {
            let sample = osc.process()
            maxSample = max(maxSample, Swift.abs(sample))
            if Swift.abs(sample) > 0.001 {
                nonZeroCount += 1
            }
            if Swift.abs(sample) > 0.3 {
                above03Count += 1
            }
        }
        
        #expect(maxSample > 0.3, "Async mode should produce output above 0.3, max sample: \(maxSample)")
        #expect(nonZeroCount > 1000, "Should have many non-zero samples, got: \(nonZeroCount)")
        #expect(above03Count > 100, "Should have samples above 0.3, got: \(above03Count)")
    }
    
    @Test("Async mode: grain density independent of pitch")
    func testGrainDensityIndependentOfPitch() {
        // Count grains by detecting when output rises above threshold
        // Use GAUSSIAN shape (unipolar) for accurate 1-crossing-per-grain counting
        func countGrains(pitch: Double, density: Double, asyncMode: Bool) -> Int {
            var testOsc = PulsarOscillator(sampleRate)
            testOsc.setFrequency(pitch)
            testOsc.setDutyCycle(0.3)  // Wider duty for clearer grains
            testOsc.setAsyncMode(asyncMode)
            testOsc.setGrainDensity(density)
            testOsc.setShape(.GAUSSIAN)  // Unipolar - one crossing per grain
            
            var grainCount = 0
            var wasAboveThreshold = false
            let threshold = 0.1  // Gaussian peaks at 1.0, this catches grain onset
            
            for _ in 0..<Int(sampleRate) {  // 1 second
                let sample = testOsc.process()
                let aboveThreshold = sample > threshold  // Gaussian is always positive
                
                // Count rising edge (entering grain)
                if aboveThreshold && !wasAboveThreshold {
                    grainCount += 1
                }
                wasAboveThreshold = aboveThreshold
            }
            return grainCount
        }
        
        // In async mode, grain density should be independent of pitch
        let grainsAt110Hz = countGrains(pitch: 110.0, density: 200.0, asyncMode: true)
        let grainsAt440Hz = countGrains(pitch: 440.0, density: 200.0, asyncMode: true)
        let grainsAt880Hz = countGrains(pitch: 880.0, density: 200.0, asyncMode: true)
        
        // All should be approximately 200 grains
        let expectedGrains = 200
        let tolerance = 40  // Allow some timing variance
        
        #expect(Swift.abs(grainsAt110Hz - expectedGrains) < tolerance,
               "At 110Hz, should have ~\(expectedGrains) grains, got \(grainsAt110Hz)")
        #expect(Swift.abs(grainsAt440Hz - expectedGrains) < tolerance,
               "At 440Hz, should have ~\(expectedGrains) grains, got \(grainsAt440Hz)")
        #expect(Swift.abs(grainsAt880Hz - expectedGrains) < tolerance,
               "At 880Hz, should have ~\(expectedGrains) grains, got \(grainsAt880Hz)")
        
        // Key test: all should be similar regardless of pitch
        let avgGrains = Double(grainsAt110Hz + grainsAt440Hz + grainsAt880Hz) / 3.0
        #expect(Swift.abs(Double(grainsAt110Hz) - avgGrains) < 30, "110Hz grain count should be near average")
        #expect(Swift.abs(Double(grainsAt440Hz) - avgGrains) < 30, "440Hz grain count should be near average")
        #expect(Swift.abs(Double(grainsAt880Hz) - avgGrains) < 30, "880Hz grain count should be near average")
    }
    
    @Test("Sync mode: grain rate equals pitch")
    func testSyncModeGrainRateEqualsPitch() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)  // Should produce ~100 grains/sec
        osc.setDutyCycle(0.3)    // Wider duty for clearer detection
        osc.setAsyncMode(false)  // Sync mode
        osc.setShape(.GAUSSIAN)  // Unipolar - one crossing per grain
        
        var grainCount = 0
        var wasAboveThreshold = false
        let threshold = 0.1  // Gaussian peaks at 1.0
        
        for _ in 0..<Int(sampleRate) {
            let sample = osc.process()
            let aboveThreshold = sample > threshold  // Gaussian is always positive
            
            // Count rising edge (entering grain)
            if aboveThreshold && !wasAboveThreshold {
                grainCount += 1
            }
            wasAboveThreshold = aboveThreshold
        }
        
        // Should be close to 100 grains (the frequency)
        #expect(Swift.abs(grainCount - 100) < 15,
               "In sync mode at 100Hz, should have ~100 grains, got \(grainCount)")
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Combined Stochastic Params Tests
    // ═══════════════════════════════════════════════════════════════════
    
    @Test("StochasticParams struct can be set and retrieved")
    func testStochasticParamsStruct() {
        var osc = PulsarOscillator(sampleRate)
        
        var params = StochasticParams()
        params.pitchScatterAmount = 30.0
        params.pitchScatterDistribution = .UNIFORM
        params.timingJitter = 10.0
        params.timingDistribution = .POISSON
        params.formantScatter = 75.0
        params.panScatter = 0.8
        params.ampScatter = 4.0
        params.cloudScatter = 0.6
        params.asyncMode = true
        params.grainDensity = 300.0
        
        osc.setStochasticParams(params)
        
        let retrieved = osc.getStochasticParams()
        #expect(retrieved.pitchScatterAmount == 30.0)
        #expect(retrieved.pitchScatterDistribution == .UNIFORM)
        #expect(retrieved.timingJitter == 10.0)
        #expect(retrieved.timingDistribution == .POISSON)
        #expect(retrieved.formantScatter == 75.0)
        #expect(Swift.abs(retrieved.panScatter - 0.8) < 0.001)
        #expect(retrieved.ampScatter == 4.0)
        #expect(Swift.abs(retrieved.cloudScatter - 0.6) < 0.001)
        #expect(retrieved.asyncMode == true)
        #expect(retrieved.grainDensity == 300.0)
    }
    
    @Test("RNG seed produces reproducible results")
    func testRNGSeedReproducibility() {
        var osc1 = PulsarOscillator(sampleRate)
        osc1.setFrequency(100.0)
        osc1.setPitchScatter(50.0)
        osc1.seedRNG(12345)
        
        var osc2 = PulsarOscillator(sampleRate)
        osc2.setFrequency(100.0)
        osc2.setPitchScatter(50.0)
        osc2.seedRNG(12345)
        
        for _ in 0..<1000 {
            let s1 = osc1.process()
            let s2 = osc2.process()
            #expect(s1 == s2, "Same seed should produce identical output")
        }
    }
    
    @Test("Reset clears stochastic state")
    func testResetClearsState() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)
        osc.setPitchScatter(50.0)
        osc.setAmpScatter(6.0)
        osc.seedRNG(42)
        
        // Process some samples
        for _ in 0..<1000 {
            _ = osc.process()
        }
        
        // Reset
        osc.reset()
        
        let state = osc.getCurrentGrainState()
        #expect(state.pitchOffsetCents == 0.0, "Reset should clear pitch offset")
        #expect(state.ampMultiplier == 1.0, "Reset should reset amp multiplier to 1")
        #expect(state.panOffset == 0.0, "Reset should clear pan offset")
    }
    
    @Test("Oscillator still produces sound with all scatter enabled")
    func testSoundWithAllScatter() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(440.0)
        osc.setDutyCycle(0.3)
        osc.setPitchScatter(50.0)
        osc.setTimingJitter(10.0)
        osc.setFormantScatter(100.0)
        osc.setPanScatter(0.5)
        osc.setAmpScatter(6.0)
        osc.setCloudScatter(1.0)
        osc.seedRNG(42)
        
        var samples: [Double] = []
        for _ in 0..<4410 {
            samples.append(osc.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.1, "Should still produce audible output with all scatter enabled")
        
        let nonZeroCount = samples.filter { Swift.abs($0) > 0.001 }.count
        #expect(nonZeroCount > 100, "Should have active grain content")
    }
}
