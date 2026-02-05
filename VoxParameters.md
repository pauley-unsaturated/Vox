# Vox Synthesizer Plugin - Parameter Reference

**Total Parameters: 58**

---

## Sound Generation Section

### 🎵 Oscillator 1

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Waveform | Sine, Saw, Square, Triangle | Sine | Indexed selection |
| Level | -60.0 to 0.0 dB | -2.0 dB | |
| Octave | -2, -1, 0, +1, +2 | 0 | Indexed selection |
| Detune | -1200.0 to +1200.0 cents | 0.0 cents | High resolution |
| Pulse Width | 2% to 98% | 50% | Affects Square wave |

### 🎵 Oscillator 2

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Waveform | Sine, Saw, Square, Triangle | Saw | Indexed selection |
| Level | -60.0 to 0.0 dB | -60.0 dB (off) | |
| Octave | -2, -1, 0, +1, +2 | 0 | Indexed selection |
| Detune | -1200.0 to +1200.0 cents | -7.0 cents | High resolution |
| Pulse Width | 2% to 98% | 50% | Affects Square wave |
| Sync | Off/On | Off | Hard sync to Osc 1 |

### 🎵 Sub Oscillator

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Level | -60.0 to 0.0 dB | -60.0 dB (off) | |
| Octave | -2, -1 | -1 | Indexed selection |
| Pulse Width | 2% to 98% | 50% | |

### 🌊 Noise Generator

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Level | -60.0 to 0.0 dB | -60.0 dB (off) | White noise |

---

## Signal Processing Section

### 🔧 High-Pass Filter (HPF)

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Cutoff | 0% to 100% (→ 20Hz-20kHz) | 0% | Exponential mapping |
| Resonance | 0% to 120% | 0% | |
| Drive | 0% to 100% | 0% | Pre-filter saturation |
| Key Amount | 0% to 100% | 0% | Keyboard tracking |
| Poles | 2, 4 | 2 | Filter slope |
| Saturation | Off/On | Off | Post-filter saturation |

### 🔧 Low-Pass Filter (LPF) - Moog Ladder Style

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Cutoff | 0% to 100% (→ 20Hz-20kHz) | 100% | Exponential mapping |
| Resonance | 0% to 120% | 0% | |
| Drive | 0% to 100% | 0% | Pre-filter saturation |
| Key Amount | 0% to 100% | 0% | Keyboard tracking |
| Poles | 2, 4 | 2 | Filter slope (12dB/24dB) |
| Saturation | Off/On | Off | Post-filter saturation |
| Velocity Amount | 0% to 100% | 0% | Velocity → cutoff |

---

## Modulation Section

### 📈 Amplitude Envelope

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Attack | 1.5 to 4000.0 ms | 10.0 ms | SH-101 style range |
| Decay | 2.0 to 10000.0 ms | 100.0 ms | |
| Sustain | 0% to 100% | 70% | |
| Release | 2.0 to 10000.0 ms | 300.0 ms | |

### 📈 Filter Envelope

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Attack | 1.5 to 4000.0 ms | 10.0 ms | SH-101 style range |
| Decay | 2.0 to 10000.0 ms | 100.0 ms | |
| Sustain | 0% to 100% | 50% | |
| Release | 2.0 to 10000.0 ms | 300.0 ms | |

### 🌊 LFO (Low Frequency Oscillator)

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Waveform | Triangle, Square, S+H, Noise | Triangle | |
| Rate | 0.1 to 20.0 Hz | 2.0 Hz | Free-run mode |
| Sync Mode | Free Run, Tempo Sync | Free Run | |
| Tempo Rate | 4 Bars to 1/32 | 1/2 | When synced |
| Phase | 0° to 360° | 0° | |
| Retrigger | Off/On | Off | Reset on note-on |
| Delay | 0.0 to 5000.0 ms | 0.0 ms | Fade-in time |

**Tempo Rate Options:** 4 Bars, 2 Bars, 1 Bar, 1/2, 1/2T, 1/4, 1/4., 1/4T, 1/8, 1/8., 1/8T, 1/16, 1/16., 1/16T, 1/32

---

## Modulation Routing Section

### 🎛️ LFO Modulation Destinations

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| LFO Amount | 0% to 100% | 0% | Global LFO intensity |
| LFO → Oscillator Pitch | 0% to 100% | 0% | Vibrato |
| LFO → Filter Cutoff | 0% to 100% | 0% | Filter wobble |
| LFO → Pulse Width | 0% to 100% | 0% | PWM effect |

### 🎛️ Envelope Modulation Destinations

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Filter Env → HPF Cutoff | 0% to 100% | 0% | |
| Filter Env → LPF Cutoff | 0% to 100% | 50% | |
| Filter Env → Pulse Width | 0% to 100% | 0% | |

---

## Performance Section

### 🎹 Voice Settings

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Legato Mode | Off/On | On | Monophonic legato |
| Free Run Oscillators | Off/On | On | Phase reset behavior |
| Glide Mode | Off, On, Auto | Off | Portamento mode |
| Glide Time | 1 to 2000 ms | 100 ms | Portamento speed |

### 🔊 Master Section

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Volume | -60.0 to 0.0 dB | -6.0 dB | Master output |

---

## Arpeggiator / Sequencer Section

### 🎼 Common Settings

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Mode | Off, Arp, Seq | Off | |
| Sync Mode | Free, Sync | Free | Host tempo sync |
| Rate | 0.5 to 50.0 Hz | 5.0 Hz | Free-run mode |
| Tempo Rate | 4 Bars to 1/32 | 1/16 | When synced |
| Gate | 10% to 100% | 75% | Note length |
| Swing | 0% to 75% | 0% | Timing swing |
| Velocity | 1 to 127 | 100 | Base velocity |
| Accent Velocity | 1 to 127 | 127 | Accented notes |

### 🎹 Arpeggiator

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Pattern | Up, Down, Up/Down, Down/Up, Random, As Played | Up | |
| Octaves | 1, 2, 3, 4 | 1 | Octave range |
| Latch | Off/On | Off | Hold notes |

### 🎼 Sequencer

| Parameter | Range | Default | Notes |
|-----------|-------|---------|-------|
| Length | 1 to 32 steps | 16 | Sequence length |

---

## UI Design Notes

**Primary Controls:** Oscillator levels, Filter cutoff/resonance, Envelope ADSR

**Secondary Controls:** Detune, octave offsets, pulse widths, LFO settings

**Advanced Controls:** Modulation routing, filter saturation, sync options

**Performance Controls:** Legato, glide, arpeggiator, sequencer

### Signal Flow

```
Osc 1 ──┐
Osc 2 ──┼──► Mixer ──► HPF ──► LPF ──► Amp Env ──► Master Out
Sub   ──┤
Noise ──┘
```
