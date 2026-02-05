//
//  StochasticDistribution.h
//  VoxCore
//
//  Probability distributions for stochastic grain synthesis (Xenakis-inspired)
//  Provides Gaussian, Uniform, Cauchy, and Poisson distributions
//
//  Phase 5: Extended with utility functions for per-grain randomization
//

#pragma once

#ifdef __cplusplus

#include <cmath>
#include <random>
#include <algorithm>
#include <numbers>

// Distribution types for stochastic parameters
enum class DistributionType {
    GAUSSIAN,   // Bell curve - most values near center
    UNIFORM,    // Equal probability across range
    CAUCHY,     // Heavy tails - more extreme outliers
    POISSON     // For timing/count events
};

class StochasticDistribution {
public:
    StochasticDistribution()
        : mGenerator(std::random_device{}())
        , mUniform(0.0, 1.0)
        , mNormal(0.0, 1.0)
    {}
    
    StochasticDistribution(unsigned int seed)
        : mGenerator(seed)
        , mUniform(0.0, 1.0)
        , mNormal(0.0, 1.0)
    {}
    
    // Seed the random generator for reproducible results
    void seed(unsigned int s) {
        mGenerator.seed(s);
    }
    
    // Generate value from specified distribution with specified spread
    // spread = standard deviation (Gaussian), half-width (Uniform), scale (Cauchy), mean (Poisson)
    // Returns value centered around 0 (except Poisson)
    double generate(DistributionType type, double spread) {
        if (spread <= 0.0) return 0.0;
        
        switch (type) {
            case DistributionType::GAUSSIAN:
                return generateGaussian(spread);
            case DistributionType::UNIFORM:
                return generateUniform(spread);
            case DistributionType::CAUCHY:
                return generateCauchy(spread);
            case DistributionType::POISSON:
                return generatePoissonCentered(spread);
            default:
                return 0.0;
        }
    }
    
    // Generate Gaussian (normal) distributed value
    // spread = standard deviation
    // Returns: typically within ±3*spread (99.7% of values)
    double generateGaussian(double spread = 1.0) {
        return mNormal(mGenerator) * spread;
    }
    
    // Generate uniformly distributed value
    // spread = half-width of distribution
    // Returns: value in range [-spread, +spread]
    double generateUniform(double spread = 1.0) {
        return (mUniform(mGenerator) * 2.0 - 1.0) * spread;
    }
    
    // Generate Cauchy distributed value (heavy tails)
    // spread = scale parameter (half-width at half-maximum)
    // Returns: value with heavy tails, clamped to ±10*spread
    double generateCauchy(double spread = 1.0) {
        double u = mUniform(mGenerator);
        // Avoid exact 0 and 1 to prevent infinity
        u = std::clamp(u, 0.001, 0.999);
        double value = spread * std::tan(std::numbers::pi * (u - 0.5));
        // Clamp to prevent extreme outliers
        return std::clamp(value, -10.0 * spread, 10.0 * spread);
    }
    
    // Generate Poisson-like timing variation, centered around 0
    // spread = mean inter-arrival time variation
    // Returns: exponentially distributed, shifted to center around 0
    double generatePoissonCentered(double spread = 1.0) {
        double u = mUniform(mGenerator);
        u = std::clamp(u, 0.001, 0.999);
        double exponential = -std::log(1.0 - u) * spread;
        // Shift to be centered around 0
        return exponential - spread;
    }
    
    // Generate raw Poisson count (non-negative integer)
    // lambda = expected value
    double generatePoissonCount(double lambda = 1.0) {
        if (lambda <= 0.0) return 0.0;
        
        // Knuth algorithm for small lambda
        if (lambda < 30.0) {
            double L = std::exp(-lambda);
            int k = 0;
            double p = 1.0;
            do {
                k++;
                p *= mUniform(mGenerator);
            } while (p > L);
            return static_cast<double>(k - 1);
        } else {
            // Normal approximation for large lambda
            return std::max(0.0, std::round(lambda + std::sqrt(lambda) * mNormal(mGenerator)));
        }
    }
    
    // Generate a raw uniform value [0, 1)
    double uniform01() {
        return mUniform(mGenerator);
    }
    
    // Generate a raw Gaussian value (mean=0, stddev=1)
    double gaussian01() {
        return mNormal(mGenerator);
    }
    
    // Convenience: generate value scaled to a specific range
    // distribution output mapped to [min, max]
    double generateScaled(DistributionType type, double min, double max, double spread = 1.0) {
        double normalized = generate(type, spread) / spread;  // Normalize to ~[-1, 1]
        double center = (min + max) / 2.0;
        double range = (max - min) / 2.0;
        return center + normalized * range;
    }
    
    // Generate bipolar value with specified amount (0-1)
    // amount = 0: always returns 0
    // amount = 1: full distribution range
    double generateWithAmount(DistributionType type, double amount, double spread = 1.0) {
        if (amount <= 0.0) return 0.0;
        return generate(type, spread) * amount;
    }
    
private:
    std::mt19937 mGenerator;
    std::uniform_real_distribution<double> mUniform;
    std::normal_distribution<double> mNormal;
};

// Alias for backwards compatibility
using StochasticGenerator = StochasticDistribution;

// ═══════════════════════════════════════════════════════════════════════════
// Utility functions for working with audio and stochastic parameters
// ═══════════════════════════════════════════════════════════════════════════

// Convert cents to frequency ratio: 100 cents = 1 semitone = 2^(1/12)
inline double centsToRatio(double cents) {
    return std::pow(2.0, cents / 1200.0);
}

// Convert frequency ratio to cents
inline double ratioToCents(double ratio) {
    if (ratio <= 0.0) return 0.0;
    return 1200.0 * std::log2(ratio);
}

// Convert milliseconds to samples
inline double msToSamples(double ms, double sampleRate) {
    return ms * sampleRate / 1000.0;
}

// Convert samples to milliseconds
inline double samplesToMs(double samples, double sampleRate) {
    return samples * 1000.0 / sampleRate;
}

// Convert dB to linear amplitude
inline double dbToLinear(double db) {
    return std::pow(10.0, db / 20.0);
}

// Convert linear amplitude to dB
inline double linearToDb(double linear) {
    if (linear <= 0.0) return -120.0;  // Very quiet
    return 20.0 * std::log10(linear);
}

#endif // __cplusplus
