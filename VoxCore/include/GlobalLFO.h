//
//  GlobalLFO.h
//  VoxCore
//
//  Phase 4.1: Global LFO - Two global LFOs that affect all voices
//  Same shapes as per-voice LFO: Sine, Triangle, Saw, Square, S&H
//

#pragma once

#ifdef __cplusplus

#include "../Oscillators/LFO.h"
#include <array>

// Modulation destinations for global LFOs
enum class GlobalLFODestination {
    None,
    Pitch,
    Formant1,
    Formant2,
    VowelMorph,
    DutyCycle,
    Pan,
    Amplitude
};

// A single global LFO with amount and destination routing
class GlobalLFO {
public:
    GlobalLFO(double sampleRate = 44100.0)
        : mLFO(sampleRate)
        , mAmount(0.0)
        , mDestination(GlobalLFODestination::None)
        , mCurrentValue(0.0)
    {
        // Global LFOs default to slower rates
        mLFO.setRate(1.0);
        mLFO.setWaveform(LFO::Waveform::SINE);
        mLFO.setSmoothingCutoff(20.0);  // Smooth output
    }
    
    void setSampleRate(double sampleRate) {
        mLFO.setSampleRate(sampleRate);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // LFO Parameters
    // ═══════════════════════════════════════════════════════════════
    
    void setRate(double rateHz) {
        mLFO.setRate(rateHz);
    }
    
    double getRate() const {
        return mLFO.getRate();
    }
    
    void setWaveform(LFO::Waveform waveform) {
        mLFO.setWaveform(waveform);
    }
    
    LFO::Waveform getWaveform() const {
        return mLFO.getWaveform();
    }
    
    // Tempo sync support
    void setSyncMode(LFO::SyncMode mode) {
        mLFO.setSyncMode(mode);
    }
    
    LFO::SyncMode getSyncMode() const {
        return mLFO.getSyncMode();
    }
    
    void setBeatDivision(LFO::BeatDivision division) {
        mLFO.setBeatDivision(division);
    }
    
    LFO::BeatDivision getBeatDivision() const {
        return mLFO.getBeatDivision();
    }
    
    void setTempo(double bpm) {
        mLFO.setTempo(bpm);
    }
    
    double getTempo() const {
        return mLFO.getTempo();
    }
    
    void setPhaseOffset(double offset) {
        mLFO.setPhaseOffset(offset);
    }
    
    double getPhaseOffset() const {
        return mLFO.getPhaseOffset();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Amount and Destination Routing
    // ═══════════════════════════════════════════════════════════════
    
    // Amount: how much this LFO modulates (-1.0 to 1.0 for bipolar control)
    void setAmount(double amount) {
        mAmount = std::max(-1.0, std::min(1.0, amount));
    }
    
    double getAmount() const {
        return mAmount;
    }
    
    // Primary destination for this LFO
    void setDestination(GlobalLFODestination dest) {
        mDestination = dest;
    }
    
    GlobalLFODestination getDestination() const {
        return mDestination;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Processing
    // ═══════════════════════════════════════════════════════════════
    
    void reset() {
        mLFO.reset();
        mCurrentValue = 0.0;
    }
    
    // Process one sample, returns value in range [-1, 1]
    double process() {
        mCurrentValue = mLFO.process();
        return mCurrentValue;
    }
    
    // Get the current output value (without advancing phase)
    double getCurrentValue() const {
        return mCurrentValue;
    }
    
    // Get modulated output (value * amount)
    double getModulatedOutput() const {
        return mCurrentValue * mAmount;
    }
    
    // Calculate modulation amount for a specific destination
    // Returns scaled value appropriate for the destination
    double getModulationFor(GlobalLFODestination dest) const {
        if (dest != mDestination) {
            return 0.0;
        }
        return mCurrentValue * mAmount;
    }
    
    // Access underlying LFO for advanced control
    LFO& getLFO() { return mLFO; }
    const LFO& getLFO() const { return mLFO; }
    
private:
    LFO mLFO;
    double mAmount;
    GlobalLFODestination mDestination;
    double mCurrentValue;
};

// Container for two global LFOs
class GlobalLFOBank {
public:
    static constexpr int kNumGlobalLFOs = 2;
    
    GlobalLFOBank(double sampleRate = 44100.0) {
        for (int i = 0; i < kNumGlobalLFOs; ++i) {
            mLFOs[i] = GlobalLFO(sampleRate);
        }
    }
    
    void setSampleRate(double sampleRate) {
        for (int i = 0; i < kNumGlobalLFOs; ++i) {
            mLFOs[i].setSampleRate(sampleRate);
        }
    }
    
    void reset() {
        for (int i = 0; i < kNumGlobalLFOs; ++i) {
            mLFOs[i].reset();
        }
    }
    
    // Process all LFOs for one sample
    void process() {
        for (int i = 0; i < kNumGlobalLFOs; ++i) {
            mLFOs[i].process();
        }
    }
    
    // Access individual LFOs
    GlobalLFO& getLFO(int index) {
        return mLFOs[std::max(0, std::min(kNumGlobalLFOs - 1, index))];
    }
    
    const GlobalLFO& getLFO(int index) const {
        return mLFOs[std::max(0, std::min(kNumGlobalLFOs - 1, index))];
    }
    
    // Convenience accessors
    GlobalLFO& lfo1() { return mLFOs[0]; }
    GlobalLFO& lfo2() { return mLFOs[1]; }
    const GlobalLFO& lfo1() const { return mLFOs[0]; }
    const GlobalLFO& lfo2() const { return mLFOs[1]; }
    
    // Get total modulation for a destination from all LFOs
    double getTotalModulationFor(GlobalLFODestination dest) const {
        double total = 0.0;
        for (int i = 0; i < kNumGlobalLFOs; ++i) {
            total += mLFOs[i].getModulationFor(dest);
        }
        return total;
    }
    
    // Set tempo for all LFOs (for host sync)
    void setTempo(double bpm) {
        for (int i = 0; i < kNumGlobalLFOs; ++i) {
            mLFOs[i].setTempo(bpm);
        }
    }
    
private:
    std::array<GlobalLFO, kNumGlobalLFOs> mLFOs;
};

#endif // __cplusplus
