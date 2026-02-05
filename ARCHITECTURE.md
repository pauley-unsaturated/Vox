# Vox Architecture Plan
## Final — February 4, 2026

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────────┐
│  VOX — Pulsar Voice Synthesizer                                 │
├─────────────────────────────────────────────────────────────────┤
│  Type: Monophonic AUv3 Instrument + FX                          │
│  Voices: 1 (expressive mono)                                    │
│  Parameters: 20                                                  │
│  MIDI: Note, Velocity, Mod Wheel, Aftertouch, Pitch Bend        │
│  Engine: Pulsaret synthesis → Formant filter → ADSR             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Identity

**Vox is a monophonic voice instrument.**

One vocal cord. One mouth. Infinite expression.

| What Vox Is | What Vox Isn't |
|-------------|----------------|
| Expressive lead synth | Pad/chord machine |
| Vocal texture generator | Sample playback |
| Reactive FX processor | Static oscillator |
| Learning instrument | Complex modular |

---

## Signal Flow

```
MIDI Note ─────────────────────────────────────────────────────────────┐
                                                                       │
          ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐│
          │  PITCH   │    │  PULSAR  │    │ FORMANT  │    │   VCA    ││
          │  + GLIDE │───►│  ENGINE  │───►│  SHAPER  │───►│   ADSR   │├──► OUT
          └──────────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘│
                               │               │               │      │
                               │               │               │      │
                          ┌────┴───────────────┴───────────────┴────┐ │
                          │            MODULATION                   │ │
                          │  LFO → duty, vowel, pitch               │ │
                          │  Velocity → env depth, formant Q        │ │
                          │  Env Follower → duty (FX mode)          │ │
                          └─────────────────────────────────────────┘ │
                                             ▲                        │
                                             │                        │
Audio In (sidechain) ────────────────────────┘                        │
                                                                      │
Gate + Velocity ──────────────────────────────────────────────────────┘
```

---

## MIDI Implementation

| Input | Target | Range | Notes |
|-------|--------|-------|-------|
| Note On | Pitch + Gate | C-1 to G9 | Triggers envelope |
| Note Off | Gate release | — | Enters release phase |
| Velocity | Env depth + Formant Q | 1-127 | Harder = brighter |
| Pitch Bend | Pitch | ±12 semi | Configurable range |
| Mod Wheel (CC1) | Vowel morph | 0-127 | A→U sweep |
| Aftertouch | Duty cycle | 0-127 | Press = brighter |
| CC74 | Air filter | 0-127 | Standard brightness |

### Glide Behavior
- **Legato:** New note while holding = glide to new pitch
- **Retrigger:** New note after release = snap to pitch + retrigger env
- **Glide time:** 0ms (instant) to 2000ms (slow portamento)

---

## Parameters (20 Total)

### Group 1: Pulsar Engine (4 params)

| ID | Name | Range | Default | Unit | Purpose |
|----|------|-------|---------|------|---------|
| `shape` | Shape | 0-3 | 0 | enum | Pulsaret waveform |
| `duty` | Duty Cycle | 1-100 | 15 | % | Harmonic brightness |
| `fine` | Fine Tune | -100 to +100 | 0 | cents | Pitch adjustment |
| `glide` | Glide | 0-2000 | 50 | ms | Portamento time |

**Shape values:** 0=Gaussian, 1=RaisedCos, 2=Sine, 3=Triangle

### Group 2: Formant Shaper (3 params)

| ID | Name | Range | Default | Unit | Purpose |
|----|------|-------|---------|------|---------|
| `vowel` | Vowel | 0-100 | 50 | % | A-E-I-O-U morph |
| `formantQ` | Resonance | 1-30 | 12 | Q | Formant sharpness |
| `air` | Air | 0-100 | 50 | % | High rolloff (darker) |

### Group 3: Envelope (5 params)

| ID | Name | Range | Default | Unit | Purpose |
|----|------|-------|---------|------|---------|
| `attack` | Attack | 1-4000 | 10 | ms | — |
| `decay` | Decay | 1-4000 | 150 | ms | — |
| `sustain` | Sustain | 0-100 | 70 | % | — |
| `release` | Release | 1-8000 | 400 | ms | — |
| `velSens` | Velocity | 0-100 | 50 | % | Velocity sensitivity |

### Group 4: Modulation (5 params)

| ID | Name | Range | Default | Unit | Purpose |
|----|------|-------|---------|------|---------|
| `lfoRate` | LFO Rate | 0.01-50 | 2.0 | Hz | Modulation speed |
| `lfoShape` | LFO Shape | 0-3 | 0 | enum | Waveform |
| `lfoDuty` | → Duty | -100 to +100 | 0 | % | LFO to duty amount |
| `lfoVowel` | → Vowel | -100 to +100 | 0 | % | LFO to vowel amount |
| `lfoPitch` | → Pitch | -100 to +100 | 0 | % | Vibrato depth |

**LFO Shape values:** 0=Sine, 1=Triangle, 2=Saw, 3=Square

### Group 5: Output (3 params)

| ID | Name | Range | Default | Unit | Purpose |
|----|------|-------|---------|------|---------|
| `gain` | Gain | -60 to +6 | 0 | dB | Output level |
| `fxMode` | FX Mode | 0/1 | 0 | bool | Enable env follower |
| `fxAmount` | FX Amount | 0-100 | 50 | % | Env follower depth |

---

## DSP Specifications

### Pulsaret Oscillator

```
Output(t) = {
    Pulsaret(phase / dutyCycle)  if phase < dutyCycle
    0                            if phase >= dutyCycle
}

phase += frequency / sampleRate
if (phase >= 1.0) phase -= 1.0
```

**Pulsaret functions:**
- Gaussian: `exp(-((x-0.5)² / (2 * 0.15²)))`
- Raised Cosine: `0.5 * (1 - cos(2π * x))`
- Sine: `sin(π * x)`
- Triangle: `1 - abs(2*x - 1)`

Where `x` = normalized position within pulsaret (0 to 1)

### Formant Filter

Two parallel state-variable bandpass filters:

```
F1: center = vowelF1[morph], Q = formantQ
F2: center = vowelF2[morph], Q = formantQ

output = (F1(input) + F2(input)) * 0.5 * wetMix + input * (1 - wetMix)
```

**Vowel table (Hz):**
| Morph | Vowel | F1 | F2 |
|-------|-------|-----|-----|
| 0.00 | A (ah) | 800 | 1200 |
| 0.25 | E (eh) | 400 | 2000 |
| 0.50 | I (ee) | 300 | 2500 |
| 0.75 | O (oh) | 500 | 800 |
| 1.00 | U (oo) | 350 | 700 |

Interpolate linearly between adjacent vowels.

### Air Filter

One-pole lowpass: `y[n] = y[n-1] + air * (x[n] - y[n-1])`

Where `air` = 0 (full brightness) to 1 (full darkness)

Actual cutoff: `20000 * (1 - air*0.9)` Hz (never fully closes)

### Envelope Follower (FX Mode)

```
envelope = max(envelope * release, abs(input))
modulation = envelope * fxAmount
duty_modulated = duty + modulation * (1 - duty)  // Opens up with input
```

Release time ~50ms for responsive tracking.

---

## Technical Decisions

| Aspect | Choice | Rationale |
|--------|--------|-----------|
| Sample rate | 44.1/48/96kHz | Standard AU rates |
| Internal rate | 2x oversample | Anti-alias low duty cycles |
| Block size | 64-4096 | Standard AU buffers |
| Pulsaret table | 2048 samples | Smooth interpolation |
| Filter type | SVF (state-variable) | Stable, modulatable |
| Parameter smooth | 10ms | Avoid zipper noise |

---

## Edge Cases

| Situation | Behavior |
|-----------|----------|
| Pitch < 20Hz | **Clamped to 20Hz** (use LFO for rhythm) |
| Pitch > 5kHz | Risk of aliasing; oversample helps |
| Duty = 100% | Continuous tone (no silence) |
| Duty = 1% | Near-impulse train (very bright) |
| Vowel morph sweep | Smooth F1/F2 interpolation |
| FX mode + no input | Envelope follower = 0, duty = base value |

---

## Implementation Phases

### Phase 1: MVP Sound ⏱️ ~4 hours
- [ ] Project scaffold (clone from AnalogThing)
- [ ] Pulsaret oscillator (one shape first: Gaussian)
- [ ] MIDI note → frequency
- [ ] Basic ADSR
- [ ] Verify AU loads in Logic

### Phase 2: Full Engine ⏱️ ~4 hours
- [ ] All 4 pulsaret shapes
- [ ] Duty cycle with parameter smoothing
- [ ] Glide/portamento
- [ ] Fine tune

### Phase 3: Formants ⏱️ ~3 hours
- [ ] SVF bandpass filter
- [ ] Vowel table + interpolation
- [ ] Vowel morph parameter
- [ ] Air filter

### Phase 4: Modulation ⏱️ ~3 hours
- [ ] LFO (4 shapes)
- [ ] Mod routing (duty, vowel, pitch)
- [ ] Velocity sensitivity
- [ ] MIDI CC mapping

### Phase 5: FX Mode ⏱️ ~2 hours
- [ ] Sidechain input
- [ ] Envelope follower
- [ ] FX → duty routing

### Phase 6: UI + Polish ⏱️ ~4 hours
- [ ] SwiftUI parameter sections
- [ ] Visual feedback (LFO indicator, envelope shape)
- [ ] Preset system
- [ ] Documentation

**Total estimate: ~20 hours** (spread across sessions)

---

## Testing Checklist

- [ ] AU validates (`auval -v aumu Vox SYNC`)
- [ ] Loads in Logic Pro
- [ ] Loads in GarageBand
- [ ] MIDI notes trigger sound
- [ ] All parameters respond
- [ ] No CPU spikes at low buffer sizes
- [ ] No aliasing artifacts audible
- [ ] Preset save/load works

---

## File Structure

```
~/Programs/Vox/
├── AGENTS.md              # Project overview
├── ARCHITECTURE.md        # This file
├── DESIGN.md              # DSP theory
├── README.md              # User docs
├── Vox.xcodeproj/         # Xcode project
├── Vox/                   # Main app target
│   ├── VoxApp.swift
│   ├── ContentView.swift
│   └── Common/
├── VoxExtension/          # AU extension target
│   ├── DSP/               # C++ DSP (headers)
│   └── UI/                # SwiftUI controls
├── VoxCore/               # C++ DSP library
│   ├── PulsarOscillator.h/cpp
│   ├── FormantFilter.h/cpp
│   ├── Envelope.h/cpp
│   ├── LFO.h/cpp
│   └── VoxVoice.h/cpp     # Main voice class
├── Source/                # ObjC++ AU glue
│   └── AudioUnit/
│       ├── VoxAudioUnit.h/mm
│       └── VoxViewController.h/mm
├── Tests/
└── build.sh
```

---

## Decisions from Mark

1. **Pitch range:** ≥20Hz only. Rhythmic effects via LFO modulation, not sub-audio pitches. ✓
2. **MIDI learn:** Not needed — DAWs handle parameter automation. ✓
3. **Output:** Stereo (mono voice → stereo field). Multichannel-ready design for future Atmos/surround. ✓

## Open Questions

1. **Preset sharing:** iCloud sync, or just local? (Phase 6 decision)

---

*Architecture finalized. Ready for implementation.*
