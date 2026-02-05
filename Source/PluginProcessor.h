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