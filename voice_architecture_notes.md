# Monophonic Voice Architecture Notes

## Roland SH-101 Architecture
- **Oscillator**: 1 VCO with:
  - Saw wave (with level control)
  - Square/Pulse wave with PWM (with level control)
  - Sub-oscillator (square wave, -1 octave, with level control)
  - White noise source (with level control)
- **Filter**: Resonant low-pass filter, self-oscillating
  - Modulation sources: Envelope, LFO, Keyboard tracking
- **Amplifier**: VCA with ADSR envelope or gate
- **LFO**: Triangle, Square, Random (S&H), Noise
- **Modulation**: PWM can be modulated by LFO, Manual, or Envelope

## Sequential Pro-One Architecture
- **Oscillators**: 2 VCOs
  - OSC A: Saw, Pulse (with width control)
  - OSC B: Saw, Pulse, Triangle (can operate as LFO)
  - Oscillator sync capability
  - White noise source
- **Mixer**: Mix levels for OSC A, OSC B, Noise
- **Filter**: 4-pole low-pass filter (24dB/octave)
  - Dedicated ADSR envelope
  - Keyboard tracking
- **Amplifier**: VCA with dedicated ADSR envelope
- **LFO**: Dedicated LFO for modulation
- **Modulation**: Comprehensive mod matrix

## Common Architecture Pattern
Both synths follow classic subtractive synthesis:
1. **Sound Sources** → 2. **Mixer** → 3. **Filter** → 4. **Amplifier** → Output

## Implementation Plan for Monophonic Voice
- Support multiple oscillators (configurable 1-2)
- Sub-oscillator option
- Noise source
- Mixer section with individual levels
- Filter with envelope modulation
- VCA with envelope
- Basic modulation routing (LFO → PWM, Filter cutoff)
- Note triggering (noteOn/noteOff)
- Pitch control (note + pitch bend)