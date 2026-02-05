//
//  FormantSequencer.h
//  VoxCore
//
//  Phase 4.6-4.8: Formant Step Sequencer
//  16-step sequencer for vowel patterns with glide/portamento
//
//  Features:
//  - 16 steps, each stores vowel position (0.0-1.0 for A-E-I-O-U morph)
//  - Free-running or tempo-synced
//  - Glide (portamento) between steps
//

#pragma once

#ifdef __cplusplus

#include <array>
#include <cmath>
#include <algorithm>

class FormantSequencer {
public:
    static constexpr int kMaxSteps = 16;
    
    enum class SyncMode {
        Free,      // Rate in Hz
        TempoSync  // Rate from host tempo
    };
    
    // Beat divisions for tempo sync
    enum class BeatDivision {
        Quarter,          // 1/4 note
        Eighth,           // 1/8 note
        Sixteenth,        // 1/16 note
        ThirtySecond,     // 1/32 note
        DottedQuarter,    // Dotted 1/4
        DottedEighth,     // Dotted 1/8
        TripletQuarter,   // 1/4 triplet
        TripletEighth,    // 1/8 triplet
        Half,             // 1/2 note
        Whole             // Whole note
    };
    
    enum class GlideCurve {
        Linear,
        Exponential
    };
    
    FormantSequencer(double sampleRate = 44100.0)
        : mSampleRate(sampleRate)
        , mStepCount(16)
        , mRate(1.0)         // 1 Hz default (1 step per second)
        , mGlide(0.0)        // 0% glide
        , mSyncMode(SyncMode::Free)
        , mBeatDivision(BeatDivision::Quarter)
        , mTempo(120.0)
        , mGlideCurve(GlideCurve::Linear)
        , mCurrentStep(0)
        , mPhase(0.0)
        , mPhaseIncrement(0.0)
        , mCurrentValue(0.0)
        , mTargetValue(0.0)
        , mGlideProgress(1.0)  // Start at target (no glide in progress)
        , mPreviousValue(0.0)
        , mRunning(true)
    {
        // Initialize steps to vowel pattern A-E-I-O-U-O-I-E...
        double vowelPattern[8] = {0.0, 0.25, 0.5, 0.75, 1.0, 0.75, 0.5, 0.25};
        for (int i = 0; i < kMaxSteps; ++i) {
            mSteps[i] = vowelPattern[i % 8];
        }
        
        updatePhaseIncrement();
    }
    
    void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        updatePhaseIncrement();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Step Pattern
    // ═══════════════════════════════════════════════════════════════
    
    // Set individual step value (0.0-1.0 = A to U vowel morph)
    void setStepValue(int step, double value) {
        if (step >= 0 && step < kMaxSteps) {
            mSteps[step] = std::max(0.0, std::min(1.0, value));
        }
    }
    
    double getStepValue(int step) const {
        if (step >= 0 && step < kMaxSteps) {
            return mSteps[step];
        }
        return 0.0;
    }
    
    // Set all steps at once
    void setPattern(const double* values, int count) {
        int copyCount = std::min(count, kMaxSteps);
        for (int i = 0; i < copyCount; ++i) {
            mSteps[i] = std::max(0.0, std::min(1.0, values[i]));
        }
    }
    
    // Set number of active steps (1-16)
    void setStepCount(int count) {
        mStepCount = std::max(1, std::min(kMaxSteps, count));
        if (mCurrentStep >= mStepCount) {
            mCurrentStep = 0;
        }
    }
    
    int getStepCount() const {
        return mStepCount;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Rate and Sync
    // ═══════════════════════════════════════════════════════════════
    
    // Rate in Hz (for free-running mode)
    void setRate(double rateHz) {
        mRate = std::max(0.1, std::min(100.0, rateHz));
        updatePhaseIncrement();
    }
    
    double getRate() const {
        return mRate;
    }
    
    void setSyncMode(SyncMode mode) {
        mSyncMode = mode;
        updatePhaseIncrement();
    }
    
    SyncMode getSyncMode() const {
        return mSyncMode;
    }
    
    void setBeatDivision(BeatDivision division) {
        mBeatDivision = division;
        updatePhaseIncrement();
    }
    
    BeatDivision getBeatDivision() const {
        return mBeatDivision;
    }
    
    void setTempo(double bpm) {
        mTempo = std::max(20.0, std::min(300.0, bpm));
        updatePhaseIncrement();
    }
    
    double getTempo() const {
        return mTempo;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Glide/Portamento
    // ═══════════════════════════════════════════════════════════════
    
    // Glide amount: 0% = instant, 100% = smooth across entire step
    void setGlide(double glidePercent) {
        mGlide = std::max(0.0, std::min(100.0, glidePercent)) / 100.0;
    }
    
    double getGlide() const {
        return mGlide * 100.0;
    }
    
    void setGlideCurve(GlideCurve curve) {
        mGlideCurve = curve;
    }
    
    GlideCurve getGlideCurve() const {
        return mGlideCurve;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Transport Control
    // ═══════════════════════════════════════════════════════════════
    
    void start() {
        mRunning = true;
    }
    
    void stop() {
        mRunning = false;
    }
    
    bool isRunning() const {
        return mRunning;
    }
    
    void reset() {
        mCurrentStep = 0;
        mPhase = 0.0;
        mCurrentValue = mSteps[0];
        mTargetValue = mSteps[0];
        mPreviousValue = mSteps[0];
        mGlideProgress = 1.0;
    }
    
    // Jump to specific step
    void setCurrentStep(int step) {
        mCurrentStep = std::max(0, std::min(mStepCount - 1, step));
        mTargetValue = mSteps[mCurrentStep];
        mCurrentValue = mTargetValue;
        mPhase = 0.0;
        mGlideProgress = 1.0;
    }
    
    int getCurrentStep() const {
        return mCurrentStep;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Processing
    // ═══════════════════════════════════════════════════════════════
    
    // Process one sample, returns vowel morph value (0.0-1.0)
    double process() {
        if (!mRunning) {
            return mCurrentValue;
        }
        
        // Advance phase
        mPhase += mPhaseIncrement;
        
        // Check for step advance
        if (mPhase >= 1.0) {
            mPhase -= 1.0;
            
            // Store previous value for glide
            mPreviousValue = mTargetValue;
            
            // Advance to next step
            mCurrentStep = (mCurrentStep + 1) % mStepCount;
            mTargetValue = mSteps[mCurrentStep];
            
            // Reset glide progress
            mGlideProgress = 0.0;
        }
        
        // Calculate glide
        if (mGlide > 0.0 && mGlideProgress < 1.0) {
            // Glide progress over portion of step time
            double glideTime = mGlide;  // 0.0-1.0 of step duration
            mGlideProgress = std::min(1.0, mPhase / glideTime);
            
            // Apply glide curve
            double t = applyGlideCurve(mGlideProgress);
            mCurrentValue = mPreviousValue + (mTargetValue - mPreviousValue) * t;
        } else {
            mCurrentValue = mTargetValue;
        }
        
        return mCurrentValue;
    }
    
    // Get current output value without advancing
    double getCurrentValue() const {
        return mCurrentValue;
    }
    
    // Get phase within current step (0.0-1.0)
    double getStepPhase() const {
        return mPhase;
    }
    
private:
    double applyGlideCurve(double t) const {
        switch (mGlideCurve) {
            case GlideCurve::Linear:
                return t;
                
            case GlideCurve::Exponential:
                // Exponential ease-out: faster start, slower end
                return 1.0 - std::pow(1.0 - t, 3.0);
        }
        return t;
    }
    
    void updatePhaseIncrement() {
        double effectiveRate = mRate;
        
        if (mSyncMode == SyncMode::TempoSync) {
            // Convert tempo and beat division to Hz
            double beatsPerSecond = mTempo / 60.0;
            
            switch (mBeatDivision) {
                case BeatDivision::Whole:
                    effectiveRate = beatsPerSecond / 4.0;
                    break;
                case BeatDivision::Half:
                    effectiveRate = beatsPerSecond / 2.0;
                    break;
                case BeatDivision::Quarter:
                    effectiveRate = beatsPerSecond;
                    break;
                case BeatDivision::DottedQuarter:
                    effectiveRate = beatsPerSecond * 2.0 / 3.0;
                    break;
                case BeatDivision::TripletQuarter:
                    effectiveRate = beatsPerSecond * 1.5;
                    break;
                case BeatDivision::Eighth:
                    effectiveRate = beatsPerSecond * 2.0;
                    break;
                case BeatDivision::DottedEighth:
                    effectiveRate = beatsPerSecond * 4.0 / 3.0;
                    break;
                case BeatDivision::TripletEighth:
                    effectiveRate = beatsPerSecond * 3.0;
                    break;
                case BeatDivision::Sixteenth:
                    effectiveRate = beatsPerSecond * 4.0;
                    break;
                case BeatDivision::ThirtySecond:
                    effectiveRate = beatsPerSecond * 8.0;
                    break;
            }
        }
        
        mPhaseIncrement = effectiveRate / mSampleRate;
    }
    
    double mSampleRate;
    
    // Step pattern
    std::array<double, kMaxSteps> mSteps;
    int mStepCount;
    
    // Rate
    double mRate;
    SyncMode mSyncMode;
    BeatDivision mBeatDivision;
    double mTempo;
    
    // Glide
    double mGlide;
    GlideCurve mGlideCurve;
    
    // State
    int mCurrentStep;
    double mPhase;
    double mPhaseIncrement;
    double mCurrentValue;
    double mTargetValue;
    double mGlideProgress;
    double mPreviousValue;
    bool mRunning;
};

#endif // __cplusplus
