#include <gtest/gtest.h>
#include "../Source/DSP/Envelopes/ADSREnvelope.h"

class EnvelopeTest : public ::testing::Test {
protected:
    const float sampleRate = 44100.0f;
    const float epsilon = 1e-6f;
};

// Test ADSR envelope basic functionality
TEST_F(EnvelopeTest, BasicFunctionality) {
    ADSREnvelope env(sampleRate);
    
    // Initial state should be idle
    EXPECT_EQ(env.getCurrentStage(), ADSREnvelope::IDLE);
    EXPECT_FALSE(env.isActive());
    
    // Set parameters
    env.setAttackTime(0.1f);
    env.setDecayTime(0.2f);
    env.setSustainLevel(0.5f);
    env.setReleaseTime(0.3f);
    
    // Verify parameters
    EXPECT_FLOAT_EQ(env.getAttackTime(), 0.1f);
    EXPECT_FLOAT_EQ(env.getDecayTime(), 0.2f);
    EXPECT_FLOAT_EQ(env.getSustainLevel(), 0.5f);
    EXPECT_FLOAT_EQ(env.getReleaseTime(), 0.3f);
}

// Test envelope stages
TEST_F(EnvelopeTest, EnvelopeStages) {
    ADSREnvelope env(sampleRate);
    
    // Set fast envelope for testing
    env.setAttackTime(0.01f);
    env.setDecayTime(0.01f);
    env.setSustainLevel(0.5f);
    env.setReleaseTime(0.01f);
    
    // Initial stage is IDLE
    EXPECT_EQ(env.getCurrentStage(), ADSREnvelope::IDLE);
    
    // Trigger note on
    env.noteOn();
    EXPECT_EQ(env.getCurrentStage(), ADSREnvelope::ATTACK);
    EXPECT_TRUE(env.isActive());
    
    // Process until decay stage
    float value = 0.0f;
    for (int i = 0; i < sampleRate * 0.02f; i++) {
        value = env.process();
        if (env.getCurrentStage() == ADSREnvelope::DECAY) break;
    }
    EXPECT_EQ(env.getCurrentStage(), ADSREnvelope::DECAY);
    EXPECT_GT(value, 0.9f); // Should have reached near maximum
    
    // Process until sustain stage
    for (int i = 0; i < sampleRate * 0.02f; i++) {
        value = env.process();
        if (env.getCurrentStage() == ADSREnvelope::SUSTAIN) break;
    }
    EXPECT_EQ(env.getCurrentStage(), ADSREnvelope::SUSTAIN);
    EXPECT_NEAR(value, env.getSustainLevel(), 0.01f);
    
    // Trigger note off
    env.noteOff();
    EXPECT_EQ(env.getCurrentStage(), ADSREnvelope::RELEASE);
    
    // Process until idle
    for (int i = 0; i < sampleRate * 0.02f; i++) {
        value = env.process();
        if (env.getCurrentStage() == ADSREnvelope::IDLE) break;
    }
    EXPECT_EQ(env.getCurrentStage(), ADSREnvelope::IDLE);
    EXPECT_NEAR(value, 0.0f, 0.01f);
    EXPECT_FALSE(env.isActive());
}

// Test envelope reset
TEST_F(EnvelopeTest, Reset) {
    ADSREnvelope env(sampleRate);
    
    // Set parameters
    env.setAttackTime(0.1f);
    env.setDecayTime(0.2f);
    env.setSustainLevel(0.5f);
    env.setReleaseTime(0.3f);
    
    // Trigger note on
    env.noteOn();
    
    // Process a bit
    for (int i = 0; i < 1000; i++) {
        env.process();
    }
    
    // Reset the envelope
    env.reset();
    
    // Should be back to idle state
    EXPECT_EQ(env.getCurrentStage(), ADSREnvelope::IDLE);
    EXPECT_FALSE(env.isActive());
    
    // Next value should be zero
    EXPECT_FLOAT_EQ(env.process(), 0.0f);
}