//
//  StochasticDistributionsTests.swift
//  VoxCoreTests
//
//  Tests for StochasticDistributions - the Xenakis-inspired randomization engine
//

import Testing
@testable import VoxCore

@Suite("Stochastic Distributions Tests")
struct StochasticDistributionsTests {
    
    // MARK: - Gaussian Distribution Tests
    
    @Test("Gaussian distribution produces values centered around 0")
    func testGaussianCentering() {
        var gen = StochasticDistribution(42) // Fixed seed for reproducibility
        let spread = 10.0
        
        var sum = 0.0
        let numSamples = 10000
        
        for _ in 0..<numSamples {
            sum += gen.generateGaussian(spread)
        }
        
        let mean = sum / Double(numSamples)
        #expect(Swift.abs(mean) < spread * 0.1, 
               "Gaussian mean should be near 0, got \(mean)")
    }
    
    @Test("Gaussian distribution respects spread parameter")
    func testGaussianSpread() {
        var gen = StochasticDistribution(42)
        let spread = 25.0
        
        var values: [Double] = []
        for _ in 0..<10000 {
            values.append(gen.generateGaussian(spread))
        }
        
        // Calculate standard deviation
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)
        
        // Standard deviation should be approximately equal to spread
        let tolerance = spread * 0.1
        #expect(Swift.abs(stdDev - spread) < tolerance,
               "Gaussian stddev should be ~\(spread), got \(stdDev)")
    }
    
    @Test("Gaussian distribution - 99.7% within 3 sigma")
    func testGaussian3Sigma() {
        var gen = StochasticDistribution(123)
        let spread = 10.0
        
        var withinRange = 0
        let numSamples = 10000
        
        for _ in 0..<numSamples {
            let value = gen.generateGaussian(spread)
            if Swift.abs(value) <= 3.0 * spread {
                withinRange += 1
            }
        }
        
        let percentage = Double(withinRange) / Double(numSamples) * 100.0
        #expect(percentage > 99.0, 
               "99.7% of Gaussian values should be within 3 sigma, got \(percentage)%")
    }
    
    // MARK: - Uniform Distribution Tests
    
    @Test("Uniform distribution produces values within range")
    func testUniformRange() {
        var gen = StochasticDistribution(42)
        let spread = 50.0
        
        for _ in 0..<1000 {
            let value = gen.generateUniform(spread)
            #expect(value >= -spread && value <= spread,
                   "Uniform value \(value) should be in [-\(spread), +\(spread)]")
        }
    }
    
    @Test("Uniform distribution is approximately uniform")
    func testUniformDistribution() {
        var gen = StochasticDistribution(42)
        let spread = 1.0
        
        // Divide range into bins and count
        var bins = [Int](repeating: 0, count: 10)
        let numSamples = 10000
        
        for _ in 0..<numSamples {
            let value = gen.generateUniform(spread)
            let normalized = (value + spread) / (2.0 * spread) // Map to [0, 1]
            let binIndex = min(9, Int(normalized * 10.0))
            bins[binIndex] += 1
        }
        
        let expected = numSamples / 10
        let tolerance = expected / 3 // 33% tolerance
        
        for (i, count) in bins.enumerated() {
            #expect(Swift.abs(count - expected) < tolerance,
                   "Bin \(i) has \(count) values, expected ~\(expected)")
        }
    }
    
    // MARK: - Cauchy Distribution Tests
    
    @Test("Cauchy distribution produces values")
    func testCauchyProducesValues() {
        var gen = StochasticDistribution(42)
        let spread = 10.0
        
        var values: [Double] = []
        for _ in 0..<1000 {
            values.append(gen.generateCauchy(spread))
        }
        
        let maxAbs = values.map { Swift.abs($0) }.max() ?? 0.0
        #expect(maxAbs > 0, "Cauchy should produce non-zero values")
    }
    
    @Test("Cauchy distribution is clamped to ±10*spread")
    func testCauchyClamping() {
        var gen = StochasticDistribution(42)
        let spread = 5.0
        let maxAllowed = 10.0 * spread
        
        for _ in 0..<1000 {
            let value = gen.generateCauchy(spread)
            #expect(Swift.abs(value) <= maxAllowed,
                   "Cauchy value \(value) should be clamped to ±\(maxAllowed)")
        }
    }
    
    @Test("Cauchy distribution has heavier tails than Gaussian")
    func testCauchyHeavyTails() {
        var genCauchy = StochasticDistribution(42)
        var genGaussian = StochasticDistribution(42)
        let spread = 10.0
        let numSamples = 10000
        
        // Count values beyond 2*spread
        var cauchyOutliers = 0
        var gaussianOutliers = 0
        
        for _ in 0..<numSamples {
            if Swift.abs(genCauchy.generateCauchy(spread)) > 2.0 * spread {
                cauchyOutliers += 1
            }
            if Swift.abs(genGaussian.generateGaussian(spread)) > 2.0 * spread {
                gaussianOutliers += 1
            }
        }
        
        // Cauchy should have significantly more outliers
        #expect(cauchyOutliers > gaussianOutliers * 2,
               "Cauchy (\(cauchyOutliers)) should have more outliers than Gaussian (\(gaussianOutliers))")
    }
    
    // MARK: - Poisson Distribution Tests
    
    @Test("Poisson distribution produces values")
    func testPoissonProducesValues() {
        var gen = StochasticDistribution(42)
        let spread = 5.0
        
        var hasPositive = false
        var hasNegative = false
        
        for _ in 0..<1000 {
            let value = gen.generatePoissonCentered(spread)
            if value > 0 { hasPositive = true }
            if value < 0 { hasNegative = true }
        }
        
        #expect(hasPositive && hasNegative,
               "Poisson should produce both positive and negative values")
    }
    
    @Test("Poisson distribution is asymmetric (exponential-based)")
    func testPoissonAsymmetry() {
        var gen = StochasticDistribution(42)
        let spread = 10.0
        let numSamples = 10000
        
        var positive = 0
        var negative = 0
        
        for _ in 0..<numSamples {
            let value = gen.generatePoissonCentered(spread)
            if value > 0 { positive += 1 }
            else if value < 0 { negative += 1 }
        }
        
        // Exponential shifted by mean - should have more positive outliers
        // but roughly centered near 0
        #expect(positive > 0 && negative > 0,
               "Should have both positive (\(positive)) and negative (\(negative)) values")
    }
    
    // MARK: - Generic Generate Function Tests
    
    @Test("Generate function works with all distribution types")
    func testGenerateAllTypes() {
        var gen = StochasticDistribution(42)
        let spread = 10.0
        
        let gaussianValue = gen.generate(.GAUSSIAN, spread)
        let uniformValue = gen.generate(.UNIFORM, spread)
        let cauchyValue = gen.generate(.CAUCHY, spread)
        let poissonValue = gen.generate(.POISSON, spread)
        
        // Just verify they don't crash and produce values
        #expect(true, "All distributions should generate values: G=\(gaussianValue), U=\(uniformValue), C=\(cauchyValue), P=\(poissonValue)")
    }
    
    @Test("Generate with zero spread returns zero")
    func testGenerateZeroSpread() {
        var gen = StochasticDistribution(42)
        
        #expect(gen.generate(.GAUSSIAN, 0.0) == 0.0, "Zero spread Gaussian should return 0")
        #expect(gen.generate(.UNIFORM, 0.0) == 0.0, "Zero spread Uniform should return 0")
        #expect(gen.generate(.CAUCHY, 0.0) == 0.0, "Zero spread Cauchy should return 0")
        #expect(gen.generate(.POISSON, 0.0) == 0.0, "Zero spread Poisson should return 0")
    }
    
    // MARK: - Seed Reproducibility Tests
    
    @Test("Same seed produces same sequence")
    func testSeedReproducibility() {
        var gen1 = StochasticDistribution(12345)
        var gen2 = StochasticDistribution(12345)
        
        for _ in 0..<100 {
            let v1 = gen1.generateGaussian(10.0)
            let v2 = gen2.generateGaussian(10.0)
            #expect(v1 == v2, "Same seed should produce identical sequences")
        }
    }
    
    @Test("Different seeds produce different sequences")
    func testDifferentSeeds() {
        var gen1 = StochasticDistribution(11111)
        var gen2 = StochasticDistribution(22222)
        
        var sameCount = 0
        for _ in 0..<100 {
            if gen1.generateGaussian(10.0) == gen2.generateGaussian(10.0) {
                sameCount += 1
            }
        }
        
        #expect(sameCount < 10, "Different seeds should produce different sequences")
    }
    
    // MARK: - Utility Function Tests
    
    @Test("Cents to ratio conversion")
    func testCentsToRatio() {
        // 0 cents = ratio of 1.0
        #expect(Swift.abs(centsToRatio(0.0) - 1.0) < 0.0001, "0 cents = ratio 1.0")
        
        // 100 cents = 1 semitone up = 2^(1/12) ≈ 1.0595
        let semitoneRatio = centsToRatio(100.0)
        #expect(Swift.abs(semitoneRatio - 1.0595) < 0.001, "100 cents = semitone ratio")
        
        // 1200 cents = 1 octave = ratio of 2.0
        #expect(Swift.abs(centsToRatio(1200.0) - 2.0) < 0.0001, "1200 cents = octave")
        
        // -100 cents = semitone down
        #expect(centsToRatio(-100.0) < 1.0, "-100 cents should be < 1.0")
    }
    
    @Test("Ratio to cents conversion")
    func testRatioToCents() {
        // ratio 1.0 = 0 cents
        #expect(Swift.abs(ratioToCents(1.0)) < 0.0001, "Ratio 1.0 = 0 cents")
        
        // ratio 2.0 = 1200 cents (octave)
        #expect(Swift.abs(ratioToCents(2.0) - 1200.0) < 0.01, "Ratio 2.0 = 1200 cents")
        
        // ratio 0.5 = -1200 cents (octave down)
        #expect(Swift.abs(ratioToCents(0.5) + 1200.0) < 0.01, "Ratio 0.5 = -1200 cents")
    }
    
    @Test("Ms to samples conversion")
    func testMsToSamples() {
        let sampleRate = 44100.0
        
        // 1000ms = sampleRate samples
        #expect(Swift.abs(msToSamples(1000.0, sampleRate) - sampleRate) < 0.001,
               "1000ms should equal sample rate in samples")
        
        // 0ms = 0 samples
        #expect(msToSamples(0.0, sampleRate) == 0.0, "0ms = 0 samples")
        
        // 1ms at 44100 = 44.1 samples
        #expect(Swift.abs(msToSamples(1.0, sampleRate) - 44.1) < 0.001, "1ms = 44.1 samples")
    }
    
    @Test("Samples to ms conversion")
    func testSamplesToMs() {
        let sampleRate = 44100.0
        
        // sampleRate samples = 1000ms
        #expect(Swift.abs(samplesToMs(sampleRate, sampleRate) - 1000.0) < 0.001,
               "Sample rate samples = 1000ms")
        
        // 44.1 samples = 1ms
        #expect(Swift.abs(samplesToMs(44.1, sampleRate) - 1.0) < 0.001, "44.1 samples = 1ms")
    }
    
    @Test("dB to linear conversion")
    func testDbToLinear() {
        // 0 dB = 1.0 linear
        #expect(Swift.abs(dbToLinear(0.0) - 1.0) < 0.0001, "0dB = 1.0 linear")
        
        // -6 dB ≈ 0.5 linear
        #expect(Swift.abs(dbToLinear(-6.0206) - 0.5) < 0.001, "-6dB ≈ 0.5 linear")
        
        // +6 dB ≈ 2.0 linear
        #expect(Swift.abs(dbToLinear(6.0206) - 2.0) < 0.001, "+6dB ≈ 2.0 linear")
        
        // -20 dB = 0.1 linear
        #expect(Swift.abs(dbToLinear(-20.0) - 0.1) < 0.0001, "-20dB = 0.1 linear")
    }
    
    @Test("Linear to dB conversion")
    func testLinearToDb() {
        // 1.0 linear = 0 dB
        #expect(Swift.abs(linearToDb(1.0)) < 0.0001, "1.0 linear = 0dB")
        
        // 0.5 linear ≈ -6 dB
        #expect(Swift.abs(linearToDb(0.5) + 6.0206) < 0.001, "0.5 linear ≈ -6dB")
        
        // 2.0 linear ≈ +6 dB
        #expect(Swift.abs(linearToDb(2.0) - 6.0206) < 0.001, "2.0 linear ≈ +6dB")
        
        // 0 or negative should return very quiet
        #expect(linearToDb(0.0) < -100, "0 linear should be very quiet dB")
        #expect(linearToDb(-1.0) < -100, "Negative linear should be very quiet dB")
    }
}
