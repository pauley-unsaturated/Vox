//
//  DPWOscillator.h
//  VoxCore
//
//  LEGACY STUB - Vox uses PulsarOscillator for pulsar synthesis
//  This stub exists only for build compatibility
//

#pragma once

#ifdef __cplusplus

#include "Oscillator.h"
#include <cmath>
#include <numbers>

class DPWOscillator : public Oscillator {
public:
    DPWOscillator(double sampleRate = 44100.0) 
        : Oscillator(sampleRate)
        , mWaveform(WaveformType::SAW)
    {
        setFrequency(440.0);
    }
    
    void setWaveform(WaveformType waveform) { mWaveform = waveform; }
    WaveformType getWaveform() const { return mWaveform; }
    
    void reset() override { Oscillator::reset(); }
    
    double process() override {
        // Simple sine output for stub
        double output = std::sin(mPhase * std::numbers::pi * 2.0);
        updatePhase();
        return output;
    }
    
private:
    WaveformType mWaveform;
};

#endif // __cplusplus
