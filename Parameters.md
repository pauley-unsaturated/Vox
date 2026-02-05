# Vox Synthesizer Parameters

This document catalogs all parameters in the Vox synthesizer, organized by scope and functionality to aid in UI design and modulation routing decisions.

## Parameter Scoping

### Global Parameters (Plugin-wide)
Parameters that affect the overall plugin behavior, not per-voice:

**Master Section:**
- `masterVolume` (Linear Gain): Master output volume (0.0-1.0, default: 0.5)

### Voice Parameters (Per-note)
Parameters that affect individual notes/voices in the synthesizer:

## Sound Generation Parameters

### Oscillator 1 Section
- `osc1Waveform` (Indexed): Waveform selection (0-3: Sine, Saw, Square, Triangle, default: 0)
- `osc1Level` (Linear Gain): Oscillator mix level (0.0-1.0, default: 0.8)
- `osc1PulseWidth` (Percent): Pulse width for square wave (0-100%, default: 50%)
- `osc1Detune` (Cents): Fine tuning adjustment (-1200 to +1200 cents, default: 0)

### Oscillator 2 Section  
- `osc2Waveform` (Indexed): Waveform selection (0-3: Sine, Saw, Square, Triangle, default: 1)
- `osc2Level` (Linear Gain): Oscillator mix level (0.0-1.0, default: 0.0 - off by default)
- `osc2PulseWidth` (Percent): Pulse width for square wave (0-100%, default: 50%)
- `osc2Detune` (Cents): Fine tuning adjustment (-1200 to +1200 cents, default: -7)
- `osc2Sync` (Boolean): Hard sync to Oscillator 1 (0/1, default: 0)

### Mixer Section
- `subOscLevel` (Linear Gain): Sub-oscillator level (0.0-1.0, default: 0.0)
- `noiseLevel` (Linear Gain): Noise generator level (0.0-1.0, default: 0.0)

### Filter Section
- `filterCutoff` (Hertz): Low-pass cutoff frequency (20-20000 Hz, default: 1000)
- `filterResonance` (Percent): Filter resonance/Q (0-95%, default: 30%)
- `filterKeyboardTracking` (Percent): Cutoff keyboard tracking amount (0-100%, default: 0%)

## Modulation Parameters

### Amp Envelope (Controls overall amplitude)
- `ampAttack` (Seconds): Attack time (0.001-2.0s, default: 0.01s)
- `ampDecay` (Seconds): Decay time (0.001-2.0s, default: 0.1s)
- `ampSustain` (Percent): Sustain level (0-100%, default: 70%)
- `ampRelease` (Seconds): Release time (0.001-3.0s, default: 0.3s)

### Filter Envelope (Modulates filter cutoff)
- `filterAttack` (Seconds): Attack time (0.001-2.0s, default: 0.01s)
- `filterDecay` (Seconds): Decay time (0.001-2.0s, default: 0.1s)
- `filterSustain` (Percent): Sustain level (0-100%, default: 50%)
- `filterRelease` (Seconds): Release time (0.001-3.0s, default: 0.3s)
- `filterEnvAmount` (Percent): Envelope modulation depth (-100 to +100%, default: 0%)

### LFO Section (Low Frequency Oscillator)
**LFO Source Parameters:**
- `lfoRate` (Hertz): LFO frequency (0.1-20.0 Hz, default: 2.0)
- `lfoWaveform` (Indexed): LFO waveform (0-3: Sine, Triangle, Square, Sample & Hold, default: 0)

**LFO Routing Parameters (Modulation Destinations):**
- `lfoAmount` (Percent): Generic LFO amount - currently maps to pitch modulation (0-100%, default: 0%)
- `lfoFilterAmount` (Percent): LFO modulation of filter cutoff (0-100%, default: 0%)
- `lfoOscAmount` (Percent): LFO modulation of oscillator pitch (0-100%, default: 0%)

## Modulation Architecture Analysis

### Current Modulation Sources:
1. **Amp Envelope** → Amplitude (hardwired)
2. **Filter Envelope** → Filter Cutoff (amount controlled by `filterEnvAmount`)
3. **LFO** → Multiple destinations (controlled by individual amount parameters)
4. **Keyboard Tracking** → Filter Cutoff (amount controlled by `filterKeyboardTracking`)

### Current Modulation Destinations:
1. **Amplitude** ← Amp Envelope (fixed routing)
2. **Filter Cutoff** ← Filter Envelope, LFO, Keyboard Tracking
3. **Oscillator Pitch** ← LFO

### SH-101/Pro-One Style Routing:
The current implementation follows classic analog synth conventions:
- **Fixed routing** for primary connections (Amp Env → Amplitude)
- **Amount controls** for secondary modulations rather than a matrix
- **Simple, predictable routing** that matches the workflow of classic instruments

### Recommendations for UI Design:
1. **Group related parameters** (Osc1, Osc2, Filter, etc.) into logical sections
2. **Show modulation visually** - highlight parameters being modulated by LFO or envelopes
3. **Amount controls** should be near their destinations (e.g., Filter Env Amount near filter section)
4. **Keep it simple** - avoid complex routing matrices in favor of dedicated amount controls
5. **Visual feedback** for envelope shapes and LFO waveforms would be valuable

## Missing Modulation Capabilities:
Potential additions for enhanced expressiveness:
- LFO → Pulse Width modulation
- LFO → Amplitude modulation (tremolo)
- Filter Envelope → Oscillator Pitch (for percussive sounds)
- Velocity sensitivity for various parameters