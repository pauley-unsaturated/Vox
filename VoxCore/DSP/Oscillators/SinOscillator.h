//
//  SinOscillator.h
//  VoxCore
//

#pragma once

#ifdef __cplusplus

#include "Oscillator.h"
#include <numbers>
#include <cmath>

class SinOscillator : public Oscillator {
public:
    SinOscillator(double sampleRate = 44100.0) : Oscillator(sampleRate) {
        setFrequency(440.0);
    }
    
    double process() override {
        const double sample = std::sin(mPhase * (std::numbers::pi_v<double> * 2.0));
        updatePhase();
        return sample;
    }
};

#endif // cplusplus
