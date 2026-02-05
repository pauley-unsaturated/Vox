//
//  DriftGenerator.h
//  VoxCore
//
//  Phase 4.2: Drift Engine - Ultra-slow random evolution
//  Inspired by Radigue/Eno's slow music principles
//
//  Modes:
//  - RandomWalk: Brownian motion, bounded
//  - Breath: Organic rise/fall pattern
//  - Tide: Slow sine, very low frequency
//

#pragma once

#ifdef __cplusplus

#include <cmath>
#include <numbers>
#include <random>
#include <algorithm>

class DriftGenerator {
public:
    enum class Mode {
        RandomWalk,  // Brownian motion, bounded (-1 to +1)
        Breath,      // Organic rise/fall pattern
        Tide         // Very slow sine wave
    };
    
    DriftGenerator(double sampleRate = 44100.0)
        : mSampleRate(sampleRate)
        , mMode(Mode::RandomWalk)
        , mRate(0.01)          // 0.01 Hz default (one cycle per 100 seconds)
        , mAmount(1.0)         // Full range
        , mCurrentValue(0.0)
        , mTargetValue(0.0)
        , mPhase(0.0)
        , mBreathPhase(0.0)
        , mBreathDirection(1.0)
        , mSmoothingCoeff(0.0001)
    {
        // Initialize random generator
        std::random_device rd;
        mRandomGen = std::mt19937(rd());
        mRandomDist = std::uniform_real_distribution<double>(-1.0, 1.0);
        mGaussianDist = std::normal_distribution<double>(0.0, 0.1);
        
        updatePhaseIncrement();
        updateSmoothingCoeff();
    }
    
    void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        updatePhaseIncrement();
        updateSmoothingCoeff();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Parameters
    // ═══════════════════════════════════════════════════════════════
    
    // Rate: 0.001 Hz to 0.1 Hz (one cycle per 16 min to 10 sec)
    void setRate(double rateHz) {
        mRate = std::max(0.001, std::min(0.1, rateHz));
        updatePhaseIncrement();
        updateSmoothingCoeff();
    }
    
    double getRate() const {
        return mRate;
    }
    
    // Amount: 0.0 to 1.0 (how far parameters drift)
    void setAmount(double amount) {
        mAmount = std::max(0.0, std::min(1.0, amount));
    }
    
    double getAmount() const {
        return mAmount;
    }
    
    // Mode: RandomWalk, Breath, or Tide
    void setMode(Mode mode) {
        mMode = mode;
    }
    
    Mode getMode() const {
        return mMode;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Processing
    // ═══════════════════════════════════════════════════════════════
    
    void reset() {
        mCurrentValue = 0.0;
        mTargetValue = 0.0;
        mPhase = 0.0;
        mBreathPhase = 0.0;
        mBreathDirection = 1.0;
    }
    
    // Process one sample, returns value in range [-1, 1] * amount
    double process() {
        double rawValue = 0.0;
        
        switch (mMode) {
            case Mode::RandomWalk:
                rawValue = processRandomWalk();
                break;
            case Mode::Breath:
                rawValue = processBreath();
                break;
            case Mode::Tide:
                rawValue = processTide();
                break;
        }
        
        // Smooth the output for all modes
        mCurrentValue += (rawValue - mCurrentValue) * mSmoothingCoeff;
        
        // Ensure bounded output
        mCurrentValue = std::max(-1.0, std::min(1.0, mCurrentValue));
        
        return mCurrentValue * mAmount;
    }
    
    // Get current value without advancing
    double getCurrentValue() const {
        return mCurrentValue * mAmount;
    }
    
    // Get raw (unscaled) value
    double getRawValue() const {
        return mCurrentValue;
    }
    
private:
    // Brownian motion with soft boundaries
    double processRandomWalk() {
        // Advance phase
        mPhase += mPhaseIncrement;
        
        // At each "cycle", add random walk step
        if (mPhase >= 1.0) {
            mPhase -= 1.0;
            
            // Gaussian random step
            double step = mGaussianDist(mRandomGen);
            mTargetValue += step;
            
            // Soft boundary reflection - pull back toward center when near edges
            double boundaryForce = -mTargetValue * 0.1;  // Springs back from edges
            mTargetValue += boundaryForce;
            
            // Hard clamp as safety
            mTargetValue = std::max(-1.0, std::min(1.0, mTargetValue));
        }
        
        return mTargetValue;
    }
    
    // Organic breathing pattern - asymmetric rise/fall
    double processBreath() {
        // Advance breath phase
        mBreathPhase += mPhaseIncrement;
        
        // Asymmetric timing: slower rise, faster fall
        double riseTime = 0.6;  // Rise takes 60% of cycle
        
        double value;
        if (mBreathPhase < riseTime) {
            // Rising phase - use smoothstep for organic feel
            double t = mBreathPhase / riseTime;
            value = smoothstep(t);
        } else {
            // Falling phase
            double t = (mBreathPhase - riseTime) / (1.0 - riseTime);
            value = 1.0 - smoothstep(t);
        }
        
        // Add slight random variation to each breath
        if (mBreathPhase >= 1.0) {
            mBreathPhase -= 1.0;
            // Small random offset to next breath amplitude
            mBreathVariation = mRandomDist(mRandomGen) * 0.1;
        }
        
        // Map from [0,1] to [-1,1] with variation
        value = (value * 2.0 - 1.0) * (1.0 + mBreathVariation);
        return std::max(-1.0, std::min(1.0, value));
    }
    
    // Very slow sine wave
    double processTide() {
        // Simple sine wave at ultra-low frequency
        mPhase += mPhaseIncrement;
        if (mPhase >= 1.0) {
            mPhase -= 1.0;
        }
        
        return std::sin(mPhase * std::numbers::pi * 2.0);
    }
    
    // Smooth interpolation curve
    double smoothstep(double t) const {
        t = std::max(0.0, std::min(1.0, t));
        return t * t * (3.0 - 2.0 * t);
    }
    
    void updatePhaseIncrement() {
        mPhaseIncrement = mRate / mSampleRate;
    }
    
    void updateSmoothingCoeff() {
        // Very slow smoothing - corresponds to rate
        // Faster rate = less smoothing needed
        double smoothingTime = 1.0 / (mRate * 10.0);  // 10 smoothing periods per cycle
        double smoothingSamples = smoothingTime * mSampleRate;
        mSmoothingCoeff = 1.0 / std::max(1.0, smoothingSamples);
    }
    
    double mSampleRate;
    Mode mMode;
    double mRate;
    double mAmount;
    double mCurrentValue;
    double mTargetValue;
    double mPhase;
    double mPhaseIncrement = 0.0;
    double mBreathPhase;
    double mBreathDirection;
    double mBreathVariation = 0.0;
    double mSmoothingCoeff;
    
    // Random generators
    std::mt19937 mRandomGen;
    std::uniform_real_distribution<double> mRandomDist;
    std::normal_distribution<double> mGaussianDist;
};

#endif // __cplusplus
