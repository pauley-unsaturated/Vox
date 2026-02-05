//
//  VoxExtensionParameterAddresses.h
//  VoxExtension
//
//  Parameter addresses for Vox Pulsar Synthesizer
//

#pragma once

#include <AudioToolbox/AUParameters.h>

typedef NS_ENUM(AUParameterAddress, VoxExtensionParameterAddress) {
    // Master Section
    masterVolume = 0,
    
    // Pulsar Oscillator Section
    pulsaretShape = 10,      // 0=Gaussian, 1=RaisedCosine, 2=Sine, 3=Triangle
    dutyCycle = 11,          // 0.01 to 1.0 (pulsaret width / period)
    
    // Formant Filter Section
    vowelMorph = 20,         // 0.0 to 1.0 (A-E-I-O-U)
    formant1Freq = 21,       // Hz (100-4000)
    formant2Freq = 22,       // Hz (100-4000)
    formant1Q = 23,          // Q factor (1-30)
    formant2Q = 24,          // Q factor (1-30)
    formantMix = 25,         // 0.0 (dry) to 1.0 (full formant)
    useVowelMorph = 26,      // Boolean: use morph or manual formants
    
    // Amp Envelope
    ampAttack = 30,          // milliseconds
    ampDecay = 31,           // milliseconds
    ampSustain = 32,         // percent (0-100)
    ampRelease = 33,         // milliseconds
    
    // Performance
    glideEnabled = 40,       // Boolean
    glideTime = 41,          // milliseconds
    pitchBendRange = 42,     // semitones (1-24)
    
    // Oscillator Section
    osc1Level = 50,          // 0.0 to 1.0
    osc2Level = 51,          // 0.0 to 1.0
    subOscLevel = 52,        // 0.0 to 1.0
    noiseLevel = 53,         // 0.0 to 1.0
    osc1Waveform = 54,       // 0=Saw, 1=Square, 2=Triangle, 3=Sine
    osc2Waveform = 55,       // 0=Saw, 1=Square, 2=Triangle, 3=Sine
    osc2Detune = 56,         // cents (-100 to +100)
    pulseWidth = 57,         // 0.0 to 1.0
    
    // LFO Section
    lfoRate = 60,            // Hz (0.1 to 50)
    lfoWaveform = 61,        // 0=Sine, 1=Triangle, 2=Saw, 3=Square, 4=S&H
    lfoPitchAmount = 62,     // semitones (0 to 12)
    lfoFilterAmount = 63,    // 0.0 to 1.0
    lfoPWMAmount = 64,       // 0.0 to 1.0
    lfoSyncMode = 65,        // 0=Free, 1=TempoSync
    lfoTempoRate = 66,       // Beat division index
    lfoRetrigger = 67,       // 0=Free, 1=NoteOn, 2=Beat
    lfoPhase = 68,           // 0.0 to 1.0
    lfoDelay = 69,           // seconds
    
    // Filter Section
    lpFilterCutoff = 70,     // normalized 0.0 to 1.0
    lpFilterResonance = 71,  // 0.0 to 1.0
    lpFilterKeyTracking = 72,// 0.0 to 1.0
    lpFilterEnvelopeAmount = 73, // 0.0 to 1.0
    lpFilterVelocityAmount = 74, // 0.0 to 1.0
    
    // Filter Envelope
    filterAttack = 80,       // milliseconds
    filterDecay = 81,        // milliseconds
    filterSustain = 82,      // percent (0-100)
    filterRelease = 83,      // milliseconds
};
