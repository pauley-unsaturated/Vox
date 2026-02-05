#include <gtest/gtest.h>
#include "../Source/DSP/Modulation/LFO.h"
#include <cmath>

class LFOTest : public ::testing::Test {
protected:
    const float sampleRate = 44100.0f;
    const float epsilon = 1e-6f;
};

// Test basic LFO functionality
TEST_F(LFOTest, BasicFunctionality) {
    LFO lfo(sampleRate);
    
    // Default values
    EXPECT_FLOAT_EQ(lfo.getFrequency(), 1.0f);
    EXPECT_EQ(lfo.getWaveform(), LFO::SINE);
    EXPECT_FALSE(lfo.getTempoSync());
    
    // Set parameters
    lfo.setFrequency(2.0f);
    lfo.setWaveform(LFO::TRIANGLE);
    
    // Verify parameters
    EXPECT_FLOAT_EQ(lfo.getFrequency(), 2.0f);
    EXPECT_EQ(lfo.getWaveform(), LFO::TRIANGLE);
}

// Test LFO output range for all waveforms
TEST_F(LFOTest, OutputRange) {
    LFO lfo(sampleRate);
    
    // Test all waveforms
    for (int waveform = LFO::SINE; waveform <= LFO::SAMPLE_HOLD; waveform++) {
        lfo.setWaveform(static_cast<LFO::Waveform>(waveform));
        
        // Process several samples and check range
        for (int i = 0; i < 1000; i++) {
            float sample = lfo.process();
            EXPECT_GE(sample, -1.0f - epsilon);
            EXPECT_LE(sample, 1.0f + epsilon);
        }
    }
}

// Test LFO tempo sync
TEST_F(LFOTest, TempoSync) {
    LFO lfo(sampleRate);
    
    // Set tempo sync
    lfo.setTempoSync(true);
    lfo.setHostBPM(120.0f);
    lfo.setSyncDivision(4); // Quarter notes
    
    EXPECT_TRUE(lfo.getTempoSync());
    EXPECT_FLOAT_EQ(lfo.getHostBPM(), 120.0f);
    EXPECT_EQ(lfo.getSyncDivision(), 4);
    
    // Calculate expected period in samples
    // At 120 BPM, quarter notes are 0.5 seconds
    float expectedPeriodInSec = 0.5f;
    int expectedSamplesPerPeriod = static_cast<int>(sampleRate * expectedPeriodInSec);
    
    // Capture first value
    float firstValue = lfo.process();
    
    // Process almost a full period
    for (int i = 1; i < expectedSamplesPerPeriod - 1; i++) {
        lfo.process();
    }
    
    // Next value should not be close to first value yet
    float midValue = lfo.process();
    EXPECT_NE(firstValue, midValue);
    
    // Process remaining samples to complete a full period
    for (int i = 0; i < expectedSamplesPerPeriod; i++) {
        lfo.process();
    }
    
    // Now the value should be close to the first value
    float endValue = lfo.process();
    EXPECT_NEAR(firstValue, endValue, 0.1f);
}

// Test LFO reset
TEST_F(LFOTest, Reset) {
    LFO lfo(sampleRate);
    lfo.setFrequency(1.0f);
    lfo.setWaveform(LFO::SINE);
    
    // Process some samples
    for (int i = 0; i < 1000; i++) {
        lfo.process();
    }
    
    // Reset and get output (should be consistent with initial value)
    lfo.reset();
    float valueAfterReset = lfo.process();
    
    // Create a new LFO and get its first output
    LFO newLfo(sampleRate);
    newLfo.setFrequency(1.0f);
    newLfo.setWaveform(LFO::SINE);
    float initialValue = newLfo.process();
    
    // Should be close to the same value
    EXPECT_NEAR(valueAfterReset, initialValue, epsilon);
}