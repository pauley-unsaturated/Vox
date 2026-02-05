//
//  MoogLadderFilter.h
//  VoxCore
//
//  LEGACY STUB - Vox uses FormantFilter for pulsar synthesis
//  This stub exists only for build compatibility
//

#pragma once

#ifdef __cplusplus

// Filter mode enum - kept for compatibility
enum class FilterMode {
    LOWPASS,
    HIGHPASS,
    BANDPASS,
    NOTCH,
    LP24,
    LP18,
    LP12,
    LP6,
    HP24,
    HP12,
    BP12,
    BP6
};

// Minimal stub class
class MoogLadderFilter {
public:
    MoogLadderFilter(double sampleRate = 44100.0) : mSampleRate(sampleRate), mCutoff(1000.0), mResonance(0.0), mMode(FilterMode::LP24), mPoles(4) {}
    
    void setSampleRate(double sr) { mSampleRate = sr; }
    void setCutoff(double c) { mCutoff = std::max(20.0, std::min(c, mSampleRate * 0.45)); }
    float getCutoff() const { return static_cast<float>(mCutoff); }
    void setResonance(double r) { mResonance = std::max(0.0, std::min(1.0, r)); }
    double getResonance() const { return mResonance; }
    void setMode(FilterMode m) { mMode = m; }
    FilterMode getMode() const { return mMode; }
    void setPoles(int p) { mPoles = (p >= 1 && p <= 4) ? p : 4; }
    int getPoles() const { return mPoles; }
    void reset() {}
    double process(double input) { return input; } // Pass-through stub
    float process(float input) { return input; }
    void processBlock(float* samples, int numSamples) {}
    
private:
    double mSampleRate;
    double mCutoff;
    double mResonance;
    FilterMode mMode;
    int mPoles;
};

#endif // __cplusplus
