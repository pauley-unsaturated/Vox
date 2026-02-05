# Vox Synthesizer UI Design Brief

## Project Context
Vox is a subtractive synthesizer AudioUnit v3 plugin inspired by classic mono-synths like the Roland SH-101 and Sequential Pro-One. The goal is to create an intuitive, professional interface that captures the workflow and aesthetic of vintage analog synthesizers while leveraging modern UI capabilities.

## Technical Constraints
- **Platform**: macOS AudioUnit v3 plugin using SwiftUI
- **Host Applications**: Logic Pro, MainStage, GarageBand, and other AUv3-compatible DAWs
- **Parameter System**: 29 parameters organized in logical groups (see parameter list below)
- **Real-time Requirements**: Low-latency parameter updates for audio processing

## Design Philosophy
- **Analog Heritage**: Visual design should evoke classic analog synthesizers without being skeuomorphic
- **Workflow First**: Prioritize musical workflow over visual complexity
- **Immediate Feedback**: Clear visual indication of current parameter values and modulation
- **Professional Polish**: Clean, modern aesthetic suitable for professional production environments

## Target User Experience
1. **Instant Playability**: New users should be able to make musical sounds immediately
2. **Familiar Workflow**: Experienced synth users should feel at home with the layout
3. **Visual Feedback**: Clear indication of what's happening sonically through visual cues
4. **Efficient Editing**: Quick access to all parameters without overwhelming the interface

## Complete Parameter List (29 parameters)

### Master Section (Global)
- `masterVolume` (0.0-1.0): Overall output level

### Oscillator 1 Section
- `osc1Waveform` (Indexed): Sine, Saw, Square, Triangle
- `osc1Level` (0.0-1.0): Mix level 
- `osc1PulseWidth` (0-100%): Square wave pulse width
- `osc1Detune` (-1200 to +1200 cents): Fine tuning

### Oscillator 2 Section  
- `osc2Waveform` (Indexed): Sine, Saw, Square, Triangle
- `osc2Level` (0.0-1.0): Mix level
- `osc2PulseWidth` (0-100%): Square wave pulse width
- `osc2Detune` (-1200 to +1200 cents): Fine tuning
- `osc2Sync` (Boolean): Hard sync to Osc1

### Mixer Section
- `subOscLevel` (0.0-1.0): Sub-oscillator level (1 octave below Osc1)
- `noiseLevel` (0.0-1.0): White noise level

### Filter Section (Moog-style low-pass)
- `filterCutoff` (20-20000 Hz): Cutoff frequency
- `filterResonance` (0-95%): Resonance/Q factor
- `filterKeyboardTracking` (0-100%): Cutoff follows keyboard

### Amp Envelope (ADSR)
- `ampAttack` (0.001-2.0s): Attack time
- `ampDecay` (0.001-2.0s): Decay time  
- `ampSustain` (0-100%): Sustain level
- `ampRelease` (0.001-3.0s): Release time

### Filter Envelope (ADSR)
- `filterAttack` (0.001-2.0s): Attack time
- `filterDecay` (0.001-2.0s): Decay time
- `filterSustain` (0-100%): Sustain level
- `filterRelease` (0.001-3.0s): Release time
- `filterEnvAmount` (-100 to +100%): Modulation depth

### LFO Section
- `lfoRate` (0.1-20.0 Hz): LFO frequency
- `lfoWaveform` (Indexed): Sine, Triangle, Square, Sample & Hold
- `lfoAmount` (0-100%): Pitch modulation depth
- `lfoFilterAmount` (0-100%): Filter cutoff modulation depth
- `lfoOscAmount` (0-100%): Oscillator pitch modulation depth

## Modulation Visualization Needs
The interface should clearly show:
1. **Active Modulation**: Which parameters are being modulated and by how much
2. **Envelope Shapes**: Visual representation of ADSR curves
3. **LFO Waveforms**: Visual indication of LFO shape and rate
4. **Parameter Relationships**: Clear connection between modulation sources and destinations

## Reference Inspirations
Consider these classic synthesizers for workflow and aesthetic inspiration:
- **Roland SH-101**: Simple, immediate layout with clear parameter grouping
- **Sequential Pro-One**: Clean panel layout with logical signal flow
- **Minimoog**: Iconic control grouping and visual hierarchy
- **Modern AUv3 Plugins**: Contemporary examples like FabFilter, Eventide, Native Instruments

## Layout Considerations
1. **Signal Flow**: Arrange sections to follow audio signal path (Oscillators → Mixer → Filter → Amp)
2. **Modulation Proximity**: Place modulation controls near their destinations
3. **Screen Real Estate**: Efficient use of space while maintaining readability
4. **Accessibility**: Appropriate contrast, font sizes, and touch target sizes

## Deliverable Request
Please create a comprehensive UI design specification including:

1. **Overall Layout**: Panel arrangement and visual hierarchy
2. **Component Design**: Specific control types for each parameter (knobs, sliders, buttons, etc.)
3. **Color Scheme**: Professional color palette with good contrast
4. **Typography**: Font choices and sizing
5. **Modulation Visualization**: How to show active modulation and envelope shapes
6. **Responsive Design**: How the interface adapts to different sizes
7. **SwiftUI Implementation Notes**: Specific guidance for development

The goal is to create a design that feels both familiar to vintage synth users and fresh for modern production workflows. Prioritize clarity, efficiency, and musical expressiveness over visual complexity.