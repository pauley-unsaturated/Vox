#include <iostream>
#include <cmath>
#include <algorithm>

// Test version of DPW to debug the algorithm
int main() {
    double sampleRate = 44100.0;
    double frequency = 440.0;
    double normalizedFreq = frequency / sampleRate;
    double scaler = 1.0 / ((4.0 * normalizedFreq) * (1.0 - normalizedFreq));
    
    std::cout << "Sample rate: " << sampleRate << "\n";
    std::cout << "Frequency: " << frequency << "\n";
    std::cout << "Normalized freq: " << normalizedFreq << "\n";
    std::cout << "Scaler: " << scaler << "\n\n";
    
    double phase = 0.0;
    double phaseIncrement = frequency / sampleRate;
    double prevValue1 = 0.0;
    double prevValue2 = 0.0;
    
    double minVal = 1000.0;
    double maxVal = -1000.0;
    
    // Generate one cycle
    int samplesPerCycle = static_cast<int>(sampleRate / frequency);
    
    std::cout << "First 20 samples:\n";
    for (int i = 0; i < samplesPerCycle; ++i) {
        // Generate parabolic wave (x^2)
        double x = (phase * 2.0) - 1.0;
        double sq = x * x;
        
        // Calculate difference (differentiate)
        double diff = 0.5 * (sq - prevValue2);
        
        // Shift the delay line
        prevValue2 = prevValue1;
        prevValue1 = sq;
        
        // Scale the output value
        double output = diff * scaler;
        
        minVal = std::min(minVal, output);
        maxVal = std::max(maxVal, output);
        
        if (i < 20) {
            std::cout << "i=" << i << " phase=" << phase << " x=" << x << " sq=" << sq 
                      << " diff=" << diff << " output=" << output << "\n";
        }
        
        // Update phase
        phase += phaseIncrement;
        if (phase >= 1.0) {
            phase -= 1.0;
        }
    }
    
    std::cout << "\nMin value: " << minVal << "\n";
    std::cout << "Max value: " << maxVal << "\n";
    
    return 0;
}