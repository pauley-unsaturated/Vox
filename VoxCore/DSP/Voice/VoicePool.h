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
    
    // Constructor
    VoicePool(int voiceCount = 8, double sampleRate = 44100.0)
        : mVoiceCount(std::min(voiceCount, kMaxVoices))
        , mSampleRate(sampleRate)
        , mAllocator(voiceCount)
    {
        // Initialize all voices
        for (int i = 0; i < kMaxVoices; ++i) {
            mVoices[i] = std::make_unique<VoxVoice>(sampleRate);
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
    
    // Note on - returns voice index or -1 if no voice available
    int noteOn(int32_t note, double velocity) {
        // Check if this note is already playing - retrigger it
        int existingVoice = mAllocator.findVoicePlayingNote(note);
        if (existingVoice >= 0) {
            mVoices[existingVoice]->noteOn(note, velocity);
            return existingVoice;
        }
        
        // Allocate a new voice
        int voiceIndex = mAllocator.allocate(note);
        if (voiceIndex >= 0) {
            mVoices[voiceIndex]->noteOn(note, velocity);
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
    int mVoiceCount;
    double mSampleRate;
    VoxVoiceParameters mParameters;
    
    std::array<std::unique_ptr<VoxVoice>, kMaxVoices> mVoices;
    VoiceAllocator mAllocator;
};

#endif // __cplusplus
