//
//  Oscillator.h
//  VoxCore
//
//  Base oscillator class
//

#pragma once

#ifdef __cplusplus

#include <numbers>
#include <cmath>
#include <algorithm>

// Base oscillator class that all oscillator types inherit from
class Oscillator {
public:
    // Supported waveform types
    enum class WaveformType {
        SINE,
        SAW,
        SQUARE,
        TRIANGLE,
        NOISE
    };
    
    Oscillator(double sampleRate = 44100.0) : mSampleRate(sampleRate), mPhase(0.0), mPhaseIncrement(0.0) {}
    virtual ~Oscillator() = default;
    
    // Process a single sample - must be implemented by derived classes
    virtual double process() = 0;
    
    // Reset oscillator state
    virtual void reset() {
        mPhase = 0.0;
        mDidWrap = false;
    }

    // Hard sync - reset phase to 0 (used for oscillator sync)
    virtual void sync() {
        mPhase = 0.0;
    }

    // Check if phase wrapped on last process() call (for hard sync)
    bool didWrap() const {
        return mDidWrap;
    }

    // Set oscillator frequency
    virtual void setFrequency(double frequency) {
        // Clamp to prevent aliasing and extreme low frequencies
        const double clampedFreq = std::max(0.01, std::min(frequency, mSampleRate * 0.49));
        mFrequency = clampedFreq;
        // Phase increment per sample
        mPhaseIncrement = mFrequency / mSampleRate;
    }
    
    // Get current frequency
    double getFrequency() const {
        return mFrequency;
    }
    
    // Set sample rate
    virtual void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        // Recalculate phase increment for new sample rate
        setFrequency(mFrequency);
    }
    
    // Get sample rate
    double getSampleRate() const {
        return mSampleRate;
    }
    
protected:
    // Update phase and handle wraparound, track if wrap occurred for sync
    inline void updatePhase() {
        mPhase += mPhaseIncrement;
        mDidWrap = false;
        if (mPhase >= 1.0) {
            mPhase -= 1.0;
            mDidWrap = true;
        }
    }

    double mSampleRate;     // Sample rate in Hz
    double mFrequency = 440.0; // Oscillator frequency in Hz
    double mPhase;          // Current phase [0.0, 1.0)
    double mPhaseIncrement; // Phase increment per sample
    bool mDidWrap = false;  // True if phase wrapped on last update (for hard sync)
};

#endif // __cplusplus
