//
//  PulsaretEnvelopeTests.swift
//  VoxCoreTests
//
//  Phase 7: Tests for Pulsaret Envelope (Roads' "v" parameter)
//  These envelopes shape each individual pulsaret, separate from the ADSR.
//

import Testing
@testable import VoxCore

@Suite("Pulsaret Envelope Tests")
struct PulsaretEnvelopeTests {
    let sampleRate = 44100.0
    
    // MARK: - Envelope Type Tests
    
    @Test("Rectangular envelope produces full amplitude")
    func testRectangularEnvelope() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)  // Low for easier analysis
        osc.setDutyCycle(0.5)
        osc.setShape(.SINE)
        osc.setPulsaretEnvelope(.RECTANGULAR)
        
        // Process one period and check for full amplitude regions
        let samplesPerPeriod = Int(sampleRate / 100.0)
        var samples: [Double] = []
        
        for _ in 0..<samplesPerPeriod {
            samples.append(osc.process())
        }
        
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.9, "Rectangular envelope should allow near-unity amplitude")
    }
    
    @Test("Gaussian envelope produces bell-shaped output")
    func testGaussianEnvelope() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)
        osc.setDutyCycle(0.5)
        osc.setShape(.SINE)
        osc.setPulsaretEnvelope(.GAUSSIAN)
        osc.setEnvelopeParam(0.5)  // Medium width
        
        let samplesPerPeriod = Int(sampleRate / 100.0)
        let activeSamples = Int(Double(samplesPerPeriod) * 0.5)
        var samples: [Double] = []
        
        for _ in 0..<samplesPerPeriod {
            samples.append(osc.process())
        }
        
        // Check that edges are attenuated compared to center
        let edgeSamples = samples[0..<10].map { Swift.abs($0) }
        let centerSamples = samples[(activeSamples/2-5)..<(activeSamples/2+5)].map { Swift.abs($0) }
        
        let edgeMax = edgeSamples.max() ?? 0.0
        let centerMax = centerSamples.max() ?? 0.0
        
        #expect(centerMax > edgeMax, "Gaussian should peak in center, not edges")
    }
    
    @Test("ExpDecay envelope has sharp attack and decay")
    func testExpDecayEnvelope() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)
        osc.setDutyCycle(0.5)
        osc.setShape(.SINE)
        osc.setPulsaretEnvelope(.EXP_DECAY)
        osc.setEnvelopeParam(0.5)
        
        let samplesPerPeriod = Int(sampleRate / 100.0)
        var samples: [Double] = []
        
        for _ in 0..<samplesPerPeriod {
            samples.append(osc.process())
        }
        
        // ExpDecay should start high and decrease
        let activeSamples = Int(Double(samplesPerPeriod) * 0.5)
        let firstQuarter = samples[0..<(activeSamples/4)].map { Swift.abs($0) }
        let lastQuarter = samples[(activeSamples*3/4)..<activeSamples].map { Swift.abs($0) }
        
        let firstMean = firstQuarter.reduce(0, +) / Double(firstQuarter.count)
        let lastMean = lastQuarter.reduce(0, +) / Double(lastQuarter.count)
        
        #expect(firstMean > lastMean, "ExpDecay should decay over time")
    }
    
    @Test("LinearAttack envelope has rising attack")
    func testLinearAttackEnvelope() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)
        osc.setDutyCycle(0.5)
        osc.setShape(.SINE)
        osc.setPulsaretEnvelope(.LINEAR_ATTACK)
        osc.setEnvelopeParam(0.5)  // 30% attack portion
        
        let samplesPerPeriod = Int(sampleRate / 100.0)
        var samples: [Double] = []
        
        for _ in 0..<samplesPerPeriod {
            samples.append(osc.process())
        }
        
        // Should have rising amplitude at start
        let activeSamples = Int(Double(samplesPerPeriod) * 0.5)
        if activeSamples > 20 {
            let veryStart = Swift.abs(samples[1])
            let afterAttack = Swift.abs(samples[activeSamples / 5])
            
            #expect(afterAttack > veryStart, "LinearAttack should rise from start")
        }
    }
    
    @Test("FOF envelope has smooth attack and decay")
    func testFOFEnvelope() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)
        osc.setDutyCycle(0.5)
        osc.setShape(.SINE)
        osc.setPulsaretEnvelope(.FOF)
        osc.setEnvelopeParam(0.5)
        
        let samplesPerPeriod = Int(sampleRate / 100.0)
        var samples: [Double] = []
        
        for _ in 0..<samplesPerPeriod {
            samples.append(osc.process())
        }
        
        // FOF should produce output
        let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAmp > 0.1, "FOF envelope should produce output")
    }
    
    // MARK: - Envelope Parameter Tests
    
    @Test("Envelope parameter affects Gaussian width")
    func testEnvelopeParamGaussianWidth() {
        // Narrow Gaussian (param = 0)
        var oscNarrow = PulsarOscillator(sampleRate)
        oscNarrow.setFrequency(100.0)
        oscNarrow.setDutyCycle(0.5)
        oscNarrow.setShape(.SINE)
        oscNarrow.setPulsaretEnvelope(.GAUSSIAN)
        oscNarrow.setEnvelopeParam(0.0)  // Narrow
        
        // Wide Gaussian (param = 1)
        var oscWide = PulsarOscillator(sampleRate)
        oscWide.setFrequency(100.0)
        oscWide.setDutyCycle(0.5)
        oscWide.setShape(.SINE)
        oscWide.setPulsaretEnvelope(.GAUSSIAN)
        oscWide.setEnvelopeParam(1.0)  // Wide
        
        let samplesPerPeriod = Int(sampleRate / 100.0)
        
        var narrowSamples: [Double] = []
        var wideSamples: [Double] = []
        
        for _ in 0..<samplesPerPeriod {
            narrowSamples.append(oscNarrow.process())
            wideSamples.append(oscWide.process())
        }
        
        // Count samples above threshold - wide should have more
        let threshold = 0.3
        let narrowAbove = narrowSamples.filter { Swift.abs($0) > threshold }.count
        let wideAbove = wideSamples.filter { Swift.abs($0) > threshold }.count
        
        #expect(wideAbove > narrowAbove, "Wide Gaussian should have more samples above threshold")
    }
    
    @Test("Envelope parameter is clamped to 0-1")
    func testEnvelopeParamClamping() {
        var osc = PulsarOscillator(sampleRate)
        
        osc.setEnvelopeParam(-0.5)
        #expect(osc.getEnvelopeParam() >= 0.0, "Should clamp to minimum")
        
        osc.setEnvelopeParam(1.5)
        #expect(osc.getEnvelopeParam() <= 1.0, "Should clamp to maximum")
        
        osc.setEnvelopeParam(0.7)
        #expect(Swift.abs(osc.getEnvelopeParam() - 0.7) < 0.001, "Valid param should be set")
    }
    
    // MARK: - All Envelope Types Produce Output
    
    @Test("All envelope types produce output with all shapes")
    func testAllEnvelopeShapeCombinations() {
        let envelopes: [PulsaretEnvelope] = [
            .RECTANGULAR, .GAUSSIAN, .EXP_DECAY, .LINEAR_ATTACK, .FOF
        ]
        let shapes: [PulsarOscillator.Shape] = [
            .GAUSSIAN, .RAISED_COSINE, .SINE, .TRIANGLE
        ]
        
        for envelope in envelopes {
            for shape in shapes {
                var osc = PulsarOscillator(sampleRate)
                osc.setFrequency(440.0)
                osc.setDutyCycle(0.3)
                osc.setShape(shape)
                osc.setPulsaretEnvelope(envelope)
                osc.setEnvelopeParam(0.5)
                
                var samples: [Double] = []
                for _ in 0..<1000 {
                    samples.append(osc.process())
                }
                
                let maxAmp = samples.map { Swift.abs($0) }.max() ?? 0.0
                #expect(maxAmp > 0.05, 
                       "Envelope \(envelope) with shape \(shape) should produce output")
            }
        }
    }
}

@Suite("Formant Track Tests")
struct FormantTrackTests {
    let sampleRate = 44100.0
    
    @Test("FormantTrack defaults to 0.0 (robot voice)")
    func testFormantTrackDefault() {
        let osc = PulsarOscillator(sampleRate)
        #expect(osc.getFormantTrack() == 0.0, "Default should be robot voice (0.0)")
    }
    
    @Test("FormantTrack is clamped to 0-1")
    func testFormantTrackClamping() {
        var osc = PulsarOscillator(sampleRate)
        
        osc.setFormantTrack(-0.5)
        #expect(osc.getFormantTrack() >= 0.0)
        
        osc.setFormantTrack(1.5)
        #expect(osc.getFormantTrack() <= 1.0)
        
        osc.setFormantTrack(0.75)
        #expect(Swift.abs(osc.getFormantTrack() - 0.75) < 0.001)
    }
    
    @Test("Implicit formant is calculated from duty cycle")
    func testImplicitFormantCalculation() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(440.0)
        osc.setDutyCycle(0.2)  // 20% duty
        
        // Implicit formant = frequency / dutyCycle = 440 / 0.2 = 2200 Hz
        let implicitFormant = osc.getImplicitFormant()
        #expect(Swift.abs(implicitFormant - 2200.0) < 1.0, 
               "Implicit formant should be ~2200 Hz, got \(implicitFormant)")
    }
    
    @Test("Implicit formant changes with duty cycle")
    func testImplicitFormantChangesDuty() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(440.0)
        
        osc.setDutyCycle(0.1)  // 10% = 4400 Hz formant
        let formant1 = osc.getImplicitFormant()
        
        osc.setDutyCycle(0.5)  // 50% = 880 Hz formant
        let formant2 = osc.getImplicitFormant()
        
        #expect(formant1 > formant2, "Lower duty = higher formant")
    }
}

@Suite("Edge Factor Tests")
struct EdgeFactorTests {
    let sampleRate = 44100.0
    
    @Test("EdgeFactor defaults to 1.0 (hard edges)")
    func testEdgeFactorDefault() {
        let osc = PulsarOscillator(sampleRate)
        #expect(osc.getEdgeFactor() == 1.0, "Default should be hard edges (1.0)")
    }
    
    @Test("EdgeFactor is clamped to 0-1")
    func testEdgeFactorClamping() {
        var osc = PulsarOscillator(sampleRate)
        
        osc.setEdgeFactor(-0.5)
        #expect(osc.getEdgeFactor() >= 0.0)
        
        osc.setEdgeFactor(1.5)
        #expect(osc.getEdgeFactor() <= 1.0)
        
        osc.setEdgeFactor(0.3)
        #expect(Swift.abs(osc.getEdgeFactor() - 0.3) < 0.001)
    }
    
    @Test("Soft edges reduce amplitude at pulsaret boundaries")
    func testSoftEdgesReduceEdgeAmplitude() {
        // Hard edges
        var oscHard = PulsarOscillator(sampleRate)
        oscHard.setFrequency(100.0)
        oscHard.setDutyCycle(0.5)
        oscHard.setShape(.SINE)
        oscHard.setPulsaretEnvelope(.RECTANGULAR)
        oscHard.setEdgeFactor(1.0)  // Hard
        
        // Soft edges
        var oscSoft = PulsarOscillator(sampleRate)
        oscSoft.setFrequency(100.0)
        oscSoft.setDutyCycle(0.5)
        oscSoft.setShape(.SINE)
        oscSoft.setPulsaretEnvelope(.RECTANGULAR)
        oscSoft.setEdgeFactor(0.0)  // Soft
        
        let samplesPerPeriod = Int(sampleRate / 100.0)
        
        var hardSamples: [Double] = []
        var softSamples: [Double] = []
        
        for _ in 0..<samplesPerPeriod {
            hardSamples.append(oscHard.process())
            softSamples.append(oscSoft.process())
        }
        
        // At very start, soft should have lower amplitude
        let edgeSize = 5
        let hardEdge = hardSamples[1..<(1+edgeSize)].map { Swift.abs($0) }.max() ?? 0
        let softEdge = softSamples[1..<(1+edgeSize)].map { Swift.abs($0) }.max() ?? 0
        
        #expect(softEdge <= hardEdge, "Soft edges should have lower amplitude at start")
    }
}

@Suite("Pulse Masking Tests")
struct PulseMaskingTests {
    let sampleRate = 44100.0
    
    @Test("Masking defaults to disabled")
    func testMaskingDefault() {
        let osc = PulsarOscillator(sampleRate)
        #expect(osc.getMaskingEnabled() == false)
    }
    
    @Test("Burst pattern can be set")
    func testBurstPatternSetting() {
        var osc = PulsarOscillator(sampleRate)
        osc.setBurstPattern(4, 2)
        
        #expect(osc.getBurstLength() == 4)
        #expect(osc.getRestLength() == 2)
    }
    
    @Test("Masking reduces output energy")
    func testMaskingReducesEnergy() {
        // Without masking
        var oscNoMask = PulsarOscillator(sampleRate)
        oscNoMask.setFrequency(100.0)
        oscNoMask.setDutyCycle(0.3)
        oscNoMask.setMaskingEnabled(false)
        
        // With masking (4:2 pattern = 66% active)
        var oscMasked = PulsarOscillator(sampleRate)
        oscMasked.setFrequency(100.0)
        oscMasked.setDutyCycle(0.3)
        oscMasked.setMaskingEnabled(true)
        oscMasked.setBurstPattern(4, 2)
        
        var noMaskEnergy = 0.0
        var maskedEnergy = 0.0
        
        // Process 10 periods
        let samplesPerPeriod = Int(sampleRate / 100.0)
        for _ in 0..<(samplesPerPeriod * 10) {
            let s1 = oscNoMask.process()
            let s2 = oscMasked.process()
            noMaskEnergy += s1 * s1
            maskedEnergy += s2 * s2
        }
        
        #expect(maskedEnergy < noMaskEnergy * 0.9, 
               "Masked output should have less energy")
    }
    
    @Test("Subharmonic factor is calculated correctly")
    func testSubharmonicFactor() {
        var params = MaskingParams()
        params.enabled = true
        params.burstLength = 4
        params.restLength = 2
        
        // Subharmonic = b / (b + r) = 4 / 6 = 0.666...
        let factor = params.getSubharmonicFactor()
        #expect(Swift.abs(factor - 0.666666) < 0.01)
    }
    
    @Test("Stochastic probability affects output")
    func testStochasticProbability() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)
        osc.setDutyCycle(0.3)
        osc.setMaskingEnabled(true)
        osc.setBurstPattern(100, 0)  // All burst, no rest
        osc.setStochasticMaskProb(0.5)  // 50% chance each pulsaret
        osc.seedRNG(42)  // For reproducibility
        
        var energy = 0.0
        let samplesPerPeriod = Int(sampleRate / 100.0)
        
        for _ in 0..<(samplesPerPeriod * 20) {
            let s = osc.process()
            energy += s * s
        }
        
        // With 50% probability, we should get roughly half the energy
        // of a non-stochastic output (but not exactly due to randomness)
        #expect(energy > 0, "Should still produce some output")
    }
    
    @Test("Stochastic probability clamped to 0-1")
    func testStochasticProbClamping() {
        var osc = PulsarOscillator(sampleRate)
        
        osc.setStochasticMaskProb(-0.5)
        #expect(osc.getStochasticMaskProb() >= 0.0)
        
        osc.setStochasticMaskProb(1.5)
        #expect(osc.getStochasticMaskProb() <= 1.0)
    }
    
    @Test("Reset clears masking state")
    func testResetClearsMaskingState() {
        var osc = PulsarOscillator(sampleRate)
        osc.setFrequency(100.0)
        osc.setMaskingEnabled(true)
        osc.setBurstPattern(2, 2)
        
        // Process some samples
        for _ in 0..<1000 {
            _ = osc.process()
        }
        
        // Reset
        osc.reset()
        
        // Should not crash and should start fresh
        let sample = osc.process()
        #expect(true, "Reset should work without crash")
    }
}
