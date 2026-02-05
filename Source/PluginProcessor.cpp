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