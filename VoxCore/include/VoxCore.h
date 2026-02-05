//
//  VoxCore.h
//  VoxCore
//
//  Vox Pulsar Synthesis DSP Library
//  Based on Curtis Roads' Microsound techniques
//
//  Signal flow: MIDI → Pitch/Glide → PulsarOscillator → FormantFilter → ADSR → Out
//

#ifndef VoxCore_h
#define VoxCore_h

// ═══════════════════════════════════════════════════════════════════════════
// CORE VOX PULSAR SYNTHESIS COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

// The heart of pulsar synthesis - generates periodic trains of pulsarets
#include "PulsarOscillator.h"

// Vowel shaping filter with dual F1/F2 resonances
#include "FormantFilter.h"

// Amplitude envelope
#include "ADSREnvelope.h"

// Complete pulsar synthesis voice
#include "VoxVoice.h"

// Polyphonic voice management
#include "VoiceAllocator.h"
#include "VoicePool.h"

// ═══════════════════════════════════════════════════════════════════════════
// SUPPORTING COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

// Base oscillator class
#include "Oscillator.h"

// Simple sine oscillator (for LFO use)
#include "SinOscillator.h"

// Low frequency oscillator for modulation
#include "LFO.h"

// Phase 4: Global Modulation Sources
#include "GlobalLFO.h"
#include "DriftGenerator.h"
#include "ChaosGenerator.h"
#include "FormantSequencer.h"
#include "GlobalModulation.h"

// Phase 5: Stochastic Cloud Engine
// StochasticDistribution.h is included by StochasticCloud.h
#include "StochasticCloud.h"

// Phase 6: Modulation Matrix
#include "ModulationMatrix.h"

// Utility functions
#include "DSPUtilities.h"

// ═══════════════════════════════════════════════════════════════════════════
// LEGACY STUBS (for build compatibility only - not used in Vox)
// ═══════════════════════════════════════════════════════════════════════════

#include "DPWOscillator.h"
#include "PolyBLEPOscillator.h"
#include "MoogLadderFilter.h"
#include "MonophonicVoice.h"
#include "Arpeggiator.h"
#include "StepSequencer.h"
#include "SyncablePhaseRamp.h"

#endif /* VoxCore_h */
