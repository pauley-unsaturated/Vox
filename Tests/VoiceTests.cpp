#include <gtest/gtest.h>
#include "../Source/DSP/Voice/Voice.h"

class VoiceTest : public ::testing::Test {
protected:
    const float sampleRate = 44100.0f;
    const float epsilon = 1e-6f;
};

// Test basic voice functionality
TEST_F(VoiceTest, BasicFunctionality) {
    Voice voice(sampleRate);
    
    // Voice should not be active initially
    EXPECT_FALSE(voice.isActive());
    
    // Trigger note on
    voice.noteOn(60, 100); // Middle C, medium velocity
    EXPECT_TRUE(voice.isActive());
    
    // Process some samples
    for (int i = 0; i < 100; i++) {
        float sample = voice.process();
        EXPECT_GE(sample, -1.0f);
        EXPECT_LE(sample, 1.0f);
    }
    
    // Trigger note off
    voice.noteOff();
    
    // Process until voice is done (release phase)
    int maxIterations = static_cast<int>(sampleRate * 1.0f); // 1 second max
    for (int i = 0; i < maxIterations && voice.isActive(); i++) {
        voice.process();
    }
    
    // Voice should not be active after release phase
    EXPECT_FALSE(voice.isActive());
}

// Test glide functionality
TEST_F(VoiceTest, Glide) {
    Voice voice(sampleRate);
    
    // Enable glide with a moderate time
    voice.setGlide(true, 0.2f);
    
    // Trigger first note
    voice.noteOn(60, 100); // Middle C
    
    // Process some samples
    for (int i = 0; i < 100; i++) {
        voice.process();
    }
    
    // Trigger second note
    voice.noteOn(72, 100); // C one octave higher
    
    // Process for glide time
    float prevSample = 0.0f;
    float currentSample = 0.0f;
    bool foundTransition = false;
    
    // Process for a while, checking if frequency changes gradually
    for (int i = 0; i < sampleRate * 0.3f; i++) {
        prevSample = currentSample;
        currentSample = voice.process();
        
        if (i > 0 && std::abs(currentSample - prevSample) > epsilon) {
            foundTransition = true;
        }
    }
    
    // Should have found some transitions due to glide
    EXPECT_TRUE(foundTransition);
}

// Test voice reset
TEST_F(VoiceTest, Reset) {
    Voice voice(sampleRate);
    
    // Trigger note on
    voice.noteOn(60, 100);
    EXPECT_TRUE(voice.isActive());
    
    // Process some samples
    for (int i = 0; i < 100; i++) {
        voice.process();
    }
    
    // Reset voice
    voice.reset();
    
    // Voice should not be active after reset
    EXPECT_FALSE(voice.isActive());
    
    // Output should be close to zero
    EXPECT_NEAR(voice.process(), 0.0f, 0.01f);
}

// Test velocity sensitivity
TEST_F(VoiceTest, VelocitySensitivity) {
    Voice voice(sampleRate);
    
    // Set up voice for testing
    voice.setModulationAmounts(0.5f, 1.0f, 0.5f, 0.5f); // Full velocity->amp sensitivity
    
    // Trigger note with low velocity
    voice.noteOn(60, 1); // Minimum velocity
    float lowVelSample = 0.0f;
    
    // Process a bit
    for (int i = 0; i < 100; i++) {
        lowVelSample = std::max(lowVelSample, std::abs(voice.process()));
    }
    
    // Reset
    voice.reset();
    
    // Trigger note with high velocity
    voice.noteOn(60, 127); // Maximum velocity
    float highVelSample = 0.0f;
    
    // Process a bit
    for (int i = 0; i < 100; i++) {
        highVelSample = std::max(highVelSample, std::abs(voice.process()));
    }
    
    // High velocity should produce stronger output
    EXPECT_GT(highVelSample, lowVelSample);
}