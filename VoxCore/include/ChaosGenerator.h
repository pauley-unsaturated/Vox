//
//  ChaosGenerator.h
//  VoxCore
//
//  Phase 4.3 & 4.4: Chaos Generators - Strange attractors as modulation sources
//  Inspired by Aphex Twin's use of chaos in sound design
//
//  Lorenz Attractor: Smooth, orbiting, never repeating
//    dx/dt = σ(y - x)
//    dy/dt = x(ρ - z) - y
//    dz/dt = xy - βz
//
//  Henon Map: Snappy, rhythmic, pseudo-periodic
//    x[n+1] = 1 - ax² + y
//    y[n+1] = bx
//

#pragma once

#ifdef __cplusplus

#include <cmath>
#include <algorithm>
#include <random>

class ChaosGenerator {
public:
    enum class ChaosType {
        Lorenz,  // Smooth, continuous chaos
        Henon    // Snappy, rhythmic chaos
    };
    
    // Output channels (for Lorenz, which has 3D state)
    enum class Output {
        X,
        Y,
        Z,
        XY_Mix  // Blend of X and Y
    };
    
    ChaosGenerator(double sampleRate = 44100.0)
        : mSampleRate(sampleRate)
        , mType(ChaosType::Lorenz)
        , mOutput(Output::X)
        , mRate(1.0)           // Speed multiplier
        , mAmount(1.0)         // Output scaling
        , mBlend(1.0)          // 0 = off, 1 = full chaos
        // Lorenz state
        , mLorenzX(0.1)
        , mLorenzY(0.0)
        , mLorenzZ(0.0)
        // Lorenz parameters (standard values)
        , mSigma(10.0)
        , mRho(28.0)
        , mBeta(8.0 / 3.0)
        // Henon state
        , mHenonX(0.1)
        , mHenonY(0.1)
        // Henon parameters (standard chaotic regime)
        , mHenonA(1.4)
        , mHenonB(0.3)
        // Output
        , mCurrentValue(0.0)
        , mSmoothedValue(0.0)
    {
        // Initialize with small perturbation to avoid fixed points
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_real_distribution<double> dist(-0.01, 0.01);
        mLorenzX += dist(gen);
        mLorenzY += dist(gen);
        mLorenzZ += dist(gen);
        mHenonX += dist(gen);
        mHenonY += dist(gen);
        
        updateTimeStep();
    }
    
    void setSampleRate(double sampleRate) {
        mSampleRate = sampleRate;
        updateTimeStep();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Parameters
    // ═══════════════════════════════════════════════════════════════
    
    void setType(ChaosType type) {
        mType = type;
    }
    
    ChaosType getType() const {
        return mType;
    }
    
    void setOutput(Output output) {
        mOutput = output;
    }
    
    Output getOutput() const {
        return mOutput;
    }
    
    // Rate: Speed of chaos evolution (0.1 to 10.0)
    void setRate(double rate) {
        mRate = std::max(0.1, std::min(10.0, rate));
        updateTimeStep();
    }
    
    double getRate() const {
        return mRate;
    }
    
    // Amount: Output scaling (0.0 to 1.0)
    void setAmount(double amount) {
        mAmount = std::max(0.0, std::min(1.0, amount));
    }
    
    double getAmount() const {
        return mAmount;
    }
    
    // Blend: 0 = no chaos, 1 = full chaos
    void setBlend(double blend) {
        mBlend = std::max(0.0, std::min(1.0, blend));
    }
    
    double getBlend() const {
        return mBlend;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Lorenz Parameters (advanced)
    // ═══════════════════════════════════════════════════════════════
    
    void setLorenzSigma(double sigma) {
        mSigma = std::max(1.0, std::min(20.0, sigma));
    }
    
    void setLorenzRho(double rho) {
        mRho = std::max(1.0, std::min(50.0, rho));
    }
    
    void setLorenzBeta(double beta) {
        mBeta = std::max(0.5, std::min(5.0, beta));
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Henon Parameters (advanced)
    // ═══════════════════════════════════════════════════════════════
    
    void setHenonA(double a) {
        mHenonA = std::max(0.5, std::min(1.5, a));
    }
    
    void setHenonB(double b) {
        mHenonB = std::max(0.1, std::min(0.5, b));
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Processing
    // ═══════════════════════════════════════════════════════════════
    
    void reset() {
        // Reset to initial conditions with small perturbation
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_real_distribution<double> dist(-0.01, 0.01);
        
        mLorenzX = 0.1 + dist(gen);
        mLorenzY = 0.0 + dist(gen);
        mLorenzZ = 0.0 + dist(gen);
        mHenonX = 0.1 + dist(gen);
        mHenonY = 0.1 + dist(gen);
        mCurrentValue = 0.0;
        mSmoothedValue = 0.0;
    }
    
    // Process one sample, returns value in range [-1, 1] * amount * blend
    double process() {
        double rawValue = 0.0;
        
        switch (mType) {
            case ChaosType::Lorenz:
                rawValue = processLorenz();
                break;
            case ChaosType::Henon:
                rawValue = processHenon();
                break;
        }
        
        // Check for numerical issues
        if (!std::isfinite(rawValue)) {
            reset();
            rawValue = 0.0;
        }
        
        mCurrentValue = rawValue;
        
        // Light smoothing to reduce harsh transitions
        double smoothingCoeff = 0.01;
        mSmoothedValue += (mCurrentValue - mSmoothedValue) * smoothingCoeff;
        
        return mSmoothedValue * mAmount * mBlend;
    }
    
    // Get current value without advancing
    double getCurrentValue() const {
        return mSmoothedValue * mAmount * mBlend;
    }
    
    // Get raw (unscaled) value
    double getRawValue() const {
        return mCurrentValue;
    }
    
    // Get Lorenz state (for visualization)
    void getLorenzState(double& x, double& y, double& z) const {
        x = mLorenzX;
        y = mLorenzY;
        z = mLorenzZ;
    }
    
    // Get Henon state (for visualization)
    void getHenonState(double& x, double& y) const {
        x = mHenonX;
        y = mHenonY;
    }
    
    // Check if state is valid (no NaN/Inf)
    bool isStateValid() const {
        return std::isfinite(mLorenzX) && std::isfinite(mLorenzY) && 
               std::isfinite(mLorenzZ) && std::isfinite(mHenonX) && 
               std::isfinite(mHenonY);
    }
    
private:
    double processLorenz() {
        // Runge-Kutta 4th order integration for stability
        double x = mLorenzX, y = mLorenzY, z = mLorenzZ;
        double dt = mTimeStep;
        
        // k1
        double k1x = mSigma * (y - x);
        double k1y = x * (mRho - z) - y;
        double k1z = x * y - mBeta * z;
        
        // k2
        double x2 = x + 0.5 * dt * k1x;
        double y2 = y + 0.5 * dt * k1y;
        double z2 = z + 0.5 * dt * k1z;
        double k2x = mSigma * (y2 - x2);
        double k2y = x2 * (mRho - z2) - y2;
        double k2z = x2 * y2 - mBeta * z2;
        
        // k3
        double x3 = x + 0.5 * dt * k2x;
        double y3 = y + 0.5 * dt * k2y;
        double z3 = z + 0.5 * dt * k2z;
        double k3x = mSigma * (y3 - x3);
        double k3y = x3 * (mRho - z3) - y3;
        double k3z = x3 * y3 - mBeta * z3;
        
        // k4
        double x4 = x + dt * k3x;
        double y4 = y + dt * k3y;
        double z4 = z + dt * k3z;
        double k4x = mSigma * (y4 - x4);
        double k4y = x4 * (mRho - z4) - y4;
        double k4z = x4 * y4 - mBeta * z4;
        
        // Update state
        mLorenzX = x + (dt / 6.0) * (k1x + 2*k2x + 2*k3x + k4x);
        mLorenzY = y + (dt / 6.0) * (k1y + 2*k2y + 2*k3y + k4y);
        mLorenzZ = z + (dt / 6.0) * (k1z + 2*k2z + 2*k3z + k4z);
        
        // Normalize output to [-1, 1]
        // Lorenz attractor typical ranges: x,y in [-20, 20], z in [0, 50]
        double output;
        switch (mOutput) {
            case Output::X:
                output = mLorenzX / 20.0;
                break;
            case Output::Y:
                output = mLorenzY / 20.0;
                break;
            case Output::Z:
                output = (mLorenzZ - 25.0) / 25.0;  // Center around 25
                break;
            case Output::XY_Mix:
            default:
                output = (mLorenzX + mLorenzY) / 40.0;
                break;
        }
        
        return std::max(-1.0, std::min(1.0, output));
    }
    
    double processHenon() {
        // Henon map is discrete, but we need smooth audio output
        // Process at a lower rate and interpolate
        
        mHenonPhaseAccum += mHenonPhaseInc;
        
        if (mHenonPhaseAccum >= 1.0) {
            mHenonPhaseAccum -= 1.0;
            
            // Store previous for interpolation
            mHenonPrevX = mHenonX;
            mHenonPrevY = mHenonY;
            
            // Henon map iteration
            double newX = 1.0 - mHenonA * mHenonX * mHenonX + mHenonY;
            double newY = mHenonB * mHenonX;
            
            mHenonX = newX;
            mHenonY = newY;
            
            // Check for escape (divergence)
            if (std::abs(mHenonX) > 10.0 || std::abs(mHenonY) > 10.0) {
                // Reset to strange attractor basin
                mHenonX = 0.1;
                mHenonY = 0.1;
            }
        }
        
        // Linear interpolation between iterations
        double t = mHenonPhaseAccum;
        double interpX = mHenonPrevX + t * (mHenonX - mHenonPrevX);
        double interpY = mHenonPrevY + t * (mHenonY - mHenonPrevY);
        
        // Normalize output to [-1, 1]
        // Henon attractor range is roughly [-1.5, 1.5]
        double output;
        switch (mOutput) {
            case Output::X:
                output = interpX / 1.5;
                break;
            case Output::Y:
                output = interpY / 0.5;  // Y has smaller range
                break;
            case Output::Z:
            case Output::XY_Mix:
            default:
                output = (interpX + interpY * 2.0) / 2.5;
                break;
        }
        
        return std::max(-1.0, std::min(1.0, output));
    }
    
    void updateTimeStep() {
        // Base time step for Lorenz (normalized time)
        // At rate=1.0, we want a reasonable evolution speed
        mTimeStep = (mRate * 0.01) / mSampleRate * 1000.0;
        
        // Henon iteration rate (how often we compute new map iteration)
        // At rate=1.0, about 20-50 iterations per second for rhythmic feel
        mHenonPhaseInc = (mRate * 30.0) / mSampleRate;
    }
    
    double mSampleRate;
    ChaosType mType;
    Output mOutput;
    double mRate;
    double mAmount;
    double mBlend;
    
    // Lorenz state and parameters
    double mLorenzX, mLorenzY, mLorenzZ;
    double mSigma, mRho, mBeta;
    double mTimeStep = 0.0;
    
    // Henon state and parameters
    double mHenonX, mHenonY;
    double mHenonPrevX = 0.1, mHenonPrevY = 0.1;
    double mHenonA, mHenonB;
    double mHenonPhaseAccum = 0.0;
    double mHenonPhaseInc = 0.0;
    
    // Output
    double mCurrentValue;
    double mSmoothedValue;
};

#endif // __cplusplus
