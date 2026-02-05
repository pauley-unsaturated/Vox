//
//  StochasticDistributions.h
//  VoxCore
//
//  Stochastic distribution generators for per-grain randomization
//  Inspired by Iannis Xenakis's stochastic music theories
//

#pragma once

#ifdef __cplusplus

#include <cmath>
#include <random>
#include <numbers>
#include <algorithm>

// Distribution types for stochastic parameters
enum class DistributionType {
    GAUSSIAN,   // Normal distribution - bell curve, natural variation
    UNIFORM,    // Equal probability across range
    CAUCHY,     // Heavy tails - occasional extreme values
    POISSON     // Discrete events in time - good for timing jitter
};

class StochasticGenerator {
public:
    StochasticGenerator(unsigned int seed = 0) 
        : mRng(seed == 0 ? std::random_device{}() : seed)
        , mUniformDist(0.0, 1.0)
        , mGaussianDist(0.0, 1.0)
    {}
    
    // Seed the RNG for reproducibility
    void seed(unsigned int s) {
        mRng.seed(s);
    }
    
    // Generate value from specified distribution
    // Returns a value centered around 0 with the specified spread (standard deviation for Gaussian)
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
                return generatePoisson(spread);
            default:
                return 0.0;
        }
    }
    
    // Generate Gaussian (normal) distributed value
    // spread = standard deviation
    // Returns: typically within ±3*spread (99.7% of values)
    double generateGaussian(double spread) {
        return mGaussianDist(mRng) * spread;
    }
    
    // Generate uniformly distributed value
    // spread = half-width of distribution
    // Returns: value in range [-spread, +spread]
    double generateUniform(double spread) {
        return (mUniformDist(mRng) * 2.0 - 1.0) * spread;
    }
    
    // Generate Cauchy distributed value (heavy tails)
    // spread = scale parameter (half-width at half-maximum)
    // Returns: value with heavy tails (occasional extreme outliers)
    // NOTE: Cauchy has undefined mean and variance, so we clamp to ±10*spread
    double generateCauchy(double spread) {
        // Inverse CDF method: x = scale * tan(π * (U - 0.5))
        double u = mUniformDist(mRng);
        // Avoid exact 0 and 1 to prevent infinity
        u = std::max(0.001, std::min(0.999, u));
        double value = spread * std::tan(std::numbers::pi * (u - 0.5));
        // Clamp to prevent extreme outliers
        return std::max(-10.0 * spread, std::min(10.0 * spread, value));
    }
    
    // Generate Poisson-like timing variation
    // spread = mean inter-arrival time variation
    // Returns: exponentially distributed positive value, shifted to center around 0
    double generatePoisson(double spread) {
        // Exponential distribution (inter-arrival times for Poisson process)
        // Using inverse CDF: -ln(1-U) * lambda
        double u = mUniformDist(mRng);
        u = std::max(0.001, std::min(0.999, u)); // Avoid log(0)
        double exponential = -std::log(1.0 - u) * spread;
        // Shift to be centered around 0 (subtract mean of exponential = spread)
        return exponential - spread;
    }
    
    // Generate a raw uniform value [0, 1) - useful for other purposes
    double uniform01() {
        return mUniformDist(mRng);
    }
    
    // Generate a raw Gaussian value (mean=0, stddev=1)
    double gaussian01() {
        return mGaussianDist(mRng);
    }
    
private:
    std::mt19937 mRng;
    std::uniform_real_distribution<double> mUniformDist;
    std::normal_distribution<double> mGaussianDist;
};

// Utility functions for working with distributions

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
