#pragma once

#include <vector>
#include <atomic>
#include <AudioToolbox/AudioToolbox.h>
#include "../DSP/Voice/Voice.h"
#include "../DSP/Performance/Arpeggiator.h"

class VoxSynthDSPKernel {
public:
    VoxSynthDSPKernel() {}
    ~VoxSynthDSPKernel() {}
    
    void init(double sampleRate) {
        // Initialize DSP components
        _sampleRate = sampleRate;
        _voice = new Voice(static_cast<float>(_sampleRate));
        _arpeggiator = new Arpeggiator(static_cast<float>(_sampleRate));
        
        // Initialize parameters
        _oscMix = 0.5f;
        _filterCutoff = 1000.0f;
        _filterResonance = 0.1f;
        
        // Initialize MIDI state
        _currentNote = -1;
        _noteIsOn = false;
    }
    
    void reset() {
        // Reset DSP components
        if (_voice) {
            _voice->reset();
        }
        
        if (_arpeggiator) {
            _arpeggiator->reset();
        }
    }
    
    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
            case 0: // oscMix
                _oscMix = value;
                break;
            case 1: // filterCutoff
                _filterCutoff = value;
                break;
            case 2: // filterResonance
                _filterResonance = value;
                break;
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        switch (address) {
            case 0: // oscMix
                return _oscMix;
            case 1: // filterCutoff
                return _filterCutoff;
            case 2: // filterResonance
                return _filterResonance;
            default:
                return 0.0f;
        }
    }
    
    void setOscMix(float value) {
        _oscMix = value;
    }
    
    float getOscMix() {
        return _oscMix;
    }
    
    void setFilterCutoff(float value) {
        _filterCutoff = value;
        if (_voice) {
            // Update voice parameters as needed
        }
    }
    
    float getFilterCutoff() {
        return _filterCutoff;
    }
    
    void setFilterResonance(float value) {
        _filterResonance = value;
        if (_voice) {
            // Update voice parameters as needed
        }
    }
    
    float getFilterResonance() {
        return _filterResonance;
    }
    
    void handleMIDIEvent(AUMIDIEvent const& midiEvent) {
        const uint8_t status = midiEvent.data[0] & 0xF0;
        const uint8_t channel = midiEvent.data[0] & 0x0F;
        
        // Handle MIDI note events
        switch (status) {
            case 0x90: { // Note On
                const uint8_t note = midiEvent.data[1];
                const uint8_t velocity = midiEvent.data[2];
                
                if (velocity > 0) {
                    _currentNote = note;
                    _noteIsOn = true;
                    
                    if (_arpeggiator && _arpeggiator->isEnabled()) {
                        _arpeggiator->noteOn(note);
                    } else if (_voice) {
                        _voice->noteOn(note, velocity);
                    }
                } else {
                    // Note On with velocity 0 is treated as Note Off
                    handleNoteOff(note);
                }
                break;
            }
            case 0x80: { // Note Off
                const uint8_t note = midiEvent.data[1];
                handleNoteOff(note);
                break;
            }
            case 0xB0: { // Control Change
                const uint8_t controlNumber = midiEvent.data[1];
                const uint8_t controlValue = midiEvent.data[2];
                
                // Handle CC messages (to be implemented)
                break;
            }
        }
    }
    
    void handleNoteOff(uint8_t note) {
        if (_arpeggiator && _arpeggiator->isEnabled()) {
            _arpeggiator->noteOff(note);
        } else if (_voice && _currentNote == note) {
            _voice->noteOff();
            _noteIsOn = false;
        }
    }
    
    void process(const AudioTimeStamp* timestamp, AUAudioFrameCount frameCount, AudioBufferList* outputBufferList) {
        // Get pointers to output buffers
        float* outL = (float*)outputBufferList->mBuffers[0].mData;
        float* outR = (outputBufferList->mNumberBuffers > 1) ? (float*)outputBufferList->mBuffers[1].mData : nullptr;
        
        // Update parameters
        updateParameters();
        
        // Process arpeggiator if enabled
        if (_arpeggiator && _arpeggiator->isEnabled() && _voice) {
            processArpeggiator(frameCount, outL, outR);
        }
        // Otherwise process the voice directly
        else if (_voice) {
            processVoice(frameCount, outL, outR);
        }
        // If neither is available, output silence
        else {
            processSilence(frameCount, outL, outR);
        }
    }
    
private:
    void updateParameters() {
        // Update DSP components with current parameter values
        // (Implementation will depend on the specific needs of the voice and arpeggiator)
    }
    
    void processArpeggiator(AUAudioFrameCount frameCount, float* outL, float* outR) {
        for (AUAudioFrameCount i = 0; i < frameCount; ++i) {
            // Get next note from arpeggiator
            int nextNote = _arpeggiator->getNextNote();
            
            // If we got a valid note, trigger the voice
            if (nextNote != -1 && nextNote != _currentNote) {
                _voice->noteOn(nextNote, 100); // Default velocity
                _currentNote = nextNote;
            }
            
            // Process the voice
            float sample = _voice->process();
            
            // Write to output
            outL[i] = sample;
            if (outR) {
                outR[i] = sample;
            }
        }
    }
    
    void processVoice(AUAudioFrameCount frameCount, float* outL, float* outR) {
        for (AUAudioFrameCount i = 0; i < frameCount; ++i) {
            // Process a single sample
            float sample = _voice->process();
            
            // Write to output
            outL[i] = sample;
            if (outR) {
                outR[i] = sample;
            }
        }
    }
    
    void processSilence(AUAudioFrameCount frameCount, float* outL, float* outR) {
        // Output silence
        for (AUAudioFrameCount i = 0; i < frameCount; ++i) {
            outL[i] = 0.0f;
            if (outR) {
                outR[i] = 0.0f;
            }
        }
    }
    
    // DSP components
    Voice* _voice = nullptr;
    Arpeggiator* _arpeggiator = nullptr;
    
    // Parameters
    float _oscMix = 0.5f;
    float _filterCutoff = 1000.0f;
    float _filterResonance = 0.1f;
    
    // MIDI state
    int _currentNote = -1;
    bool _noteIsOn = false;
    
    // Audio settings
    double _sampleRate = 44100.0;
};