//
//  PolyBLEPOscillator.h
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

class PolyBLEPOscillator : public Oscillator {
public:
    PolyBLEPOscillator(double sampleRate = 44100.0) 
        : Oscillator(sampleRate)
        , mWaveform(WaveformType::SAW)
        , mPulseWidth(0.5)
    {
        setFrequency(440.0);
    }
    
    void setWaveform(WaveformType waveform) { mWaveform = waveform; }
    WaveformType getWaveform() const { return mWaveform; }
    void setPulseWidth(double pw) { mPulseWidth = std::max(0.01, std::min(0.99, pw)); }
    double getPulseWidth() const { return mPulseWidth; }
    
    void reset() override { Oscillator::reset(); }
    
    double process() override {
        // Simple sine output for stub
        double output = std::sin(mPhase * std::numbers::pi * 2.0);
        updatePhase();
        return output;
    }
    
private:
    WaveformType mWaveform;
    double mPulseWidth;
};

#endif // __cplusplus
