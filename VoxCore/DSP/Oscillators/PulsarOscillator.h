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
//  Phase 7: Roads Pulsar Synthesis Alignment
//  - PulsaretEnvelope: Separate envelope shapes each pulsaret (v in Roads' model)
//  - FormantTrack: Controls how formant frequency tracks fundamental
//  - EdgeFactor: Controls crossfade when duty approaches period
//  - Pulse Masking: Burst patterns for subharmonics
//

#pragma once

#ifdef __cplusplus

#include <cmath>
#include <algorithm>
#include <numbers>
#include "../Modulators/StochasticDistribution.h"

// ═══════════════════════════════════════════════════════════════════════════
// Phase 7: Pulsaret Envelope Types (Roads' "v" parameter)
// ═══════════════════════════════════════════════════════════════════════════
//
// The pulsaret envelope shapes EACH individual pulsaret (1-10ms timescale).
// This is SEPARATE from the amplitude ADSR which shapes the overall note.
//
// From Roads: "The pulsaret envelope's contribution to the spectrum is
// significant... A rectangular envelope produces a broad sinc function...
// A Gaussian envelope compresses the spectral energy, centering it around
// the formant frequency."
//

enum class PulsaretEnvelope : int {
    RECTANGULAR = 0,  // Current behavior, hard edges, broad sinc spectrum
    GAUSSIAN,         // Smooth bell curve, focused formant, minimizes sidebands
    EXP_DECAY,        // FOF-style exponential decay, vocal formant character
    LINEAR_ATTACK,    // Linear rise with fast decay, percussive character
    FOF,              // Classic formant synthesis: sharp attack + exp decay
    COUNT
};

// ═══════════════════════════════════════════════════════════════════════════
// Phase 7: Masking Parameters
// ═══════════════════════════════════════════════════════════════════════════
//
// Pulse masking creates rhythmic patterns and subharmonics.
// Burst pattern b:r creates subharmonics at fp/(b+r).
//

struct MaskingParams {
    bool enabled = false;
    int burstLength = 4;          // b: number of pulsarets before rest
    int restLength = 2;           // r: number of silent pulsarets
    float stochasticProb = 1.0f;  // 0-1: probability of emitting each pulsaret
    
    // Calculated subharmonic factor: fp/(b+r)
    double getSubharmonicFactor() const {
        if (!enabled || (burstLength + restLength) <= 0) return 1.0;
        return static_cast<double>(burstLength) / static_cast<double>(burstLength + restLength);
    }
};

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
    // Pulsaret waveform shapes (the carrier waveform)
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
        , mPulsaretEnvelope(PulsaretEnvelope::RECTANGULAR)
        , mEnvelopeParam(0.5)
        , mFormantTrack(0.0)
        , mEdgeFactor(1.0)
        , mMasking()
        , mMaskCounter(0)
        , mMaskInBurst(true)
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
    // Phase 7: Pulsaret Envelope (Roads)
    // ═══════════════════════════════════════════════════════════════════
    
    // Set the pulsaret envelope type
    // This shapes EACH pulsaret, separate from the amp ADSR
    void setPulsaretEnvelope(PulsaretEnvelope envelope) {
        mPulsaretEnvelope = envelope;
    }
    
    PulsaretEnvelope getPulsaretEnvelope() const { return mPulsaretEnvelope; }
    
    // Envelope shaping parameter (0.0 to 1.0)
    // - For GAUSSIAN: controls width (0 = narrow/focused, 1 = wide/broad)
    // - For EXP_DECAY: controls decay rate (0 = fast, 1 = slow)
    // - For LINEAR_ATTACK: controls attack portion (0 = instant, 1 = full ramp)
    // - For FOF: controls the balance of attack vs decay
    void setEnvelopeParam(double param) {
        mEnvelopeParam = std::max(0.0, std::min(1.0, param));
    }
    
    double getEnvelopeParam() const { return mEnvelopeParam; }
    
    // ═══════════════════════════════════════════════════════════════════
    // Phase 7: Formant Track (Roads)
    // ═══════════════════════════════════════════════════════════════════
    
    // Formant tracking: how much the implicit formant (fd = 1/d) tracks
    // the fundamental frequency (fp)
    // 0.0 = Robot voice (fd fixed regardless of fp changes)
    // 1.0 = Natural voice (fd tracks fp, maintaining vocal character)
    void setFormantTrack(double track) {
        mFormantTrack = std::max(0.0, std::min(1.0, track));
    }
    
    double getFormantTrack() const { return mFormantTrack; }
    
    // Get the implicit formant frequency from duty cycle
    // fd = sampleRate / (dutyCycle * period_in_samples)
    // Simplified: fd = frequency / dutyCycle
    double getImplicitFormant() const {
        if (mDutyCycle <= 0.0) return 0.0;
        return mFrequency / mDutyCycle;
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Phase 7: Edge Factor (Roads PulWM)
    // ═══════════════════════════════════════════════════════════════════
    
    // Edge factor controls what happens when duty cycle approaches or
    // exceeds the period (duty > period scenario in PulWM).
    // 0.0 = Soft crossfade at edges (smoother, less aliasing)
    // 1.0 = Hard cutoff (brighter, more edge harmonics)
    void setEdgeFactor(double factor) {
        mEdgeFactor = std::max(0.0, std::min(1.0, factor));
    }
    
    double getEdgeFactor() const { return mEdgeFactor; }
    
    // ═══════════════════════════════════════════════════════════════════
    // Phase 7: Pulse Masking (Roads)
    // ═══════════════════════════════════════════════════════════════════
    
    void setMaskingParams(const MaskingParams& params) {
        mMasking = params;
        // Reset mask counter when params change
        mMaskCounter = 0;
        mMaskInBurst = true;
    }
    
    MaskingParams getMaskingParams() const { return mMasking; }
    
    // Enable/disable masking
    void setMaskingEnabled(bool enabled) {
        mMasking.enabled = enabled;
        if (enabled) {
            mMaskCounter = 0;
            mMaskInBurst = true;
        }
    }
    
    bool getMaskingEnabled() const { return mMasking.enabled; }
    
    // Set burst pattern: b pulsarets on, r pulsarets off
    // Creates subharmonics at fp/(b+r)
    void setBurstPattern(int burstLength, int restLength) {
        mMasking.burstLength = std::max(1, burstLength);
        mMasking.restLength = std::max(0, restLength);
    }
    
    int getBurstLength() const { return mMasking.burstLength; }
    int getRestLength() const { return mMasking.restLength; }
    
    // Stochastic probability: 0-1 probability of emitting each pulsaret
    // Values 0.8-0.9 create "erratic contact" analog feel
    void setStochasticMaskProb(float prob) {
        mMasking.stochasticProb = std::max(0.0f, std::min(1.0f, prob));
    }
    
    float getStochasticMaskProb() const { return mMasking.stochasticProb; }
    
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
        
        // Phase 7: Reset masking state
        mMaskCounter = 0;
        mMaskInBurst = true;
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
            
            // ═══════════════════════════════════════════════════════════
            // Phase 7: Apply pulse masking
            // ═══════════════════════════════════════════════════════════
            if (mMasking.enabled) {
                // Check burst/rest pattern
                if (mMaskInBurst) {
                    mMaskCounter++;
                    if (mMaskCounter >= mMasking.burstLength) {
                        mMaskCounter = 0;
                        mMaskInBurst = false;  // Enter rest phase
                    }
                } else {
                    mMaskCounter++;
                    if (mMaskCounter >= mMasking.restLength) {
                        mMaskCounter = 0;
                        mMaskInBurst = true;  // Enter burst phase
                    }
                }
                
                // Apply stochastic dropout
                if (mMaskInBurst && mMasking.stochasticProb < 1.0f) {
                    double random = mRng.generate(DistributionType::UNIFORM, 1.0);
                    if (random > mMasking.stochasticProb) {
                        mMaskInBurst = false;  // Skip this pulsaret
                    }
                }
                
                // If we're in rest phase, don't emit this pulsaret
                if (!mMaskInBurst) {
                    advancePhases();
                    return 0.0;
                }
            }
            
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
            
            // ═══════════════════════════════════════════════════════════
            // Generate carrier waveform
            // ═══════════════════════════════════════════════════════════
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
            
            // ═══════════════════════════════════════════════════════════
            // Phase 7: Apply pulsaret envelope (Roads' "v" parameter)
            // ═══════════════════════════════════════════════════════════
            double envelope = generatePulsaretEnvelope(pulsaretPhase);
            output *= envelope;
            
            // ═══════════════════════════════════════════════════════════
            // Phase 7: Apply edge factor (crossfade at boundaries)
            // ═══════════════════════════════════════════════════════════
            if (mEdgeFactor < 1.0) {
                double edgeEnv = applyEdgeCrossfade(pulsaretPhase);
                output *= edgeEnv;
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
    
    // ═══════════════════════════════════════════════════════════════════
    // Phase 7: Pulsaret Envelope Generation (Roads' "v" parameter)
    // ═══════════════════════════════════════════════════════════════════
    
    // Generate the pulsaret envelope based on current envelope type
    // Input phase is 0 to 1 within the pulsaret
    double generatePulsaretEnvelope(double phase) {
        switch (mPulsaretEnvelope) {
            case PulsaretEnvelope::RECTANGULAR:
                // Hard edges, no shaping - current default behavior
                return 1.0;
                
            case PulsaretEnvelope::GAUSSIAN:
                return generateGaussianEnvelope(phase);
                
            case PulsaretEnvelope::EXP_DECAY:
                return generateExpDecayEnvelope(phase);
                
            case PulsaretEnvelope::LINEAR_ATTACK:
                return generateLinearAttackEnvelope(phase);
                
            case PulsaretEnvelope::FOF:
                return generateFOFEnvelope(phase);
                
            default:
                return 1.0;
        }
    }
    
    // Gaussian envelope: smooth bell curve, minimizes spectral sidebands
    // Centers spectral energy around the formant frequency
    double generateGaussianEnvelope(double phase) {
        // Map 0-1 to -1 to +1 (centered at 0.5)
        double x = (phase - 0.5) * 2.0;
        
        // Width controlled by envelope param (0.1 to 1.0 effective range)
        // Lower param = narrower Gaussian = more focused spectrum
        double sigma = 0.15 + mEnvelopeParam * 0.35;  // 0.15 to 0.5
        
        return std::exp(-(x * x) / (2.0 * sigma * sigma));
    }
    
    // Exponential decay: sharp attack, exponential falloff
    // Good for FOF-style vocal formant synthesis
    double generateExpDecayEnvelope(double phase) {
        // Decay rate controlled by envelope param
        // Lower param = faster decay = brighter/percussive
        double decayRate = 3.0 + (1.0 - mEnvelopeParam) * 7.0;  // 3 to 10
        
        return std::exp(-phase * decayRate);
    }
    
    // Linear attack: linear rise with fast decay
    // Percussive, forward-leaning character
    double generateLinearAttackEnvelope(double phase) {
        // Attack portion controlled by envelope param
        double attackPortion = 0.1 + mEnvelopeParam * 0.4;  // 0.1 to 0.5
        
        if (phase < attackPortion) {
            // Linear rise
            return phase / attackPortion;
        } else {
            // Exponential decay for the rest
            double decayPhase = (phase - attackPortion) / (1.0 - attackPortion);
            return std::exp(-decayPhase * 4.0);
        }
    }
    
    // FOF (Formant Wave Function) envelope: classic formant synthesis shape
    // Sharp attack followed by exponential decay with slight overshoot
    // Used in CHANT and other formant synthesizers
    double generateFOFEnvelope(double phase) {
        // Attack time controlled by envelope param
        double attackTime = 0.02 + mEnvelopeParam * 0.08;  // 0.02 to 0.1
        
        if (phase < attackTime) {
            // Sine-squared rise (smooth attack)
            double attackPhase = phase / attackTime;
            double sinVal = std::sin(attackPhase * std::numbers::pi * 0.5);
            return sinVal * sinVal;
        } else {
            // Exponential decay
            double decayPhase = (phase - attackTime) / (1.0 - attackTime);
            double decayRate = 2.0 + (1.0 - mEnvelopeParam) * 4.0;  // 2 to 6
            return std::exp(-decayPhase * decayRate);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Phase 7: Edge Crossfade (Roads PulWM)
    // ═══════════════════════════════════════════════════════════════════
    
    // Apply soft crossfade at pulsaret edges when edgeFactor < 1.0
    // This reduces aliasing when duty cycle is high
    double applyEdgeCrossfade(double phase) {
        // Crossfade region size based on edge factor
        // edgeFactor = 0: maximum crossfade (10% of pulsaret at each edge)
        // edgeFactor = 1: no crossfade (hard edges)
        double crossfadeSize = (1.0 - mEdgeFactor) * 0.1;
        
        if (crossfadeSize <= 0.0) {
            return 1.0;  // No crossfade
        }
        
        double envelope = 1.0;
        
        // Fade in at start
        if (phase < crossfadeSize) {
            envelope *= phase / crossfadeSize;
        }
        
        // Fade out at end
        if (phase > (1.0 - crossfadeSize)) {
            envelope *= (1.0 - phase) / crossfadeSize;
        }
        
        return envelope;
    }
    
    double mSampleRate;
    double mPhase;
    double mPhaseIncrement;
    double mFrequency;
    double mDutyCycle;
    Shape mShape;
    
    // Phase 7: Pulsaret envelope (Roads' "v" parameter)
    PulsaretEnvelope mPulsaretEnvelope;
    double mEnvelopeParam;      // 0.0 to 1.0, controls envelope shape
    
    // Phase 7: Formant tracking
    double mFormantTrack;       // 0.0 = robot, 1.0 = natural
    
    // Phase 7: Edge factor for PulWM
    double mEdgeFactor;         // 0.0 = soft, 1.0 = hard
    
    // Phase 7: Pulse masking
    MaskingParams mMasking;
    int mMaskCounter;           // Current position in burst/rest cycle
    bool mMaskInBurst;          // true = emitting, false = resting
    
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
