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
    
    // Modulation Routing - LFO Destinations (Phase 2.3)
    double lfoToPitch = 0.0;         // semitones (bipolar: ±amount)
    double lfoToFormant1 = 0.0;      // Hz (bipolar: ±amount)
    double lfoToFormant2 = 0.0;      // Hz (bipolar: ±amount)
    double lfoToDutyCycle = 0.0;     // normalized 0-1 (bipolar: ±amount)
    
    // Modulation Routing - Mod Envelope Destinations (Phase 2.3)
    double modEnvToPitch = 0.0;      // semitones (unipolar: 0 to +amount)
    double modEnvToFormant1 = 0.0;   // Hz (unipolar: 0 to +amount)
    double modEnvToFormant2 = 0.0;   // Hz (unipolar: 0 to +amount)
    double modEnvToDutyCycle = 0.0;  // normalized (unipolar: 0 to +amount)
    
    // Velocity Sensitivity (Phase 2.4)
    double velocitySensitivity = 1.0;  // 0.0 = no effect, 1.0 = full velocity scaling
    double velocityToModEnv = 0.0;     // 0.0 = no effect, 1.0 = velocity fully scales mod env
    
    // Polyphonic Aftertouch Routing (Phase 2.5)
    double aftertouchToPitch = 0.0;      // semitones at full pressure
    double aftertouchToFormant1 = 0.0;   // Hz at full pressure
    double aftertouchToFormant2 = 0.0;   // Hz at full pressure
    double aftertouchToLFOAmount = 0.0;  // Additional LFO depth at full pressure
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
        double clampedVelocity = std::max(0.0, std::min(1.0, velocity));
        
        // Apply velocity sensitivity (Phase 2.4)
        // At 0% sensitivity: effective velocity = 1.0 (no effect)
        // At 100% sensitivity: effective velocity = velocity (full effect)
        mVelocity = (1.0 - mParams.velocitySensitivity) + (clampedVelocity * mParams.velocitySensitivity);
        
        // Store raw velocity for mod envelope scaling
        mRawVelocity = clampedVelocity;
        
        mTargetNote = noteNumber;
        mTargetFrequency = noteToFrequency(noteNumber);
        
        // Apply pitch bend
        if (std::abs(mParams.pitchBendSemitones) > 0.001) {
            mTargetFrequency *= std::pow(2.0, mParams.pitchBendSemitones / 12.0);
        }
        
        // Apply detune (Hz)
        mTargetFrequency += mParams.detuneHz;
        
        // Phase 3.1: Apply detune offset (cents)
        if (std::abs(mDetuneOffset) > 0.001) {
            mTargetFrequency *= std::pow(2.0, mDetuneOffset / 1200.0);
        }
        
        // Handle glide
        if (!mParams.glideEnabled || mCurrentNote < 0) {
            // No glide or first note - jump to frequency
            mCurrentFrequency = mTargetFrequency;
            mCurrentNote = noteNumber;
        }
        // else: glide will happen in process()
        
        mPulsarOsc.setFrequency(mCurrentFrequency);
        
        // Phase 3.2: Handle time offset (delay before envelope triggers)
        mTimeOffsetSamples = mTimeOffsetMs * mSampleRate / 1000.0;
        mTimeOffsetCounter = static_cast<int>(std::abs(mTimeOffsetSamples));
        
        if (mTimeOffsetCounter <= 0) {
            // No time offset - trigger immediately
            mAmpEnvelope.noteOn();
            mModEnvelope.noteOn();
            
            if (mParams.lfoRetrigger) {
                mLFO.retrigger();
            }
        }
        // else: envelope will be triggered in process() after offset countdown
        
        // Reset aftertouch on new note (Phase 2.5)
        mAftertouch = 0.0;
        
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
        mTimeOffsetCounter = 0;  // Phase 3.2
    }
    
    // Process one sample
    double process() {
        // Phase 3.2: Handle time offset countdown
        if (mTimeOffsetCounter > 0) {
            mTimeOffsetCounter--;
            if (mTimeOffsetCounter == 0) {
                // Time offset complete - trigger envelopes now
                mAmpEnvelope.noteOn();
                mModEnvelope.noteOn();
                
                if (mParams.lfoRetrigger) {
                    mLFO.retrigger();
                }
            }
        }
        
        // Handle glide
        if (mParams.glideEnabled && std::abs(mCurrentFrequency - mTargetFrequency) > 0.1) {
            mCurrentFrequency += (mTargetFrequency - mCurrentFrequency) * mGlideCoeff;
        } else if (std::abs(mCurrentFrequency - mTargetFrequency) > 0.1) {
            // Not gliding but frequency mismatch (pitch bend change)
            mCurrentFrequency = mTargetFrequency;
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
        
        // ═══════════════════════════════════════════════════════════════
        // Phase 2.3 & 2.4: Apply Modulation Routing
        // ═══════════════════════════════════════════════════════════════
        
        // Calculate effective mod envelope value with velocity scaling (Phase 2.4)
        // At velocityToModEnv = 0: full mod env
        // At velocityToModEnv = 1: mod env scaled by raw velocity
        double velocityModScale = (1.0 - mParams.velocityToModEnv) + (mRawVelocity * mParams.velocityToModEnv);
        double effectiveModEnv = mCurrentModEnvValue * velocityModScale;
        
        // Calculate effective LFO amount with aftertouch scaling (Phase 2.5)
        double effectiveLFOAmount = 1.0 + (mAftertouch * mParams.aftertouchToLFOAmount);
        
        // Calculate pitch modulation (in semitones)
        // LFO is bipolar (-1 to +1), mod env is unipolar (0 to 1), aftertouch is unipolar (0 to 1)
        double pitchModSemitones = (mCurrentLFOValue * mParams.lfoToPitch * effectiveLFOAmount) + 
                                   (effectiveModEnv * mParams.modEnvToPitch) +
                                   (mAftertouch * mParams.aftertouchToPitch);  // Phase 2.5
        
        // Apply pitch modulation to frequency
        double modulatedFrequency = mCurrentFrequency;
        if (std::abs(pitchModSemitones) > 0.001) {
            modulatedFrequency *= std::pow(2.0, pitchModSemitones / 12.0);
        }
        mPulsarOsc.setFrequency(modulatedFrequency);
        
        // Calculate duty cycle modulation
        double dutyMod = (mCurrentLFOValue * mParams.lfoToDutyCycle * effectiveLFOAmount) +
                         (effectiveModEnv * mParams.modEnvToDutyCycle);
        double modulatedDuty = std::max(0.01, std::min(1.0, mParams.dutyCycle + dutyMod));
        mPulsarOsc.setDutyCycle(modulatedDuty);
        
        // Calculate formant modulation (including aftertouch - Phase 2.5)
        // Phase 3.3: Include formant offset from constellation
        double formant1Mod = (mCurrentLFOValue * mParams.lfoToFormant1 * effectiveLFOAmount) +
                             (effectiveModEnv * mParams.modEnvToFormant1) +
                             (mAftertouch * mParams.aftertouchToFormant1) +
                             mFormantOffsetHz;  // Constellation offset
        double formant2Mod = (mCurrentLFOValue * mParams.lfoToFormant2 * effectiveLFOAmount) +
                             (effectiveModEnv * mParams.modEnvToFormant2) +
                             (mAftertouch * mParams.aftertouchToFormant2) +
                             (mFormantOffsetHz * 0.8);  // Slightly less offset for F2
        
        // Apply formant modulation (only if using manual formants, not vowel morph)
        if (!mParams.useVowelMorph) {
            double modulatedF1 = std::max(80.0, std::min(4000.0, mParams.formant1Freq + formant1Mod));
            double modulatedF2 = std::max(200.0, std::min(6000.0, mParams.formant2Freq + formant2Mod));
            mFormantFilter.setFormant1Frequency(modulatedF1);
            mFormantFilter.setFormant2Frequency(modulatedF2);
        }
        
        // ═══════════════════════════════════════════════════════════════
        
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
    
    // Polyphonic aftertouch (Phase 2.5)
    void setAftertouch(double pressure) {
        mAftertouch = std::max(0.0, std::min(1.0, pressure));
    }
    double getAftertouch() const { return mAftertouch; }
    
    // ═══════════════════════════════════════════════════════════════
    // Phase 3: Voice Constellation Parameters
    // ═══════════════════════════════════════════════════════════════
    
    // Phase 3.1: Detune offset in cents
    void setDetuneOffset(double cents) { mDetuneOffset = cents; }
    double getDetuneOffset() const { return mDetuneOffset; }
    
    // Phase 3.2: Time offset in milliseconds (delay before note triggers)
    void setTimeOffset(double ms) { mTimeOffsetMs = ms; }
    double getTimeOffset() const { return mTimeOffsetMs; }
    
    // Phase 3.3: Formant offset in Hz
    void setFormantOffset(double hz) { mFormantOffsetHz = hz; }
    double getFormantOffset() const { return mFormantOffsetHz; }
    
    // Phase 3.4: Pan position (-1 = left, 0 = center, +1 = right)
    void setPan(double pan) { mPan = std::max(-1.0, std::min(1.0, pan)); }
    double getPan() const { return mPan; }
    
    // Phase 3.5: LFO phase offset (0.0 to 1.0, represents 0-360°)
    void setLFOPhaseOffset(double offset) {
        mLFOPhaseOffset = std::fmod(std::max(0.0, offset), 1.0);
        mLFO.setPhaseOffset(mLFOPhaseOffset);
    }
    double getLFOPhaseOffset() const { return mLFOPhaseOffset; }
    
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
    double mRawVelocity = 1.0;  // Phase 2.4: Raw velocity for mod env scaling
    bool mNoteOn;
    int mVoiceIndex;
    double mCurrentLFOValue = 0.0;
    double mCurrentModEnvValue = 0.0;  // Phase 2.2
    double mAftertouch = 0.0;          // Phase 2.5
    
    // Phase 3: Constellation offsets
    double mDetuneOffset = 0.0;      // cents
    double mTimeOffsetMs = 0.0;      // milliseconds
    double mTimeOffsetSamples = 0.0; // cached sample count
    int mTimeOffsetCounter = 0;      // countdown for time offset
    double mFormantOffsetHz = 0.0;   // Hz
    double mPan = 0.0;               // -1 to +1
    double mLFOPhaseOffset = 0.0;    // 0 to 1
};

#endif // __cplusplus
