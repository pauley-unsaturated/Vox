# Synthesizer Plugin Code Components (Continued)

Continuation of the synthesizer plugin code components:

### Filter Tests (Continued)
**Location:** `Tests/FilterTests.cpp` (continued)

```cpp
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
```

### Envelope Tests
**Location:** `Tests/EnvelopeTests.cpp`

```cpp
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
```

### LFO Tests
**Location:** `Tests/LFOTests.cpp`

```cpp
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
```

### Voice Tests
**Location:** `Tests/VoiceTests.cpp`

```cpp
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
```

### Arpeggiator Tests
**Location:** `Tests/ArpeggiatorTests.cpp`

```cpp
#include <gtest/gtest.h>
#include "../Source/DSP/Performance/Arpeggiator.h"

class ArpeggiatorTest : public ::testing::Test {
protected:
    const float sampleRate = 44100.0f;
};

// Test basic arpeggiator functionality
TEST_F(ArpeggiatorTest, BasicFunctionality) {
    Arpeggiator arp(sampleRate);
    
    // Default values
    EXPECT_FALSE(arp.isEnabled());
    EXPECT_EQ(arp.getMode(), Arpeggiator::UP);
    EXPECT_EQ(arp.getOctaveRange(), 1);
    
    // Enable arpeggiator
    arp.setEnabled(true);
    EXPECT_TRUE(arp.isEnabled());
    
    // Without notes, getNextNote should return -1
    EXPECT_EQ(arp.getNextNote(), -1);
    
    // Add notes
    arp.noteOn(60); // Middle C
    arp.noteOn(64); // E
    arp.noteOn(67); // G
    
    // Get notes for a while
    int previousNote = -1;
    bool foundDifferentNotes = false;
    
    for (int i = 0; i < sampleRate * 0.5f; i++) {
        int currentNote = arp.getNextNote();
        if (currentNote != -1 && previousNote != -1 && currentNote != previousNote) {
            foundDifferentNotes = true;
            break;
        }
        previousNote = currentNote;
    }
    
    // Should have found different notes
    EXPECT_TRUE(foundDifferentNotes);
}

// Test arpeggiator modes
TEST_F(ArpeggiatorTest, Modes) {
    Arpeggiator arp(sampleRate);
    arp.setEnabled(true);
    
    // Add notes in ascending order
    arp.noteOn(60); // C
    arp.noteOn(64); // E
    arp.noteOn(67); // G
    
    // Test UP mode
    arp.setMode(Arpeggiator::UP);
    int notesUp[10];
    for (int i = 0; i < 10; i++) {
        notesUp[i] = arp.getNextNote();
        // Process enough samples to advance to next note
        for (int j = 0; j < sampleRate * 0.2f; j++) {
            arp.getNextNote();
        }
    }
    
    // Verify pattern: C, E, G, C, E, G, ...
    EXPECT_EQ(notesUp[0], 60);
    EXPECT_EQ(notesUp[1], 64);
    EXPECT_EQ(notesUp[2], 67);
    EXPECT_EQ(notesUp[3], 60);
    
    // Test DOWN mode
    arp.setMode(Arpeggiator::DOWN);
    arp.reset();
    int notesDown[10];
    for (int i = 0; i < 10; i++) {
        notesDown[i] = arp.getNextNote();
        // Process enough samples to advance to next note
        for (int j = 0; j < sampleRate * 0.2f; j++) {
            arp.getNextNote();
        }
    }
    
    // Verify pattern: G, E, C, G, E, C, ...
    EXPECT_EQ(notesDown[0], 67);
    EXPECT_EQ(notesDown[1], 64);
    EXPECT_EQ(notesDown[2], 60);
    EXPECT_EQ(notesDown[3], 67);
}

// Test octave range
TEST_F(ArpeggiatorTest, OctaveRange) {
    Arpeggiator arp(sampleRate);
    arp.setEnabled(true);
    arp.setMode(Arpeggiator::UP);
    
    // Add a note
    arp.noteOn(60); // Middle C
    
    // Test with 1 octave range (default)
    arp.setOctaveRange(1);
    int notes1Oct[10];
    for (int i = 0; i < 10; i++) {
        notes1Oct[i] = arp.getNextNote();
        // Process enough samples to advance to next note
        for (int j = 0; j < sampleRate * 0.2f; j++) {
            arp.getNextNote();
        }
    }
    
    // Verify pattern: C, C, C, ... (only one note in one octave)
    EXPECT_EQ(notes1Oct[0], 60);
    EXPECT_EQ(notes1Oct[1], 60);
    
    // Test with 2 octave range
    arp.setOctaveRange(2);
    arp.reset();
    int notes2Oct[10];
    for (int i = 0; i < 10; i++) {
        notes2Oct[i] = arp.getNextNote();
        // Process enough samples to advance to next note
        for (int j = 0; j < sampleRate * 0.2f; j++) {
            arp.getNextNote();
        }
    }
    
    // Verify pattern: C, C+12, C, C+12, ... (one note in two octaves)
    EXPECT_EQ(notes2Oct[0], 60);   // C4
    EXPECT_EQ(notes2Oct[1], 60+12); // C5
    EXPECT_EQ(notes2Oct[2], 60);   // C4
}

// Test note removal
TEST_F(ArpeggiatorTest, NoteRemoval) {
    Arpeggiator arp(sampleRate);
    arp.setEnabled(true);
    arp.setMode(Arpeggiator::UP);
    
    // Add notes
    arp.noteOn(60); // C
    arp.noteOn(64); // E
    arp.noteOn(67); // G
    
    // Check that we get all three notes
    bool foundC = false, foundE = false, foundG = false;
    for (int i = 0; i < sampleRate * 1.0f; i++) {
        int note = arp.getNextNote();
        if (note == 60) foundC = true;
        if (note == 64) foundE = true;
        if (note == 67) foundG = true;
    }
    
    EXPECT_TRUE(foundC && foundE && foundG);
    
    // Remove one note
    arp.noteOff(64); // Remove E
    
    // Reset flags
    foundC = foundE = foundG = false;
    
    // Check that we only get C and G now
    for (int i = 0; i < sampleRate * 1.0f; i++) {
        int note = arp.getNextNote();
        if (note == 60) foundC = true;
        if (note == 64) foundE = true;
        if (note == 67) foundG = true;
    }
    
    EXPECT_TRUE(foundC);
    EXPECT_FALSE(foundE); // E should not be found
    EXPECT_TRUE(foundG);
}

// Test transpose functionality
TEST_F(ArpeggiatorTest, Transpose) {
    Arpeggiator arp(sampleRate);
    arp.setEnabled(true);
    
    // Add a note
    arp.noteOn(60); // Middle C
    
    // Get the note without transpose
    int noteBeforeTranspose = arp.getNextNote();
    EXPECT_EQ(noteBeforeTranspose, 60);
    
    // Apply transpose
    arp.transposePattern(5); // Up a perfect fourth
    
    // Get the note after transpose
    int noteAfterTranspose = arp.getNextNote();
    EXPECT_EQ(noteAfterTranspose, 65); // 60 + 5 = 65
    
    // Reset transpose
    arp.transposePattern(0);
    
    // Get the note after reset
    int noteAfterReset = arp.getNextNote();
    EXPECT_EQ(noteAfterReset, 60);
}
```

## Main Project Files

### Plugin Processor Header
**Location:** `Source/PluginProcessor.h`

```cpp
#pragma once

#include <JuceHeader.h>
#include "DSP/Voice/Voice.h"
#include "DSP/Performance/Arpeggiator.h"

//==============================================================================
class SynthesizerAudioProcessor  : public juce::AudioProcessor
{
public:
    //==============================================================================
    SynthesizerAudioProcessor();
    ~SynthesizerAudioProcessor() override;

    //==============================================================================
    void prepareToPlay (double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;

    bool isBusesLayoutSupported (const BusesLayout& layouts) const override;

    void processBlock (juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    //==============================================================================
    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override;

    //==============================================================================
    const juce::String getName() const override;

    bool acceptsMidi() const override;
    bool producesMidi() const override;
    bool isMidiEffect() const override;
    double getTailLengthSeconds() const override;

    //==============================================================================
    int getNumPrograms() override;
    int getCurrentProgram() override;
    void setCurrentProgram (int index) override;
    const juce::String getProgramName (int index) override;
    void changeProgramName (int index, const juce::String& newName) override;

    //==============================================================================
    void getStateInformation (juce::MemoryBlock& destData) override;
    void setStateInformation (const void* data, int sizeInBytes) override;

private:
    // Synthesizer components
    Voice* voice;
    Arpeggiator* arpeggiator;
    
    // Parameter handling
    juce::AudioProcessorValueTreeState parameters;
    std::atomic<float>* oscMixParam = nullptr;
    std::atomic<float>* filterCutoffParam = nullptr;
    std::atomic<float>* filterResonanceParam = nullptr;
    std::atomic<float>* filterEnvAmountParam = nullptr;
    std::atomic<float>* attackParam = nullptr;
    std::atomic<float>* decayParam = nullptr;
    std::atomic<float>* sustainParam = nullptr;
    std::atomic<float>* releaseParam = nullptr;
    std::atomic<float>* glideTimeParam = nullptr;
    std::atomic<float>* glideEnabledParam = nullptr;
    std::atomic<float>* oscAlgorithmParam = nullptr;
    std::atomic<float>* subOscOctaveParam = nullptr;
    std::atomic<float>* pulseWidthParam = nullptr;
    std::atomic<float>* arpEnabledParam = nullptr;
    std::atomic<float>* arpModeParam = nullptr;
    std::atomic<float>* arpRateParam = nullptr;
    std::atomic<float>* arpOctavesParam = nullptr;
    
    // MIDI state
    int currentNote = -1;
    bool noteIsOn = false;
    
    // Create parameter layout
    juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout();
    
    // Update parameters
    void updateParameters();
    
    //==============================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SynthesizerAudioProcessor)
};
```

### Plugin Processor Implementation Skeleton
**Location:** `Source/PluginProcessor.cpp`

```cpp
#include "PluginProcessor.h"
#include "PluginEditor.h"

//==============================================================================
SynthesizerAudioProcessor::SynthesizerAudioProcessor()
    : AudioProcessor (BusesProperties()
                      .withOutput ("Output", juce::AudioChannelSet::stereo(), true)),
      parameters(*this, nullptr, "Parameters", createParameterLayout())
{
    // Initialize voice and arpeggiator
    voice = new Voice(44100.0f);
    arpeggiator = new Arpeggiator(44100.0f);
    
    // Get parameter pointers
    oscMixParam = parameters.getRawParameterValue("oscMix");
    filterCutoffParam = parameters.getRawParameterValue("filterCutoff");
    filterResonanceParam = parameters.getRawParameterValue("filterResonance");
    filterEnvAmountParam = parameters.getRawParameterValue("filterEnvAmount");
    attackParam = parameters.getRawParameterValue("attack");
    decayParam = parameters.getRawParameterValue("decay");
    sustainParam = parameters.getRawParameterValue("sustain");
    releaseParam = parameters.getRawParameterValue("release");
    glideTimeParam = parameters.getRawParameterValue("glideTime");
    glideEnabledParam = parameters.getRawParameterValue("glideEnabled");
    oscAlgorithmParam = parameters.getRawParameterValue("oscAlgorithm");
    subOscOctaveParam = parameters.getRawParameterValue("subOscOctave");
    pulseWidthParam = parameters.getRawParameterValue("pulseWidth");
    arpEnabledParam = parameters.getRawParameterValue("arpEnabled");
    arpModeParam = parameters.getRawParameterValue("arpMode");
    arpRateParam = parameters.getRawParameterValue("arpRate");
    arpOctavesParam = parameters.getRawParameterValue("arpOctaves");
}

SynthesizerAudioProcessor::~SynthesizerAudioProcessor()
{
    delete voice;
    delete arpeggiator;
}

//==============================================================================
juce::AudioProcessorValueTreeState::ParameterLayout SynthesizerAudioProcessor::createParameterLayout()
{
    juce::AudioProcessorValueTreeState::ParameterLayout layout;
    
    // Oscillator parameters
    layout.add(std::make_unique<juce::AudioParameterFloat>("oscMix", "Oscillator Mix", 0.0f, 1.0f, 0.5f));
    layout.add(std::make_unique<juce::AudioParameterChoice>("oscAlgorithm", "Oscillator Algorithm", 
                                                          juce::StringArray("DPW", "PolyBLEP"), 1));
    layout.add(std::make_unique<juce::AudioParameterInt>("subOscOctave", "Sub Oscillator Octave", -2, -1, -1));
    layout.add(std::make_unique<juce::AudioParameterFloat>("pulseWidth", "Pulse Width", 0.05f, 0.95f, 0.5f));
    
    // Filter parameters
    layout.add(std::make_unique<juce::AudioParameterFloat>("filterCutoff", "Filter Cutoff", 20.0f, 20000.0f, 1000.0f));
    layout.add(std::make_unique<juce::AudioParameterFloat>("filterResonance", "Filter Resonance", 0.0f, 1.0f, 0.1f));
    layout.add(std::make_unique<juce::AudioParameterFloat>("filterEnvAmount", "Filter Env Amount", 0.0f, 1.0f, 0.5f));
    
    // Envelope parameters
    layout.add(std::make_unique<juce::AudioParameterFloat>("attack", "Attack", 0.001f, 5.0f, 0.01f));
    layout.add(std::make_unique<juce::AudioParameterFloat>("decay", "Decay", 0.001f, 5.0f, 0.1f));
    layout.add(std::make_unique<juce::AudioParameterFloat>("sustain", "Sustain", 0.0f, 1.0f, 0.7f));
    layout.add(std::make_unique<juce::AudioParameterFloat>("release", "Release", 0.001f, 5.0f, 0.3f));
    
    // Glide parameters
    layout.add(std::make_unique<juce::AudioParameterBool>("glideEnabled", "Glide Enabled", false));
    layout.add(std::make_unique<juce::AudioParameterFloat>("glideTime", "Glide Time", 0.001f, 5.0f, 0.1f));
    
    // Arpeggiator parameters
    layout.add(std::make_unique<juce::AudioParameterBool>("arpEnabled", "Arpeggiator Enabled", false));
    layout.add(std::make_unique<juce::AudioParameterChoice>("arpMode", "Arpeggiator Mode", 
                                                          juce::StringArray("Up", "Down", "Up/Down", "Random"), 0));
    layout.add(std::make_unique<juce::AudioParameterFloat>("arpRate", "Arpeggiator Rate", 0.1f, 20.0f, 5.0f));
    layout.add(std::make_unique<juce::AudioParameterInt>("arpOctaves", "Arpeggiator Octaves", 1, 3, 1));
    
    return layout;
}

void SynthesizerAudioProcessor::updateParameters()
{
    // TODO: Update voice and arpeggiator parameters based on parameter values
    // This will be implemented in detail during the project development
}

//==============================================================================
const juce::String SynthesizerAudioProcessor::getName() const
{
    return JucePlugin_Name;
}

bool SynthesizerAudioProcessor::acceptsMidi() const
{
    return true;
}

bool SynthesizerAudioProcessor::producesMidi() const
{
    return false;
}

bool SynthesizerAudioProcessor::isMidiEffect() const
{
    return false;
}

double SynthesizerAudioProcessor::getTailLengthSeconds() const
{
    return 0.0;
}

int SynthesizerAudioProcessor::getNumPrograms()
{
    return 1;   // NB: some hosts don't cope very well if you tell them there are 0 programs,
                // so this should be at least 1, even if you're not really implementing programs.
}

int SynthesizerAudioProcessor::getCurrentProgram()
{
    return 0;
}

void SynthesizerAudioProcessor::setCurrentProgram (int index)
{
    // Implement if needed
}

const juce::String SynthesizerAudioProcessor::getProgramName (int index)
{
    return {};
}

void SynthesizerAudioProcessor::changeProgramName (int index, const juce::String& newName)
{
    // Implement if needed
}

//==============================================================================
void SynthesizerAudioProcessor::prepareToPlay (double sampleRate, int samplesPerBlock)
{
    // Set sample rate for voice and arpeggiator
    voice->setSampleRate(static_cast<float>(sampleRate));
    arpeggiator->setSampleRate(static_cast<float>(sampleRate));
    
    // Update parameters
    updateParameters();
}

void SynthesizerAudioProcessor::releaseResources()
{
    // Release resources when plugin is no longer playing
    voice->reset();
    arpeggiator->reset();
}

bool SynthesizerAudioProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
    // Only support stereo output
    if (layouts.getMainOutputChannelSet() != juce::AudioChannelSet::stereo())
        return false;
    
    return true;
}

void SynthesizerAudioProcessor::processBlock (juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
{
    // TODO: Implement full audio processing
    // This will be implemented in detail during the project development
}

//==============================================================================
bool SynthesizerAudioProcessor::hasEditor() const
{
    return true;
}

juce::AudioProcessorEditor* SynthesizerAudioProcessor::createEditor()
{
    // Return a generic editor for now, will be replaced with custom editor
    return new juce::GenericAudioProcessorEditor(*this);
}

//==============================================================================
void SynthesizerAudioProcessor::getStateInformation (juce::MemoryBlock& destData)
{
    // Save plugin state
    auto state = parameters.copyState();
    std::unique_ptr<juce::XmlElement> xml(state.createXml());
    copyXmlToBinary(*xml, destData);
}

void SynthesizerAudioProcessor::setStateInformation (const void* data, int sizeInBytes)
{
    // Restore plugin state
    std::unique_ptr<juce::XmlElement> xmlState(getXmlFromBinary(data, sizeInBytes));
    
    if (xmlState.get() != nullptr)
        if (xmlState->hasTagName(parameters.state.getType()))
            parameters.replaceState(juce::ValueTree::fromXml(*xmlState));
}

//==============================================================================
// This creates new instances of the plugin..
juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new SynthesizerAudioProcessor();
}
```

These code components provide a comprehensive foundation for implementing the subtractive synthesizer plugin. Claude Code can use these as building blocks and place them in the appropriate folders within the project repository structure.

The implementation follows modern C++ practices and is organized in a modular way to facilitate testing and maintenance. Each component has a clear responsibility and is designed to interact seamlessly with other components in the system.

The repository structure should follow the organization implied in the file paths, with separate directories for different categories of components (Oscillators, Filters, Envelopes, etc.).
