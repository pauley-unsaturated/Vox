//
//  FormantFilter.h
//  VoxCore
//
//  Dual formant (resonant bandpass) filter for vocal synthesis
//  Uses two parallel SVF (state variable filter) bandpass filters
//

#pragma once

#ifdef __cplusplus

#include <cmath>
#include <algorithm>
#include <numbers>

class FormantFilter {
public:
    FormantFilter(double sampleRate = 44100.0)
        : mSampleRate(sampleRate)
    {
        reset();
        // Initialize with default vowel 'A' formants
        setFormant1Frequency(800.0);
        setFormant2Frequency(1200.0);
        setFormant1Q(10.0);
        setFormant2Q(10.0);
        setFormant1Gain(1.0);
        setFormant2Gain(0.7);
        setDryGain(0.0);
    }
    
    void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        updateCoefficients();
    }
    
    // Set formant 1 center frequency (Hz)
    void setFormant1Frequency(double freq) {
        mF1Freq = std::max(80.0, std::min(freq, mSampleRate * 0.45));
        updateCoefficients();
    }
    
    // Set formant 2 center frequency (Hz)
    void setFormant2Frequency(double freq) {
        mF2Freq = std::max(80.0, std::min(freq, mSampleRate * 0.45));
        updateCoefficients();
    }
    
    // Set formant 1 Q (resonance/bandwidth)
    void setFormant1Q(double q) {
        mF1Q = std::max(0.5, std::min(q, 50.0));
        updateCoefficients();
    }
    
    // Set formant 2 Q (resonance/bandwidth)
    void setFormant2Q(double q) {
        mF2Q = std::max(0.5, std::min(q, 50.0));
        updateCoefficients();
    }
    
    // Set formant 1 output gain
    void setFormant1Gain(double gain) {
        mF1Gain = std::max(0.0, std::min(gain, 2.0));
    }
    
    // Set formant 2 output gain
    void setFormant2Gain(double gain) {
        mF2Gain = std::max(0.0, std::min(gain, 2.0));
    }
    
    // Set dry (unfiltered) signal gain
    void setDryGain(double gain) {
        mDryGain = std::max(0.0, std::min(gain, 2.0));
    }
    
    // Vowel morphing (0.0 = A, 0.25 = E, 0.5 = I, 0.75 = O, 1.0 = U)
    void setVowelMorph(double morph) {
        morph = std::max(0.0, std::min(1.0, morph));
        
        // Vowel formant frequencies (approximate)
        // A: F1=800, F2=1200
        // E: F1=400, F2=2200
        // I: F1=300, F2=2700
        // O: F1=500, F2=800
        // U: F1=350, F2=700
        
        static const double vowelF1[] = {800, 400, 300, 500, 350};
        static const double vowelF2[] = {1200, 2200, 2700, 800, 700};
        
        // Interpolate between vowels
        double pos = morph * 4.0; // 0-4 for 5 vowels
        int idx1 = static_cast<int>(pos);
        int idx2 = (idx1 + 1) % 5;
        double frac = pos - idx1;
        
        if (idx1 >= 4) {
            idx1 = 4;
            idx2 = 4;
            frac = 0.0;
        }
        
        double f1 = vowelF1[idx1] * (1.0 - frac) + vowelF1[idx2] * frac;
        double f2 = vowelF2[idx1] * (1.0 - frac) + vowelF2[idx2] * frac;
        
        setFormant1Frequency(f1);
        setFormant2Frequency(f2);
    }
    
    void reset() {
        // Reset SVF state for both formants
        mF1_ic1eq = 0.0;
        mF1_ic2eq = 0.0;
        mF2_ic1eq = 0.0;
        mF2_ic2eq = 0.0;
    }
    
    // Process a single sample
    double process(double input) {
        // Formant 1 - SVF bandpass
        double v1_1 = mF1_a1 * mF1_ic1eq + mF1_a2 * (input - mF1_ic2eq);
        double v2_1 = mF1_ic2eq + mF1_a2 * mF1_ic1eq + mF1_a3 * (input - mF1_ic2eq);
        mF1_ic1eq = 2.0 * v1_1 - mF1_ic1eq;
        mF1_ic2eq = 2.0 * v2_1 - mF1_ic2eq;
        double bp1 = v1_1;
        
        // Formant 2 - SVF bandpass
        double v1_2 = mF2_a1 * mF2_ic1eq + mF2_a2 * (input - mF2_ic2eq);
        double v2_2 = mF2_ic2eq + mF2_a2 * mF2_ic1eq + mF2_a3 * (input - mF2_ic2eq);
        mF2_ic1eq = 2.0 * v1_2 - mF2_ic1eq;
        mF2_ic2eq = 2.0 * v2_2 - mF2_ic2eq;
        double bp2 = v1_2;
        
        // Mix formants and dry signal
        return bp1 * mF1Gain + bp2 * mF2Gain + input * mDryGain;
    }
    
    void processBlock(double* samples, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            samples[i] = process(samples[i]);
        }
    }
    
private:
    void updateCoefficients() {
        // SVF coefficients for formant 1
        double g1 = std::tan(std::numbers::pi * mF1Freq / mSampleRate);
        double k1 = 1.0 / mF1Q;
        mF1_a1 = 1.0 / (1.0 + g1 * (g1 + k1));
        mF1_a2 = g1 * mF1_a1;
        mF1_a3 = g1 * mF1_a2;
        
        // SVF coefficients for formant 2
        double g2 = std::tan(std::numbers::pi * mF2Freq / mSampleRate);
        double k2 = 1.0 / mF2Q;
        mF2_a1 = 1.0 / (1.0 + g2 * (g2 + k2));
        mF2_a2 = g2 * mF2_a1;
        mF2_a3 = g2 * mF2_a2;
    }
    
    double mSampleRate;
    
    // Formant parameters
    double mF1Freq = 800.0;
    double mF2Freq = 1200.0;
    double mF1Q = 10.0;
    double mF2Q = 10.0;
    double mF1Gain = 1.0;
    double mF2Gain = 0.7;
    double mDryGain = 0.0;
    
    // SVF coefficients for formant 1
    double mF1_a1 = 0.0, mF1_a2 = 0.0, mF1_a3 = 0.0;
    double mF1_ic1eq = 0.0, mF1_ic2eq = 0.0;
    
    // SVF coefficients for formant 2
    double mF2_a1 = 0.0, mF2_a2 = 0.0, mF2_a3 = 0.0;
    double mF2_ic1eq = 0.0, mF2_ic2eq = 0.0;
};

#endif // __cplusplus
