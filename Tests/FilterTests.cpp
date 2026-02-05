#include <gtest/gtest.h>
#include "../Source/DSP/Filters/MoogLadderFilter.h"
#include <cmath>

class FilterTest : public ::testing::Test {
protected:
    const float sampleRate = 44100.0f;
    const float epsilon = 1e-6f;
};

// Test basic filter functionality
TEST_F(FilterTest, BasicFunctionality) {
    MoogLadderFilter filter(sampleRate);
    
    // Default parameters
    EXPECT_FLOAT_EQ(filter.getCutoff(), 1000.0f);
    EXPECT_FLOAT_EQ(filter.getResonance(), 0.0f);
    EXPECT_EQ(filter.getMode(), FilterMode::LOWPASS);
    EXPECT_EQ(filter.getPoles(), 4);
    
    // Set parameters
    filter.setCutoff(2000.0f);
    filter.setResonance(0.5f);
    filter.setMode(FilterMode::BANDPASS);
    filter.setPoles(2);
    
    // Verify parameters
    EXPECT_FLOAT_EQ(filter.getCutoff(), 2000.0f);
    EXPECT_FLOAT_EQ(filter.getResonance(), 0.5f);
    EXPECT_EQ(filter.getMode(), FilterMode::BANDPASS);
    EXPECT_EQ(filter.getPoles(), 2);
}

// Test that output with zero input is zero
TEST_F(FilterTest, ZeroInput) {
    MoogLadderFilter filter(sampleRate);
    
    // Process one sample with zero input
    float output = filter.process(0.0f);
    EXPECT_NEAR(output, 0.0f, epsilon);
    
    // Process several samples with zero input
    for (int i = 0; i < 100; i++) {
        output = filter.process(0.0f);
        EXPECT_NEAR(output, 0.0f, epsilon);
    }
}

// Test resonance self-oscillation
TEST_F(FilterTest, SelfOscillation) {
    MoogLadderFilter filter(sampleRate);
    filter.setCutoff(1000.0f);
    filter.setResonance(1.0f); // Maximum resonance
    
    // Process zero input, which should result in self-oscillation
    float maxOutput = 0.0f;
    
    // Prime the filter with some input
    for (int i = 0; i < 100; i++) {
        filter.process(1.0f);
    }
    
    // Check output with zero input
    for (int i = 0; i < 1000; i++) {
        float output = std::abs(filter.process(0.0f));
        maxOutput = std::max(maxOutput, output);
        
        // Output should be within reasonable bounds even with resonance
        EXPECT_GE(output, -1.5f);
        EXPECT_LE(output, 1.5f);
    }
}

// Test filter cutoff parameter
TEST_F(FilterTest, CutoffParameter) {
    MoogLadderFilter filter(sampleRate);
    
    // Set initial cutoff
    float initialCutoff = 1000.0f;
    filter.setCutoff(initialCutoff);
    EXPECT_FLOAT_EQ(filter.getCutoff(), initialCutoff);
    
    // Update cutoff
    float newCutoff = 5000.0f;
    filter.setCutoff(newCutoff);
    EXPECT_FLOAT_EQ(filter.getCutoff(), newCutoff);
    
    // Test cutoff clamping
    filter.setCutoff(25000.0f); // Beyond Nyquist
    EXPECT_FLOAT_EQ(filter.getCutoff(), 20000.0f); // Should be clamped
    
    filter.setCutoff(10.0f); // Too low
    EXPECT_FLOAT_EQ(filter.getCutoff(), 20.0f); // Should be clamped
}

// Test filter resonance parameter
TEST_F(FilterTest, ResonanceParameter) {
    MoogLadderFilter filter(sampleRate);
    
    // Set initial resonance
    float initialResonance = 0.3f;
    filter.setResonance(initialResonance);
    EXPECT_FLOAT_EQ(filter.getResonance(), initialResonance);
    
    // Update resonance
    float newResonance = 0.7f;
    filter.setResonance(newResonance);
    EXPECT_FLOAT_EQ(filter.getResonance(), newResonance);
    
    // Test resonance clamping
    filter.setResonance(1.5f); // Beyond maximum
    EXPECT_FLOAT_EQ(filter.getResonance(), 1.0f); // Should be clamped
    
    filter.setResonance(-0.2f); // Negative
    EXPECT_FLOAT_EQ(filter.getResonance(), 0.0f); // Should be clamped
}

// Test filter mode switching
TEST_F(FilterTest, ModeParameter) {
    MoogLadderFilter filter(sampleRate);
    
    // Default should be lowpass
    EXPECT_EQ(filter.getMode(), FilterMode::LOWPASS);
    
    // Switch to bandpass
    filter.setMode(FilterMode::BANDPASS);
    EXPECT_EQ(filter.getMode(), FilterMode::BANDPASS);
    
    // Switch to highpass
    filter.setMode(FilterMode::HIGHPASS);
    EXPECT_EQ(filter.getMode(), FilterMode::HIGHPASS);
    
    // Process some audio through each mode to ensure no crashes
    for (int i = 0; i < 100; i++) {
        float input = std::sin(2.0f * M_PI * 440.0f * i / sampleRate);
        float output = filter.process(input);
        EXPECT_GE(output, -1.5f);
        EXPECT_LE(output, 1.5f);
    }
}

// Test filter poles parameter
TEST_F(FilterTest, PolesParameter) {
    MoogLadderFilter filter(sampleRate);
    
    // Default should be 4 poles (24dB/oct)
    EXPECT_EQ(filter.getPoles(), 4);
    
    // Switch to 2 poles (12dB/oct)
    filter.setPoles(2);
    EXPECT_EQ(filter.getPoles(), 2);
    
    // Test with invalid pole values
    filter.setPoles(3); // Not supported
    EXPECT_EQ(filter.getPoles(), 4); // Should default to 4
    
    filter.setPoles(6); // Not supported
    EXPECT_EQ(filter.getPoles(), 4); // Should default to 4
}

// Test filter reset
TEST_F(FilterTest, Reset) {
    MoogLadderFilter filter(sampleRate);
    filter.setCutoff(1000.0f);
    filter.setResonance(0.9f);
    
    // Process some audio to build up filter state
    for (int i = 0; i < 100; i++) {
        filter.process(1.0f); // Constant input to charge filter
    }
    
    // Now reset the filter
    filter.reset();
    
    // Next output should be close to zero
    float output = filter.process(0.0f);
    EXPECT_NEAR(output, 0.0f, 0.01f);
}