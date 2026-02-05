//
//  ADSREnvelope.h
//  VoxCore
//
//  ADSR Envelope Generator
//  Analog-style exponential curves (RC circuit behavior like SH-101)
//

#pragma once

#ifdef __cplusplus

#include <algorithm>
#include <cmath>

class ADSREnvelope {
public:
    enum class State {
        IDLE,
        ATTACK,
        DECAY,
        SUSTAIN,
        RELEASE
    };
    
    ADSREnvelope(double sampleRate = 44100.0) 
        : mSampleRate(sampleRate),
          mState(State::IDLE),
          mCurrentLevel(0.0),
          mSmoothedOutput(0.0),
          mAttackTime(0.01),    // 10ms default
          mDecayTime(0.1),      // 100ms default
          mSustainLevel(0.7),   // 70% default
          mReleaseTime(0.3),    // 300ms default
          mAttackCoeff(0.0),
          mDecayCoeff(0.0),
          mReleaseCoeff(0.0),
          mSmoothingCoeff(0.99) {
        calculateCoefficients();
        calculateSmoothingCoeff();
    }
    
    // Set sample rate
    void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        calculateCoefficients();
        calculateSmoothingCoeff();
    }
    
    // ADSR parameter setters (times in seconds)
    void setAttackTime(double seconds) {
        mAttackTime = std::max(0.001, seconds); // Minimum 1ms
        calculateAttackCoeff();
    }
    
    void setDecayTime(double seconds) {
        mDecayTime = std::max(0.001, seconds);
        calculateDecayCoeff();
    }
    
    void setSustainLevel(double level) {
        mSustainLevel = std::max(0.0, std::min(1.0, level));
    }
    
    void setReleaseTime(double seconds) {
        mReleaseTime = std::max(0.001, seconds);
        calculateReleaseCoeff();
    }
    
    // ADSR parameter getters
    double getAttackTime() const { return mAttackTime; }
    double getDecayTime() const { return mDecayTime; }
    double getSustainLevel() const { return mSustainLevel; }
    double getReleaseTime() const { return mReleaseTime; }
    
    // Get current envelope state
    State getState() const { return mState; }
    double getCurrentLevel() const { return mCurrentLevel; }
    
    // Gate control
    void noteOn() {
        // For legato behavior, always retrigger to attack phase
        // but continue from current level for smooth transitions
        mState = State::ATTACK;
    }
    
    void noteOff() {
        if (mState != State::IDLE) {
            mState = State::RELEASE;
        }
    }
    
    // Reset envelope to idle state
    void reset() {
        mState = State::IDLE;
        mCurrentLevel = 0.0;
        mSmoothedOutput = 0.0;
    }
    
    // Process next sample - analog RC circuit style exponential curves
    double process() {
        switch (mState) {
            case State::IDLE:
                mCurrentLevel = 0.0;
                break;
                
            case State::ATTACK:
                // Exponential rise toward target above 1.0
                // We aim for kAttackTarget so we actually reach 1.0
                // This mimics an RC circuit charging toward a higher voltage
                mCurrentLevel = mCurrentLevel + (kAttackTarget - mCurrentLevel) * mAttackCoeff;
                if (mCurrentLevel >= 0.999) {
                    mCurrentLevel = 1.0;
                    mState = State::DECAY;
                }
                break;
                
            case State::DECAY:
                // Exponential decay toward sustain level
                // Classic RC discharge curve
                mCurrentLevel = mCurrentLevel + (mSustainLevel - mCurrentLevel) * mDecayCoeff;
                // Check if we're close enough to sustain (within 0.1% or below)
                if (std::abs(mCurrentLevel - mSustainLevel) < 0.001) {
                    mCurrentLevel = mSustainLevel;
                    mState = State::SUSTAIN;
                }
                break;
                
            case State::SUSTAIN:
                mCurrentLevel = mSustainLevel;
                break;
                
            case State::RELEASE:
                // Exponential decay toward zero
                // Classic RC discharge curve - fast initial drop, long tail
                mCurrentLevel = mCurrentLevel * (1.0 - mReleaseCoeff);
                if (mCurrentLevel < 0.0001) {
                    mCurrentLevel = 0.0;
                    mState = State::IDLE;
                }
                break;
        }
        
        // Apply one-pole smoothing filter to remove clicks and discontinuities
        // This smooths out any sudden jumps in envelope level
        mSmoothedOutput = mSmoothedOutput * mSmoothingCoeff + mCurrentLevel * (1.0 - mSmoothingCoeff);
        
        return mSmoothedOutput;
    }
    
    // Process block of samples
    void processBlock(double* output, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            output[i] = process();
        }
    }
    
private:
    // Attack target slightly above 1.0 so exponential curve actually reaches 1.0
    // In a real RC circuit, you charge toward a higher voltage than your threshold
    static constexpr double kAttackTarget = 1.2;
    
    // Time constant multiplier - how many time constants to reach ~99.3% of target
    // 5 time constants = 99.3% of final value (e^-5 ≈ 0.007)
    static constexpr double kTimeConstantMultiplier = 5.0;
    
    void calculateCoefficients() {
        calculateAttackCoeff();
        calculateDecayCoeff();
        calculateReleaseCoeff();
    }
    
    void calculateAttackCoeff() {
        // Coefficient for exponential approach
        // We want to reach ~99% of target in the specified attack time
        // coeff = 1 - e^(-1 / (tau * sampleRate))
        // where tau = attackTime / kTimeConstantMultiplier
        double tau = mAttackTime / kTimeConstantMultiplier;
        mAttackCoeff = 1.0 - std::exp(-1.0 / (tau * mSampleRate));
    }
    
    void calculateDecayCoeff() {
        // Same formula for decay toward sustain level
        double tau = mDecayTime / kTimeConstantMultiplier;
        mDecayCoeff = 1.0 - std::exp(-1.0 / (tau * mSampleRate));
    }
    
    void calculateReleaseCoeff() {
        // Same formula for release toward zero
        double tau = mReleaseTime / kTimeConstantMultiplier;
        mReleaseCoeff = 1.0 - std::exp(-1.0 / (tau * mSampleRate));
    }
    
    void calculateSmoothingCoeff() {
        // Calculate one-pole filter coefficient for ~1ms smoothing time
        // This provides click-free envelope transitions without affecting musical timing
        double smoothingTimeMs = 1.0; // 1ms smoothing
        double smoothingTimeSamples = (smoothingTimeMs / 1000.0) * mSampleRate;
        mSmoothingCoeff = std::exp(-1.0 / smoothingTimeSamples);
    }
    
    double mSampleRate;
    State mState;
    double mCurrentLevel;
    double mSmoothedOutput;  // One-pole filtered output for click-free transitions
    
    // ADSR parameters
    double mAttackTime;      // Time to reach full level (seconds)
    double mDecayTime;       // Time to reach sustain level (seconds)
    double mSustainLevel;    // Level to hold while gate is on (0-1)
    double mReleaseTime;     // Time to reach zero after gate off (seconds)
    
    // Calculated coefficients for exponential curves (per sample)
    double mAttackCoeff;
    double mDecayCoeff;
    double mReleaseCoeff;
    
    // Smoothing filter coefficient for click prevention
    double mSmoothingCoeff;
};

#endif // __cplusplus
