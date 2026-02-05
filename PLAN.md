# Vox Modulation Architecture & Implementation Plan

*"One vocal cord. Infinite voices. Living modulation."*

---

## Vision

Vox is a **polyphonic pulsar synthesizer** where every parameter breathes. Drawing from Curtis Roads' pulsar synthesis theory and the creative visions of electronic music pioneers, Vox combines:

1. **Dual-Domain Synthesis** (Roads) — Formant and fundamental are independent
2. **Stochastic Clouds** (Xenakis) — Per-grain probability distributions
3. **Slow Drift** (Radigue/Eno) — Ultra-slow evolution over minutes
4. **Chaos Modulators** (Aphex Twin) — Strange attractors as mod sources
5. **Voice Constellation** (Herndon) — Choir-like polyphony with individual voice personalities

---

## Part I: Architecture

### Voice Engine (Polyphonic)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           VOX POLYPHONIC ENGINE                          │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │ VOICE CONSTELLATION                                                  ││
│  │                                                                      ││
│  │   V1 ──○     ○── V5        Spread: detune, timing, formant, pan    ││
│  │        \   /                Phase: LFO offset per voice             ││
│  │    V2 ──○─○── V6           Sympathy: cross-voice modulation        ││
│  │        /   \                                                        ││
│  │   V3 ──○     ○── V7        8 voices, expandable to 16              ││
│  │          ○                                                          ││
│  │         V4 ○── V8                                                   ││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │ GLOBAL MODULATION                                                    ││
│  │                                                                      ││
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐ ││
│  │  │  Drift   │ │ Chaos    │ │ Global   │ │ Formant  │ │   Mod     │ ││
│  │  │  Engine  │ │ Lorenz/  │ │ LFO 1-2  │ │ Step Seq │ │  Matrix   │ ││
│  │  │ 0.001 Hz │ │ Henon    │ │ 0.01-50Hz│ │ 16 steps │ │  12x12    │ ││
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └───────────┘ ││
│  └─────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘
```

### Per-Voice Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│ VOICE N                                                                  │
│                                                                          │
│  MIDI ──►┌─────────┐    ┌───────────────┐    ┌────────────┐    ┌─────┐│
│  Note    │ Pitch   │───►│    Pulsar     │───►│  Formant   │───►│ VCA ││
│  ──────► │ Engine  │    │  Oscillator   │    │  Filter    │    │     ││
│          │ + Glide │    │               │    │  (F1+F2)   │    │     ││
│          └────┬────┘    └───────┬───────┘    └─────┬──────┘    └──┬──┘│
│               │                 │                  │              │    │
│               │    ┌────────────┼──────────────────┼──────────────┤    │
│               │    │            │                  │              │    │
│               ▼    ▼            ▼                  ▼              ▼    │
│          ┌─────────────────────────────────────────────────────────┐  │
│          │              PER-VOICE MODULATION                        │  │
│          │                                                          │  │
│          │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────┐│  │
│          │  │ Env 1   │  │ Env 2   │  │ LFO 1   │  │ Stochastic  ││  │
│          │  │ (Amp)   │  │ (Mod)   │  │ (Voice) │  │   Cloud     ││  │
│          │  │ DAHDSR  │  │ DAHDSR  │  │ w/phase │  │  (per-grain)││  │
│          │  └─────────┘  └─────────┘  └─────────┘  └─────────────┘│  │
│          └─────────────────────────────────────────────────────────┘  │
│                                                                          │
│  Voice Offset: Δpitch, Δtime, Δformant, Δpan, ΔLFO phase               │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part II: Modulation Systems

### 1. Dual-Domain Control (Roads)

The fundamental insight: **pitch and formant are independent**.

| Control | What It Does | Range |
|---------|--------------|-------|
| **Pitch** | Pulsaret repetition rate | 20 Hz - 5 kHz |
| **Formant 1** | First resonance peak | 80 Hz - 4 kHz |
| **Formant 2** | Second resonance peak | 200 Hz - 6 kHz |
| **Formant Track** | How much formant follows pitch | 0-100% |

**Use Cases:**
- Track = 0%: Robot voice (formant fixed regardless of pitch)
- Track = 100%: Natural voice (formant follows pitch)
- Track = 50%: Hybrid (subtle vowel shift with pitch)

---

### 2. Stochastic Cloud Engine (Xenakis)

Per-grain randomization with statistical control.

| Parameter | Mean | Variance | Distribution |
|-----------|------|----------|--------------|
| **Pitch** | Note pitch | ±cents | Gaussian |
| **Timing** | Grid position | ±ms | Poisson |
| **Formant** | Target formant | ±Hz | Gaussian |
| **Pan** | Center position | ±width | Uniform |
| **Amplitude** | Target level | ±dB | Gaussian |
| **Duty Cycle** | Target duty | ±% | Gaussian |

**Controls:**
- **Cloud Density**: Grains per second (independent of pitch!)
- **Cloud Scatter**: Global multiplier for all variances
- **Distribution Type**: Per-parameter (Gaussian/Uniform/Cauchy)

---

### 3. Slow Drift System (Radigue/Eno)

Ultra-slow modulation for imperceptible evolution.

| Drift Mode | Behavior | Time Scale |
|------------|----------|------------|
| **Random Walk** | Brownian motion, bounded | 10s - 10min per cycle |
| **Breath** | Organic rise/fall pattern | 5s - 5min |
| **Tide** | Slow sine, very low freq | 1min - 1hour |
| **Entropy** | One-way decay toward target | Adjustable half-life |

**Controls:**
- **Drift Rate**: 0.001 Hz to 0.1 Hz (one cycle per 16 min to 10 sec)
- **Drift Amount**: How far parameters wander
- **Drift Targets**: Which parameters drift (pitch, formant, duty, pan)
- **Per-Voice vs Global**: Individual wandering or collective evolution

---

### 4. Chaos Modulators (Aphex Twin)

Strange attractors as modulation sources.

**Lorenz Attractor** (smooth, orbiting)
```
dx/dt = σ(y - x)
dy/dt = x(ρ - z) - y  
dz/dt = xy - βz
```
- Best for: Pitch vibrato, formant sweeps, slow evolution
- Character: Smooth, continuous, never repeating

**Henon Map** (snappy, rhythmic)
```
x[n+1] = 1 - ax[n]² + y[n]
y[n+1] = bx[n]
```
- Best for: Duty cycle, gate patterns, rhythmic modulation
- Character: Sharper, more angular, pseudo-rhythmic

**Controls:**
- **Chaos Rate**: How fast the attractor evolves
- **Chaos → Destination**: Amount to each target
- **Chaos Blend**: Mix with deterministic LFO (0% = pure LFO, 100% = pure chaos)
- **Attractor Type**: Lorenz / Henon / Rössler

---

### 5. Voice Constellation (Herndon)

Polyphonic richness through voice variation.

| Spread Parameter | Range | Effect |
|------------------|-------|--------|
| **Detune** | 0 - 50 cents | Subtle pitch differences |
| **Time Offset** | 0 - 50 ms | Strum/humanize attack |
| **Formant Offset** | 0 - 200 Hz | Each voice slightly different vowel |
| **Pan Spread** | 0 - 100% | Stereo distribution |
| **LFO Phase** | 0 - 360° | Voices drift in/out of sync |

**Constellation Modes:**
- **Unison**: All offsets at 0, maximum tightness
- **Ensemble**: Subtle offsets, string section feel
- **Choir**: Maximum offsets, individual voices audible
- **Random**: Offsets randomized per note

**Cross-Voice Modulation:**
- Voice N's envelope can modulate Voice N+1's formant
- "Sympathy" control: how much voices respond to each other
- Global "Conductor" envelope shapes all voices together

---

### 6. Formant Step Sequencer

16-step sequencer for vowel patterns.

```
Step:  1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16
Vowel: A   A   E   E   I   -   O   O   U   U   O   -   E   E   A   A
       ▓▓▓▓▓▓▓▓████████▓▓▓▓    ▓▓▓▓▓▓▓▓████████    ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
```

**Controls:**
- **Steps**: 1-16 active steps
- **Rate**: Sync to tempo or free-running
- **Glide**: Portamento between vowel steps (0-100%)
- **Pattern**: Preset patterns (speaking, singing, robot)
- **Vowel Set**: Human M/F, Child, Alien, Robot

---

### 7. Modulation Matrix

12 sources × 12 destinations with full routing.

**Sources:**
1. Env 1 (Amp)
2. Env 2 (Mod)  
3. LFO 1 (per-voice)
4. LFO 2 (global)
5. Drift
6. Chaos
7. Step Seq
8. Velocity
9. Aftertouch
10. Mod Wheel
11. Note Number
12. Random (per-note)

**Destinations:**
1. Pitch
2. Formant 1 Freq
3. Formant 2 Freq
4. Vowel Morph
5. Duty Cycle
6. Grain Density
7. Cloud Scatter
8. Pan
9. Amplitude
10. LFO 1 Rate
11. LFO 2 Rate
12. Chaos Rate

**Per-Route Controls:**
- Amount: -100% to +100%
- Curve: Linear / Exp / Log / S-curve
- Via: Secondary modulator scales amount

---

## Part III: User Interface

### Main Performance View

```
┌─────────────────────────────────────────────────────────────────────────┐
│  VOX                                                    ┌─────────────┐ │
│  ══════                                                 │   -12 dB    │ │
│                                                         │    ████     │ │
│  ┌─────────────────────────────────────────────────┐   │    ████     │ │
│  │           PULSARET VISUALIZER                    │   │    ████     │ │
│  │                                                  │   │    ████     │ │
│  │    ╭──╮        ╭──╮        ╭──╮        ╭──╮    │   │    ████     │ │
│  │   ╱    ╲      ╱    ╲      ╱    ╲      ╱    ╲   │   │    ▓▓▓▓     │ │
│  │ ─╯      ╰────╯      ╰────╯      ╰────╯      ╰─ │   │    ▓▓▓▓     │ │
│  │                                                  │   │            │ │
│  │  Duty: 23%    Density: 440/s    Shape: R.Cos   │   └─────────────┘ │
│  └─────────────────────────────────────────────────┘                   │
│                                                                          │
│  ┌──────────────────────┐  ┌──────────────────────────────────────────┐│
│  │   FORMANT SPECTRUM   │  │          VOICE CONSTELLATION              ││
│  │                      │  │                                           ││
│  │   ▓▓                 │  │        ○ V1        ○ V5                  ││
│  │   ██ ▓▓              │  │          \        /                      ││
│  │   ██ ██              │  │     ○ V2  ╲  ●  ╱  ○ V6                 ││
│  │   ██ ██ ▓▓           │  │            ╲  ╱                          ││
│  │   ██ ██ ██           │  │     ○ V3    ╳    ○ V7                   ││
│  │   ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁   │  │            ╱  ╲                          ││
│  │   100 500 1k 2k 4k   │  │     ○ V4  ╱    ╲  ○ V8                  ││
│  │   F1↑    F2↑         │  │                                           ││
│  │                      │  │   Spread: ████░░░░   Phase: ██████░░░░  ││
│  │   Vowel: A──E        │  │                                           ││
│  └──────────────────────┘  └──────────────────────────────────────────┘│
│                                                                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐│
│  │   PULSAR    │ │   FORMANT   │ │  ENVELOPE   │ │      MASTER         ││
│  │             │ │             │ │             │ │                     ││
│  │  Shape ○○●○ │ │  Vowel      │ │  A ████     │ │  Volume ████████░░ ││
│  │  Duty  ███░ │ │  ══A═E═I═O═U│ │  D ██████   │ │                     ││
│  │  Fine  ░░█░ │ │  Mix  ████░ │ │  S ████░░   │ │  Glide  ███░░░░░░░ ││
│  │             │ │  Track ██░░ │ │  R ██████░  │ │  Bend   ░░░██░░░░░ ││
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘
```

### Modulation Deep View

```
┌─────────────────────────────────────────────────────────────────────────┐
│  VOX › MODULATION                                              [BACK]   │
│  ════════════════                                                        │
│                                                                          │
│  ┌───────────────────────────────┐  ┌───────────────────────────────────┐│
│  │      CHAOS VISUALIZER         │  │         DRIFT TIMELINE            ││
│  │                               │  │                                    ││
│  │         ●                     │  │  Pitch  ═══════════●═══════════   ││
│  │        ╱ ╲                    │  │  Formant ════●══════════════════  ││
│  │       ╱   ●                   │  │  Duty   ══════════════●════════   ││
│  │      ●     ╲                  │  │  Pan    ═════════════════●═════   ││
│  │       ╲   ╱                   │  │                                    ││
│  │        ╲ ╱                    │  │  ├──────┼──────┼──────┼──────┤    ││
│  │         ●                     │  │  now   +1min  +2min  +3min  +4min ││
│  │                               │  │                                    ││
│  │  Type: Lorenz  Rate: ███░░   │  │  Rate: ██░░░░░░   Amount: ████░░  ││
│  └───────────────────────────────┘  └───────────────────────────────────┘│
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────────┐│
│  │                        MODULATION MATRIX                              ││
│  │                                                                       ││
│  │          Pitch F1   F2   Vowel Duty Dens Scat Pan  Amp  LFO1 LFO2 Cha││
│  │  Env1    ░░░░ ░░░░ ░░░░ ░░░░  ░░░░ ░░░░ ░░░░ ░░░░ ████ ░░░░ ░░░░ ░░░││
│  │  Env2    ░░░░ ██░░ ██░░ ░░░░  ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░││
│  │  LFO1    ██░░ ░░░░ ░░░░ ░░░░  ███░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░││
│  │  LFO2    ░░░░ ░░░░ ░░░░ ████  ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░││
│  │  Drift   ░░░░ █░░░ █░░░ ░░░░  ░░░░ ░░░░ ░░░░ █░░░ ░░░░ ░░░░ ░░░░ ░░░││
│  │  Chaos   ░░░░ ░░░░ ░░░░ ░░░░  ██░░ ░░░░ ██░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░││
│  │  StepSeq ░░░░ ░░░░ ░░░░ ████  ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░││
│  │  Vel     ░░░░ ░░░░ ░░░░ ░░░░  ░░░░ ░░░░ ░░░░ ░░░░ ██░░ ░░░░ ░░░░ ░░░││
│  │  AfterT  ░░░░ ██░░ ░░░░ ░░░░  ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░││
│  │  ModWhl  ░░░░ ░░░░ ░░░░ ████  ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░░ ░░░││
│  │                                                                       ││
│  │  Click cell to edit: Amount, Curve, Via                              ││
│  └───────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                      FORMANT STEP SEQUENCER                          │ │
│  │                                                                      │ │
│  │   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16     │ │
│  │  ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐  │ │
│  │  │A│ │A│ │E│ │E│ │I│ │-│ │O│ │O│ │U│ │U│ │O│ │-│ │E│ │E│ │A│ │A│  │ │
│  │  └▲┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘  │ │
│  │   ●                                                                  │ │
│  │  Rate: ████░░░░░░  Glide: ██████░░░░  Steps: 16                     │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

### Stochastic Cloud View

```
┌─────────────────────────────────────────────────────────────────────────┐
│  VOX › CLOUD                                                   [BACK]   │
│  ══════════                                                              │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                     GRAIN CLOUD VISUALIZER                           ││
│  │                                                                      ││
│  │    ●                    ●              ●                             ││
│  │         ●        ●            ●    ●        ●                        ││
│  │      ●      ●          ●   ●     ●      ●       ●                   ││
│  │   ●      ●    ●    ●         ●       ●     ●       ●    ●           ││
│  │      ●         ●       ●         ●            ●         ●           ││
│  │         ●            ●      ●           ●          ●                 ││
│  │    ●          ●                ●    ●        ●                       ││
│  │                                                                      ││
│  │  X: Pan (-L ──────────────────────────────── R+)                    ││
│  │  Y: Pitch   Size: Amplitude   Brightness: Duty                      ││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌────────────┐│
│  │  PITCH CLOUD   │ │ FORMANT CLOUD  │ │ TIMING CLOUD   │ │  PAN CLOUD ││
│  │                │ │                │ │                │ │            ││
│  │  Mean: C4      │ │  Mean: 800 Hz  │ │  Mean: 0 ms    │ │ Mean: C    ││
│  │  ════●════     │ │  ════●════     │ │  ════●════     │ │ ════●════  ││
│  │                │ │                │ │                │ │            ││
│  │  Var: ±10¢     │ │  Var: ±50 Hz   │ │  Var: ±5 ms    │ │ Var: ±30%  ││
│  │  ████░░░░░░    │ │  ████░░░░░░    │ │  ██░░░░░░░░    │ │ ████░░░░░░ ││
│  │                │ │                │ │                │ │            ││
│  │  Dist: Gauss   │ │  Dist: Gauss   │ │  Dist: Poisson │ │ Dist: Uni  ││
│  │  [●]Gau [○]Uni │ │  [●]Gau [○]Cau │ │  [○]Gau [●]Poi │ │ [○]G [●]U  ││
│  └────────────────┘ └────────────────┘ └────────────────┘ └────────────┘│
│                                                                          │
│  Global:  Density ████████░░░░  Scatter ██████░░░░░░                    │
└─────────────────────────────────────────────────────────────────────────┘
```

### Visual Feedback Elements

| Element | Purpose | Animation |
|---------|---------|-----------|
| **Pulsaret Scope** | Show grain shapes firing | Real-time waveform with duty cycle visible |
| **Formant Spectrum** | Show F1/F2 peaks | FFT-style display with resonance peaks highlighted |
| **Chaos Attractor** | Visualize Lorenz/Henon | 2D phase plot, dot traces the attractor |
| **Drift Timeline** | Show slow parameter evolution | Horizontal timeline showing past/future drift |
| **Voice Constellation** | Show all voices' states | Circular plot, voice positions show phase/detune |
| **Grain Cloud** | Visualize stochastic spread | Scatter plot of recent grains (x=pan, y=pitch, size=amp) |
| **Mod Matrix Glow** | Show active modulation | Cells glow when modulation is active |
| **Envelope Trace** | Show envelope stage | Classic ADSR display with playhead |
| **Step Indicator** | Show sequencer position | Bouncing ball / highlight on current step |
| **Level Meters** | Per-voice and master | VU-style with peak hold |

---

## Part IV: Implementation Tentpoles

### Phase 1: Polyphonic Foundation
*Get multiple voices playing independently*

| # | Task | Dependencies | Estimate |
|---|------|--------------|----------|
| 1.1 | **Voice allocator** (8 voices, round-robin/lowest/highest) | Current mono voice | 4h |
| 1.2 | **Voice pool manager** (note on/off routing) | 1.1 | 4h |
| 1.3 | **Per-voice state isolation** (each voice independent) | 1.2 | 3h |
| 1.4 | **Voice stealing** (when pool exhausted) | 1.2 | 2h |
| 1.5 | **Polyphonic MIDI handling** | 1.2 | 2h |
| 1.6 | **Voice mixing** (sum all voices to stereo out) | 1.3 | 2h |

**Milestone:** Play chords, each note independent voice

---

### Phase 2: Per-Voice Modulation
*Each voice has its own mod sources*

| # | Task | Dependencies | Estimate |
|---|------|--------------|----------|
| 2.1 | **Per-voice LFO** (with phase offset capability) | 1.3 | 4h |
| 2.2 | **Per-voice Env 2** (modulation envelope, separate from amp) | 1.3 | 3h |
| 2.3 | **Mod routing per voice** (LFO/Env to pitch/formant/duty) | 2.1, 2.2 | 4h |
| 2.4 | **Velocity sensitivity** per voice | 1.3 | 2h |
| 2.5 | **Aftertouch (poly)** per voice | 1.3 | 2h |

**Milestone:** Each voice can have vibrato/tremolo at different phases

---

### Phase 3: Voice Constellation
*Choir-like variation between voices*

| # | Task | Dependencies | Estimate |
|---|------|--------------|----------|
| 3.1 | **Detune spread** (±cents across voices) | 1.6 | 2h |
| 3.2 | **Time offset spread** (±ms strum effect) | 1.6 | 2h |
| 3.3 | **Formant offset spread** (each voice different vowel tint) | 1.6 | 2h |
| 3.4 | **Pan spread** (voices distributed L-R) | 1.6 | 2h |
| 3.5 | **LFO phase spread** (voices drift in/out of sync) | 2.1 | 2h |
| 3.6 | **Constellation modes** (Unison/Ensemble/Choir/Random) | 3.1-3.5 | 3h |
| 3.7 | **Unison voice count** (1-8 voices per note in unison mode) | 3.6 | 2h |

**Milestone:** Single note can sound like a choir

---

### Phase 4: Global Modulation Sources
*Modulation that affects all voices*

| # | Task | Dependencies | Estimate |
|---|------|--------------|----------|
| 4.1 | **Global LFO 1 & 2** | - | 3h |
| 4.2 | **Drift engine** (ultra-slow random walk, 0.001-0.1 Hz) | - | 4h |
| 4.3 | **Chaos generator** (Lorenz attractor) | - | 4h |
| 4.4 | **Chaos generator** (Henon map) | - | 3h |
| 4.5 | **Chaos rate/amount controls** | 4.3, 4.4 | 2h |
| 4.6 | **Formant step sequencer** (16 steps) | - | 4h |
| 4.7 | **Sequencer sync** (tempo/free) | 4.6 | 2h |
| 4.8 | **Sequencer glide** (portamento between steps) | 4.6 | 2h |

**Milestone:** Parameters evolve over minutes, chaos modulation works

---

### Phase 5: Stochastic Cloud Engine
*Per-grain randomization*

| # | Task | Dependencies | Estimate |
|---|------|--------------|----------|
| 5.1 | **Per-grain pitch scatter** (Gaussian distribution) | 1.3 | 3h |
| 5.2 | **Per-grain timing jitter** (Poisson distribution) | 1.3 | 3h |
| 5.3 | **Per-grain formant scatter** | 1.3 | 2h |
| 5.4 | **Per-grain pan scatter** | 1.3 | 2h |
| 5.5 | **Per-grain amplitude scatter** | 1.3 | 2h |
| 5.6 | **Distribution type selector** (Gaussian/Uniform/Cauchy/Poisson) | 5.1-5.5 | 3h |
| 5.7 | **Global scatter amount** (multiplier for all variances) | 5.6 | 1h |
| 5.8 | **Grain density control** (independent of pitch) | 5.2 | 3h |

**Milestone:** Clouds of grains with statistical control

---

### Phase 6: Modulation Matrix
*Full routing flexibility*

| # | Task | Dependencies | Estimate |
|---|------|--------------|----------|
| 6.1 | **Matrix data structure** (12x12, bipolar amounts) | - | 2h |
| 6.2 | **Matrix routing engine** (sum all sources per destination) | 6.1, Phase 4 | 4h |
| 6.3 | **Curve types** (linear/exp/log/S-curve) | 6.2 | 2h |
| 6.4 | **Via modulation** (mod source scales amount) | 6.2 | 3h |
| 6.5 | **Matrix preset save/load** | 6.1 | 2h |

**Milestone:** Any modulation source can control any parameter

---

### Phase 7: UI - Basic Controls
*Get parameters controllable*

| # | Task | Dependencies | Estimate |
|---|------|--------------|----------|
| 7.1 | **Pulsar section** (shape, duty, fine tune) | Phase 1 | 3h |
| 7.2 | **Formant section** (vowel, F1, F2, track, mix) | Phase 1 | 3h |
| 7.3 | **Envelope section** (ADSR x2) | Phase 2 | 3h |
| 7.4 | **LFO section** (rate, shape, amount per-voice/global) | Phase 2, 4 | 3h |
| 7.5 | **Constellation section** (spread controls, mode) | Phase 3 | 3h |
| 7.6 | **Drift/Chaos section** (rate, amount, type) | Phase 4 | 3h |
| 7.7 | **Step sequencer section** (16 step grid) | Phase 4 | 4h |
| 7.8 | **Cloud section** (scatter controls per-parameter) | Phase 5 | 4h |
| 7.9 | **Matrix UI** (12x12 clickable grid) | Phase 6 | 6h |

**Milestone:** All parameters accessible from UI

---

### Phase 8: UI - Visual Feedback
*Make it feel alive*

| # | Task | Dependencies | Estimate |
|---|------|--------------|----------|
| 8.1 | **Pulsaret scope** (real-time grain visualization) | Phase 7 | 6h |
| 8.2 | **Formant spectrum display** (FFT with F1/F2 markers) | Phase 7 | 6h |
| 8.3 | **Chaos attractor plot** (2D phase visualization) | Phase 4, 7 | 4h |
| 8.4 | **Drift timeline** (horizontal evolution display) | Phase 4, 7 | 4h |
| 8.5 | **Voice constellation display** (circular voice positions) | Phase 3, 7 | 5h |
| 8.6 | **Grain cloud scatter plot** (real-time grain positions) | Phase 5, 7 | 6h |
| 8.7 | **Level meters** (per-voice and master) | Phase 1, 7 | 3h |
| 8.8 | **Envelope trace display** | Phase 2, 7 | 3h |
| 8.9 | **Step sequencer playhead** | Phase 4, 7 | 2h |
| 8.10 | **Matrix activity glow** | Phase 6, 7 | 3h |

**Milestone:** UI shows what the sound is doing in real-time

---

### Phase 9: Presets & Polish
*Ship it*

| # | Task | Dependencies | Estimate |
|---|------|--------------|----------|
| 9.1 | **Preset system** (full state save/load) | All | 4h |
| 9.2 | **Factory presets** (10-20 curated sounds) | 9.1 | 8h |
| 9.3 | **MIDI learn** for all parameters | All | 4h |
| 9.4 | **CPU optimization** (profile and optimize hot paths) | All | 8h |
| 9.5 | **Documentation** (user manual) | All | 4h |
| 9.6 | **Final testing** (Logic, Ableton, AUM, auval) | All | 4h |

**Milestone:** Ready for release

---

## Summary: Dependency Graph

```
Phase 1: Polyphonic Foundation
    │
    ├──► Phase 2: Per-Voice Modulation
    │        │
    │        └──► Phase 3: Voice Constellation
    │
    ├──► Phase 4: Global Modulation ──► Phase 6: Mod Matrix
    │
    └──► Phase 5: Stochastic Cloud
    
                    ║
                    ▼
              Phase 7: UI Basic
                    │
                    ▼
              Phase 8: UI Visual
                    │
                    ▼
              Phase 9: Presets & Polish
```

---

## Estimated Total: ~180 hours

| Phase | Hours |
|-------|-------|
| 1. Polyphonic Foundation | 17h |
| 2. Per-Voice Modulation | 15h |
| 3. Voice Constellation | 15h |
| 4. Global Modulation | 24h |
| 5. Stochastic Cloud | 19h |
| 6. Modulation Matrix | 13h |
| 7. UI Basic | 32h |
| 8. UI Visual | 42h |
| 9. Presets & Polish | 32h |
| **Total** | **~180h** |

---

*"One vocal cord. Infinite voices. Living modulation."*

— Sync, February 2026
