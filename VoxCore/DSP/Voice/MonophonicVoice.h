//
//  MonophonicVoice.h
//  VoxCore
//
//  LEGACY STUB - Vox uses VoxVoice for pulsar synthesis
//  This stub exists only for build compatibility
//

#pragma once

#ifdef __cplusplus

#include "PolyBLEPOscillator.h"
#include "DPWOscillator.h"
#include "MoogLadderFilter.h"
#include "ADSREnvelope.h"
#include "LFO.h"
#include <cmath>

class MonophonicVoice {
public:
    enum class OscillatorType {
        POLYBLEP,
        DPW
    };
    
    struct VoiceParameters {
        double masterVolume = 1.0;
        double osc1Level = 1.0;
        double osc2Level = 0.0;
        double subOscLevel = 0.0;
        double noiseLevel = 0.0;
        Oscillator::WaveformType osc1Waveform = Oscillator::WaveformType::SAW;
        Oscillator::WaveformType osc2Waveform = Oscillator::WaveformType::SAW;
        double osc2Detune = 0.0;
        int osc1Octave = 0;
        int osc2Octave = 0;
        int subOscOctave = -1;
        double pulseWidth = 0.5;
        double lpFilterCutoff = 0.86;
        double lpFilterResonance = 0.0;
        double lpFilterKeyTracking = 0.0;
        double lpFilterEnvelopeAmount = 0.0;
        double lpFilterVelocityAmount = 0.0;
        double ampAttack = 0.01;
        double ampDecay = 0.1;
        double ampSustain = 0.7;
        double ampRelease = 0.3;
        double filterAttack = 0.01;
        double filterDecay = 0.2;
        double filterSustain = 0.5;
        double filterRelease = 0.3;
        double lfoRate = 1.0;
        LFO::Waveform lfoWaveform = LFO::Waveform::TRIANGLE;
        double lfoPitchAmount = 0.0;
        double lfoFilterAmount = 0.0;
        double lfoPWMAmount = 0.0;
        LFO::SyncMode lfoSyncMode = LFO::SyncMode::FREE;
        LFO::BeatDivision lfoTempoRate = LFO::BeatDivision::QUARTER;
        LFO::RetriggerMode lfoRetrigger = LFO::RetriggerMode::FREE;
        double lfoPhase = 0.0;
        double lfoDelay = 0.0;
        double pitchBendRange = 2.0;
        bool legatoMode = true;
        int glideMode = 0;
        double glideTime = 100.0;
    };
    
    MonophonicVoice(double sampleRate = 44100.0, OscillatorType type = OscillatorType::POLYBLEP)
        : mSampleRate(sampleRate), mCurrentNote(-1), mNoteOn(false) {}
    
    void setSampleRate(double sr) { mSampleRate = sr; }
    void setParameters(const VoiceParameters& params) { mParams = params; }
    VoiceParameters getParameters() const { return mParams; }
    
    void noteOn(int32_t note, double velocity) { mCurrentNote = note; mNoteOn = true; }
    void noteOff(int32_t note = -1) { mNoteOn = false; }
    void setPitchBend(double semitones) {}
    void setTempo(double bpm) {}
    
    bool isActive() const { return mNoteOn; }
    int32_t getCurrentNote() const { return mCurrentNote; }
    
    void reset() { mCurrentNote = -1; mNoteOn = false; }
    
    double process() { return 0.0; } // Stub returns silence
    
private:
    double mSampleRate;
    VoiceParameters mParams;
    int32_t mCurrentNote;
    bool mNoteOn;
};

#endif // __cplusplus
