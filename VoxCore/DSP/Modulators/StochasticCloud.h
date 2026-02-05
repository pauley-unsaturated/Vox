//
//  StochasticCloud.h
//  VoxCore
//
//  Per-grain stochastic parameter scattering (Xenakis-inspired cloud synthesis)
//  Each grain gets randomized values from probability distributions
//

#pragma once

#ifdef __cplusplus

// Include the distribution utilities from the same directory
#include "StochasticDistribution.h"
#include <cmath>

// Parameters for stochastic cloud synthesis
struct CloudParameters {
    // Master control - scales all scatter amounts
    double cloudScatter = 0.0;          // 0-1, multiplier for all scatter
    
    // Pitch scatter
    double pitchScatter = 0.0;          // 0-100 cents
    DistributionType pitchDistribution = DistributionType::GAUSSIAN;
    
    // Timing jitter
    double timingJitter = 0.0;          // 0-50 ms
    DistributionType timingDistribution = DistributionType::POISSON;
    
    // Formant scatter
    double formantScatter = 0.0;        // 0-200 Hz
    DistributionType formantDistribution = DistributionType::GAUSSIAN;
    
    // Pan scatter
    double panScatter = 0.0;            // 0-1 (full stereo width)
    DistributionType panDistribution = DistributionType::UNIFORM;
    
    // Amplitude scatter  
    double ampScatter = 0.0;            // 0-12 dB
    DistributionType ampDistribution = DistributionType::GAUSSIAN;
    
    // Grain density (independent of pitch)
    double grainDensity = 0.0;          // 0-1: 0 = use oscillator freq, 1 = use densityHz
    double densityHz = 100.0;           // Target grains per second when density > 0
};

// Output from cloud generator - offsets to apply to current grain
struct GrainScatter {
    double pitchCents = 0.0;            // Pitch offset in cents
    double timingMs = 0.0;              // Timing offset in ms
    double formant1Hz = 0.0;            // F1 offset in Hz
    double formant2Hz = 0.0;            // F2 offset in Hz
    double panOffset = 0.0;             // Pan offset (-1 to +1)
    double ampDB = 0.0;                 // Amplitude offset in dB
};

class StochasticCloud {
public:
    StochasticCloud() = default;
    
    void setParameters(const CloudParameters& params) {
        mParams = params;
    }
    
    const CloudParameters& getParameters() const {
        return mParams;
    }
    
    // Set individual parameters
    void setCloudScatter(double amount) {
        mParams.cloudScatter = std::clamp(amount, 0.0, 1.0);
    }
    
    void setPitchScatter(double cents, DistributionType dist = DistributionType::GAUSSIAN) {
        mParams.pitchScatter = std::clamp(cents, 0.0, 100.0);
        mParams.pitchDistribution = dist;
    }
    
    void setTimingJitter(double ms, DistributionType dist = DistributionType::POISSON) {
        mParams.timingJitter = std::clamp(ms, 0.0, 50.0);
        mParams.timingDistribution = dist;
    }
    
    void setFormantScatter(double hz, DistributionType dist = DistributionType::GAUSSIAN) {
        mParams.formantScatter = std::clamp(hz, 0.0, 200.0);
        mParams.formantDistribution = dist;
    }
    
    void setPanScatter(double amount, DistributionType dist = DistributionType::UNIFORM) {
        mParams.panScatter = std::clamp(amount, 0.0, 1.0);
        mParams.panDistribution = dist;
    }
    
    void setAmpScatter(double dB, DistributionType dist = DistributionType::GAUSSIAN) {
        mParams.ampScatter = std::clamp(dB, 0.0, 12.0);
        mParams.ampDistribution = dist;
    }
    
    void setGrainDensity(double mix, double hz) {
        mParams.grainDensity = std::clamp(mix, 0.0, 1.0);
        mParams.densityHz = std::clamp(hz, 20.0, 2000.0);
    }
    
    // Generate scatter values for current grain
    // Call this once per grain (at grain onset)
    GrainScatter generateGrainScatter() {
        GrainScatter scatter;
        
        double masterScale = mParams.cloudScatter;
        if (masterScale <= 0.0) {
            return scatter;  // All zeros
        }
        
        // Pitch scatter (in cents)
        if (mParams.pitchScatter > 0.0) {
            double amount = mParams.pitchScatter * masterScale;
            scatter.pitchCents = mDistribution.generateWithAmount(
                mParams.pitchDistribution, amount, 0.33);
        }
        
        // Timing jitter (in ms) - always positive for Poisson
        if (mParams.timingJitter > 0.0) {
            double amount = mParams.timingJitter * masterScale;
            if (mParams.timingDistribution == DistributionType::POISSON) {
                // Poisson gives positive values, scale by amount
                scatter.timingMs = mDistribution.generatePoissonCount(amount * 0.5) * 2.0;
                scatter.timingMs = std::min(scatter.timingMs, amount);  // Cap at max
            } else {
                scatter.timingMs = std::abs(mDistribution.generateWithAmount(
                    mParams.timingDistribution, amount, 0.5));
            }
        }
        
        // Formant scatter (both F1 and F2 scatter together but independently)
        if (mParams.formantScatter > 0.0) {
            double amount = mParams.formantScatter * masterScale;
            scatter.formant1Hz = mDistribution.generateWithAmount(
                mParams.formantDistribution, amount, 0.33);
            scatter.formant2Hz = mDistribution.generateWithAmount(
                mParams.formantDistribution, amount, 0.33);
        }
        
        // Pan scatter
        if (mParams.panScatter > 0.0) {
            double amount = mParams.panScatter * masterScale;
            scatter.panOffset = mDistribution.generateWithAmount(
                mParams.panDistribution, amount, 1.0);
        }
        
        // Amplitude scatter (in dB)
        if (mParams.ampScatter > 0.0) {
            double amount = mParams.ampScatter * masterScale;
            scatter.ampDB = mDistribution.generateWithAmount(
                mParams.ampDistribution, amount, 0.33);
        }
        
        return scatter;
    }
    
    // Convert amplitude scatter from dB to linear multiplier
    static double dbToLinear(double dB) {
        return std::pow(10.0, dB / 20.0);
    }
    
    // Convert pitch scatter from cents to frequency ratio
    static double centsToRatio(double cents) {
        return std::pow(2.0, cents / 1200.0);
    }
    
    // Get effective grain period based on density settings
    // Returns period in samples
    double getEffectiveGrainPeriod(double oscillatorFreq, double sampleRate) const {
        if (mParams.grainDensity <= 0.0 || mParams.densityHz <= 0.0) {
            // Use oscillator frequency (normal pulsar behavior)
            return sampleRate / oscillatorFreq;
        }
        
        // Blend between oscillator freq and density Hz
        double oscPeriod = sampleRate / oscillatorFreq;
        double densityPeriod = sampleRate / mParams.densityHz;
        
        return oscPeriod + (densityPeriod - oscPeriod) * mParams.grainDensity;
    }
    
    // Seed random generator (for reproducible results)
    void seed(unsigned int s) {
        mDistribution.seed(s);
    }
    
private:
    CloudParameters mParams;
    StochasticDistribution mDistribution;
};

#endif // __cplusplus
