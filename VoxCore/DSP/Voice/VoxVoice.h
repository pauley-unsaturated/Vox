//
//  VoxVoice.h
//  VoxCore
//
//  Vox Pulsar Synthesis Voice
//  Combines PulsarOscillator + FormantFilter + ADSR Envelope + Per-Voice LFO
//

#pragma once

#ifdef __cplusplus

#include "PulsarOscillator.h"
#include "FormantFilter.h"
#include "ADSREnvelope.h"
#include "LFO.h"
#include <cmath>
#include <algorithm>

// Voice parameters structure
struct VoxVoiceParameters {
    // Master
    double masterVolume = 1.0;       // 0.0 to 1.0
    
    // Pulsar Oscillator
    double dutyCycle = 0.2;          // 0.01 to 1.0
    int pulsaretShape = 1;           // 0=Gaussian, 1=RaisedCosine, 2=Sine, 3=Triangle
    
    // Formant Filter
    double formant1Freq = 800.0;     // Hz
    double formant2Freq = 1200.0;    // Hz
    double formant1Q = 10.0;         // Q factor
    double formant2Q = 10.0;         // Q factor
    double vowelMorph = 0.0;         // 0.0 to 1.0 (A-E-I-O-U)
    double formantMix = 1.0;         // 0.0 = dry, 1.0 = full formant
    bool useVowelMorph = true;       // Use vowel morph or manual formants
    
    // Amp Envelope
    double ampAttack = 0.01;         // seconds
    double ampDecay = 0.1;           // seconds
    double ampSustain = 0.7;         // 0.0 to 1.0
    double ampRelease = 0.3;         // seconds
    
    // Pitch
    double pitchBendSemitones = 0.0; // -12 to +12
    double detuneHz = 0.0;           // Fine detune in Hz
    
    // Glide/Portamento
    bool glideEnabled = false;
    double glideTime = 0.1;          // seconds
    
    // Per-Voice LFO (Phase 2.1)
    double lfoRate = 1.0;            // Hz (0.01 to 100)
    int lfoWaveform = 0;             // 0=Sine, 1=Triangle, 2=Saw, 3=Square, 4=S&H
    double lfoPhaseOffset = 0.0;     // 0.0 to 1.0 (represents 0-360°)
    bool lfoRetrigger = true;        // Retrigger LFO on note on
    double lfoPhaseSpread = 0.0;     // 0.0 to 1.0 (spread across voices)
    
    // Per-Voice Mod Envelope (Phase 2.2)
    double modAttack = 0.01;         // seconds
    double modDecay = 0.1;           // seconds
    double modSustain = 0.5;         // 0.0 to 1.0
    double modRelease = 0.3;         // seconds
};

class VoxVoice {
public:
    VoxVoice(double sampleRate = 44100.0)
        : mSampleRate(sampleRate)
        , mPulsarOsc(sampleRate)
        , mFormantFilter(sampleRate)
        , mAmpEnvelope(sampleRate)
        , mModEnvelope(sampleRate)
        , mLFO(sampleRate)
        , mCurrentNote(-1)
        , mTargetNote(-1)
        , mCurrentFrequency(440.0)
        , mTargetFrequency(440.0)
        , mGlideCoeff(1.0)
        , mVelocity(1.0)
        , mNoteOn(false)
        , mVoiceIndex(0)
    {
        // Initialize with default parameters
        setParameters(VoxVoiceParameters());
    }
    
    void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        mPulsarOsc.setSampleRate(sampleRate);
        mFormantFilter.setSampleRate(sampleRate);
        mAmpEnvelope.setSampleRate(sampleRate);
        mModEnvelope.setSampleRate(sampleRate);
        mLFO.setSampleRate(sampleRate);
        updateGlideCoeff();
    }
    
    void setParameters(const VoxVoiceParameters& params) {
        mParams = params;
        
        // Apply to pulsar oscillator
        mPulsarOsc.setDutyCycle(params.dutyCycle);
        mPulsarOsc.setShape(static_cast<PulsarOscillator::Shape>(params.pulsaretShape));
        
        // Apply to formant filter
        if (params.useVowelMorph) {
            mFormantFilter.setVowelMorph(params.vowelMorph);
        } else {
            mFormantFilter.setFormant1Frequency(params.formant1Freq);
            mFormantFilter.setFormant2Frequency(params.formant2Freq);
        }
        mFormantFilter.setFormant1Q(params.formant1Q);
        mFormantFilter.setFormant2Q(params.formant2Q);
        
        // Calculate formant mix gains
        double formantGain = params.formantMix;
        double dryGain = 1.0 - params.formantMix;
        mFormantFilter.setFormant1Gain(formantGain);
        mFormantFilter.setFormant2Gain(formantGain * 0.7);  // F2 slightly lower
        mFormantFilter.setDryGain(dryGain);
        
        // Apply to amp envelope
        mAmpEnvelope.setAttackTime(params.ampAttack);
        mAmpEnvelope.setDecayTime(params.ampDecay);
        mAmpEnvelope.setSustainLevel(params.ampSustain);
        mAmpEnvelope.setReleaseTime(params.ampRelease);
        
        // Apply to mod envelope (Phase 2.2)
        mModEnvelope.setAttackTime(params.modAttack);
        mModEnvelope.setDecayTime(params.modDecay);
        mModEnvelope.setSustainLevel(params.modSustain);
        mModEnvelope.setReleaseTime(params.modRelease);
        
        // Apply to LFO
        mLFO.setRate(params.lfoRate);
        mLFO.setWaveform(static_cast<LFO::Waveform>(params.lfoWaveform));
        
        // Calculate effective phase offset including voice spread
        double effectivePhaseOffset = params.lfoPhaseOffset;
        if (params.lfoPhaseSpread > 0.0) {
            // Spread phase across voices (assuming max 8 voices)
            effectivePhaseOffset += (mVoiceIndex / 8.0) * params.lfoPhaseSpread;
            effectivePhaseOffset = std::fmod(effectivePhaseOffset, 1.0);
        }
        mLFO.setPhaseOffset(effectivePhaseOffset);
        
        // Set retrigger mode
        mLFO.setRetriggerMode(params.lfoRetrigger ? 
            LFO::RetriggerMode::NOTE_ON : LFO::RetriggerMode::FREE);
        
        // Update glide coefficient
        updateGlideCoeff();
    }
    
    VoxVoiceParameters getParameters() const {
        return mParams;
    }
    
    // Note on with velocity (0.0 to 1.0)
    void noteOn(int noteNumber, double velocity = 1.0) {
        mVelocity = std::max(0.0, std::min(1.0, velocity));
        mTargetNote = noteNumber;
        mTargetFrequency = noteToFrequency(noteNumber);
        
        // Apply pitch bend
        if (std::abs(mParams.pitchBendSemitones) > 0.001) {
            mTargetFrequency *= std::pow(2.0, mParams.pitchBendSemitones / 12.0);
        }
        
        // Apply detune
        mTargetFrequency += mParams.detuneHz;
        
        // Handle glide
        if (!mParams.glideEnabled || mCurrentNote < 0) {
            // No glide or first note - jump to frequency
            mCurrentFrequency = mTargetFrequency;
            mCurrentNote = noteNumber;
        }
        // else: glide will happen in process()
        
        mPulsarOsc.setFrequency(mCurrentFrequency);
        mAmpEnvelope.noteOn();
        mModEnvelope.noteOn();  // Trigger mod envelope (Phase 2.2)
        
        // Retrigger LFO if configured
        if (mParams.lfoRetrigger) {
            mLFO.retrigger();
        }
        
        mNoteOn = true;
    }
    
    // Note off
    void noteOff(int noteNumber = -1) {
        // Only release if this is the current note (or no note specified)
        if (noteNumber < 0 || noteNumber == mCurrentNote || noteNumber == mTargetNote) {
            mAmpEnvelope.noteOff();
            mModEnvelope.noteOff();  // Release mod envelope (Phase 2.2)
            mNoteOn = false;
        }
    }
    
    // Set pitch bend in semitones
    void setPitchBend(double semitones) {
        mParams.pitchBendSemitones = std::max(-12.0, std::min(12.0, semitones));
        
        // Recalculate target frequency if note is playing
        if (mTargetNote >= 0) {
            mTargetFrequency = noteToFrequency(mTargetNote);
            mTargetFrequency *= std::pow(2.0, mParams.pitchBendSemitones / 12.0);
            mTargetFrequency += mParams.detuneHz;
        }
    }
    
    // Check if voice is active (making sound)
    bool isActive() const {
        return mAmpEnvelope.getState() != ADSREnvelope::State::IDLE;
    }
    
    // Reset voice
    void reset() {
        mPulsarOsc.reset();
        mFormantFilter.reset();
        mAmpEnvelope.reset();
        mModEnvelope.reset();  // Reset mod envelope (Phase 2.2)
        mLFO.reset();
        mCurrentNote = -1;
        mTargetNote = -1;
        mNoteOn = false;
        mCurrentLFOValue = 0.0;
        mCurrentModEnvValue = 0.0;
    }
    
    // Process one sample
    double process() {
        // Handle glide
        if (mParams.glideEnabled && std::abs(mCurrentFrequency - mTargetFrequency) > 0.1) {
            mCurrentFrequency += (mTargetFrequency - mCurrentFrequency) * mGlideCoeff;
            mPulsarOsc.setFrequency(mCurrentFrequency);
        } else if (std::abs(mCurrentFrequency - mTargetFrequency) > 0.1) {
            // Not gliding but frequency mismatch (pitch bend change)
            mCurrentFrequency = mTargetFrequency;
            mPulsarOsc.setFrequency(mCurrentFrequency);
        }
        
        // Update current note when glide completes
        if (mParams.glideEnabled && mTargetNote != mCurrentNote) {
            if (std::abs(mCurrentFrequency - mTargetFrequency) < 0.1) {
                mCurrentNote = mTargetNote;
            }
        }
        
        // Process LFO (advance phase even when voice may not be modulating yet)
        mCurrentLFOValue = mLFO.process();
        
        // Process mod envelope (Phase 2.2)
        mCurrentModEnvValue = mModEnvelope.process();
        
        // Generate pulsar signal
        double signal = mPulsarOsc.process();
        
        // Apply formant filter
        signal = mFormantFilter.process(signal);
        
        // Apply amplitude envelope
        double envValue = mAmpEnvelope.process();
        signal *= envValue;
        
        // Apply velocity and master volume
        signal *= mVelocity * mParams.masterVolume;
        
        return signal;
    }
    
    // Process a block of samples
    void processBlock(double* output, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            output[i] = process();
        }
    }
    
    // Process and add to buffer (for mixing multiple voices)
    void processBlockAdd(double* output, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            output[i] += process();
        }
    }
    
    // Get current envelope state
    ADSREnvelope::State getEnvelopeState() const {
        return mAmpEnvelope.getState();
    }
    
    // Get current note
    int getCurrentNote() const { return mCurrentNote; }
    
    // Voice index (for LFO phase spreading)
    void setVoiceIndex(int index) { 
        mVoiceIndex = index;
        // Reapply parameters to update phase offset
        setParameters(mParams);
    }
    int getVoiceIndex() const { return mVoiceIndex; }
    
    // Get current LFO value (for monitoring/visualization)
    double getLFOValue() const { return mCurrentLFOValue; }
    
    // Access to LFO for advanced control
    LFO& getLFO() { return mLFO; }
    const LFO& getLFO() const { return mLFO; }
    
    // Get current mod envelope value (Phase 2.2)
    double getModEnvelopeValue() const { return mCurrentModEnvValue; }
    
    // Get mod envelope state (Phase 2.2)
    ADSREnvelope::State getModEnvelopeState() const { return mModEnvelope.getState(); }
    
    // Access to mod envelope for advanced control
    ADSREnvelope& getModEnvelope() { return mModEnvelope; }
    const ADSREnvelope& getModEnvelope() const { return mModEnvelope; }
    
private:
    double noteToFrequency(int noteNumber) const {
        // MIDI note to frequency: f = 440 * 2^((n-69)/12)
        return 440.0 * std::pow(2.0, (noteNumber - 69) / 12.0);
    }
    
    void updateGlideCoeff() {
        // Calculate coefficient for exponential glide
        // Coefficient determines how quickly we approach target frequency
        if (mParams.glideTime > 0.001) {
            double glideTimeSamples = mParams.glideTime * mSampleRate;
            // We want to reach ~99% of target in glideTime
            mGlideCoeff = 1.0 - std::exp(-5.0 / glideTimeSamples);
        } else {
            mGlideCoeff = 1.0;  // Instant (no glide)
        }
    }
    
    double mSampleRate;
    
    // Components
    PulsarOscillator mPulsarOsc;
    FormantFilter mFormantFilter;
    ADSREnvelope mAmpEnvelope;
    ADSREnvelope mModEnvelope;  // Mod envelope (Phase 2.2)
    LFO mLFO;
    
    // Parameters
    VoxVoiceParameters mParams;
    
    // State
    int mCurrentNote;
    int mTargetNote;
    double mCurrentFrequency;
    double mTargetFrequency;
    double mGlideCoeff;
    double mVelocity;
    bool mNoteOn;
    int mVoiceIndex;
    double mCurrentLFOValue = 0.0;
    double mCurrentModEnvValue = 0.0;  // Phase 2.2
};

#endif // __cplusplus
