# Vox DSP Design Document

## Pulsar Synthesis Theory

### What is a Pulsaret?

A **pulsaret** is an ultra-short waveform, typically shorter than one period of the fundamental frequency. When repeated at audio rates, pulsarets create rich, evolving spectra.

```
Single Pulsaret:
    ╭──╮
   ╱    ╲
──╯      ╰──────────────────  (duty cycle ~20%)

Pulsar Train:
    ╭──╮        ╭──╮        ╭──╮
   ╱    ╲      ╱    ╲      ╱    ╲
──╯      ╰────╯      ╰────╯      ╰──
   |<-period->|
```

### Duty Cycle

The **duty cycle** (d) is the ratio of pulsaret duration to period:

```
d = pulsaret_duration / period
```

- `d = 0.01`: Click train (impulse-like, broadband)
- `d = 0.1-0.3`: Formant-rich (vocal quality)
- `d = 0.5`: Square-wave-like
- `d = 1.0`: Continuous tone (no silence between pulsarets)

**Key insight**: Duty cycle controls the bandwidth. Lower duty = more harmonics = brighter/noisier. This is how we get vocal-like formants!

### Pulsaret Shapes

Different pulsaret waveforms create different spectral envelopes:

1. **Gaussian**: Smooth, minimal sidebands (Roads' preferred)
2. **Raised Cosine**: Similar to Gaussian, easier to compute
3. **Sinc**: Band-limited, very clean
4. **Triangle**: Bright, buzzy
5. **Custom**: User-drawn or wavetable

## Implementation

### PulsarOscillator

```cpp
class PulsarOscillator {
public:
    // Core parameters
    float fundamentalHz;     // Pulsar repetition rate
    float dutyCycle;         // 0.01 to 1.0
    PulsaretShape shape;     // Waveform type
    
    // State
    float phase;             // 0.0 to 1.0 (within period)
    
    float process() {
        float output = 0.0f;
        
        // Only output during pulsaret portion
        if (phase < dutyCycle) {
            float pulsaretPhase = phase / dutyCycle;
            output = computePulsaret(pulsaretPhase, shape);
        }
        
        // Advance phase
        phase += fundamentalHz / sampleRate;
        if (phase >= 1.0f) phase -= 1.0f;
        
        return output;
    }
    
private:
    float computePulsaret(float t, PulsaretShape shape) {
        switch (shape) {
            case Gaussian:
                // Gaussian window: exp(-((t-0.5)^2) / (2 * sigma^2))
                return gaussianWindow(t, 0.2f);
            case RaisedCosine:
                // Hann window: 0.5 * (1 - cos(2*pi*t))
                return 0.5f * (1.0f - cosf(2.0f * M_PI * t));
            case Sine:
                return sinf(M_PI * t);  // Half sine
            // ... etc
        }
    }
};
```

### FormantFilter

Formants are resonant peaks in the spectrum, characteristic of vowel sounds:

| Vowel | F1 (Hz) | F2 (Hz) |
|-------|---------|---------|
| A (ah)| 800     | 1200    |
| E (eh)| 400     | 2000    |
| I (ee)| 300     | 2500    |
| O (oh)| 500     | 800     |
| U (oo)| 350     | 700     |

Implementation: Two parallel resonant bandpass filters, mixed with dry signal.

```cpp
class FormantFilter {
public:
    ResonantBPF formant1;
    ResonantBPF formant2;
    float formant1Gain;
    float formant2Gain;
    float dryGain;
    
    float process(float input) {
        float f1 = formant1.process(input) * formant1Gain;
        float f2 = formant2.process(input) * formant2Gain;
        float dry = input * dryGain;
        return f1 + f2 + dry;
    }
};
```

### Vowel Morphing

Smooth interpolation through vowel space using a single parameter (0.0 to 1.0):

```cpp
struct VowelPreset {
    float f1Freq, f2Freq;
    float f1Q, f2Q;
};

VowelPreset vowels[5] = {
    {800, 1200, 10, 10},   // A
    {400, 2000, 12, 8},    // E
    {300, 2500, 15, 7},    // I
    {500, 800, 10, 12},    // O
    {350, 700, 12, 14},    // U
};

void setVowelMorph(float morph) {
    // morph: 0.0 = A, 0.25 = E, 0.5 = I, 0.75 = O, 1.0 = U
    int idx = (int)(morph * 4);
    float frac = (morph * 4) - idx;
    
    // Interpolate between adjacent vowels
    VowelPreset& v1 = vowels[idx];
    VowelPreset& v2 = vowels[min(idx + 1, 4)];
    
    formant1.setFrequency(lerp(v1.f1Freq, v2.f1Freq, frac));
    formant2.setFrequency(lerp(v1.f2Freq, v2.f2Freq, frac));
    // ... etc
}
```

## Signal Flow Diagram

```
                          ┌─────────────┐
         MIDI Note ──────►│   Pitch     │
                          │  (Hz/Note)  │
                          └──────┬──────┘
                                 │
                                 ▼
┌─────────────┐           ┌─────────────┐           ┌─────────────┐
│  Pulsaret   │           │   Pulsar    │           │   Formant   │
│   Shape     │──────────►│ Oscillator  │──────────►│   Filter    │
│  Selector   │           │             │           │             │
└─────────────┘           └──────┬──────┘           └──────┬──────┘
                                 ▲                         │
                                 │                         │
┌─────────────┐           ┌──────┴──────┐                  │
│ Duty Cycle  │──────────►│             │                  │
│  Control    │           │             │                  │
└─────────────┘           │             │                  │
       ▲                  │   LFO /     │                  ▼
       │                  │   Mod       │           ┌─────────────┐
       │                  │   Matrix    │           │    ADSR     │
┌──────┴──────┐           │             │──────────►│  Envelope   │
│  Envelope   │           │             │           │             │
│  Follower   │◄──────────┤             │           └──────┬──────┘
│ (FX mode)   │           └─────────────┘                  │
└─────────────┘                                            │
       ▲                                                   ▼
       │                                            ┌─────────────┐
  Audio Input                                       │   Output    │
  (FX mode)                                         │   Gain      │
                                                    └─────────────┘
```

## FX Mode

When used as an effect:
1. Audio input feeds envelope follower
2. Envelope follower modulates duty cycle (or other params)
3. Pulsar oscillator runs independently
4. Result: input dynamics shape the pulsar timbre

Optional: pitch tracking on input to lock pulsar rate to input pitch.

## Anti-Aliasing

Pulsarets with sharp edges (low duty cycle) are rich in harmonics. To avoid aliasing:

1. **Band-limited pulsaret tables**: Pre-compute pulsarets at different duty cycles with appropriate bandwidth
2. **Oversampling**: 2x or 4x internal sample rate
3. **Soft edges**: Use Gaussian/raised-cosine shapes that naturally roll off high frequencies

## Performance Considerations

- Pulsaret computation is cheap (table lookup)
- Formant filters: 2 biquads = minimal CPU
- Main cost: oversampling (if used)
- Target: < 5% CPU in Logic at 256 buffer size

## Parameter Ranges

| Parameter | Min | Max | Default | Unit |
|-----------|-----|-----|---------|------|
| pulseRate | 20 | 2000 | 220 | Hz |
| dutyCycle | 0.01 | 1.0 | 0.2 | ratio |
| formant1Freq | 100 | 4000 | 800 | Hz |
| formant2Freq | 100 | 4000 | 1200 | Hz |
| formant1Q | 1 | 30 | 10 | Q |
| formant2Q | 1 | 30 | 10 | Q |
| vowelMorph | 0 | 1 | 0.5 | normalized |
| attack | 0.001 | 2.0 | 0.01 | seconds |
| decay | 0.001 | 2.0 | 0.1 | seconds |
| sustain | 0 | 1 | 0.7 | ratio |
| release | 0.001 | 5.0 | 0.3 | seconds |
