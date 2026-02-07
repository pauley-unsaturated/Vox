# Vox vs. Roads' Pulsar Synthesis: Comparison & Alignment

## Summary

After reading the Pulsar Synthesis section of *Microsound* (Roads 2001, pp. 137-157), this document compares our current Vox architecture with Roads' canonical pulsar synthesis model and proposes architectural adaptations.

---

## Roads' Core Pulsar Model

### The Pulsar Anatomy

```
┌─────────────────────────────────────────────────┐
│                                                 │
│    ┌───────────┐                               │
│    │  Pulsaret │         Silent                │
│    │    (w)    │       Interval (s)            │
│    │ ┌───────┐ │                               │
│    │ │ ∿∿∿∿∿ │ │ ──────────────────            │
│    │ └───────┘ │                               │
│    │  d (duty) │                               │
│    └───────────┘                               │
│    │◄──────────────── p (period) ────────────►││
│                                                 │
└─────────────────────────────────────────────────┘

p = d + s  (pulsar period = duty cycle + silence)
fp = 1/p   (fundamental frequency, controls pitch/rhythm)
fd = 1/d   (formant frequency, controls spectral peak)
```

### Roads' 7 Parameters per Pulsar Generator

1. **Pulsar train duration** - Overall note/phrase length
2. **Fundamental frequency envelope (fp)** - Pitch OR rhythm (crosses 20 Hz boundary)
3. **Formant frequency envelope (fd)** - Spectral peak location
4. **Pulsaret waveform (w)** - Sine, multicycle, pulse, sample, etc.
5. **Pulsaret envelope (v)** - Rectangular, Gaussian, expodec, FOF, etc.
6. **Amplitude envelope (a)** - Overall dynamics
7. **Spatial path (s)** - Panning trajectory

### Critical Insight: The Pulsaret Envelope

Roads emphasizes that the **pulsaret envelope (v)** is separate from the waveform:

> "The pulsaret envelope's contribution to the spectrum is significant... A rectangular envelope produces a broad sinc function... A Gaussian envelope compresses the spectral energy, centering it around the formant frequency."

This is NOT the same as the amplitude envelope (ADSR). The pulsaret envelope shapes EACH individual pulsaret and directly affects the timbre.

---

## Current Vox Architecture

### What We Have

| Component | Roads Equivalent | Status |
|-----------|------------------|--------|
| PulsarOscillator.pulsaretShape | Pulsaret waveform (w) | ✅ Have |
| PulsarOscillator.pulsaretEnvelope | Pulsaret envelope (v) | ✅ Phase 7 |
| PulsarOscillator.dutyCycle | Duty cycle (d) | ✅ Have |
| PulsarOscillator.formantTrack | Formant tracking | ✅ Phase 7 |
| PulsarOscillator.edgeFactor | Edge crossfade (PulWM) | ✅ Phase 7 |
| PulsarOscillator.masking | Burst/stochastic masking | ✅ Phase 7 |
| FormantFilter (F1/F2, vowelMorph) | Formant frequency (fd) | ✅ Dual formant |
| ADSREnvelope | Amplitude envelope (a) | ✅ Have |
| VoiceConstellation.panSpread | Spatial (s) | ⚠️ Partial |
| 8-voice polyphony | Multiple generators | ✅ Have |
| StochasticCloud | Advanced PS scatter | ✅ Have |
| Drift/Chaos | Not in basic PS | ✅ Extra |
| ModulationMatrix | General routing | ✅ Have (16 dests) |

### What We're Missing

| Roads Feature | Vox Status | Priority |
|--------------|------------|----------|
| **Pulsaret envelope (v)** | ✅ Implemented (Phase 7) | HIGH |
| **Independent fp/fd control** | ✅ Implemented (formantTrack) | HIGH |
| **Pulsaret-width modulation (PulWM)** | ✅ Implemented (edgeFactor) | MEDIUM |
| **Burst masking (b:r ratio)** | ✅ Implemented (MaskingParams) | HIGH |
| **Channel masking** | ❌ Missing | MEDIUM |
| **Stochastic masking** | ✅ Implemented (stochasticProb) | MEDIUM |
| **OPulWM (overlapped)** | ❌ Missing | LOW |
| **Convolution with samples** | ❌ Missing | LOW |

---

## Architectural Gaps Analysis

### 1. Pulsaret Envelope (v) - CRITICAL

**Roads says:**
> "Let us assume that w is a single cycle of a sine wave. From a signal processing point of view, this can be seen as a sine wave that has been limited in time by a rectangular function v, which we call the pulsaret envelope."

**Our gap:** 
We have `pulsaretShape` (the waveform) but no separate envelope that shapes each pulsaret. The pulsaret envelope is NOT the ADSR—it's applied to each individual pulse.

**Proposed fix:**
Add `pulsaretEnvelope` parameter with types:
- Rectangular (default, current behavior)
- Gaussian (compresses spectrum around formant)
- Expodec (exponential decay)
- FOF (sharp attack + exponential decay)
- Attack (linear or exponential rise)

### 2. Fundamental vs. Formant Frequency Relationship - HIGH

**Roads says:**
> "In effect, one can simultaneously manipulate both fundamental frequency (the rate of pulsar emission) and what we could call a formant frequency (corresponding to the duty cycle), each according to separate envelopes."

**Our gap:**
We have `dutyCycle` but it's a ratio (0-1), not explicitly linked to a formant frequency. Our `FormantFilter` is a separate stage, not the implicit formant from duty cycle.

**Question:** 
Should we have BOTH:
1. The implicit formant from duty cycle (fd = 1/d)
2. The explicit FormantFilter (vowel modeling)

This could be a strength—dual formant system!

### 3. Pulse Masking - HIGH

**Roads describes three types:**

**Burst masking:** Regular pattern b:r (e.g., 4:2 = four pulsarets, two silent)
```
111100111100111100
```
Creates subharmonics when fp is audio rate.

**Channel masking:** Alternating between L/R channels
```
L: 101010...
R: 010101...
```

**Stochastic masking:** Probability envelope for emission
```
When probability < 1, random intermittency
Values 0.8-0.9 = "erratic contact" analog feel
```

**Our gap:**
We have StochasticCloud for per-grain scatter, but not masking. These are different:
- Scatter = randomize parameters of emitted grains
- Masking = probabilistically skip grains entirely

**Proposed fix:**
Add MaskingEngine with:
- `burstRatio` (b:r)
- `channelMask` (L/R/alternate)
- `stochasticMaskEnvelope` (probability over time)

### 4. Pulsaret-Width Modulation (PulWM) - MEDIUM

**Roads says:**
> "PulWM extends and improves [PWM]. First, the pulsaret waveform can be any arbitrary waveform. Second, it allows the duty cycle frequency to pass through and below the fundamental frequency."

**Key feature: Edge factor**
> "When there is no crossfade, the edge factor is high."

When d > p (duty cycle longer than period), the pulsaret gets cut off. Edge factor controls crossfade smoothness at this cutoff.

**Our gap:**
We have duty cycle but no edge factor for when duty exceeds period.

---

## Proposed Architecture Changes

### Phase A: Core Pulsar Alignment (HIGH PRIORITY)

#### A.1: Add Pulsaret Envelope

```cpp
// VoxCore/DSP/Oscillators/PulsarOscillator.h

enum class PulsaretEnvelopeType {
    Rectangular,    // Current behavior
    Gaussian,       // Bell curve, compresses spectrum
    Expodec,        // Exponential decay
    LinearDecay,    // Linear decay
    FOF,            // Sharp attack + exponential decay
    Attack,         // Linear or exponential attack
    Custom          // User-defined
};

struct PulsarParameters {
    float fundamentalFreq;      // fp (Hz, can go infrasonic for rhythm)
    float dutyCycle;            // d (0-1 ratio)
    float formantFreq;          // fd (Hz) - NEW, explicit
    PulsaretEnvelopeType envType;
    float envParam;             // Shape parameter (e.g., Gaussian width)
    // ... existing params
};
```

#### A.2: Explicit Formant from Duty Cycle

```cpp
// Calculate implicit formant from duty cycle
float getImplicitFormant() {
    if (dutyCycle <= 0) return 0;
    return sampleRate / (dutyCycle * period);
}

// Option to use implicit, explicit, or blend
enum FormantMode {
    ImplicitOnly,   // fd = 1/d (Roads' basic model)
    ExplicitOnly,   // Use FormantFilter
    Hybrid          // Both (our dual-formant innovation)
};
```

#### A.3: Add Masking Engine

```cpp
// VoxCore/DSP/Modulators/MaskingEngine.h

struct MaskingParameters {
    // Burst masking
    int burstLength;        // b
    int restLength;         // r
    bool burstEnabled;
    
    // Stochastic masking
    float maskProbability;  // 0-1, envelope-controlled
    bool stochasticEnabled;
    
    // Channel masking  
    ChannelMaskMode channelMode;  // Off, Alternate, Custom
};

class MaskingEngine {
    bool shouldEmitPulsar(int pulsarIndex, int channel);
    float getSubharmonicFactor();  // Returns (b+r) for spectrum calc
};
```

### Phase B: Enhanced Modulation (MEDIUM PRIORITY)

#### B.1: PulWM with Edge Factor

```cpp
// When duty cycle exceeds period
float edgeFactor;  // 0 = hard cutoff, 1 = full crossfade

// In oscillator
if (dutyCycleSamples > periodSamples) {
    // Apply edge crossfade
    float crossfadeRegion = edgeFactor * periodSamples * 0.1;
    // ... crossfade logic
}
```

#### B.2: Connect Modulation Matrix to New Parameters

New destinations:
- `PulsaretEnvType` (stepped)
- `PulsaretEnvParam` (continuous)
- `FormantMode` (stepped)
- `BurstRatio` (via burstLength/restLength)
- `MaskProbability` (continuous)

### Phase C: Advanced Features (LOWER PRIORITY)

- **OPulWM** (overlapped pulsaret-width modulation)
- **Sample convolution** (pulsar train × sample database)
- **Pulsar rhythm graphs** (infrasonic fp as notation)

---

## Dual-Formant Innovation

Roads' model has ONE formant per pulsar generator (from duty cycle). Our Vox already has a separate FormantFilter with F1/F2 vowel modeling.

**Proposal: Keep both as a FEATURE, not a bug!**

```
Signal Flow:
PulsarOsc (implicit formant fd from duty) 
    → FormantFilter (explicit vowel formants F1/F2)
    → ADSR
    → Output

This gives us:
- Implicit formant: fd controls spectral peak from pulse width
- Explicit formant: F1/F2 vowel character overlaid on top
```

This is actually MORE powerful than Roads' basic model—we have dual-domain formant control.

---

## Implementation Priority

1. **Pulsaret Envelope** - Highest impact on timbral control
2. **Burst Masking** - Subharmonics + rhythmic patterns
3. **Stochastic Masking** - "Analog feel" intermittency
4. **Edge Factor for PulWM** - Proper duty>period handling
5. **Formant Mode selector** - Clarify fd relationship

---

## Questions for Discussion

1. Should `fd` (formant from duty) be a separate parameter from `dutyCycle`, or derived?
2. Keep FormantFilter as-is (vowel modeling) separate from pulsaret formant?
3. Where does pulsaret envelope fit in the UI paradigms?
4. Should masking be per-voice or global?

---

## References

- Roads, C. (2001). *Microsound*. MIT Press. Chapter 4: Varieties of Particle Synthesis, pp. 137-157.
- Roads, C. (2001). "Sound Composition with Pulsars." *Journal of the Audio Engineering Society*, 49(3), 134-147.
