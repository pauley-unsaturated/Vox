# Vox Synthesizer - User Interface Specification (Final)

## Overall Layout
The UI is organized into four distinct vertical columns, corresponding to sound generation and modulation stages, culminating in the main output and performance controls.

---

## Column 1: Oscillators & Sub-Oscillator

This column houses the primary sound sources of the synthesizer.

### Section Title: OSCILLATORS

#### Oscillator 1 & 2 (Tabbed Interface)
**Tab Control**: Users can select between OSC1, OSC2, SUB-OSC, and NOISE tabs to edit their respective parameters.

**Oscillator Controls (OSC1 & OSC2):**
- **Tune**: Rotary knob, Range: -100 to +100 cents (continuous fine tuning)
- **Octave**: Rotary knob, Range: -2, -1, 0, +1, +2 octaves (5 discrete stepped positions)
- **Wave**: Horizontal 4-button selector: Sine, Saw, Square, Triangle
- **PW (Pulse Width)**: Rotary knob, Range: 2% to 98% (applies to Square wave only)
- **Level**: Rotary knob, Range: -60dB to 0dB
- **Sync** (OSC2 only): Toggle button for hard sync to OSC1

#### Sub-Oscillator Controls
- **Octave**: Rotary knob, Range: -2 or -1 octaves relative to main oscillators (2 discrete positions)
- **PW (Pulse Width)**: Rotary knob, Range: 2% to 98% (fixed square wave)
- **Level**: Rotary knob, Range: -60dB to 0dB

#### Noise Generator Controls
- **Level**: Rotary knob, Range: -60dB to 0dB (white noise generator)

---

## Column 2: Mix & Filter

This column manages the blending of sound sources and sound sculpting.

### Section Title: MIX
**Controls**:
- **Oscillator 1 Volume**: Vertical slider, Range: -60dB to 0dB
- **Oscillator 2 Volume**: Vertical slider, Range: -60dB to 0dB  
- **Sub Oscillator Volume**: Vertical slider, Range: -60dB to 0dB
- **Noise Volume**: Vertical slider, Range: -60dB to 0dB

### Section Title: FILTER
**Architecture**: Two separate, serial filters: a High-pass Filter followed by a Low-pass Filter.

**HP (High Pass) Filter Controls:**
- **Cutoff**: Vertical slider, Range: 20Hz to 20kHz (exponential mapping from 0-100%)
- **Resonance**: Vertical slider, Range: 0% to 120% (allows self-oscillation)
- **Drive**: Vertical slider, Range: 0dB to +24dB (drives tanh non-linearity)
- **Key Amt (Key Tracking)**: Vertical slider for filter cutoff, Range: 0% to 100%
- **Poles**: Filter order selector, Values: 2-pole (12dB/oct) or 4-pole (24dB/oct)
- **SAT (Saturation)**: Toggle for inter-stage non-linearity (more CPU intensive)

**LP (Low Pass) Filter Controls:**
- **Cutoff**: Vertical slider, Range: 20Hz to 20kHz (exponential mapping from 0-100%)
- **Resonance**: Vertical slider, Range: 0% to 120% (allows self-oscillation)
- **Drive**: Vertical slider, Range: 0dB to +24dB (drives tanh non-linearity)
- **Key Amt (Key Tracking)**: Vertical slider for filter cutoff, Range: 0% to 100%
- **Poles**: Filter order selector, Values: 2-pole (12dB/oct) or 4-pole (24dB/oct)
- **SAT (Saturation)**: Toggle for inter-stage non-linearity (more CPU intensive)

---

## Column 3: Envelope & LFO

This column controls the dynamic evolution of sound over time and low-frequency modulation.

### Section Title: ENVELOPE
**Tab Control**: Users can select between AMPLITUDE and FILTER envelope tabs.

**ADSR Controls (applies to selected tab)**:
- **A (Attack)**: Vertical slider, Range: 1ms to 4000ms
- **D (Decay)**: Vertical slider, Range: 1.5ms to 10000ms
- **S (Sustain)**: Vertical slider, Range: 0% to 100% level
- **R (Release)**: Vertical slider, Range: 2ms to 10000ms

**Built-in Envelope Routing**:
- **Filter Envelope AMT**: Routes to LP Filter Cutoff, Range: -100% to +100% modulation depth
- **Amp Envelope AMT**: Routes to Master Amplitude (post-filter), Range: 0% to 100% level

**Additional Envelope Modulation Destinations** (grouped controls):

*Oscillator Pitch Group:*
- **OSC1 Pitch**: Rotary knob, Range: 0% to 100%
- **OSC2 Pitch**: Rotary knob, Range: 0% to 100%

*Pulse Width Group:*
- **OSC1 PW**: Rotary knob, Range: 0% to 100%
- **OSC2 PW**: Rotary knob, Range: 0% to 100%
- **Sub OSC PW**: Rotary knob, Range: 0% to 100%

*Mix Levels Group:*
- **OSC1 Level**: Rotary knob, Range: 0% to 100%
- **OSC2 Level**: Rotary knob, Range: 0% to 100%
- **Sub Level**: Rotary knob, Range: 0% to 100%
- **Noise Level**: Rotary knob, Range: 0% to 100%

*Filter Group:*
- **LP Filter Drive**: Rotary knob, Range: 0% to 100%

### Section Title: LFO

**Controls**:
- **Wave**: 4-button horizontal selector: Sine, Triangle, Square, Sample & Hold
- **Rate**: Rotary knob, Range: 0.1Hz to 20Hz (free-running mode)
- **Tempo Rate**: When synced, musical divisions: 4 Bars, 2 Bars, 1 Bar, 1/2, 1/2T, 1/4, 1/4., 1/4T, 1/8, 1/8., 1/8T, 1/16, 1/16., 1/16T, 1/32
- **Phase**: Rotary knob, Range: 0° to 360° (visual indicator only)
- **Delay**: Rotary knob, Range: 0ms to 5000ms (delay before LFO starts)
- **Sync**: Checkbox to synchronize LFO tempo to host BPM
- **RTRG (Retrigger)**: Checkbox to retrigger LFO phase on each new note

**LFO Modulation Destinations** (grouped controls):

*Oscillator Pitch Group:*
- **OSC1 Pitch**: Rotary knob, Range: 0% to 100% (vibrato)
- **OSC2 Pitch**: Rotary knob, Range: 0% to 100% (vibrato)

*Pulse Width Group:*
- **OSC1 PW**: Rotary knob, Range: 0% to 100% (PWM effect)
- **OSC2 PW**: Rotary knob, Range: 0% to 100% (PWM effect)
- **Sub OSC PW**: Rotary knob, Range: 0% to 100% (PWM effect)

*Mix Levels Group:*
- **OSC1 Level**: Rotary knob, Range: 0% to 100%
- **OSC2 Level**: Rotary knob, Range: 0% to 100%
- **Sub Level**: Rotary knob, Range: 0% to 100%
- **Noise Level**: Rotary knob, Range: 0% to 100%

*Filter Group:*
- **LP Filter Cutoff**: Rotary knob, Range: 0% to 100% (filter sweep)
- **LP Filter Drive**: Rotary knob, Range: 0% to 100% (dynamic drive)

*Master Group:*
- **Master Amplitude**: Rotary knob, Range: 0% to 100% (tremolo effect)

---

## Column 4: Main Controls & Performance

This column contains global settings, master output, and performance parameters.

### Section Title: MAIN

**Preset Management**:
- **Preset Selector**: Dropdown menu for loading/saving presets
- **RTZ (Return to Zero)**: Button to reset all parameters to default values
- **LAST**: Button to recall the last saved/loaded state

**Master Controls**:
- **Volume**: Large rotary knob, Range: -60dB to 0dB (master output level)
- **Meter**: Vertical level meter, Scale: dBFS (output level indication)

### Section Title: PERFORMANCE

**Voice Controls**:
- **Legato**: Checkbox - enables legato playing mode (no envelope retrigger on overlapping notes)

**Arpeggiator Controls**:
- **ARP On/Off**: Checkbox to enable built-in arpeggiator
- **Pattern**: Selector for arpeggiator patterns:
  - Up (ascending through held notes)
  - Down (descending through held notes)  
  - Up-Down (ascending then descending)
  - Pendulum (up-down with repeated end notes)
- **Rate**: Rotary knob for arpeggiator speed (synchronized to host tempo)
- **Octaves**: Selector for octave range: 1, 2, 3, or 4 octaves
  - 1 = held notes only
  - 2 = held notes + one octave up
  - 3 = held notes + one and two octaves up
  - 4 = held notes + one, two, and three octaves up
- **Swing**: Rotary knob for rhythmic swing (nice-to-have feature)

**Velocity Controls**:
- **Velocity Sensitivity**: Horizontal slider, Range: 0% to 100%

---

## Implementation Notes

### Parameter Specifications
- **Total Parameters**: 36+ (with arpeggiator expansion)
- **Parameter Addressing**: Organized by functional groups
- **Automation**: All continuous parameters support host automation and ramping
- **Default State**: Carefully chosen defaults for immediate usability

### Technical Details
- **Filter Implementation**: Moog ladder filter with Huovilainen Zero-Delay Feedback approach
- **Oscillator Anti-aliasing**: PolyBLEP or DPW techniques for alias-free operation
- **Real-time Safety**: No allocations in audio thread, denormal prevention
- **Host Integration**: Full AUv3 compliance with parameter automation and preset management

### UI Framework
- **Platform**: SwiftUI-based interface for AUv3 plugin
- **Controls**: Custom SynthKnob, SynthSlider, SynthButton components
- **Layout**: Tabbed interfaces for space efficiency and logical organization
- **Theming**: Dark theme with orange accent color for active elements

---

## Future Enhancements
- **Additional Modulation**: Velocity sensitivity routing, aftertouch support
- **Sequencer**: Step sequencer integration with arpeggiator
- **Effects**: Built-in chorus, delay, or reverb
- **Preset Expansion**: User preset libraries and randomization features

---
## ASCII-art mockup of the UI

```ascii
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Vox Synthesizer Interface (revised)                                                                                                                     |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                               |                                       |                                                 |                                         |
|  COLUMN 1: OSCILLATORS        |  COLUMN 2: MIX & FILTER               |  COLUMN 3: ENVELOPE & LFO                       |  COLUMN 4: MAIN & PERFORMANCE           |
|                               |                                       |                                                 |                                         |
| ============================= | ===================================== | =============================================== | ======================================= |
|                               |                                       |                                                 |                                         |
|   --- OSCILLATORS ---         |   --- MIX ---                         |   --- ENVELOPE ---                              |   --- MAIN ---                          |
|                               |                                       |                                                 |                                         |
| [ OSC1 ] [ OSC2 ] [ SUB ]     |    OSC1  OSC2   SUB  NOISE            | [ AMPLITUDE ] [ FILTER ]                        |   Preset: [ My Awesome Patch   v ]      |
|                               |    | |   | |   | |   | |              |                                                 |                                         |
|   Tune: ( o )  Octave: ( o )  |    |-|   |-|   |-|   |-|              |    A    D    S    R         Filter Env Amt: ( o ) |   [ RTZ ]  [ LAST ]                      |
|   -100..+100    -2..+2        |    | |   | |   | |   | |              |   | |  | |  | |  | |                               |                                         |
|                               |    | |   |-|   | |   |-|              |   |-|  |-|  |-|  |-|                               |   Master Volume:                        |
|   Waveform:                   |    |-|   | |   |-|   | |              |   | |  | |  | |  | |         Amp Env Amt:    ( o ) |      /=======\                        |
|   [Sin] [Saw] [Sqr] [Tri]     |                                       |   | |  |-|  | |  |-|                               |     /   ( o )   \                       |
|                               | ------------------------------------- |   |-|  | |  |-|  | |                               |    |           |                        |
|   PW: ( o )     Level: ( o )  |   --- HP FILTER ---                   |                                                 |     \         /                         |
|   2..98%        -60..0dB      |                                       |   Mod Destinations (Filter Env):                |      \=======/                          |
|                               |   Cutoff Reson. Drive KeyAmt          |   OSC Pitch: (1) (2)   PW: (1) (2) (S)          |                                         |
|   (OSC2 Only: Sync [X])       |    | |    | |    | |    | |           |   Levels: (1)(2)(S)(N) Filter Drive: (o)        |   Meter:                                |
|                               |    |-|    |-|    |-|    |-|           |                                                 |   | | 0dB                             |
| ----------------------------- |    | |    | |    | |    | |           | ----------------------------------------------- |   |-|                                 |
|                               |   Poles: [ 2 ] [ 4 ]  SAT: [X] On     |                                                 |   |-| -6dB                            |
|   --- SUB-OSCILLATOR ---      |                                       |   --- LFO ---                                   |   |-|                                 |
|                               | ------------------------------------- |                                                 |   | | -12dB                           |
|   Octave: [ -1 ] [ -2 ]       |   --- LP FILTER ---                   |   Wave: [Sin] [Tri] [Sqr] [S&H]                 |   |-|                                 |
|   PW: ( o )     Level: ( o )  |                                       |                                                 |                                         |
|                               |   Cutoff Reson. Drive KeyAmt          |   Rate: ( o )   Phase: ( o )   Delay: ( o )     | --------------------------------------- |
| ----------------------------- |    | |    | |    | |    | |           |   0.1..20Hz      0..360       0..5s            |                                         |
|                               |    |-|    |-|    |-|    |-|           |                                                 |   --- PERFORMANCE ---                   |
|   --- NOISE ---               |    | |    | |    | |    | |           |   [X] Sync to Host   [X] Retrigger             |                                         |
|                               |   Poles: [ 2 ] [ 4 ]  SAT: [X] On     |                                                 |   [X] Legato                            |
|   Level: ( o )                |                                       |   Mod Destinations (LFO):                       |                                         |
|                               |                                       |   OSC Pitch: (1) (2)   PW: (1) (2) (S)          |   Arp: [X] On                           |
|                               |                                       |   Levels: (1)(2)(S)(N) Filter Cutoff: (o)       |   Pattern: [ Up/Down v ]                |
|                               |                                       |   Filter Drive: (o)  Master Amp: (o)           |   Rate: ( o )   Octs: [1][2][3][4]      |
|                               |                                       |                                                 |                                         |
|                               |                                       |                                                 |   Vel Sens: <----|------------>         |
|                               |                                       |                                                 |                                         |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+
```
