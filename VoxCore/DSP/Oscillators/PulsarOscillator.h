//
//  PulsarOscillator.h
//  VoxCore
//
//  Pulsar synthesis oscillator based on Curtis Roads' Microsound techniques
//  Generates periodic trains of sonic particles (pulsarets)
//

#pragma once

#ifdef __cplusplus

#include <cmath>
#include <algorithm>
#include <numbers>

class PulsarOscillator {
public:
    // Pulsaret waveform shapes
    enum class Shape {
        GAUSSIAN,
        RAISED_COSINE,
        SINE,
        TRIANGLE
    };
    
    PulsarOscillator(double sampleRate = 44100.0)
        : mSampleRate(sampleRate)
        , mPhase(0.0)
        , mPhaseIncrement(0.0)
        , mFrequency(440.0)
        , mDutyCycle(0.2)
        , mShape(Shape::RAISED_COSINE)
    {
        setFrequency(440.0);
    }
    
    void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        setFrequency(mFrequency);
    }
    
    void setFrequency(double frequency) {
        mFrequency = std::max(0.1, std::min(frequency, mSampleRate * 0.45));
        mPhaseIncrement = mFrequency / mSampleRate;
    }
    
    double getFrequency() const { return mFrequency; }
    
    // Set duty cycle (pulsaret width as fraction of period)
    // 0.01 to 1.0 - smaller values = more impulsive
    void setDutyCycle(double dutyCycle) {
        mDutyCycle = std::max(0.01, std::min(1.0, dutyCycle));
    }
    
    double getDutyCycle() const { return mDutyCycle; }
    
    void setShape(Shape shape) {
        mShape = shape;
    }
    
    Shape getShape() const { return mShape; }
    
    void reset() {
        mPhase = 0.0;
    }
    
    // Process one sample
    double process() {
        double output = 0.0;
        
        // Check if we're within the pulsaret window
        if (mPhase < mDutyCycle) {
            // Normalize phase within pulsaret (0 to 1)
            double pulsaretPhase = mPhase / mDutyCycle;
            
            switch (mShape) {
                case Shape::GAUSSIAN:
                    output = generateGaussian(pulsaretPhase);
                    break;
                case Shape::RAISED_COSINE:
                    output = generateRaisedCosine(pulsaretPhase);
                    break;
                case Shape::SINE:
                    output = generateSine(pulsaretPhase);
                    break;
                case Shape::TRIANGLE:
                    output = generateTriangle(pulsaretPhase);
                    break;
            }
        }
        // else: outside pulsaret window, output is 0 (silence between pulses)
        
        // Update phase
        mPhase += mPhaseIncrement;
        if (mPhase >= 1.0) {
            mPhase -= 1.0;
        }
        
        return output;
    }
    
    void processBlock(double* output, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            output[i] = process();
        }
    }
    
private:
    // Gaussian window (bell curve)
    double generateGaussian(double phase) {
        // Map 0-1 to -3 to +3 standard deviations
        double x = (phase - 0.5) * 6.0;
        return std::exp(-0.5 * x * x);
    }
    
    // Raised cosine (Hann-like envelope * sine carrier)
    double generateRaisedCosine(double phase) {
        // Hann window
        double envelope = 0.5 * (1.0 - std::cos(2.0 * std::numbers::pi * phase));
        // Sine carrier at the fundamental
        double carrier = std::sin(2.0 * std::numbers::pi * phase);
        return envelope * carrier;
    }
    
    // Full sine wave within the pulsaret
    double generateSine(double phase) {
        return std::sin(2.0 * std::numbers::pi * phase);
    }
    
    // Triangle wave within the pulsaret
    double generateTriangle(double phase) {
        if (phase < 0.5) {
            return 4.0 * phase - 1.0;
        } else {
            return 3.0 - 4.0 * phase;
        }
    }
    
    double mSampleRate;
    double mPhase;
    double mPhaseIncrement;
    double mFrequency;
    double mDutyCycle;
    Shape mShape;
};

#endif // __cplusplus
