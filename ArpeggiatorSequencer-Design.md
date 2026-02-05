# Vox Arpeggiator/Sequencer - Design Specification

## Overview

This document specifies the design for the Arpeggiator/Sequencer feature, including UI layout changes, parameter definitions, and interaction patterns. The design is inspired by the Roland SH-101's sequencer workflow, enhanced with visual feedback.

---

## UI Layout Restructure

### Current Layout (4-column horizontal, all controls visible)

The current UI displays all controls simultaneously without tabs. PERFORMANCE is a vertical
section in the rightmost column.

```
┌───────────────────────┬─────────────────────┬─────────────────────┬─────────────────────┐
│      OSCILLATORS      │       FILTER        │         LFO         │        MAIN         │
│  ┌─────────────────┐  │  ┌───────┬───────┐  │                     │  ┌───────────────┐  │
│  │ OSC1    OSC2    │  │  │  HP   │  LP   │  │  Wave: [∿][△][□][⚡] │  │ Preset Picker │  │
│  │ Tune Wave PW    │  │  │ Freq  │ Freq  │  │  Rate: (◐)          │  └───────────────┘  │
│  │ Octave  Detune  │  │  │ Res   │ Res   │  │  Phase: (◐)         │  Volume: (◐)        │
│  └─────────────────┘  │  │ Drive │ Drive │  │  Tempo: [1/16 ▼]    │  [====▓▓====] OUT   │
│  ┌─────────────────┐  │  │ Poles │ Poles │  │  Mod Amounts: (◐)×3 │                     │
│  │   SUB-OSC       │  │  └───────┴───────┘  │  Delay: (◐)         │                     │
│  │ Wave Oct PW     │  │                     │                     │                     │
│  └─────────────────┘  │                     │                     │                     │
├───────────┬───────────┤                     │                     ├─────────────────────┤
│    MIX    │  ENVELOPE │                     │                     │    PERFORMANCE      │
│  ════════ │  A D S R  │                     │                     │  LEGATO  [●]        │
│  OSC1 ║   │  ││││││││ │                     │                     │  GLIDE [Off|On|●]   │
│  OSC2 ║   │           │                     │                     │  Time (◐)           │
│  SUB  ║   │  Env Amt  │                     │                     │  ARPEGGIATOR (TODO) │
│  NOISE║   │  (◐)      │                     │                     │  VELOCITY ════      │
└───────────┴───────────┴─────────────────────┴─────────────────────┴─────────────────────┘
```

### New Layout (3-column, 2-row + full-width PERFORMANCE bottom)
```
┌─────────────────┬─────────────────┬─────────────────┬─────────────────┐
│   OSCILLATORS   │     FILTER      │       LFO       │      MAIN       │
│   (OSC1/2/SUB)  │    (LP / HP)    │                 │  Preset/Volume  │
├─────────────────┼─────────────────┼─────────────────┴─────────────────┤
│       MIX       │    ENVELOPE     │          (available space)        │
│  (OSC1/2/S/N)   │   (AMP/FILTER)  │     (or expand LFO/Envelope)      │
├─────────────────┴─────────────────┴───────────────────────────────────┤
│                              PERFORMANCE                               │
│   [Legato] [Glide] │ [OFF|ARP|SEQ] │ Step Buttons 1-8 │ Page │ Timing │
└───────────────────────────────────────────────────────────────────────┘
```

### Dimensions (estimated from current UI)
- **Total UI width**: ~1160px (content area)
- **PERFORMANCE strip height**: ~140-160px
- **Available width for step grid**: ~700-800px (after mode/timing controls)

---

## PERFORMANCE Section Layout

The full-width PERFORMANCE section is divided into functional zones:

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ PERFORMANCE                                                                                                │
├──────────────┬──────────────┬───────────────────────────────────────────────────────────┬──────────────────┤
│   VOICE      │    MODE      │                    STEP GRID                              │     TIMING       │
│              │              │                                                           │                  │
│  LEGATO      │  ┌────────┐  │  ┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐        │   SYNC           │
│  ┌────────┐  │  │  OFF   │  │  │ 1  ││ 2  ││ 3  ││ 4  ││ 5  ││ 6  ││ 7  ││ 8  │        │  ┌──────────┐    │
│  │   ●    │  │  │  ARP   │  │  │ +0 ││ +2 ││ +4 ││ +5 ││ +7 ││ +9 ││+11 ││+12 │        │  │ ● Free   │    │
│  └────────┘  │  │  SEQ ● │  │  └────┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘        │  │   1/16   │    │
│              │  └────────┘  │    ▓▓    ▓▓    ▓▓    ▓A    ▓▓    --    ▓T    ▓▓          │  └──────────┘    │
│  GLIDE       │              │                                                           │                  │
│  ┌────────┐  │  PATTERN     │   [◀ 1-8 ]  [ 9-16 ]  [ 17-24 ]  [ 25-32 ▶]              │   RATE           │
│  │Off|On |●│ │  (ARP only)  │                                                           │  ┌──────────┐    │
│  └────────┘  │  ┌────────┐  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                      │  │    ◐     │    │
│  ┌────────┐  │  │ ↑↓ ↕ ⚄ │  │  │ REC  │ │ REST │ │ TIE  │ │ ACC  │     LENGTH: 16 ▼    │  │   5.0Hz  │    │
│  │  TIME  │  │  └────────┘  │  └──────┘ └──────┘ └──────┘ └──────┘                      │  └──────────┘    │
│  │  (◐)   │  │              │                                                           │                  │
│  │  88ms  │  │  OCTAVE: 2   │  [▶ PLAY]  [■ STOP]  [✕ CLEAR]                           │  GATE: 75%       │
│  └────────┘  │  LATCH: OFF  │                                                           │  SWING: 0%       │
│              │              │                                                           │                  │
│  VEL  ACC    │              │                                                           │                  │
│  (◐)  (◐)    │              │                                                           │                  │
└──────────────┴──────────────┴───────────────────────────────────────────────────────────┴──────────────────┘

Legend:  ▓▓ = Gate ON (orange)   -- = Rest (dark)   A = Accent   T = Tie   ● = Active/Selected
```

### Step Grid Visibility

| Mode | Step Grid Behavior |
|------|-------------------|
| **OFF** | Hidden or grayed out |
| **ARP** | Grayed out, disabled (arp doesn't use step data) |
| **SEQ** | Fully active and interactive |

When in ARP mode, the step grid area should be visually dimmed and non-interactive
to indicate that step editing is not applicable to the arpeggiator.

---

## Step Button Design (Proposal C: Classic Buttons)

Each step is a clickable button showing:
- **Step number** (top, small)
- **Pitch offset** (center, prominent): -12 to +12 semitones
- **Gate indicator** (bottom bar): Orange = on, Dark = rest
- **Modifier badges**: "A" for accent, "T" for tie

### Single Step Button Anatomy
```
     44px wide
    ┌────────┐
    │   5    │  ← Step number (10px, gray)
    │        │
    │  +7    │  ← Pitch offset (18px, white)
    │        │
    │ ▓▓▓▓▓▓ │  ← Gate bar (orange if on)
    │   A    │  ← Modifier badge (if any)
    └────────┘
     ~70px tall
```

### Step Button States
| State | Appearance |
|-------|------------|
| **Gate ON** | Orange bottom bar, white pitch text |
| **Gate OFF (Rest)** | Dark bottom bar, dimmed pitch text |
| **Accent** | "A" badge, slightly brighter |
| **Tie** | "T" badge, connected visual to previous |
| **Current (playing)** | Orange glow/border animation |
| **Selected (editing)** | White border highlight |

### Step Interaction
| Gesture | Action |
|---------|--------|
| **Click** | Toggle gate on/off |
| **Drag up/down** | Adjust pitch offset (-12 to +12) |
| **Shift+Click** | Toggle accent |
| **Option+Click** | Toggle tie |
| **Double-click** | Reset step to default (+0, gate on) |

### Page Navigation
- 8 steps visible at once
- Page buttons: `[1-8]` `[9-16]` `[17-24]` `[25-32]`
- Or use `◀` `▶` arrows to shift by 8

---

## Parameter Specification

### Mode Parameters

| Parameter | Type | Values | Default | Description |
|-----------|------|--------|---------|-------------|
| `arpSeqMode` | Indexed | Off, Arp, Seq | Off | Main mode selector |
| `arpPattern` | Indexed | Up, Down, UpDown, UpDown+, Random, Order | Up | Arp note pattern |
| `arpOctaves` | Indexed | 1, 2, 3, 4 | 1 | Octave range for arp |
| `seqLength` | Integer | 1-32 | 16 | Active sequence length |
| `latch` | Boolean | Off, On | Off | Hold notes without keys |

### Timing Parameters (matches LFO)

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `arpSeqSyncMode` | Indexed | Free, Sync | Free | Timing mode |
| `arpSeqRate` | Float | 0.5 - 50.0 Hz | 5.0 Hz | Free-run rate |
| `arpSeqTempoRate` | Indexed | 4Bars...1/32 | 1/16 | Synced divisions |
| `arpSeqGate` | Float | 10% - 100% | 75% | Note duration |
| `arpSeqSwing` | Float | 0% - 75% | 0% | Shuffle amount |

### Velocity Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `arpSeqVelocity` | Float | 1 - 127 | 100 | Normal step velocity |
| `arpSeqAccentVelocity` | Float | 1 - 127 | 127 | Accent step velocity |

These two knobs control the MIDI velocity values used for normal and accented steps.
The accent velocity should typically be higher than normal velocity for emphasis.

### Tempo Rate Values (same as LFO)
```
4 Bars, 2 Bars, 1 Bar, 1/2, 1/2T, 1/4, 1/4., 1/4T, 
1/8, 1/8., 1/8T, 1/16, 1/16., 1/16T, 1/32
```

### Step Data (per step, 32 steps max)

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `step[n].pitch` | Integer | -12 to +12 | 0 | Semitone offset |
| `step[n].gate` | Boolean | Off, On | On | Note plays or rest |
| `step[n].tie` | Boolean | Off, On | Off | Legato to next |
| `step[n].accent` | Boolean | Off, On | Off | Trigger accent |

**Note**: Step data could be stored as a single blob parameter or as 32×4 = 128 individual parameters. Blob is more practical for presets.

### Voice Parameters (existing, moved to PERFORMANCE)

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `legato` | Boolean | Off, On | On | Legato mode |
| `glideMode` | Indexed | Off, On, Auto | Auto | Glide behavior |
| `glideTime` | Float | 1ms - 500ms | 88ms | Portamento time |
| `velocitySens` | Float | 0% - 100% | 0% | Velocity sensitivity |

---

## Transposition Behavior (SH-101 Style)

### Reference Note
- **C3 (MIDI note 60)** = No transposition
- Playing C4 transposes sequence up 12 semitones
- Playing A2 transposes sequence down 3 semitones

### Transpose Modes
| Mode | Behavior |
|------|----------|
| **ARP** | Held notes become the arpeggio; no transposition concept |
| **SEQ** | Single received note transposes entire sequence |

- Enables smooth "Moroder bass" key changes

### Legato Transpose
When `legato` is ON and sequence is running:
- New note changes transposition without retriggering envelope
- Very similar to normal transpose

---

## Transport & State Machine

### Arp/Seq State Machine

The arpeggiator/sequencer has three states that govern its behavior:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         ARP/SEQ STATE MACHINE                            │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────┐      [Mode Button]       ┌─────────┐                      │
│   │   OFF   │ ─────────────────────►   │ ENABLED │ ◄──────────────┐     │
│   │  (0)    │ ◄─────────────────────   │   (1)   │                │     │
│   └─────────┘      [Mode Button]       └────┬────┘                │     │
│        ▲                                    │                     │     │
│        │                     [Play Button OR Transport Starts]    │     │
│        │                                    │                     │     │
│        │           [Mode Button]            ▼                     │     │
│        └─────────────────────────────  ┌─────────┐                │     │
│                                        │ RUNNING │                │     │
│                                        │   (2)   │ ───────────────┘     │
│                                        └─────────┘                      │
│                                              [Transport Stops]          │
│                                                                          │
│   Note: Play button in ENABLED starts sequencer independently of        │
│   transport. This allows tweaking sequences when transport is stopped.  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### State Descriptions

| State | Description |
|-------|-------------|
| **OFF (0)** | Arp/Seq disabled. Transport events are ignored. Mode button → ENABLED. |
| **ENABLED (1)** | Waiting for trigger. Play button OR transport start → RUNNING. Mode button → OFF. |
| **RUNNING (2)** | Actively stepping through pattern. Transport stop → ENABLED. Mode button → OFF. |

### Key Behaviors

1. **Play button for standalone operation**: Press Play in ENABLED state to start the sequencer without needing DAW transport. This allows ergonomic tweaking of sequences.

2. **Transport start auto-triggers**: If in ENABLED state and DAW transport starts, sequencer automatically transitions to RUNNING and syncs to beat position.

3. **Play button behavior**: Starts the sequencer in free-run mode, independent of DAW transport. If transport is running, syncs to it.

4. **Mode button is the kill switch**: From any state, pressing Mode button (to OFF) immediately stops all notes and returns to OFF state.

### Transport Sync Behavior

When in RUNNING state with tempo sync enabled:

| Event | Behavior |
|-------|----------|
| **Transport starts** | Reset to step 1, sync phase to beat position |
| **Transport stops** | Continue running at last known tempo |
| **Tempo change** | Immediately adjust step rate |
| **Song position jump** | Recalculate step position from beat position |

---

## Recording Workflow

### Real-time Recording (SH-101 style)

Recording is a step-by-step process, not real-time capture. Each input event adds one step.

**Recording State Machine:**
```
┌─────────────────────────────────────────────────────────────────────────┐
│                         RECORDING STATE MACHINE                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   IDLE ──[REC pressed]──► RECORDING ──[REC/STOP pressed]──► IDLE        │
│                               │                                          │
│                               │ On entry: Clear sequence, length = 0     │
│                               │                                          │
│                               ▼                                          │
│                     ┌─────────────────┐                                  │
│                     │ Waiting for     │                                  │
│                     │ input event...  │                                  │
│                     └────────┬────────┘                                  │
│                              │                                           │
│          ┌───────────────────┼───────────────────┐                      │
│          │                   │                   │                      │
│          ▼                   ▼                   ▼                      │
│    [MIDI Note]          [REST btn]          [TIE btn]                   │
│         │                    │                   │                      │
│         ▼                    ▼                   ▼                      │
│   Add step:             Add step:           Set tie=true                │
│   pitch = note - 60     gate = OFF          on PREVIOUS step            │
│   gate = ON             pitch = 0           (no new step)               │
│   length++              length++                                        │
│                                                                          │
│   [ACC btn]: Sets accent flag for NEXT recorded step                    │
│   [Max 32 steps]: After 32, wrap to step 1 (overdub)                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Example Recording Session:**
```
Action                      Result
──────────────────────────  ──────────────────────────────────
Press [REC]                 Enter recording, length = 0
Hit C2 on keyboard          Step 1: pitch=-12, gate=ON, length=1
Hit E2 on keyboard          Step 2: pitch=-8, gate=ON, length=2
Press [REST]                Step 3: pitch=0, gate=OFF, length=3
Hit B3 on keyboard          Step 4: pitch=11, gate=ON, length=4
Press [TIE]                 Step 4: tie=true (extends into step 5)
Hit B5 on keyboard          Step 5: pitch=35, gate=ON, length=5
Hit E2 on keyboard          Step 6: pitch=-8, gate=ON, length=6
Hit A1 on keyboard          Step 7: pitch=-15, gate=ON, length=7
Press [REST]                Step 8: pitch=0, gate=OFF, length=8
Press [REC]                 Exit recording, final length=8
```

### Step Edit Mode (mouse/touch)
1. Click step to toggle gate on/off
2. Drag up/down on step to change pitch offset
3. Shift+Click to toggle accent
4. Option+Click to toggle tie
5. Double-click to reset step to default (+0, gate on)

### Transport Controls
| Button | Action |
|--------|--------|
| **▶ PLAY** | Transition to RUNNING state (starts from step 1) |
| **■ STOP** | Transition to ENABLED state, reset to step 1 |
| **● REC** | Toggle record mode (clears sequence on entry) |
| **✕ CLEAR** | Clear all steps to default (gate on, pitch 0, no tie/accent) |

---

## Visual Feedback

### Current Step Indicator
- Playing step has **orange pulsing glow**
- Border animates on each trigger
- Gate bar "lights up" brighter momentarily

### Recording Indicator
- **REC** button glows red when active
- Step being recorded flashes
- New steps appear as they're added

### Transpose Display
- Small indicator showing current transpose offset
- Example: "T: +5" when playing F3

---

## Implementation Notes

### SyncablePhaseRamp Architecture

A key architectural decision is to create a reusable **SyncablePhaseRamp** class that provides
a normalized 0.0-1.0 phase ramp, which can be used as input to both the LFO and the Sequencer.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      SyncablePhaseRamp Component                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Inputs:                          Outputs:                              │
│   ├─ sampleRate                    ├─ phase (0.0 - 1.0)                 │
│   ├─ rate (Hz, free-run mode)      ├─ wrapped (bool, true when wraps)   │
│   ├─ beatDivision (sync mode)      └─ stepIndex (integer step number)   │
│   ├─ tempo (BPM)                                                        │
│   ├─ syncMode (Free/Sync)                                               │
│   ├─ phaseOffset (0.0 - 1.0)                                            │
│   └─ transportState                                                      │
│                                                                          │
│   Methods:                                                               │
│   ├─ process() → advances phase, returns current phase                  │
│   ├─ reset() → resets phase to 0 + offset                               │
│   ├─ syncToBeatPosition(beatPos) → calculates phase from song position  │
│   └─ setTempo(bpm) → updates tempo for sync mode                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              │ phase output
                              ▼
         ┌────────────────────┴────────────────────┐
         │                                         │
         ▼                                         ▼
   ┌───────────┐                           ┌─────────────┐
   │    LFO    │                           │  Sequencer  │
   │           │                           │             │
   │ Applies   │                           │ Converts    │
   │ waveform  │                           │ phase to    │
   │ shaping   │                           │ step index  │
   │ (sin,tri, │                           │             │
   │ sq, etc)  │                           │ stepIndex = │
   │           │                           │ floor(phase │
   │ Output:   │                           │ × length)   │
   │ -1 to +1  │                           │             │
   └───────────┘                           └─────────────┘
```

**Benefits of this architecture:**
1. **Separation of concerns**: Sync/phase logic is decoupled from LFO shaping and step sequencing
2. **Shared transport handling**: Both LFO and Sequencer use the same beat position sync logic
3. **Easier testing**: PhaseRamp can be unit tested independently
4. **Future-proof**: Easy to add new features that need tempo-synced timing (e.g., delay, tremolo)

**Integration with existing LFO:**
The current `LFO.h` already has `syncToBeatPosition()` logic. This can be refactored to use
the new SyncablePhaseRamp internally, maintaining API compatibility.

### DSP Requirements
- **Clock sync**: Must receive host tempo and transport state via existing DSPKernel infrastructure
- **Sample-accurate timing**: Step triggers aligned to musical grid
- **Swing implementation**: Delay even-numbered steps by swing percentage
- **Gate timing**: Note-off scheduled based on gate length %
- **Leverage existing transport detection**: Use `AUHostTransportStateMoving` flag already implemented in DSPKernel

### Parameter Addressing
Suggest grouping as:
- `performance.legato`
- `performance.glide.mode`
- `performance.glide.time`
- `performance.velocity`
- `arpseq.mode`
- `arpseq.pattern`
- `arpseq.sync`
- `arpseq.rate`
- `arpseq.tempoRate`
- `arpseq.gate`
- `arpseq.swing`
- `arpseq.latch`
- `arpseq.length`
- `arpseq.octaves`
- `arpseq.velocity` (normal step velocity)
- `arpseq.accentVelocity` (accent step velocity)
- `arpseq.steps` (blob or array)

### UI Components Needed
1. **StepButton** - Custom button with pitch/gate/modifiers
2. **StepGrid** - HStack of 8 StepButtons with page navigation
3. **ModeSelector** - 3-way toggle (Off/Arp/Seq)
4. **PatternSelector** - Arp pattern picker
5. **TransportBar** - Play/Stop/Rec/Clear buttons
6. **TimingPanel** - Sync toggle, rate knob, gate/swing sliders

---

## ASCII Mockup - Full Interface (Proposed with Arp/Seq)

Note: The upper section reflects the CURRENT UI (no tabs, all controls visible).
The PERFORMANCE section shows the PROPOSED new layout.

```
┌───────────────────────────┬─────────────────────────────┬─────────────────────────┬─────────────────────────┐
│       OSCILLATORS         │           FILTER            │           LFO           │          MAIN           │
│  ┌──────────────────────┐ │  ┌───────────┬───────────┐  │                         │  PRESET                 │
│  │ OSC1      OSC2       │ │  │    HP     │    LP     │  │  Wave: [∿][△][□][⚡]    │  ┌─────────────────┐    │
│  │ Tune Wave  Tune Wave │ │  │ Freq  Res │ Freq  Res │  │                         │  │  Init Patch ▼   │    │
│  │ (◐) [∿]   (◐) [∿]   │ │  │ (◐)  (◐) │ (◐)  (◐) │  │  Rate: (◐) 2.0 Hz       │  └─────────────────┘    │
│  │ PW   Oct   PW   Oct  │ │  │ Drive Pol │ Drive Pol │  │  Phase: (◐)             │                         │
│  │ (◐) [-1]  (◐) [+0]  │ │  │ (◐) [4]  │ (◐) [4]  │  │  Tempo: [1/16 ▼]        │  MASTER                 │
│  └──────────────────────┘ │  └───────────┴───────────┘  │                         │  Volume: (◐) -6dB      │
│  ┌──────────────────────┐ │                             │  Mod Amounts:           │  [====▓▓====] OUT       │
│  │ SUB-OSCILLATOR       │ │                             │  OSC (◐) FLT (◐)       │                         │
│  │ Wave (◐)  Oct [-2]   │ │                             │  PWM (◐)               │                         │
│  └──────────────────────┘ │                             │  Delay: (◐) 0ms         │                         │
├───────────┬───────────────┤                             │                         │                         │
│    MIX    │   ENVELOPE    │                             │                         │                         │
│  ════════ │  A   D   S  R │                             │                         │                         │
│  OSC1 ║   │  ││  ││  ││ │││                             │                         │                         │
│  OSC2 ║   │               │                             │                         │                         │
│  SUB  ║   │  Env Amt (◐)  │                             │                         │                         │
│  NOISE║   │               │                             │                         │                         │
├───────────┴───────────────┴─────────────────────────────┴─────────────────────────┴─────────────────────────┤
│ PERFORMANCE                                                                                                  │
├────────────┬─────────────┬──────────────────────────────────────────────────────────────────┬───────────────┤
│   VOICE    │    MODE     │                         SEQUENCER                                │    TIMING     │
│            │             │  (grayed out when mode = ARP)                                    │               │
│  LEGATO    │ ┌─────────┐ │  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐       │  SYNC         │
│   [●]      │ │   OFF   │ │  │ 1  │ │ 2  │ │ 3  │ │ 4  │ │ 5  │ │ 6  │ │ 7  │ │ 8  │       │ [●Free][1/16] │
│            │ │   ARP   │ │  │ +0 │ │ +2 │ │ +4 │ │ +5 │ │ +7 │ │ +9 │ │+11 │ │+12 │       │               │
│  GLIDE     │ │   SEQ ● │ │  │▓▓▓▓│ │▓▓▓▓│ │▓▓▓▓│ │▓▓A▓│ │▓▓▓▓│ │    │ │▓▓T▓│ │▓▓▓▓│       │  RATE         │
│ [Off|On|●] │ └─────────┘ │  └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘       │  (◐) 5.0 Hz   │
│            │             │                                                                  │               │
│  TIME      │ ARP PATTERN │    [1-8]  [9-16]  [17-24]  [25-32]      LENGTH: [16 ▼]          │  GATE         │
│  (◐) 88ms  │ [↑][↓][↕][⚄]│                                                                  │  (◐) 75%      │
│            │             │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                            │               │
│  VEL  ACC  │ OCTAVE: [2] │  │● REC │ │ REST │ │ TIE  │ │ ACC  │   [▶ PLAY] [■ STOP] [CLR] │  SWING        │
│  (◐)  (◐)  │ LATCH: [○]  │  └──────┘ └──────┘ └──────┘ └──────┘                            │  (◐) 0%       │
└────────────┴─────────────┴──────────────────────────────────────────────────────────────────┴───────────────┘
```

---

## Summary

### New Parameters Added: ~15-20
- Mode, Pattern, Sync, Rate, TempoRate, Gate, Swing, Latch, Length, Octaves
- Step data (32 steps × 4 properties, stored as blob)

### UI Changes Required
1. Move PERFORMANCE from right column to full-width bottom row
2. Add StepButton grid component
3. Add transport controls
4. Add page navigation for steps
5. Reclaim right-column space (could expand LFO mod destinations or leave empty)

### Implementation Phases
1. **Phase 1**: UI restructure - move PERFORMANCE to bottom
2. **Phase 2**: Arpeggiator with timing sync
3. **Phase 3**: Step sequencer with recording
4. **Phase 4**: Polish and preset integration

---

## Testing Strategy

Tests are written alongside implementation using Swift Testing framework. Each phase includes corresponding tests.

### Test File Locations

| Component | Test File | Location |
|-----------|-----------|----------|
| Arpeggiator DSP | `ArpeggiatorTests.swift` | `VoxCoreTests/` |
| Sequencer DSP | `SequencerTests.swift` | `VoxCoreTests/` |
| Clock/Timing | `ArpSeqClockTests.swift` | `VoxCoreTests/` |
| Integration | `ArpSeqIntegrationTests.swift` | `VoxCoreTests/` |
| UI Components | `ArpSeqUITests.swift` | `VoxTests/` |
| Parameter Sync | `ArpSeqParameterTests.swift` | `VoxTests/` |

---

### Unit Tests: Arpeggiator (ArpeggiatorTests.swift)

```swift
import Testing
@testable import VoxCore

@Suite("Arpeggiator Tests")
struct ArpeggiatorTests {
    
    // MARK: - Pattern Tests
    
    @Test("Up pattern produces ascending notes")
    func testUpPattern() {
        // Hold C, E, G → should produce C, E, G, C, E, G...
    }
    
    @Test("Down pattern produces descending notes")
    func testDownPattern() {
        // Hold C, E, G → should produce G, E, C, G, E, C...
    }
    
    @Test("UpDown pattern ping-pongs without repeating edges")
    func testUpDownPattern() {
        // Hold C, E, G → should produce C, E, G, E, C, E, G...
    }
    
    @Test("UpDown+ pattern repeats notes at edges")
    func testUpDownPlusPattern() {
        // Hold C, E, G → should produce C, E, G, G, E, C, C, E, G...
    }
    
    @Test("Random pattern produces all held notes")
    func testRandomPattern() {
        // Hold C, E, G → over N iterations, all three should appear
    }
    
    @Test("Order pattern follows key press order")
    func testOrderPattern() {
        // Press E, then C, then G → should produce E, C, G, E, C, G...
    }
    
    // MARK: - Octave Range Tests
    
    @Test("Octave range 1 stays within original octave")
    func testOctaveRange1() {
        // Hold C4 with octave=1 → only C4
    }
    
    @Test("Octave range 2 spans two octaves")
    func testOctaveRange2() {
        // Hold C4 with octave=2 → C4, C5 in pattern
    }
    
    @Test("Octave range 4 spans four octaves")
    func testOctaveRange4() {
        // Hold C4 with octave=4 → C4, C5, C6, C7
    }
    
    // MARK: - Note Handling Tests
    
    @Test("Adding notes updates arp immediately")
    func testAddNotes() {
        // Start with C, add E → should include E in next cycle
    }
    
    @Test("Removing notes updates arp immediately")
    func testRemoveNotes() {
        // Start with C, E, G, release E → should only cycle C, G
    }
    
    @Test("All notes released stops arp")
    func testAllNotesReleased() {
        // Release all → no output
    }
    
    @Test("Latch mode holds notes after release")
    func testLatchMode() {
        // Enable latch, press C, release C → should continue arp
    }
}
```

---

### Unit Tests: Sequencer (SequencerTests.swift)

```swift
import Testing
@testable import VoxCore

@Suite("Sequencer Tests")
struct SequencerTests {
    
    // MARK: - Step Data Tests
    
    @Test("Step pitch offset applies correctly")
    func testStepPitchOffset() {
        // Step with +7 offset, input C4 → outputs G4 (MIDI 67)
    }
    
    @Test("Step pitch offset negative values work")
    func testStepPitchOffsetNegative() {
        // Step with -5 offset, input C4 → outputs G3 (MIDI 55)
    }
    
    @Test("Rest step produces no note")
    func testRestStep() {
        // Step with gate=off → no noteOn triggered
    }
    
    @Test("Tie step extends previous note")
    func testTieStep() {
        // Step 1: note, Step 2: tie → no noteOff between, no retrigger
    }
    
    @Test("Accent step triggers higher velocity")
    func testAccentStep() {
        // Step with accent → velocity = accent velocity (e.g., 127)
    }
    
    // MARK: - Transposition Tests (SH-101 Style)
    
    @Test("C3 input produces no transposition")
    func testC3NoTranspose() {
        // Input C3 (MIDI 60), step offset +0 → outputs C3
    }
    
    @Test("Input note transposes sequence")
    func testTransposition() {
        // Input E3 (MIDI 64), step offset +0 → outputs E3 (+4 from reference)
    }
    
    @Test("Transposition stacks with step offset")
    func testTranspositionPlusOffset() {
        // Input E3 (+4 from C3), step offset +7 → outputs B3 (+11 total)
    }
    
    @Test("Legato transpose changes pitch without retrigger")
    func testLegatoTranspose() {
        // Sequence running, legato on, new input note → pitch changes, envelope continues
    }
    
    // MARK: - Sequence Length Tests
    
    @Test("Sequence wraps at length boundary")
    func testSequenceWrap() {
        // Length=4, advance through 1,2,3,4,1,2,3,4...
    }
    
    @Test("Changing length mid-playback wraps correctly")
    func testLengthChange() {
        // At step 8, change length to 4 → should wrap to step 1
    }
    
    // MARK: - Recording Tests
    
    @Test("Recording adds steps from MIDI input")
    func testRecordingAddsSteps() {
        // Enter record, play C3, play E3 → steps 1=+0, 2=+4
    }
    
    @Test("Rest button inserts rest step")
    func testRecordRest() {
        // Enter record, play C, press REST, play E → step 2 is rest (gate off)
    }
    
    @Test("Tie button extends previous step")
    func testRecordTie() {
        // Enter record, play C, press TIE → step 2 has tie=true
    }
    
    @Test("Clear resets all steps to default")
    func testClear() {
        // Record sequence, call clear → all steps = +0, gate on, no tie/accent
    }
}
```

---

### Unit Tests: Clock/Timing (ArpSeqClockTests.swift)

```swift
import Testing
@testable import VoxCore

@Suite("Arp/Seq Clock Tests")
struct ArpSeqClockTests {
    
    let sampleRate = 44100.0
    
    // MARK: - Free Run Mode Tests
    
    @Test("Free run rate produces correct step frequency")
    func testFreeRunRate() {
        // Rate = 10 Hz, 44100 sample rate → step every 4410 samples
        let samplesPerStep = Int(sampleRate / 10.0)
        #expect(samplesPerStep == 4410)
    }
    
    @Test("Free run rate limits are enforced")
    func testFreeRunRateLimits() {
        // Rate < 0.5 → clamped to 0.5
        // Rate > 50 → clamped to 50
    }
    
    // MARK: - Tempo Sync Mode Tests
    
    @Test("Quarter note sync at 120 BPM produces 2 Hz")
    func testQuarterNoteSync() {
        // 120 BPM = 2 beats/sec, quarter note = 1 beat → 2 Hz
    }
    
    @Test("Sixteenth note sync at 120 BPM produces 8 Hz")
    func testSixteenthNoteSync() {
        // 120 BPM, 1/16 note = 4 per beat → 8 Hz
    }
    
    @Test("Triplet divisions calculate correctly")
    func testTripletDivisions() {
        // 120 BPM, 1/8T → 3 per beat = 6 Hz
    }
    
    @Test("Dotted divisions calculate correctly")
    func testDottedDivisions() {
        // 120 BPM, 1/8. (dotted eighth) → 1.5 eighths per beat
    }
    
    @Test("All beat divisions produce valid frequencies")
    func testAllBeatDivisions() {
        // Iterate through all 15 divisions, verify rate > 0, no crashes
    }
    
    // MARK: - Swing Tests
    
    @Test("Swing 0% produces even timing")
    func testSwingZero() {
        // Steps 1,2,3,4 evenly spaced
    }
    
    @Test("Swing 50% delays even steps")
    func testSwing50() {
        // Even-numbered steps delayed by 50% of step duration
    }
    
    @Test("Swing only affects even-numbered steps")
    func testSwingEvenStepsOnly() {
        // Odd steps: no delay. Even steps: delayed by swing amount
    }
    
    // MARK: - Gate Length Tests
    
    @Test("Gate 100% holds full step duration")
    func testGate100() {
        // noteOff occurs at next step trigger
    }
    
    @Test("Gate 50% holds half step duration")
    func testGate50() {
        // noteOff at 50% through step
    }
    
    @Test("Gate 10% produces staccato")
    func testGate10() {
        // noteOff at 10% through step
    }
    
    // MARK: - Transport Tests
    
    @Test("Play starts from step 1")
    func testPlayStart() {
        // Press play → first step triggered is step 1
    }
    
    @Test("Stop resets to step 1")
    func testStopReset() {
        // Play to step 5, stop → internal position resets
    }
    
    @Test("Tempo change mid-playback adjusts timing")
    func testTempoChange() {
        // Playing at 120 BPM, change to 60 BPM → step rate halves
    }
}
```

---

### Integration Tests (ArpSeqIntegrationTests.swift)

```swift
import Testing
@testable import VoxCore

@Suite("Arp/Seq Integration Tests")
struct ArpSeqIntegrationTests {
    
    // MARK: - Voice Integration Tests
    
    @Test("Arpeggiator triggers voice noteOn/noteOff")
    func testArpTriggersVoice() {
        var voice = MonophonicVoice(44100.0, .POLYBLEP)
        // Configure arp mode, hold notes, process samples
        // Verify envelope triggers, RMS > threshold
    }
    
    @Test("Sequencer triggers voice with correct pitch")
    func testSeqTriggersVoice() {
        var voice = MonophonicVoice(44100.0, .POLYBLEP)
        // Configure seq mode, input note, process samples
        // Verify output pitch matches input + step offset
    }
    
    @Test("Accent affects velocity and filter response")
    func testAccentAffectsFilter() {
        // Accent step with velocity sensitivity → brighter sound
    }
    
    @Test("Gate length affects envelope timing")
    func testGateLengthAffectsEnvelope() {
        // Short gate → release phase starts earlier
    }
    
    // MARK: - Mode Switching Tests
    
    @Test("Switching modes mid-playback doesn't crash")
    func testModeSwitchStability() {
        // Play arp, switch to seq, switch to off rapidly
    }
    
    @Test("Switching to OFF stops all notes immediately")
    func testModeOffStopsNotes() {
        // Playing arp, switch to OFF → noteOff sent, output decays
    }
    
    // MARK: - Preset Persistence Tests
    
    @Test("Step data survives parameter save/load")
    func testStepDataPersistence() {
        // Record sequence, get state, restore state → sequence matches
    }
    
    @Test("Arp settings survive parameter save/load")
    func testArpSettingsPersistence() {
        // Configure pattern/octaves/rate, save, load → matches
    }
    
    // MARK: - Real-time Safety Tests
    
    @Test("Processing is deterministic")
    func testDeterministicProcessing() {
        // Same input → same output (excluding random pattern)
    }
    
    @Test("Rapid parameter changes don't cause glitches")
    func testRapidParameterChanges() {
        // While playing, change pattern/rate/length rapidly
        // Verify audio output remains valid (no NaN, no extreme values)
    }
}
```

---

### UI Tests (ArpSeqUITests.swift)

```swift
import Testing
@testable import Vox

@Suite("Arp/Seq UI Tests")
struct ArpSeqUITests {
    
    // MARK: - Step Button Display Tests
    
    @Test("Step button displays pitch offset correctly")
    func testStepButtonPitchDisplay() {
        // Step with offset +7 → shows "+7" text
        // Step with offset -3 → shows "-3" text
        // Step with offset 0 → shows "+0" or "0"
    }
    
    @Test("Step button shows gate state")
    func testStepButtonGateState() {
        // Gate on: orange bar visible
        // Gate off: dark/dim bar
    }
    
    @Test("Step button shows accent badge")
    func testStepButtonAccentBadge() {
        // Accent true → "A" badge visible
    }
    
    @Test("Step button shows tie badge")
    func testStepButtonTieBadge() {
        // Tie true → "T" badge visible
    }
    
    // MARK: - Step Button Interaction Tests
    
    @Test("Click toggles gate state")
    func testClickTogglesGate() {
        // Gate on, simulate click → gate becomes off
        // Click again → gate becomes on
    }
    
    @Test("Vertical drag adjusts pitch offset")
    func testDragAdjustsPitch() {
        // Simulate drag up → pitch increases
        // Simulate drag down → pitch decreases
        // Verify clamped to -12...+12
    }
    
    @Test("Pitch drag clamps to valid range")
    func testPitchDragClamping() {
        // Drag far up → clamped to +12
        // Drag far down → clamped to -12
    }
    
    // MARK: - Page Navigation Tests
    
    @Test("Page buttons select correct step range")
    func testPageButtons() {
        // Click [1-8] → shows steps 1-8
        // Click [9-16] → shows steps 9-16
    }
    
    @Test("Page tracks current playing step")
    func testPageAutoTracking() {
        // Playing step 12 → page shows 9-16 automatically
    }
    
    // MARK: - Parameter Binding Tests
    
    @Test("Mode selector updates AudioUnit parameter")
    func testModeSelectorBinding() {
        // Select SEQ → arpSeqMode parameter value updates
    }
    
    @Test("Rate knob updates AudioUnit parameter")
    func testRateKnobBinding() {
        // Rotate knob → arpSeqRate parameter changes
    }
    
    @Test("Parameter automation updates UI")
    func testAutomationUpdatesUI() {
        // External parameter change → UI reflects new value
    }
}
```

---

### Parameter Tests (ArpSeqParameterTests.swift)

```swift
import Testing
@testable import Vox

@Suite("Arp/Seq Parameter Tests")
struct ArpSeqParameterTests {
    
    // MARK: - Parameter Registration
    
    @Test("All arp/seq parameters exist in tree")
    func testParametersRegistered() {
        // Verify parameter tree includes:
        // arpSeqMode, arpPattern, arpSeqSyncMode, arpSeqRate,
        // arpSeqTempoRate, arpSeqGate, arpSeqSwing, latch,
        // seqLength, arpOctaves
    }
    
    @Test("Parameters have correct value ranges")
    func testParameterRanges() {
        // arpSeqRate: 0.5...50.0
        // arpSeqGate: 0.1...1.0 (10%...100%)
        // arpSeqSwing: 0.0...0.75 (0%...75%)
    }
    
    @Test("Parameters have correct default values")
    func testParameterDefaults() {
        // arpSeqMode: 0 (Off)
        // arpSeqRate: 5.0
        // arpSeqGate: 0.75 (75%)
    }
    
    // MARK: - Step Data Encoding
    
    @Test("Step data encodes to blob correctly")
    func testStepDataEncode() {
        // Create step data, encode → valid Data object
    }
    
    @Test("Step data decodes from blob correctly")
    func testStepDataDecode() {
        // Encode then decode → values match original
    }
    
    @Test("Invalid step data handled gracefully")
    func testInvalidStepData() {
        // Decode corrupted data → resets to defaults, no crash
    }
    
    @Test("Step data blob has expected size")
    func testStepDataSize() {
        // 32 steps × (pitch:Int8 + flags:UInt8) = 64 bytes minimum
    }
}
```

---

### Test Execution

Run all tests:
```bash
./test.sh
```

Run specific arp/seq test suites:
```bash
# Run just arpeggiator tests
xcodebuild test -scheme VoxCore -only-testing:VoxCoreTests/ArpeggiatorTests

# Run just sequencer tests
xcodebuild test -scheme VoxCore -only-testing:VoxCoreTests/SequencerTests

# Run clock/timing tests
xcodebuild test -scheme VoxCore -only-testing:VoxCoreTests/ArpSeqClockTests

# Run integration tests
xcodebuild test -scheme VoxCore -only-testing:VoxCoreTests/ArpSeqIntegrationTests
```

---

### Test-Driven Development Workflow

For each implementation phase:

1. **Write failing tests first** for the component being built
2. **Implement minimum code** to make tests pass
3. **Refactor** while keeping tests green
4. **Add edge case tests** discovered during implementation
5. **Run full suite** before committing

### Phase-Test Mapping

| Phase | Test Files to Create First |
|-------|---------------------------|
| Phase 1 (UI Restructure) | UI layout tests (manual verification) |
| Phase 2 (Arpeggiator) | `ArpeggiatorTests.swift`, `ArpSeqClockTests.swift` |
| Phase 3 (Sequencer) | `SequencerTests.swift`, `ArpSeqIntegrationTests.swift` |
| Phase 4 (Polish) | `ArpSeqParameterTests.swift`, `ArpSeqUITests.swift` |

### Coverage Goals

| Component | Target Coverage |
|-----------|-----------------|
| Clock/Timing | 95%+ |
| Arpeggiator patterns | 90%+ |
| Sequencer step logic | 90%+ |
| Transposition | 95%+ |
| UI bindings | 80%+ |
| Integration | 85%+ |

### Test Patterns (Following Existing Codebase)

Based on existing tests like `LFOTests.swift` and `HostTempoSyncTests.swift`:

- Use `MonophonicVoice` for integration tests requiring audio processing
- Process sufficient samples for reliable measurements (minimum 1000 samples)
- Use RMS calculations to verify audio output presence
- Test parameter limits are enforced (clamping behavior)
- Verify no crashes with edge case inputs
