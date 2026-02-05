//
//  VoicePool.h
//  VoxCore
//
//  Voice Pool Manager for Polyphonic Synthesis
//  Manages VoxVoice instances and handles MIDI note routing
//
//  Phase 3: Voice Constellation - choir-like voice spreading
//

#pragma once

#ifdef __cplusplus

#include "VoiceAllocator.h"
#include "VoxVoice.h"
#include <array>
#include <memory>
#include <random>

class VoicePool {
public:
    // Maximum voices supported
    static constexpr int kMaxVoices = VoiceAllocator::kMaxVoices;
    
    // Voice stealing modes
    enum class StealingMode {
        Oldest,    // Steal the oldest active voice
        Quietest   // Steal the voice with lowest velocity
    };
    
    // Phase 3.6: Constellation modes
    enum class ConstellationMode {
        Unison,    // All spreads = 0 (tight, fat sound)
        Ensemble,  // Subtle spreads (string section feel)
        Choir,     // Maximum spreads (individual voices audible)
        Random     // Randomize offsets per note
    };
    
    // Constructor
    VoicePool(int voiceCount = 8, double sampleRate = 44100.0)
        : mVoiceCount(std::min(voiceCount, kMaxVoices))
        , mSampleRate(sampleRate)
        , mAllocator(voiceCount)
        , mStealingEnabled(true)
        , mStealingMode(StealingMode::Oldest)
        , mConstellationMode(ConstellationMode::Unison)
        , mDetuneSpread(0.0)
        , mTimeOffsetSpread(0.0)
        , mFormantOffsetSpread(0.0)
        , mPanSpread(0.0)
        , mLFOPhaseSpread(0.0)
        , mUnisonVoices(1)
        , mRandomGenerator(std::random_device{}())
        , mRandomDist(-1.0, 1.0)
    {
        // Initialize all voices with their index for LFO phase spreading
        for (int i = 0; i < kMaxVoices; ++i) {
            mVoices[i] = std::make_unique<VoxVoice>(sampleRate);
            mVoices[i]->setVoiceIndex(i);  // Set voice index for phase spreading
            mVoiceVelocities[i] = 0.0;
            mUnisonGroupNote[i] = -1;  // Track which note this voice is part of (for unison)
        }
    }
    
    // Set sample rate for all voices
    void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        for (int i = 0; i < mVoiceCount; ++i) {
            mVoices[i]->setSampleRate(sampleRate);
        }
    }
    
    // Set parameters for all voices (applies constellation spreads)
    void setParameters(const VoxVoiceParameters& params) {
        mParameters = params;
        applyConstellationToAllVoices();
    }
    
    VoxVoiceParameters getParameters() const {
        return mParameters;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Phase 3: Voice Constellation Parameters
    // ═══════════════════════════════════════════════════════════════
    
    // Phase 3.1: Detune Spread (0-50 cents)
    void setDetuneSpread(double cents) {
        mDetuneSpread = std::max(0.0, std::min(50.0, cents));
        applyConstellationToAllVoices();
    }
    
    double getDetuneSpread() const {
        return mDetuneSpread;
    }
    
    // Phase 3.2: Time Offset Spread (0-50 ms)
    void setTimeOffsetSpread(double ms) {
        mTimeOffsetSpread = std::max(0.0, std::min(50.0, ms));
        applyConstellationToAllVoices();
    }
    
    double getTimeOffsetSpread() const {
        return mTimeOffsetSpread;
    }
    
    // Phase 3.3: Formant Offset Spread (0-200 Hz)
    void setFormantOffsetSpread(double hz) {
        mFormantOffsetSpread = std::max(0.0, std::min(200.0, hz));
        applyConstellationToAllVoices();
    }
    
    double getFormantOffsetSpread() const {
        return mFormantOffsetSpread;
    }
    
    // Phase 3.4: Pan Spread (0-1.0)
    void setPanSpread(double spread) {
        mPanSpread = std::max(0.0, std::min(1.0, spread));
        applyConstellationToAllVoices();
    }
    
    double getPanSpread() const {
        return mPanSpread;
    }
    
    // Phase 3.5: LFO Phase Spread (0-360 degrees)
    void setLFOPhaseSpread(double degrees) {
        mLFOPhaseSpread = std::max(0.0, std::min(360.0, degrees));
        applyConstellationToAllVoices();
    }
    
    double getLFOPhaseSpread() const {
        return mLFOPhaseSpread;
    }
    
    // Phase 3.6: Constellation Mode (acts as preset)
    void setConstellationMode(ConstellationMode mode) {
        mConstellationMode = mode;
        applyConstellationModePreset();  // Apply preset values
        applyConstellationToAllVoices();
    }
    
    ConstellationMode getConstellationMode() const {
        return mConstellationMode;
    }
    
    // Phase 3.7: Unison Voice Count (1-8)
    void setUnisonVoices(int count) {
        mUnisonVoices = std::max(1, std::min(8, count));
    }
    
    int getUnisonVoices() const {
        return mUnisonVoices;
    }
    
    // Get voice count
    int getVoiceCount() const {
        return mVoiceCount;
    }
    
    // Get number of currently active voices
    int getActiveVoiceCount() const {
        int count = 0;
        for (int i = 0; i < mVoiceCount; ++i) {
            if (mVoices[i]->isActive()) {
                count++;
            }
        }
        return count;
    }
    
    // Check if a specific note is currently active
    bool isNoteActive(int32_t note) const {
        int voiceIndex = mAllocator.findVoicePlayingNote(note);
        if (voiceIndex >= 0 && voiceIndex < mVoiceCount) {
            return mVoices[voiceIndex]->isActive();
        }
        return false;
    }
    
    // Allocation mode control
    void setAllocationMode(VoiceAllocator::Mode mode) {
        mAllocator.setAllocationMode(mode);
    }
    
    VoiceAllocator::Mode getAllocationMode() const {
        return mAllocator.getAllocationMode();
    }
    
    // Voice stealing control
    void setStealingEnabled(bool enabled) {
        mStealingEnabled = enabled;
    }
    
    bool isStealingEnabled() const {
        return mStealingEnabled;
    }
    
    void setStealingMode(StealingMode mode) {
        mStealingMode = mode;
    }
    
    StealingMode getStealingMode() const {
        return mStealingMode;
    }
    
    // Note on - returns voice index or -1 if no voice available
    // With unison voices > 1, triggers multiple voices for a single note
    int noteOn(int32_t note, double velocity) {
        // Check if this note is already playing - retrigger it
        int existingVoice = mAllocator.findVoicePlayingNote(note);
        if (existingVoice >= 0) {
            // Retrigger all unison voices for this note
            for (int i = 0; i < mVoiceCount; ++i) {
                if (mUnisonGroupNote[i] == note) {
                    mVoices[i]->noteOn(note, velocity);
                    mVoiceVelocities[i] = velocity;
                }
            }
            return existingVoice;
        }
        
        // For unison mode, allocate multiple voices
        int firstVoiceIndex = -1;
        int voicesAllocated = 0;
        
        for (int u = 0; u < mUnisonVoices && voicesAllocated < mVoiceCount; ++u) {
            int voiceIndex = mAllocator.allocate(note);
            
            // If no free voice and stealing is enabled, steal one
            if (voiceIndex < 0 && mStealingEnabled) {
                voiceIndex = stealVoice();
                if (voiceIndex >= 0) {
                    mAllocator.deallocate(voiceIndex);
                    voiceIndex = mAllocator.allocate(note);
                    if (voiceIndex < 0) {
                        voiceIndex = stealVoice();
                    }
                }
            }
            
            if (voiceIndex >= 0) {
                if (firstVoiceIndex < 0) firstVoiceIndex = voiceIndex;
                
                mVoices[voiceIndex]->reset();
                applyConstellationToVoice(voiceIndex, u, mUnisonVoices);
                mVoices[voiceIndex]->noteOn(note, velocity);
                mVoiceVelocities[voiceIndex] = velocity;
                mUnisonGroupNote[voiceIndex] = note;
                voicesAllocated++;
            } else {
                break;  // No more voices available
            }
        }
        
        return firstVoiceIndex;
    }
    
    // Note off - releases all unison voices playing this note
    void noteOff(int32_t note) {
        // Release all voices in the unison group for this note
        for (int i = 0; i < mVoiceCount; ++i) {
            if (mUnisonGroupNote[i] == note) {
                mVoices[i]->noteOff(note);
                // Don't deallocate yet - wait for envelope to reach idle
            }
        }
    }
    
    // Release all notes
    void allNotesOff() {
        for (int i = 0; i < mVoiceCount; ++i) {
            if (mVoices[i]->isActive()) {
                mVoices[i]->noteOff();
            }
        }
    }
    
    // Set pitch bend (affects all voices)
    void setPitchBend(double semitones) {
        for (int i = 0; i < mVoiceCount; ++i) {
            mVoices[i]->setPitchBend(semitones);
        }
    }
    
    // Set polyphonic aftertouch for a specific note (Phase 2.5)
    void setPolyAftertouch(int32_t note, double pressure) {
        int voiceIndex = mAllocator.findVoicePlayingNote(note);
        if (voiceIndex >= 0 && voiceIndex < mVoiceCount) {
            mVoices[voiceIndex]->setAftertouch(pressure);
        }
    }
    
    // Reset all voices immediately
    void reset() {
        for (int i = 0; i < mVoiceCount; ++i) {
            mVoices[i]->reset();
        }
        mAllocator.reset();
    }
    
    // Process one sample - sums all active voices
    double process() {
        double output = 0.0;
        
        for (int i = 0; i < mVoiceCount; ++i) {
            if (mVoices[i]->isActive()) {
                output += mVoices[i]->process();
                
                // Check if voice has finished (envelope reached idle)
                // Return voice to pool
                if (!mVoices[i]->isActive()) {
                    mAllocator.deallocate(i);
                    mUnisonGroupNote[i] = -1;
                }
            }
        }
        
        return output;
    }
    
    // Process a block of samples
    void processBlock(double* output, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            output[i] = process();
        }
    }
    
    // Process stereo with pan spread applied
    void processBlockStereo(double* left, double* right, int numSamples) {
        for (int s = 0; s < numSamples; ++s) {
            double leftSum = 0.0;
            double rightSum = 0.0;
            
            for (int i = 0; i < mVoiceCount; ++i) {
                if (mVoices[i]->isActive()) {
                    double sample = mVoices[i]->process();
                    
                    // Apply pan (constant-power panning)
                    double pan = mVoices[i]->getPan();  // -1 (left) to +1 (right)
                    double panAngle = (pan + 1.0) * 0.25 * 3.14159265359;  // 0 to π/2
                    double leftGain = std::cos(panAngle);
                    double rightGain = std::sin(panAngle);
                    
                    leftSum += sample * leftGain;
                    rightSum += sample * rightGain;
                    
                    // Check if voice has finished
                    if (!mVoices[i]->isActive()) {
                        mAllocator.deallocate(i);
                        mUnisonGroupNote[i] = -1;
                    }
                }
            }
            
            left[s] = leftSum;
            right[s] = rightSum;
        }
    }
    
    // Get access to the allocator for advanced queries
    const VoiceAllocator& getAllocator() const {
        return mAllocator;
    }
    
    // Get a voice by index (for voice stealing etc.)
    VoxVoice* getVoice(int index) {
        if (index >= 0 && index < mVoiceCount) {
            return mVoices[index].get();
        }
        return nullptr;
    }
    
    const VoxVoice* getVoice(int index) const {
        if (index >= 0 && index < mVoiceCount) {
            return mVoices[index].get();
        }
        return nullptr;
    }
    
private:
    // Find a voice to steal based on current stealing mode
    int stealVoice() {
        switch (mStealingMode) {
            case StealingMode::Oldest:
                return mAllocator.getOldestActiveVoice();
                
            case StealingMode::Quietest:
                return findQuietestVoice();
        }
        return -1;
    }
    
    // Find the voice with the lowest velocity
    int findQuietestVoice() {
        int quietest = -1;
        double quietestVelocity = 2.0;  // Higher than max possible
        
        for (int i = 0; i < mVoiceCount; ++i) {
            if (mVoices[i]->isActive() && mVoiceVelocities[i] < quietestVelocity) {
                quietestVelocity = mVoiceVelocities[i];
                quietest = i;
            }
        }
        return quietest;
    }
    
    // Get current spread values (mode presets modify these when set)
    void getEffectiveSpreads(double& detune, double& timeOffset, double& formantOffset, 
                            double& pan, double& lfoPhase) const {
        // Just return the current spread values - mode presets set these when activated
        detune = mDetuneSpread;
        timeOffset = mTimeOffsetSpread;
        formantOffset = mFormantOffsetSpread;
        pan = mPanSpread;
        lfoPhase = mLFOPhaseSpread;
    }
    
    // Apply constellation mode as a preset that sets all spread values
    void applyConstellationModePreset() {
        switch (mConstellationMode) {
            case ConstellationMode::Unison:
                // All spreads = 0 (tight, fat)
                mDetuneSpread = 0.0;
                mTimeOffsetSpread = 0.0;
                mFormantOffsetSpread = 0.0;
                mPanSpread = 0.0;
                mLFOPhaseSpread = 0.0;
                break;
                
            case ConstellationMode::Ensemble:
                // Subtle spreads (string section feel)
                mDetuneSpread = 15.0;
                mTimeOffsetSpread = 10.0;
                mFormantOffsetSpread = 50.0;
                mPanSpread = 0.4;
                mLFOPhaseSpread = 45.0;
                break;
                
            case ConstellationMode::Choir:
                // Maximum spreads (individual voices audible)
                mDetuneSpread = 50.0;
                mTimeOffsetSpread = 50.0;
                mFormantOffsetSpread = 200.0;
                mPanSpread = 1.0;
                mLFOPhaseSpread = 360.0;
                break;
                
            case ConstellationMode::Random:
                // Keep current values but randomize application
                // Values stay as user set them
                break;
        }
    }
    
    // Apply constellation settings to all voices
    void applyConstellationToAllVoices() {
        for (int i = 0; i < mVoiceCount; ++i) {
            applyConstellationToVoice(i, i, mVoiceCount);
        }
    }
    
    // Apply constellation settings to a specific voice
    // Uses the voice's pool index for consistent stereo/detune positioning
    // unisonIndex/unisonCount are for distribution within unison groups
    void applyConstellationToVoice(int voiceIndex, int unisonIndex, int unisonCount) {
        if (voiceIndex < 0 || voiceIndex >= mVoiceCount) return;
        
        double detune, timeOffset, formantOffset, pan, lfoPhase;
        getEffectiveSpreads(detune, timeOffset, formantOffset, pan, lfoPhase);
        
        // Calculate position in spread range (-1 to +1)
        // Use the voice's pool index for consistent positioning (each "singer" has their spot)
        double spreadPos;
        double center = (mVoiceCount - 1) / 2.0;  // e.g., 3.5 for 8 voices
        if (center > 0.0) {
            spreadPos = (voiceIndex - center) / center;  // -1 to +1
        } else {
            spreadPos = 0.0;
        }
        
        // Apply random variation for Random mode
        if (mConstellationMode == ConstellationMode::Random) {
            spreadPos = mRandomDist(mRandomGenerator);
        }
        
        // Calculate and apply offsets
        double detuneOffset = spreadPos * detune;
        double timeOffsetValue = spreadPos * timeOffset;
        double formantOffsetValue = spreadPos * formantOffset;
        double panValue = spreadPos * pan;  // -1 to +1
        
        // LFO phase uses voice index for consistent distribution
        double lfoPhaseOffset = (static_cast<double>(voiceIndex) / mVoiceCount) * lfoPhase / 360.0;
        
        if (mConstellationMode == ConstellationMode::Random) {
            lfoPhaseOffset = std::abs(mRandomDist(mRandomGenerator)) * lfoPhase / 360.0;
        }
        
        // Apply to voice parameters
        VoxVoiceParameters voiceParams = mParameters;
        voiceParams.lfoPhaseSpread = lfoPhaseOffset;
        
        mVoices[voiceIndex]->setParameters(voiceParams);
        mVoices[voiceIndex]->setDetuneOffset(detuneOffset);
        mVoices[voiceIndex]->setTimeOffset(timeOffsetValue);
        mVoices[voiceIndex]->setFormantOffset(formantOffsetValue);
        mVoices[voiceIndex]->setPan(panValue);
        mVoices[voiceIndex]->setLFOPhaseOffset(lfoPhaseOffset);
    }
    
    int mVoiceCount;
    double mSampleRate;
    VoxVoiceParameters mParameters;
    
    std::array<std::unique_ptr<VoxVoice>, kMaxVoices> mVoices;
    std::array<double, kMaxVoices> mVoiceVelocities;
    std::array<int32_t, kMaxVoices> mUnisonGroupNote;  // Track unison groups
    VoiceAllocator mAllocator;
    
    bool mStealingEnabled;
    StealingMode mStealingMode;
    
    // Phase 3: Constellation parameters
    ConstellationMode mConstellationMode;
    double mDetuneSpread;      // 0-50 cents
    double mTimeOffsetSpread;  // 0-50 ms
    double mFormantOffsetSpread;  // 0-200 Hz
    double mPanSpread;         // 0-1.0 (0-100%)
    double mLFOPhaseSpread;    // 0-360 degrees
    int mUnisonVoices;         // 1-8
    
    // Random generator for Random mode
    mutable std::mt19937 mRandomGenerator;
    mutable std::uniform_real_distribution<double> mRandomDist;
};

#endif // __cplusplus
