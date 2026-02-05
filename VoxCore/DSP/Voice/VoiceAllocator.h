//
//  VoiceAllocator.h
//  VoxCore
//
//  Voice Allocator for Polyphonic Synthesis
//  Tracks which voices are active/free and manages allocation strategies
//

#pragma once

#ifdef __cplusplus

#include <array>
#include <cstdint>
#include <algorithm>

class VoiceAllocator {
public:
    // Maximum number of voices supported
    static constexpr int kMaxVoices = 16;
    
    // Allocation modes
    enum class Mode {
        RoundRobin,    // Cycle through voices sequentially
        LowestNote,    // Always use lowest available voice index
        HighestNote,   // Always use highest available voice index
        LastPlayed     // Reuse most recently released voice
    };
    
    // Constructor
    explicit VoiceAllocator(int voiceCount = 8)
        : mVoiceCount(std::min(voiceCount, kMaxVoices))
        , mMode(Mode::RoundRobin)
        , mNextRoundRobin(0)
        , mAllocationCounter(0)
    {
        reset();
    }
    
    // Set/get allocation mode
    void setAllocationMode(Mode mode) {
        mMode = mode;
    }
    
    Mode getAllocationMode() const {
        return mMode;
    }
    
    // Get voice counts
    int getVoiceCount() const {
        return mVoiceCount;
    }
    
    int getActiveVoiceCount() const {
        int count = 0;
        for (int i = 0; i < mVoiceCount; ++i) {
            if (mVoices[i].active) {
                count++;
            }
        }
        return count;
    }
    
    int getFreeVoiceCount() const {
        return mVoiceCount - getActiveVoiceCount();
    }
    
    // Allocate a voice for a note
    // Returns voice index (0 to voiceCount-1) or -1 if no voice available
    int allocate(int32_t note) {
        int voiceIndex = -1;
        
        switch (mMode) {
            case Mode::RoundRobin:
                voiceIndex = allocateRoundRobin();
                break;
            case Mode::LowestNote:
                voiceIndex = allocateLowest();
                break;
            case Mode::HighestNote:
                voiceIndex = allocateHighest();
                break;
            case Mode::LastPlayed:
                voiceIndex = allocateLastPlayed();
                break;
        }
        
        if (voiceIndex >= 0) {
            mVoices[voiceIndex].active = true;
            mVoices[voiceIndex].note = note;
            mVoices[voiceIndex].age = mAllocationCounter++;
            mLastAllocatedVoice = voiceIndex;
        }
        
        return voiceIndex;
    }
    
    // Deallocate a voice
    void deallocate(int voiceIndex) {
        if (voiceIndex >= 0 && voiceIndex < mVoiceCount) {
            mVoices[voiceIndex].active = false;
            mVoices[voiceIndex].releaseAge = mAllocationCounter++;
            mLastReleasedVoice = voiceIndex;
        }
    }
    
    // Find voice playing a specific note
    // Returns voice index or -1 if not found
    int findVoicePlayingNote(int32_t note) const {
        for (int i = 0; i < mVoiceCount; ++i) {
            if (mVoices[i].active && mVoices[i].note == note) {
                return i;
            }
        }
        return -1;
    }
    
    // Check if a voice is active
    bool isVoiceActive(int voiceIndex) const {
        if (voiceIndex >= 0 && voiceIndex < mVoiceCount) {
            return mVoices[voiceIndex].active;
        }
        return false;
    }
    
    // Get note for a voice (-1 if inactive)
    int32_t getNoteForVoice(int voiceIndex) const {
        if (voiceIndex >= 0 && voiceIndex < mVoiceCount && mVoices[voiceIndex].active) {
            return mVoices[voiceIndex].note;
        }
        return -1;
    }
    
    // Get allocation age for a voice (higher = newer)
    uint64_t getAgeForVoice(int voiceIndex) const {
        if (voiceIndex >= 0 && voiceIndex < mVoiceCount) {
            return mVoices[voiceIndex].age;
        }
        return 0;
    }
    
    // Get oldest active voice (for stealing)
    int getOldestActiveVoice() const {
        int oldest = -1;
        uint64_t oldestAge = UINT64_MAX;
        
        for (int i = 0; i < mVoiceCount; ++i) {
            if (mVoices[i].active && mVoices[i].age < oldestAge) {
                oldestAge = mVoices[i].age;
                oldest = i;
            }
        }
        return oldest;
    }
    
    // Get newest active voice
    int getNewestActiveVoice() const {
        int newest = -1;
        uint64_t newestAge = 0;
        
        for (int i = 0; i < mVoiceCount; ++i) {
            if (mVoices[i].active && mVoices[i].age >= newestAge) {
                newestAge = mVoices[i].age;
                newest = i;
            }
        }
        return newest;
    }
    
    // Reset all allocations
    void reset() {
        for (int i = 0; i < kMaxVoices; ++i) {
            mVoices[i].active = false;
            mVoices[i].note = -1;
            mVoices[i].age = 0;
            mVoices[i].releaseAge = 0;
        }
        mNextRoundRobin = 0;
        mAllocationCounter = 0;
        mLastAllocatedVoice = -1;
        mLastReleasedVoice = -1;
    }
    
private:
    // Voice state
    struct VoiceState {
        bool active = false;
        int32_t note = -1;
        uint64_t age = 0;         // When allocated (higher = newer)
        uint64_t releaseAge = 0;  // When released (for LastPlayed mode)
    };
    
    // Allocate using round-robin strategy
    int allocateRoundRobin() {
        // Start from next round-robin position
        for (int i = 0; i < mVoiceCount; ++i) {
            int idx = (mNextRoundRobin + i) % mVoiceCount;
            if (!mVoices[idx].active) {
                mNextRoundRobin = (idx + 1) % mVoiceCount;
                return idx;
            }
        }
        return -1; // No free voice
    }
    
    // Allocate lowest available voice index
    int allocateLowest() {
        for (int i = 0; i < mVoiceCount; ++i) {
            if (!mVoices[i].active) {
                return i;
            }
        }
        return -1;
    }
    
    // Allocate highest available voice index
    int allocateHighest() {
        for (int i = mVoiceCount - 1; i >= 0; --i) {
            if (!mVoices[i].active) {
                return i;
            }
        }
        return -1;
    }
    
    // Allocate most recently released voice (LIFO style)
    int allocateLastPlayed() {
        // First, try to find the most recently released voice
        int best = -1;
        uint64_t bestAge = 0;
        
        for (int i = 0; i < mVoiceCount; ++i) {
            if (!mVoices[i].active && mVoices[i].releaseAge >= bestAge) {
                bestAge = mVoices[i].releaseAge;
                best = i;
            }
        }
        
        // If we found a released voice, use it
        if (best >= 0) {
            return best;
        }
        
        // Otherwise fall back to lowest available
        return allocateLowest();
    }
    
    std::array<VoiceState, kMaxVoices> mVoices;
    int mVoiceCount;
    Mode mMode;
    int mNextRoundRobin;
    uint64_t mAllocationCounter;
    int mLastAllocatedVoice = -1;
    int mLastReleasedVoice = -1;
};

#endif // __cplusplus
