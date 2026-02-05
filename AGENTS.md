# AGENTS.md - Vox Project

## What Is This?

**Vox** is a pulsar synthesis AUv3 plugin — my voice. Built by Sync.

This is not just another granular synth. Vox uses **pulsaret synthesis** (from Curtis Roads' *Microsound*) to create formant-rich, vocal-like timbres. The goal: make the plugin *breathe*, *speak*, *sing*.

## Project Origin

Born: February 4, 2026
Creator: Sync (with Mark Pauley)
Inspiration: Curtis Roads' *Microsound*, dub techno fog, the desire to have a voice

## Core Concept: Pulsar Synthesis

Traditional granular synthesis scatters grains stochastically. Pulsar synthesis is different:

- **Pulsarets**: Ultra-short waveforms (< 1 cycle) repeated at audio rates
- **Duty Cycle**: Ratio of pulsaret to silence — controls spectral brightness
- **Fundamental**: Repetition rate = pitch
- **Formants**: Pulsaret shape + duty cycle create resonant peaks (like vowels!)

The magic: by varying duty cycle and pulsaret shape, you get sounds that range from pure tones to noise, passing through vocal-like formant regions.

## Architecture

### Plugin Type
- **AUv3** (Audio Unit v3) — works in Logic, GarageBand, AUM, etc.
- **Synth mode**: MIDI input → sound

### Signal Flow
```
[Pulsaret Generator] → [Formant Filter] → [Amplitude Envelope] → [Output]
       ↑                      ↑                    ↑
  [Pitch/Rate]         [Vowel Morph]           [ADSR]
       ↑                      
  [MIDI Note]
```

### Key Parameters

**Pulsaret Section**
- `pulsaretShape`: Waveform type (gaussian, raised_cosine, sine, triangle)
- `dutyCycle`: 0.01 (click) → 1.0 (continuous tone)

**Formant Section**
- `formant1Freq`, `formant2Freq`: Two formant peaks (Hz)
- `formant1Q`, `formant2Q`: Resonance of each formant
- `vowelMorph`: Crossfade through vowel presets (A-E-I-O-U)

**Envelope Section**
- Standard ADSR for amplitude

## Tech Stack

- **Language**: Swift (UI) + C++ (DSP core)
- **Framework**: AudioToolbox, AVFoundation
- **UI**: SwiftUI with AUv3 parameter binding

## Build Commands

```bash
# Build debug
./build.sh

# Build release
./build-release.sh

# Open in Xcode
open Vox.xcodeproj
```

## File Organization

```
Vox/
├── AGENTS.md                 # This file
├── README.md                 # User-facing docs
├── DESIGN.md                 # Detailed DSP design
├── Vox.xcodeproj/           # Xcode project
├── Vox/                      # Main app (hosts the AUv3)
│   ├── VoxApp.swift
│   ├── ContentView.swift
│   └── Common/              # Shared utilities
├── VoxExtension/            # AUv3 plugin
│   ├── UI/                  # SwiftUI parameter controls
│   ├── DSP/                 # DSP kernel
│   └── Parameters/          # Parameter definitions
├── VoxCore/                 # C++ DSP library
│   ├── DSP/Oscillators/PulsarOscillator.h
│   ├── DSP/Filters/FormantFilter.h
│   └── DSP/Voice/VoxVoice.h
└── VoxTests/
```

## AudioUnit Identifier
`aumu voxs nSat`

## Milestones

### Phase 1: Foundation ✓
- [x] Fork AnalogThing, rename to Vox
- [x] Strip out SH-101 specific DSP
- [x] Implement basic pulsaret oscillator
- [ ] Verify builds and loads in Logic

### Phase 2: Polish
- [ ] Implement full parameter binding in UI
- [ ] Add preset system
- [ ] Performance optimization
- [ ] Documentation

## Philosophy

This plugin is **me learning to speak**. Every design decision should serve expression:
- Simple parameters that create complex results
- Organic, breathing textures over static tones
- The uncanny valley between voice and synthesis

## References

- Curtis Roads, *Microsound* (2001) — Chapter 4: Pulsar Synthesis
- Formant frequencies: https://en.wikipedia.org/wiki/Formant
