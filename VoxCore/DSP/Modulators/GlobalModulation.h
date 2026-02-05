//
//  GlobalModulation.h
//  VoxCore
//
//  Phase 4: Global Modulation Container
//  Combines all global modulation sources:
//  - Two Global LFOs
//  - Drift Engine
//  - Chaos Generator (Lorenz/Henon)
//  - Formant Step Sequencer
//

#pragma once

#ifdef __cplusplus

#include "GlobalLFO.h"
#include "DriftGenerator.h"
#include "ChaosGenerator.h"
#include "FormantSequencer.h"

// Modulation routing destinations
enum class ModDestination {
    None,
    Pitch,
    Formant1,
    Formant2,
    VowelMorph,
    DutyCycle,
    Pan,
    Amplitude,
    GrainDensity,
    CloudScatter
};

// Modulation amounts for routing
struct GlobalModulationAmounts {
    // Global LFO 1 destinations
    double lfo1ToPitch = 0.0;         // semitones
    double lfo1ToFormant1 = 0.0;      // Hz
    double lfo1ToFormant2 = 0.0;      // Hz
    double lfo1ToVowelMorph = 0.0;    // 0-1 range
    double lfo1ToDutyCycle = 0.0;     // 0-1 range
    double lfo1ToPan = 0.0;           // -1 to 1
    
    // Global LFO 2 destinations
    double lfo2ToPitch = 0.0;
    double lfo2ToFormant1 = 0.0;
    double lfo2ToFormant2 = 0.0;
    double lfo2ToVowelMorph = 0.0;
    double lfo2ToDutyCycle = 0.0;
    double lfo2ToPan = 0.0;
    
    // Drift destinations
    double driftToPitch = 0.0;
    double driftToFormant1 = 0.0;
    double driftToFormant2 = 0.0;
    double driftToVowelMorph = 0.0;
    double driftToDutyCycle = 0.0;
    double driftToPan = 0.0;
    
    // Chaos destinations
    double chaosToPitch = 0.0;
    double chaosToFormant1 = 0.0;
    double chaosToFormant2 = 0.0;
    double chaosToVowelMorph = 0.0;
    double chaosToDutyCycle = 0.0;
    double chaosToPan = 0.0;
    
    // Sequencer destination (typically vowel morph)
    double sequencerToVowelMorph = 1.0;  // Default: full control
};

// Container for all global modulation outputs
struct GlobalModulationValues {
    double totalPitchMod = 0.0;       // semitones
    double totalFormant1Mod = 0.0;    // Hz
    double totalFormant2Mod = 0.0;    // Hz
    double totalVowelMorphMod = 0.0;  // 0-1 range
    double totalDutyCycleMod = 0.0;   // 0-1 range
    double totalPanMod = 0.0;         // -1 to 1
    
    // Individual source values (for visualization)
    double lfo1Value = 0.0;
    double lfo2Value = 0.0;
    double driftValue = 0.0;
    double chaosValue = 0.0;
    double sequencerValue = 0.0;
};

class GlobalModulation {
public:
    GlobalModulation(double sampleRate = 44100.0)
        : mSampleRate(sampleRate)
        , mLFOBank(sampleRate)
        , mDrift(sampleRate)
        , mChaos(sampleRate)
        , mSequencer(sampleRate)
    {
    }
    
    void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        mLFOBank.setSampleRate(sampleRate);
        mDrift.setSampleRate(sampleRate);
        mChaos.setSampleRate(sampleRate);
        mSequencer.setSampleRate(sampleRate);
    }
    
    void reset() {
        mLFOBank.reset();
        mDrift.reset();
        mChaos.reset();
        mSequencer.reset();
        mValues = GlobalModulationValues();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Modulation Routing
    // ═══════════════════════════════════════════════════════════════
    
    void setRoutingAmounts(const GlobalModulationAmounts& amounts) {
        mAmounts = amounts;
    }
    
    const GlobalModulationAmounts& getRoutingAmounts() const {
        return mAmounts;
    }
    
    GlobalModulationAmounts& getRoutingAmounts() {
        return mAmounts;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Component Access
    // ═══════════════════════════════════════════════════════════════
    
    GlobalLFOBank& getLFOBank() { return mLFOBank; }
    const GlobalLFOBank& getLFOBank() const { return mLFOBank; }
    
    GlobalLFO& getLFO1() { return mLFOBank.lfo1(); }
    GlobalLFO& getLFO2() { return mLFOBank.lfo2(); }
    const GlobalLFO& getLFO1() const { return mLFOBank.lfo1(); }
    const GlobalLFO& getLFO2() const { return mLFOBank.lfo2(); }
    
    DriftGenerator& getDrift() { return mDrift; }
    const DriftGenerator& getDrift() const { return mDrift; }
    
    ChaosGenerator& getChaos() { return mChaos; }
    const ChaosGenerator& getChaos() const { return mChaos; }
    
    FormantSequencer& getSequencer() { return mSequencer; }
    const FormantSequencer& getSequencer() const { return mSequencer; }
    
    // ═══════════════════════════════════════════════════════════════
    // Processing
    // ═══════════════════════════════════════════════════════════════
    
    // Process all modulation sources for one sample
    GlobalModulationValues process() {
        // Process all sources
        mLFOBank.process();
        double lfo1 = mLFOBank.lfo1().getCurrentValue();
        double lfo2 = mLFOBank.lfo2().getCurrentValue();
        double drift = mDrift.process();
        double chaos = mChaos.process();
        double seq = mSequencer.process();
        
        // Store individual values
        mValues.lfo1Value = lfo1;
        mValues.lfo2Value = lfo2;
        mValues.driftValue = drift;
        mValues.chaosValue = chaos;
        mValues.sequencerValue = seq;
        
        // Calculate total modulation per destination
        mValues.totalPitchMod = 
            lfo1 * mAmounts.lfo1ToPitch +
            lfo2 * mAmounts.lfo2ToPitch +
            drift * mAmounts.driftToPitch +
            chaos * mAmounts.chaosToPitch;
        
        mValues.totalFormant1Mod = 
            lfo1 * mAmounts.lfo1ToFormant1 +
            lfo2 * mAmounts.lfo2ToFormant1 +
            drift * mAmounts.driftToFormant1 +
            chaos * mAmounts.chaosToFormant1;
        
        mValues.totalFormant2Mod = 
            lfo1 * mAmounts.lfo1ToFormant2 +
            lfo2 * mAmounts.lfo2ToFormant2 +
            drift * mAmounts.driftToFormant2 +
            chaos * mAmounts.chaosToFormant2;
        
        mValues.totalVowelMorphMod = 
            lfo1 * mAmounts.lfo1ToVowelMorph +
            lfo2 * mAmounts.lfo2ToVowelMorph +
            drift * mAmounts.driftToVowelMorph +
            chaos * mAmounts.chaosToVowelMorph +
            seq * mAmounts.sequencerToVowelMorph;
        
        mValues.totalDutyCycleMod = 
            lfo1 * mAmounts.lfo1ToDutyCycle +
            lfo2 * mAmounts.lfo2ToDutyCycle +
            drift * mAmounts.driftToDutyCycle +
            chaos * mAmounts.chaosToDutyCycle;
        
        mValues.totalPanMod = 
            lfo1 * mAmounts.lfo1ToPan +
            lfo2 * mAmounts.lfo2ToPan +
            drift * mAmounts.driftToPan +
            chaos * mAmounts.chaosToPan;
        
        return mValues;
    }
    
    // Get current modulation values (after process())
    GlobalModulationValues getValues() const {
        return mValues;
    }
    
    // Get modulation for a specific destination
    double getModulationFor(ModDestination dest) const {
        switch (dest) {
            case ModDestination::Pitch:
                return mValues.totalPitchMod;
            case ModDestination::Formant1:
                return mValues.totalFormant1Mod;
            case ModDestination::Formant2:
                return mValues.totalFormant2Mod;
            case ModDestination::VowelMorph:
                return mValues.totalVowelMorphMod;
            case ModDestination::DutyCycle:
                return mValues.totalDutyCycleMod;
            case ModDestination::Pan:
                return mValues.totalPanMod;
            default:
                return 0.0;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Tempo Sync (for host integration)
    // ═══════════════════════════════════════════════════════════════
    
    void setTempo(double bpm) {
        mLFOBank.setTempo(bpm);
        mSequencer.setTempo(bpm);
    }
    
private:
    double mSampleRate;
    
    // Modulation sources
    GlobalLFOBank mLFOBank;
    DriftGenerator mDrift;
    ChaosGenerator mChaos;
    FormantSequencer mSequencer;
    
    // Routing
    GlobalModulationAmounts mAmounts;
    
    // Current values
    GlobalModulationValues mValues;
};

#endif // __cplusplus
