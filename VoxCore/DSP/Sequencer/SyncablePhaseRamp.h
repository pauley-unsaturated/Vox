//
//  SyncablePhaseRamp.h
//  VoxCore
//
//  A phase ramp generator that can be synced to host tempo
//

#pragma once

#ifdef __cplusplus

#include <cmath>
#include <algorithm>
#include <numbers>

class SyncablePhaseRamp {
public:
    // Return type for process()
    struct ProcessResult {
        double phase;     // Current phase [0, 1)
        bool wrapped;     // True if phase wrapped this sample
        int cycleCount;   // Number of complete cycles so far
    };
    
    enum class SyncMode {
        FREE_RUN,     // Free running at specified Hz rate
        BEAT_SYNC     // Synced to host tempo
    };
    
    enum class BeatDivision {
        FOUR_BARS,        // 4 bars
        TWO_BARS,         // 2 bars
        WHOLE,            // 1 bar (whole note)
        HALF_DOT,         // Dotted half note
        HALF,             // Half note
        HALF_TRIPLET,     // Half note triplet
        QUARTER_DOT,      // Dotted quarter note
        QUARTER,          // Quarter note
        QUARTER_TRIPLET,  // Quarter note triplet
        EIGHTH_DOT,       // Dotted eighth note
        EIGHTH,           // Eighth note
        EIGHTH_TRIPLET,   // Eighth note triplet
        SIXTEENTH_DOT,    // Dotted sixteenth note
        SIXTEENTH,        // Sixteenth note
        SIXTEENTH_TRIPLET,// Sixteenth note triplet
        THIRTYSECOND      // Thirty-second note
    };
    
    SyncablePhaseRamp(double sampleRate = 44100.0, double rate = 1.0, double phaseOffset = 0.0)
        : mSampleRate(sampleRate)
        , mPhase(0.0)
        , mPhaseOffset(std::fmod(std::abs(phaseOffset), 1.0))
        , mSyncMode(SyncMode::FREE_RUN)
        , mBeatDivision(BeatDivision::QUARTER)
        , mTempo(120.0)
        , mDidWrap(false)
    {
        setRate(rate);
    }
    
    void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        updatePhaseIncrement();
    }
    
    double getSampleRate() const { return mSampleRate; }
    
    void setRate(double rateHz) {
        // Clamp rate to valid range
        mRate = std::max(0.1, std::min(50.0, rateHz));
        updatePhaseIncrement();
    }
    
    double getRate() const { return mRate; }
    
    void setPhaseOffset(double offset) {
        mPhaseOffset = std::fmod(std::abs(offset), 1.0);
    }
    
    double getPhaseOffset() const { return mPhaseOffset; }
    
    void setSyncMode(SyncMode mode) {
        mSyncMode = mode;
        updatePhaseIncrement();
    }
    
    SyncMode getSyncMode() const { return mSyncMode; }
    
    void setBeatDivision(BeatDivision division) {
        mBeatDivision = division;
        updatePhaseIncrement();
    }
    
    BeatDivision getBeatDivision() const { return mBeatDivision; }
    
    void setTempo(double bpm) {
        mTempo = std::max(20.0, std::min(300.0, bpm));
        updatePhaseIncrement();
    }
    
    double getTempo() const { return mTempo; }
    
    void reset() {
        mPhase = mPhaseOffset;
        mDidWrap = false;
        mCycleCount = 0;
        mIsEvenStep = true;
    }
    
    void hardSync() {
        mPhase = mPhaseOffset;
    }
    
    bool didWrap() const { return mDidWrap; }
    
    int getCycleCount() const { return mCycleCount; }
    
    double getSamplesPerCycle() const {
        if (mPhaseIncrement > 0) {
            return 1.0 / mPhaseIncrement;
        }
        return mSampleRate; // Default if no rate set
    }
    
    double getEffectiveRate() const {
        return mPhaseIncrement * mSampleRate;
    }
    
    // Swing timing
    void setSwing(double amount) {
        mSwing = std::max(0.0, std::min(1.0, amount));
        updateSwingDelay();
    }
    
    double getSwing() const { return mSwing; }
    
    double getSwingDelaySamples() const { return static_cast<double>(mSwingDelaySamples); }
    
    bool isEvenStep() const { return mIsEvenStep; }
    
    void syncToBeatPosition(double beatPosition) {
        // Set phase based on beat position
        mPhase = std::fmod(beatPosition, 1.0);
    }
    
    // Process one sample, returns struct with phase info
    ProcessResult process() {
        ProcessResult result;
        result.phase = std::fmod(mPhase + mPhaseOffset, 1.0);
        result.wrapped = false;
        result.cycleCount = mCycleCount;
        
        // Update phase
        mPhase += mPhaseIncrement;
        mDidWrap = false;
        
        if (mPhase >= 1.0) {
            mPhase -= 1.0;
            mDidWrap = true;
            result.wrapped = true;
            mCycleCount++;
            result.cycleCount = mCycleCount;
            mIsEvenStep = !mIsEvenStep;
        }
        
        return result;
    }
    
    // Get current phase without advancing
    double getCurrentPhase() const {
        return std::fmod(mPhase + mPhaseOffset, 1.0);
    }
    
private:
    void updatePhaseIncrement() {
        double effectiveRate = mRate;
        
        if (mSyncMode == SyncMode::BEAT_SYNC) {
            // Convert beat division to Hz based on tempo
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
                case BeatDivision::HALF_DOT:
                    effectiveRate = beatsPerSecond / 3.0;
                    break;
                case BeatDivision::HALF:
                    effectiveRate = beatsPerSecond / 2.0;
                    break;
                case BeatDivision::HALF_TRIPLET:
                    effectiveRate = beatsPerSecond * 3.0 / 4.0;
                    break;
                case BeatDivision::QUARTER_DOT:
                    effectiveRate = beatsPerSecond * 2.0 / 3.0;
                    break;
                case BeatDivision::QUARTER:
                    effectiveRate = beatsPerSecond;
                    break;
                case BeatDivision::QUARTER_TRIPLET:
                    effectiveRate = beatsPerSecond * 1.5;
                    break;
                case BeatDivision::EIGHTH_DOT:
                    effectiveRate = beatsPerSecond * 4.0 / 3.0;
                    break;
                case BeatDivision::EIGHTH:
                    effectiveRate = beatsPerSecond * 2.0;
                    break;
                case BeatDivision::EIGHTH_TRIPLET:
                    effectiveRate = beatsPerSecond * 3.0;
                    break;
                case BeatDivision::SIXTEENTH_DOT:
                    effectiveRate = beatsPerSecond * 8.0 / 3.0;
                    break;
                case BeatDivision::SIXTEENTH:
                    effectiveRate = beatsPerSecond * 4.0;
                    break;
                case BeatDivision::SIXTEENTH_TRIPLET:
                    effectiveRate = beatsPerSecond * 6.0;
                    break;
                case BeatDivision::THIRTYSECOND:
                    effectiveRate = beatsPerSecond * 8.0;
                    break;
            }
        }
        
        mPhaseIncrement = effectiveRate / mSampleRate;
    }
    
    void updateSwingDelay() {
        // Calculate swing delay in samples based on current rate
        double samplesPerBeat = getSamplesPerCycle();
        mSwingDelaySamples = static_cast<int>(samplesPerBeat * mSwing * 0.5);
    }
    
    double mSampleRate;
    double mPhase;
    double mPhaseIncrement = 0.0;
    double mPhaseOffset;
    double mRate = 1.0;
    SyncMode mSyncMode;
    BeatDivision mBeatDivision;
    double mTempo;
    bool mDidWrap;
    int mCycleCount = 0;
    double mSwing = 0.0;
    int mSwingDelaySamples = 0;
    bool mIsEvenStep = true;
};

#endif // __cplusplus
