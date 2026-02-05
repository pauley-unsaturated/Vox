//
//  LFO.h
//  VoxCore
//
//  Low Frequency Oscillator for modulation
//

#pragma once

#ifdef __cplusplus

#include <cmath>
#include <numbers>
#include <algorithm>
#include <random>

class LFO {
public:
    enum class Waveform {
        SINE,
        TRIANGLE,
        SAW,
        SQUARE,
        SAMPLE_AND_HOLD,
        RANDOM,        // Alias for SAMPLE_AND_HOLD
        NOISE          // Continuous random noise
    };
    
    // Tempo sync modes
    enum class SyncMode {
        FREE,       // Free running (rate in Hz)
        FREE_RUN,   // Alias for FREE
        TEMPO_SYNC, // Synced to host tempo
        BEAT_SYNC   // Alias for TEMPO_SYNC
    };
    
    // Beat divisions for tempo sync
    enum class BeatDivision {
        FOUR_BARS,      // 4 bars
        TWO_BARS,       // 2 bars
        WHOLE,          // 1 bar
        HALF,           // 1/2
        HALF_TRIPLET,   // 1/2 triplet
        QUARTER,        // 1/4 (1 beat at 4/4)
        QUARTER_DOT,    // Dotted quarter
        QUARTER_TRIPLET,// Quarter triplet
        EIGHTH,         // 1/8
        EIGHTH_DOT,     // Dotted eighth
        EIGHTH_TRIPLET, // Eighth triplet
        SIXTEENTH,      // 1/16
        SIXTEENTH_DOT,  // Dotted sixteenth
        SIXTEENTH_TRIPLET, // Sixteenth triplet
        THIRTY_SECOND,  // 1/32
        THIRTYSECOND,   // Alias for THIRTY_SECOND
        DOTTED_HALF,
        DOTTED_QUARTER,
        DOTTED_EIGHTH,
        TRIPLET_HALF,
        TRIPLET_QUARTER,
        TRIPLET_EIGHTH
    };
    
    // Retrigger modes
    enum class RetriggerMode {
        FREE,           // Never retrigger
        FREE_RUN,       // Alias for FREE
        NOTE_ON,        // Retrigger on note on
        BEAT            // Retrigger on beat
    };
    
    LFO(double sampleRate = 44100.0)
        : mSampleRate(sampleRate)
        , mPhase(0.0)
        , mPhaseIncrement(0.0)
        , mRate(1.0)
        , mWaveform(Waveform::SINE)
        , mSyncMode(SyncMode::FREE)
        , mBeatDivision(BeatDivision::QUARTER)
        , mRetriggerMode(RetriggerMode::FREE)
        , mTempo(120.0)
        , mPhaseOffset(0.0)
        , mDelayTime(0.0)
        , mDelaySamples(0)
        , mDelayCounter(0)
        , mSmoothingCutoff(20.0)
        , mSavedRandom(0.0)
        , mSmoothedValue(0.0)
    {
        setRate(1.0);
        // Initialize random generator
        std::random_device rd;
        mRandomGen = std::mt19937(rd());
        mRandomDist = std::uniform_real_distribution<double>(-1.0, 1.0);
        updateSmoothingCoeff();
    }
    
    void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        setRate(mRate);
    }
    
    void setRate(double rateHz) {
        mRate = std::max(0.01, std::min(100.0, rateHz));
        mPhaseIncrement = mRate / mSampleRate;
    }
    
    double getRate() const { return mRate; }
    
    void setWaveform(Waveform waveform) {
        mWaveform = waveform;
    }
    
    Waveform getWaveform() const { return mWaveform; }
    
    void reset() {
        mPhase = mPhaseOffset;
        mDelayCounter = mDelaySamples;
        mSmoothedValue = 0.0;
    }
    
    // Alias for setRate
    void setFrequency(double freq) {
        setRate(freq);
    }
    
    double getFrequency() const { return mRate; }
    
    void setSyncMode(SyncMode mode) {
        mSyncMode = mode;
        updateEffectiveRate();
    }
    
    SyncMode getSyncMode() const { return mSyncMode; }
    
    void setBeatDivision(BeatDivision division) {
        mBeatDivision = division;
        updateEffectiveRate();
    }
    
    BeatDivision getBeatDivision() const { return mBeatDivision; }
    
    void setTempo(double bpm) {
        mTempo = std::max(20.0, std::min(300.0, bpm));
        updateEffectiveRate();
    }
    
    double getTempo() const { return mTempo; }
    
    void setPhaseOffset(double offset) {
        mPhaseOffset = std::fmod(std::abs(offset), 1.0);
    }
    
    double getPhaseOffset() const { return mPhaseOffset; }
    
    void setRetriggerMode(RetriggerMode mode) {
        mRetriggerMode = mode;
    }
    
    RetriggerMode getRetriggerMode() const { return mRetriggerMode; }
    
    void retrigger() {
        mPhase = mPhaseOffset;
        mDelayCounter = mDelaySamples;
    }
    
    void setDelayTime(double seconds) {
        mDelayTime = std::max(0.0, seconds);
        mDelaySamples = static_cast<int>(mDelayTime * mSampleRate);
        mDelayCounter = mDelaySamples;
    }
    
    double getDelayTime() const { return mDelayTime; }
    
    void setSmoothingCutoff(double cutoffHz) {
        mSmoothingCutoff = std::max(0.1, std::min(cutoffHz, mSampleRate * 0.45));
        updateSmoothingCoeff();
    }
    
    double getSmoothingCutoff() const { return mSmoothingCutoff; }
    
    // Returns value in range [-1, 1]
    double process() {
        // Handle delay
        if (mDelayCounter > 0) {
            mDelayCounter--;
            return 0.0;
        }
        
        double output = 0.0;
        bool didWrap = false;
        
        // Apply phase offset
        double effectivePhase = std::fmod(mPhase + mPhaseOffset, 1.0);
        
        switch (mWaveform) {
            case Waveform::SINE:
                output = std::sin(effectivePhase * std::numbers::pi * 2.0);
                break;
                
            case Waveform::TRIANGLE:
                // Triangle wave: rising from -1 to 1, then falling from 1 to -1
                if (effectivePhase < 0.5) {
                    output = 4.0 * effectivePhase - 1.0;
                } else {
                    output = 3.0 - 4.0 * effectivePhase;
                }
                break;
                
            case Waveform::SAW:
                // Saw wave: rising from -1 to 1
                output = 2.0 * effectivePhase - 1.0;
                break;
                
            case Waveform::SQUARE:
                output = (effectivePhase < 0.5) ? 1.0 : -1.0;
                break;
                
            case Waveform::SAMPLE_AND_HOLD:
            case Waveform::RANDOM:
                output = mSavedRandom;
                break;
                
            case Waveform::NOISE:
                output = mRandomDist(mRandomGen);
                break;
        }
        
        // Update phase
        mPhase += mPhaseIncrement;
        if (mPhase >= 1.0) {
            mPhase -= 1.0;
            didWrap = true;
        }
        
        // For S&H, grab new random value on phase wrap
        if ((mWaveform == Waveform::SAMPLE_AND_HOLD || mWaveform == Waveform::RANDOM) && didWrap) {
            mSavedRandom = mRandomDist(mRandomGen);
        }
        
        // Apply smoothing
        if (mSmoothingCutoff < mSampleRate * 0.4) {
            mSmoothedValue += (output - mSmoothedValue) * mSmoothingCoeff;
            return mSmoothedValue;
        }
        
        return output;
    }
    
private:
    void updateEffectiveRate() {
        double effectiveRate = mRate;
        
        if (mSyncMode == SyncMode::TEMPO_SYNC || mSyncMode == SyncMode::BEAT_SYNC) {
            double beatsPerSecond = mTempo / 60.0;
            
            switch (mBeatDivision) {
                case BeatDivision::FOUR_BARS:
                    effectiveRate = beatsPerSecond / 16.0;
                    break;
                case BeatDivision::TWO_BARS:
                    effectiveRate = beatsPerSecond / 8.0;
                    break;
                case BeatDivision::WHOLE:
                    effectiveRate = beatsPerSecond / 4.0;
                    break;
                case BeatDivision::HALF:
                case BeatDivision::DOTTED_HALF:
                    effectiveRate = beatsPerSecond / 2.0;
                    break;
                case BeatDivision::QUARTER:
                case BeatDivision::DOTTED_QUARTER:
                    effectiveRate = beatsPerSecond;
                    break;
                case BeatDivision::EIGHTH:
                case BeatDivision::DOTTED_EIGHTH:
                    effectiveRate = beatsPerSecond * 2.0;
                    break;
                case BeatDivision::SIXTEENTH:
                case BeatDivision::SIXTEENTH_DOT:
                    effectiveRate = beatsPerSecond * 4.0;
                    break;
                case BeatDivision::THIRTY_SECOND:
                case BeatDivision::THIRTYSECOND:
                    effectiveRate = beatsPerSecond * 8.0;
                    break;
                case BeatDivision::HALF_TRIPLET:
                case BeatDivision::TRIPLET_HALF:
                    effectiveRate = beatsPerSecond * 3.0 / 4.0;
                    break;
                case BeatDivision::QUARTER_DOT:
                    effectiveRate = beatsPerSecond * 2.0 / 3.0;
                    break;
                case BeatDivision::QUARTER_TRIPLET:
                case BeatDivision::TRIPLET_QUARTER:
                    effectiveRate = beatsPerSecond * 1.5;
                    break;
                case BeatDivision::EIGHTH_DOT:
                    effectiveRate = beatsPerSecond * 4.0 / 3.0;
                    break;
                case BeatDivision::EIGHTH_TRIPLET:
                case BeatDivision::TRIPLET_EIGHTH:
                    effectiveRate = beatsPerSecond * 3.0;
                    break;
                case BeatDivision::SIXTEENTH_TRIPLET:
                    effectiveRate = beatsPerSecond * 6.0;
                    break;
            }
        }
        
        mPhaseIncrement = effectiveRate / mSampleRate;
    }
    
    void updateSmoothingCoeff() {
        // One-pole lowpass coefficient
        double fc = mSmoothingCutoff / mSampleRate;
        mSmoothingCoeff = 1.0 - std::exp(-2.0 * std::numbers::pi * fc);
    }
    
    double mSampleRate;
    double mPhase;
    double mPhaseIncrement;
    double mRate;
    Waveform mWaveform;
    SyncMode mSyncMode;
    BeatDivision mBeatDivision;
    RetriggerMode mRetriggerMode;
    double mTempo;
    double mPhaseOffset;
    double mDelayTime;
    int mDelaySamples;
    int mDelayCounter;
    double mSmoothingCutoff;
    double mSmoothingCoeff = 1.0;
    
    // For S&H
    double mSavedRandom;
    double mSmoothedValue;
    std::mt19937 mRandomGen;
    std::uniform_real_distribution<double> mRandomDist;
};

#endif // __cplusplus
