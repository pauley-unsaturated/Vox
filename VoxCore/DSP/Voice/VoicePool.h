//
//  VoicePool.h
//  VoxCore
//
//  Voice Pool Manager for Polyphonic Synthesis
//  Manages VoxVoice instances and handles MIDI note routing
//

#pragma once

#ifdef __cplusplus

#include "VoiceAllocator.h"
#include "VoxVoice.h"
#include <array>
#include <memory>

class VoicePool {
public:
    // Maximum voices supported
    static constexpr int kMaxVoices = VoiceAllocator::kMaxVoices;
    
    // Voice stealing modes
    enum class StealingMode {
        Oldest,    // Steal the oldest active voice
        Quietest   // Steal the voice with lowest velocity
    };
    
    // Constructor
    VoicePool(int voiceCount = 8, double sampleRate = 44100.0)
        : mVoiceCount(std::min(voiceCount, kMaxVoices))
        , mSampleRate(sampleRate)
        , mAllocator(voiceCount)
        , mStealingEnabled(true)
        , mStealingMode(StealingMode::Oldest)
    {
        // Initialize all voices with their index for LFO phase spreading
        for (int i = 0; i < kMaxVoices; ++i) {
            mVoices[i] = std::make_unique<VoxVoice>(sampleRate);
            mVoices[i]->setVoiceIndex(i);  // Set voice index for phase spreading
            mVoiceVelocities[i] = 0.0;
        }
    }
    
    // Set sample rate for all voices
    void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        for (int i = 0; i < mVoiceCount; ++i) {
            mVoices[i]->setSampleRate(sampleRate);
        }
    }
    
    // Set parameters for all voices
    void setParameters(const VoxVoiceParameters& params) {
        mParameters = params;
        for (int i = 0; i < mVoiceCount; ++i) {
            mVoices[i]->setParameters(params);
        }
    }
    
    VoxVoiceParameters getParameters() const {
        return mParameters;
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
    int noteOn(int32_t note, double velocity) {
        // Check if this note is already playing - retrigger it
        int existingVoice = mAllocator.findVoicePlayingNote(note);
        if (existingVoice >= 0) {
            mVoices[existingVoice]->noteOn(note, velocity);
            mVoiceVelocities[existingVoice] = velocity;
            return existingVoice;
        }
        
        // Try to allocate a new voice
        int voiceIndex = mAllocator.allocate(note);
        
        // If no free voice and stealing is enabled, steal one
        if (voiceIndex < 0 && mStealingEnabled) {
            voiceIndex = stealVoice();
            if (voiceIndex >= 0) {
                // Deallocate the stolen voice first
                mAllocator.deallocate(voiceIndex);
                // Then reallocate it for the new note
                mAllocator.allocate(note);
                // The allocator will give us a different index potentially,
                // so we need to find the right one
                voiceIndex = mAllocator.findVoicePlayingNote(note);
                if (voiceIndex < 0) {
                    // Fallback - just use the stolen voice directly
                    voiceIndex = stealVoice();
                }
            }
        }
        
        if (voiceIndex >= 0) {
            mVoices[voiceIndex]->reset();  // Clean slate for stolen voice
            mVoices[voiceIndex]->setParameters(mParameters);
            mVoices[voiceIndex]->noteOn(note, velocity);
            mVoiceVelocities[voiceIndex] = velocity;
        }
        return voiceIndex;
    }
    
    // Note off
    void noteOff(int32_t note) {
        int voiceIndex = mAllocator.findVoicePlayingNote(note);
        if (voiceIndex >= 0) {
            mVoices[voiceIndex]->noteOff(note);
            // Don't deallocate yet - wait for envelope to reach idle
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
    
    // Process stereo (mono voice to both channels)
    void processBlockStereo(double* left, double* right, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            double sample = process();
            left[i] = sample;
            right[i] = sample;
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
    
    int mVoiceCount;
    double mSampleRate;
    VoxVoiceParameters mParameters;
    
    std::array<std::unique_ptr<VoxVoice>, kMaxVoices> mVoices;
    std::array<double, kMaxVoices> mVoiceVelocities;
    VoiceAllocator mAllocator;
    
    bool mStealingEnabled;
    StealingMode mStealingMode;
};

#endif // __cplusplus
