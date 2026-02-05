//
//  VoxExtensionDSPKernel.hpp
//  VoxExtension
//
//  Vox Pulsar Synthesizer DSP Kernel
//

#pragma once

#import <AudioToolbox/AudioToolbox.h>
#include <cstring>
#include <cstdint>
#include <unordered_map>
#include <cmath>
#import <CoreMIDI/CoreMIDI.h>
#import <algorithm>
#import <vector>
#import <span>
#import <memory>

#import "VoxExtensionParameterAddresses.h"
#include <VoxCore/VoxCore.h>

/*
 VoxExtensionDSPKernel
 As a non-ObjC class, this is safe to use from render thread.
 */
class VoxExtensionDSPKernel {
public:
    VoxExtensionDSPKernel() {
        // Initialize stored parameters
        std::memset(&mStoredParameters, 0, sizeof(mStoredParameters));
        
        // Set sensible defaults
        mStoredParameters.masterVolume = 0.5;
        mStoredParameters.dutyCycle = 0.2;
        mStoredParameters.pulsaretShape = 1;
        mStoredParameters.vowelMorph = 0.0;
        mStoredParameters.formant1Freq = 800.0;
        mStoredParameters.formant2Freq = 1200.0;
        mStoredParameters.formant1Q = 10.0;
        mStoredParameters.formant2Q = 10.0;
        mStoredParameters.formantMix = 1.0;
        mStoredParameters.useVowelMorph = true;
        mStoredParameters.ampAttack = 0.01;
        mStoredParameters.ampDecay = 0.1;
        mStoredParameters.ampSustain = 0.7;
        mStoredParameters.ampRelease = 0.3;
        mStoredParameters.glideEnabled = false;
        mStoredParameters.glideTime = 0.1;
        mStoredParameters.pitchBendSemitones = 0.0;
    }
    
    void initialize(int channelCount, double inSampleRate) {
        mSampleRate = inSampleRate;
        
        // Initialize VoxVoice
        mVoice = std::make_unique<VoxVoice>(inSampleRate);
        mVoice->setParameters(mStoredParameters);
        
        // Initialize output level metering
        mLevelDecayCoeff = std::exp(-1.0f / (static_cast<float>(mSampleRate) * 0.05f));
        mPeakHoldDecayCoeff = std::exp(-1.0f / (static_cast<float>(mSampleRate) * 1.5f));
    }
    
    void deInitialize() {
        mVoice.reset();
    }
    
    // MARK: - Bypass
    bool isBypassed() {
        return mBypassed;
    }
    
    void setBypass(bool shouldBypass) {
        mBypassed = shouldBypass;
    }
    
    // MARK: - Parameter Getter / Setter
    void setParameter(AUParameterAddress address, AUValue value) {
        // Store raw parameter value
        mRawParameterValues[address] = value;
        
        bool updateVoice = true;
        
        switch (address) {
            // Master Section
            case VoxExtensionParameterAddress::masterVolume:
                mStoredParameters.masterVolume = dBToAmplitude(value);
                break;
                
            // Pulsar Oscillator
            case VoxExtensionParameterAddress::pulsaretShape:
                mStoredParameters.pulsaretShape = static_cast<int>(value);
                break;
            case VoxExtensionParameterAddress::dutyCycle:
                mStoredParameters.dutyCycle = value / 100.0;  // Convert from percent
                break;
                
            // Formant Filter
            case VoxExtensionParameterAddress::useVowelMorph:
                mStoredParameters.useVowelMorph = (value >= 0.5);
                break;
            case VoxExtensionParameterAddress::vowelMorph:
                mStoredParameters.vowelMorph = value;
                break;
            case VoxExtensionParameterAddress::formant1Freq:
                mStoredParameters.formant1Freq = value;
                break;
            case VoxExtensionParameterAddress::formant2Freq:
                mStoredParameters.formant2Freq = value;
                break;
            case VoxExtensionParameterAddress::formant1Q:
                mStoredParameters.formant1Q = value;
                break;
            case VoxExtensionParameterAddress::formant2Q:
                mStoredParameters.formant2Q = value;
                break;
            case VoxExtensionParameterAddress::formantMix:
                mStoredParameters.formantMix = value / 100.0;  // Convert from percent
                break;
                
            // Amp Envelope
            case VoxExtensionParameterAddress::ampAttack:
                mStoredParameters.ampAttack = value / 1000.0;  // Convert from ms to seconds
                break;
            case VoxExtensionParameterAddress::ampDecay:
                mStoredParameters.ampDecay = value / 1000.0;
                break;
            case VoxExtensionParameterAddress::ampSustain:
                mStoredParameters.ampSustain = value / 100.0;  // Convert from percent
                break;
            case VoxExtensionParameterAddress::ampRelease:
                mStoredParameters.ampRelease = value / 1000.0;
                break;
                
            // Performance
            case VoxExtensionParameterAddress::glideEnabled:
                mStoredParameters.glideEnabled = (value >= 0.5);
                break;
            case VoxExtensionParameterAddress::glideTime:
                mStoredParameters.glideTime = value / 1000.0;  // Convert from ms
                break;
            case VoxExtensionParameterAddress::pitchBendRange:
                mPitchBendRange = static_cast<int>(value);
                updateVoice = false;
                break;
                
            default:
                updateVoice = false;
                break;
        }
        
        // Apply to voice if it exists
        if (updateVoice && mVoice) {
            mVoice->setParameters(mStoredParameters);
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        // Return raw parameter value if stored
        auto it = mRawParameterValues.find(address);
        if (it != mRawParameterValues.end()) {
            return it->second;
        }
        
        // Return defaults
        switch (address) {
            case VoxExtensionParameterAddress::masterVolume:
                return -6.0f;
            case VoxExtensionParameterAddress::pulsaretShape:
                return 1.0f;
            case VoxExtensionParameterAddress::dutyCycle:
                return 20.0f;
            case VoxExtensionParameterAddress::useVowelMorph:
                return 1.0f;
            case VoxExtensionParameterAddress::vowelMorph:
                return 0.0f;
            case VoxExtensionParameterAddress::formant1Freq:
                return 800.0f;
            case VoxExtensionParameterAddress::formant2Freq:
                return 1200.0f;
            case VoxExtensionParameterAddress::formant1Q:
                return 10.0f;
            case VoxExtensionParameterAddress::formant2Q:
                return 10.0f;
            case VoxExtensionParameterAddress::formantMix:
                return 100.0f;
            case VoxExtensionParameterAddress::ampAttack:
                return 10.0f;
            case VoxExtensionParameterAddress::ampDecay:
                return 100.0f;
            case VoxExtensionParameterAddress::ampSustain:
                return 70.0f;
            case VoxExtensionParameterAddress::ampRelease:
                return 300.0f;
            case VoxExtensionParameterAddress::glideEnabled:
                return 0.0f;
            case VoxExtensionParameterAddress::glideTime:
                return 100.0f;
            case VoxExtensionParameterAddress::pitchBendRange:
                return 2.0f;
            default:
                return 0.0f;
        }
    }
    
    // MARK: - Max Frames
    AUAudioFrameCount maximumFramesToRender() const {
        return mMaxFramesToRender;
    }
    
    void setMaximumFramesToRender(const AUAudioFrameCount &maxFrames) {
        mMaxFramesToRender = maxFrames;
    }
    
    // MARK: - Musical Context
    void setMusicalContextBlock(AUHostMusicalContextBlock contextBlock) {
        mMusicalContextBlock = contextBlock;
    }
    
    void setTransportStateBlock(AUHostTransportStateBlock transportBlock) {
        mTransportStateBlock = transportBlock;
    }
    
    // MARK: - MIDI Protocol
    MIDIProtocolID AudioUnitMIDIProtocol() const {
        return kMIDIProtocol_2_0;
    }
    
    // MARK: - Output Level Metering
    float getOutputLevel() const {
        return mOutputLevel;
    }
    
    float getOutputPeakHold() const {
        return mOutputPeakHold;
    }
    
    // MARK: - Internal Process
    void process(std::span<float *> outputBuffers, AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount) {
        if (mBypassed) {
            for (UInt32 channel = 0; channel < outputBuffers.size(); ++channel) {
                std::fill_n(outputBuffers[channel], frameCount, 0.f);
            }
            return;
        }
        
        // Generate per sample DSP
        for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
            // Process the voice
            const auto sample = static_cast<float>(mVoice->process());
            
            for (UInt32 channel = 0; channel < outputBuffers.size(); ++channel) {
                outputBuffers[channel][frameIndex] = sample;
            }
        }
        
        // Update output level metering
        updateOutputMetering(outputBuffers, frameCount);
    }
    
    // MARK: - Output Level Metering
    void updateOutputMetering(std::span<float *> outputBuffers, AUAudioFrameCount frameCount) {
        if (outputBuffers.empty() || frameCount == 0) return;
        
        float bufferPeak = 0.0f;
        for (UInt32 i = 0; i < frameCount; ++i) {
            float absSample = std::fabs(outputBuffers[0][i]);
            if (absSample > bufferPeak) {
                bufferPeak = absSample;
            }
        }
        
        if (bufferPeak > mCurrentLevel) {
            mCurrentLevel = bufferPeak;
        } else {
            float decayFactor = std::pow(mLevelDecayCoeff, static_cast<float>(frameCount));
            mCurrentLevel *= decayFactor;
        }
        
        if (bufferPeak > mPeakHoldValue) {
            mPeakHoldValue = bufferPeak;
        } else {
            float decayFactor = std::pow(mPeakHoldDecayCoeff, static_cast<float>(frameCount));
            mPeakHoldValue *= decayFactor;
        }
        
        mOutputLevel = mCurrentLevel;
        mOutputPeakHold = mPeakHoldValue;
    }
    
    void handleOneEvent(AUEventSampleTime now, AURenderEvent const *event) {
        switch (event->head.eventType) {
            case AURenderEventParameter: {
                handleParameterEvent(now, event->parameter);
                break;
            }
            case AURenderEventParameterRamp: {
                handleParameterEvent(now, event->parameter);
                break;
            }
            case AURenderEventMIDIEventList: {
                handleMIDIEventList(now, &event->MIDIEventsList);
                break;
            }
            default:
                break;
        }
    }
    
    void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {
        setParameter(parameterEvent.parameterAddress, parameterEvent.value);
    }
    
    void handleMIDIEventList(AUEventSampleTime now, AUMIDIEventList const* midiEvent) {
        auto visitor = [] (void* context, MIDITimeStamp timeStamp, MIDIUniversalMessage message) {
            auto thisObject = static_cast<VoxExtensionDSPKernel *>(context);
            
            switch (message.type) {
                case kMIDIMessageTypeChannelVoice2: {
                    thisObject->handleMIDI2VoiceMessage(message);
                    break;
                }
                default:
                    break;
            }
        };
        
        MIDIEventListForEachEvent(&midiEvent->eventList, visitor, this);
    }
    
    void handleMIDI2VoiceMessage(const struct MIDIUniversalMessage& message) {
        const auto& note = message.channelVoice2.note;
        
        switch (message.channelVoice2.status) {
            case kMIDICVStatusNoteOff: {
                if (mVoice) {
                    mVoice->noteOff(note.number);
                }
                break;
            }
            case kMIDICVStatusNoteOn: {
                if (mVoice) {
                    const auto velocity = message.channelVoice2.note.velocity;
                    const double normalizedVelocity = (double)velocity / (double)std::numeric_limits<std::uint16_t>::max();
                    mVoice->noteOn(note.number, normalizedVelocity);
                }
                break;
            }
            case kMIDICVStatusPitchBend: {
                if (mVoice) {
                    // Convert MIDI 2.0 pitch bend to semitones
                    const double normalizedBend = ((double)message.channelVoice2.pitchBend.data / (double)0xFFFFFFFF) * 2.0 - 1.0;
                    const double semitones = normalizedBend * mPitchBendRange;
                    mVoice->setPitchBend(semitones);
                }
                break;
            }
            case kMIDICVStatusControlChange: {
                // Handle mod wheel, etc. (future expansion)
                break;
            }
            default:
                break;
        }
    }
    
    // MARK: - Utility
    static constexpr double kMinimumGainDB = -60.0;
    
    static inline double dBToAmplitude(double dB) {
        if (dB <= kMinimumGainDB) {
            return 0.0;
        }
        return std::pow(10.0, dB / 20.0);
    }
    
private:
    double mSampleRate = 44100.0;
    bool mBypassed = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;
    
    // Voice
    std::unique_ptr<VoxVoice> mVoice;
    VoxVoiceParameters mStoredParameters;
    std::unordered_map<AUParameterAddress, AUValue> mRawParameterValues;
    
    // Performance settings
    int mPitchBendRange = 2;  // semitones
    
    // Host context
    AUHostMusicalContextBlock mMusicalContextBlock = nullptr;
    AUHostTransportStateBlock mTransportStateBlock = nullptr;
    
    // Level metering
    float mCurrentLevel = 0.0f;
    float mPeakHoldValue = 0.0f;
    float mOutputLevel = 0.0f;
    float mOutputPeakHold = 0.0f;
    float mLevelDecayCoeff = 0.0f;
    float mPeakHoldDecayCoeff = 0.0f;
};
