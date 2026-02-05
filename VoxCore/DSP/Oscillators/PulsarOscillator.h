//
//  PulsarOscillator.h
//  VoxCore
//
//  Pulsar synthesis oscillator based on Curtis Roads' Microsound techniques
//  Generates periodic trains of sonic particles (pulsarets)
//
//  Phase 5: Stochastic Cloud Engine (Xenakis-inspired)
//  Per-grain randomization for pitch, timing, formant, pan, and amplitude
//

#pragma once

#ifdef __cplusplus

#include <cmath>
#include <algorithm>
#include <numbers>
#include "../Modulators/StochasticDistribution.h"

// Stochastic parameters structure for per-grain variation
struct StochasticParams {
    // Phase 5.1: Pitch scatter
    double pitchScatterAmount = 0.0;           // 0-100 cents
    DistributionType pitchScatterDistribution = DistributionType::GAUSSIAN;
    
    // Phase 5.2: Timing jitter
    double timingJitter = 0.0;                 // 0-50 ms
    DistributionType timingDistribution = DistributionType::GAUSSIAN;
    
    // Phase 5.3: Formant scatter (applied externally by voice)
    double formantScatter = 0.0;               // 0-200 Hz
    DistributionType formantDistribution = DistributionType::GAUSSIAN;
    
    // Phase 5.4: Pan scatter (applied externally by voice/mixer)
    double panScatter = 0.0;                   // 0-1.0 (100%)
    DistributionType panDistribution = DistributionType::UNIFORM;
    
    // Phase 5.5: Amplitude scatter
    double ampScatter = 0.0;                   // 0-12 dB
    DistributionType ampDistribution = DistributionType::GAUSSIAN;
    
    // Phase 5.7: Global scatter master (scales all scatter amounts)
    double cloudScatter = 1.0;                 // 0-1.0 (100%)
    
    // Phase 5.8: Grain density control (async mode)
    bool asyncMode = false;                    // When true, density is independent of pitch
    double grainDensity = 100.0;               // 20-2000 grains/sec (only when asyncMode=true)
};

// Per-grain state - randomized at the start of each grain
struct GrainState {
    double pitchOffsetCents = 0.0;    // Pitch variation in cents
    double timingOffsetSamples = 0.0; // Timing jitter in samples
    double formantOffsetHz = 0.0;     // Formant variation in Hz
    double panOffset = 0.0;           // Pan variation (-1 to +1)
    double ampMultiplier = 1.0;       // Amplitude variation (linear)
};

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
        , mStochastic()
        , mCurrentGrain()
        , mRng(0)
        , mInGrain(false)
        , mAsyncPhase(0.0)
        , mAsyncPhaseIncrement(0.0)
        , mTimingJitterCounter(0.0)
    {
        setFrequency(440.0);
    }
    
    void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        setFrequency(mFrequency);
        updateAsyncPhaseIncrement();
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
    
    // ═══════════════════════════════════════════════════════════════════
    // Phase 5: Stochastic Parameters
    // ═══════════════════════════════════════════════════════════════════
    
    void setStochasticParams(const StochasticParams& params) {
        mStochastic = params;
        updateAsyncPhaseIncrement();
    }
    
    StochasticParams getStochasticParams() const {
        return mStochastic;
    }
    
    // Phase 5.1: Pitch scatter
    void setPitchScatter(double cents, DistributionType dist = DistributionType::GAUSSIAN) {
        mStochastic.pitchScatterAmount = std::max(0.0, std::min(100.0, cents));
        mStochastic.pitchScatterDistribution = dist;
    }
    
    double getPitchScatterAmount() const { return mStochastic.pitchScatterAmount; }
    DistributionType getPitchScatterDistribution() const { return mStochastic.pitchScatterDistribution; }
    
    // Phase 5.2: Timing jitter
    void setTimingJitter(double ms, DistributionType dist = DistributionType::GAUSSIAN) {
        mStochastic.timingJitter = std::max(0.0, std::min(50.0, ms));
        mStochastic.timingDistribution = dist;
    }
    
    double getTimingJitter() const { return mStochastic.timingJitter; }
    DistributionType getTimingDistribution() const { return mStochastic.timingDistribution; }
    
    // Phase 5.3: Formant scatter
    void setFormantScatter(double hz, DistributionType dist = DistributionType::GAUSSIAN) {
        mStochastic.formantScatter = std::max(0.0, std::min(200.0, hz));
        mStochastic.formantDistribution = dist;
    }
    
    double getFormantScatter() const { return mStochastic.formantScatter; }
    DistributionType getFormantDistribution() const { return mStochastic.formantDistribution; }
    
    // Phase 5.4: Pan scatter
    void setPanScatter(double amount, DistributionType dist = DistributionType::UNIFORM) {
        mStochastic.panScatter = std::max(0.0, std::min(1.0, amount));
        mStochastic.panDistribution = dist;
    }
    
    double getPanScatter() const { return mStochastic.panScatter; }
    DistributionType getPanDistribution() const { return mStochastic.panDistribution; }
    
    // Phase 5.5: Amplitude scatter
    void setAmpScatter(double db, DistributionType dist = DistributionType::GAUSSIAN) {
        mStochastic.ampScatter = std::max(0.0, std::min(12.0, db));
        mStochastic.ampDistribution = dist;
    }
    
    double getAmpScatter() const { return mStochastic.ampScatter; }
    DistributionType getAmpDistribution() const { return mStochastic.ampDistribution; }
    
    // Phase 5.7: Global scatter (master)
    void setCloudScatter(double amount) {
        mStochastic.cloudScatter = std::max(0.0, std::min(1.0, amount));
    }
    
    double getCloudScatter() const { return mStochastic.cloudScatter; }
    
    // Phase 5.8: Grain density (async mode)
    void setAsyncMode(bool enabled) {
        mStochastic.asyncMode = enabled;
        updateAsyncPhaseIncrement();
    }
    
    bool getAsyncMode() const { return mStochastic.asyncMode; }
    
    void setGrainDensity(double grainsPerSecond) {
        mStochastic.grainDensity = std::max(20.0, std::min(2000.0, grainsPerSecond));
        updateAsyncPhaseIncrement();
    }
    
    double getGrainDensity() const { return mStochastic.grainDensity; }
    
    // Get current grain state (for external use - formant/pan applied by voice)
    GrainState getCurrentGrainState() const { return mCurrentGrain; }
    
    // Seed the RNG for reproducible results
    void seedRNG(unsigned int seed) {
        mRng.seed(seed);
    }
    
    void reset() {
        mPhase = 0.0;
        mAsyncPhase = 0.0;
        mInGrain = false;
        mTimingJitterCounter = 0.0;
        mCurrentGrain = GrainState();
    }
    
    // Process one sample
    double process() {
        double output = 0.0;
        
        // Handle timing jitter countdown
        if (mTimingJitterCounter > 0) {
            mTimingJitterCounter -= 1.0;
            advancePhases();
            return 0.0;
        }
        
        // Get the current phase for grain window detection
        // In async mode, use async phase for grain timing
        // In sync mode, use main phase
        double grainPhase = mStochastic.asyncMode ? mAsyncPhase : mPhase;
        
        // Check if we're in the grain window
        bool inGrainWindow = grainPhase < mDutyCycle;
        
        // Detect grain start: entering grain window when we weren't in one
        if (inGrainWindow && !mInGrain) {
            mInGrain = true;
            randomizeGrain();
            
            // Apply timing jitter (delays grain start)
            if (mCurrentGrain.timingOffsetSamples > 0) {
                mTimingJitterCounter = mCurrentGrain.timingOffsetSamples;
                advancePhases();
                return 0.0;
            }
        } else if (!inGrainWindow && mInGrain) {
            // Exiting grain window
            mInGrain = false;
        }
        
        // Generate output if in grain window
        if (inGrainWindow) {
            // Normalize phase within pulsaret (0 to 1)
            double pulsaretPhase = grainPhase / mDutyCycle;
            
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
            
            // Apply amplitude scatter
            output *= mCurrentGrain.ampMultiplier;
        }
        
        // Advance phases
        advancePhases();
        
        return output;
    }
    
    void processBlock(double* output, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            output[i] = process();
        }
    }
    
private:
    void advancePhases() {
        // Always advance main phase (for pitch tracking in sync mode)
        mPhase += mPhaseIncrement;
        
        // Apply pitch scatter to phase increment when in grain
        double effectiveIncrement = mPhaseIncrement;
        if (mInGrain && mCurrentGrain.pitchOffsetCents != 0.0) {
            effectiveIncrement *= centsToRatio(mCurrentGrain.pitchOffsetCents);
        }
        
        if (mPhase >= 1.0) {
            mPhase -= 1.0;
        }
        
        // Always advance async phase (for grain timing in async mode)
        mAsyncPhase += mAsyncPhaseIncrement;
        if (mAsyncPhase >= 1.0) {
            mAsyncPhase -= 1.0;
        }
    }
    
    void updateAsyncPhaseIncrement() {
        mAsyncPhaseIncrement = mStochastic.grainDensity / mSampleRate;
    }
    
    void randomizeGrain() {
        double scatter = mStochastic.cloudScatter;
        
        // Phase 5.1: Pitch scatter (in cents)
        if (mStochastic.pitchScatterAmount > 0 && scatter > 0) {
            double effectiveAmount = mStochastic.pitchScatterAmount * scatter;
            mCurrentGrain.pitchOffsetCents = mRng.generate(
                mStochastic.pitchScatterDistribution, effectiveAmount);
        } else {
            mCurrentGrain.pitchOffsetCents = 0.0;
        }
        
        // Phase 5.2: Timing jitter (in samples)
        if (mStochastic.timingJitter > 0 && scatter > 0) {
            double effectiveJitterMs = mStochastic.timingJitter * scatter;
            double jitterMs = mRng.generate(mStochastic.timingDistribution, effectiveJitterMs);
            mCurrentGrain.timingOffsetSamples = std::max(0.0, msToSamples(jitterMs, mSampleRate));
        } else {
            mCurrentGrain.timingOffsetSamples = 0.0;
        }
        
        // Phase 5.3: Formant scatter (in Hz) - stored for external use
        if (mStochastic.formantScatter > 0 && scatter > 0) {
            double effectiveAmount = mStochastic.formantScatter * scatter;
            mCurrentGrain.formantOffsetHz = mRng.generate(
                mStochastic.formantDistribution, effectiveAmount);
        } else {
            mCurrentGrain.formantOffsetHz = 0.0;
        }
        
        // Phase 5.4: Pan scatter - stored for external use
        if (mStochastic.panScatter > 0 && scatter > 0) {
            double effectiveAmount = mStochastic.panScatter * scatter;
            mCurrentGrain.panOffset = mRng.generate(
                mStochastic.panDistribution, effectiveAmount);
            // Clamp to valid pan range
            mCurrentGrain.panOffset = std::max(-1.0, std::min(1.0, mCurrentGrain.panOffset));
        } else {
            mCurrentGrain.panOffset = 0.0;
        }
        
        // Phase 5.5: Amplitude scatter (in dB, converted to linear)
        if (mStochastic.ampScatter > 0 && scatter > 0) {
            double effectiveDb = mStochastic.ampScatter * scatter;
            double dbOffset = mRng.generate(mStochastic.ampDistribution, effectiveDb);
            mCurrentGrain.ampMultiplier = dbToLinear(dbOffset);
        } else {
            mCurrentGrain.ampMultiplier = 1.0;
        }
    }
    
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
    
    // Phase 5: Stochastic cloud parameters
    StochasticParams mStochastic;
    GrainState mCurrentGrain;
    StochasticDistribution mRng;
    bool mInGrain;
    
    // Async mode (grain density independent of pitch)
    double mAsyncPhase;
    double mAsyncPhaseIncrement;
    
    // Timing jitter state
    double mTimingJitterCounter;
};

#endif // __cplusplus
