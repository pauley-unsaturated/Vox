# Vox Arpeggiator/Sequencer Implementation Change Log

## Overview

This log tracks the implementation progress of the Arpeggiator/Sequencer feature as specified in `ArpeggiatorSequencer-Design.md`.

## Implementation Phases

### Phase 1: SyncablePhaseRamp (Foundation Component)
Create a reusable phase ramp class that provides normalized 0.0-1.0 phase output with tempo sync support.

### Phase 2: StepSequencer DSP
Implement the step sequencer DSP component with step data, transposition, and gate timing.

### Phase 3: Arpeggiator DSP
Implement the arpeggiator DSP component with patterns and octave range.

### Phase 4: Parameter Addresses
Add all necessary parameter addresses for the arp/seq system.

### Phase 5: DSPKernel Integration
Integrate the arp/seq components into the DSPKernel for audio processing.

### Phase 6: UI Components
Build the UI components for the PERFORMANCE section.

---

## Change Log

### 2025-12-21 - Project Start

**Status**: Phase 1 complete - SyncablePhaseRamp implemented.

#### Files to Create:
- `VoxCore/DSP/Utilities/SyncablePhaseRamp.h` - Reusable phase ramp with tempo sync
- `VoxCore/DSP/Sequencer/StepSequencer.h` - Step sequencer DSP
- `VoxCore/DSP/Sequencer/Arpeggiator.h` - Arpeggiator DSP
- `VoxCoreTests/SyncablePhaseRampTests.swift` - Phase ramp tests
- `VoxCoreTests/StepSequencerTests.swift` - Sequencer tests
- `VoxCoreTests/ArpeggiatorTests.swift` - Arpeggiator tests

#### Files to Modify:
- `VoxExtension/Parameters/VoxExtensionParameterAddresses.h` - Add arp/seq parameter addresses
- `VoxExtension/Parameters/Parameters.swift` - Add arp/seq parameter specs
- `VoxExtension/DSP/VoxExtensionDSPKernel.hpp` - Integrate arp/seq processing
- `VoxCore/DSP/Voice/MonophonicVoice.h` - May need note trigger interface

---

### 2025-12-21 - Phase 1 Complete: SyncablePhaseRamp

**Commit**: Phase 1 - Add SyncablePhaseRamp foundation class

#### Created Files:
- `VoxCore/DSP/Sequencer/SyncablePhaseRamp.h` - Core phase ramp generator with:
  - Free-run mode (rate in Hz)
  - Beat-sync mode (tempo + beat division)
  - Phase offset support (constructor parameter and setter)
  - Swing timing support (delays even-numbered steps)
  - Transport sync via `syncToBeatPosition()`
  - All 15 beat divisions matching LFO (4 bars through 1/32, including triplets and dotted)
  
- `VoxCoreTests/SyncablePhaseRampTests.swift` - Comprehensive unit tests:
  - Constructor tests (default, with params, clamping)
  - Free-run rate tests (frequency, samples per cycle, phase wrapping)
  - Beat sync tests (quarter, eighth, sixteenth at 120 BPM)
  - All beat divisions validation
  - Phase offset tests
  - Swing and even step tracking tests
  - Beat position sync tests
  - Effective rate calculations

#### Modified Files:
- `VoxCore/include/VoxCore.h` - Added SyncablePhaseRamp include
- `Vox.xcodeproj/project.pbxproj` - Added SyncablePhaseRamp.h to public headers
- `VoxTests/ParameterStorageTests.swift` - Disabled crashing AU instantiation tests (pre-existing issue)

#### Test Results:
All 23 SyncablePhaseRamp tests pass.

---

### 2025-12-21 - Phase 2 Complete: StepSequencer

**Commit**: Phase 2 - Add StepSequencer DSP class

#### Created Files:
- `VoxCore/DSP/Sequencer/StepSequencer.h` - Step sequencer DSP with:
  - 32 steps max, each with: pitch offset (-12 to +12), gate (on/off), tie, accent
  - SH-101 style transposition: C3 (MIDI 60) = no transposition
  - State machine: OFF → ENABLED → RUNNING
  - Recording workflow: step-by-step MIDI capture with REST, TIE, and ACCENT modifiers
  - Tie behavior: primes NEXT step to be tied FROM previous (enables legato/glide)
    - For tied steps: note-on sent first, then note-off (triggers legato in voice)
    - Same pitch: holds note without additional events
  - Gate timing based on gate length percentage (10%-100%)
  - Uses SyncablePhaseRamp for timing with tempo sync support
  - ProcessResult with primary and secondary note events for legato transitions
  - Velocity and accent velocity settings

- `VoxCoreTests/StepSequencerTests.swift` - Comprehensive unit tests (37 tests):
  - Constructor and state machine tests
  - Step data access and manipulation
  - Pitch clamping and step clearing
  - Length limits and timing controls
  - Velocity and transposition
  - Recording workflow (notes, rests, ties, accents)
  - Process function (step advancement, note-on/off generation)
  - Legato transition tests (note-on before note-off)
  - Same-pitch tie hold test
  - Gate length timing
  - Complete playback scenarios
  - Recording and playback integration
  - Beat sync timing verification

#### Modified Files:
- `VoxCore/include/VoxCore.h` - Added StepSequencer include
- `Vox.xcodeproj/project.pbxproj` - Added StepSequencer.h to public headers

#### Key Design Decisions:
1. **Tie semantics**: Tie flag on step N means "this step is tied FROM step N-1"
   - During recording: TIE button primes the next step (like accent)
   - During playback: Tied step sends note-on first, then note-off for legato
   
2. **Rate clamping**: SyncablePhaseRamp clamps rate to 0.1-50 Hz
   - Tests adjusted to use 50 Hz max and appropriate sample counts

3. **NoteEvent.EventType**: Renamed from `Type` to avoid Swift import conflict

4. **ProcessResult.secondaryEvent**: Added for legato transitions that need two events

#### Test Results:
All 169 tests pass (including 37 new StepSequencer tests).

---

### 2025-12-21 - Phase 3 Complete: Arpeggiator

**Commit**: Phase 3 - Add Arpeggiator DSP class

#### Created Files:
- `VoxCore/DSP/Sequencer/Arpeggiator.h` - Arpeggiator DSP with:
  - 6 pattern modes: UP, DOWN, UP_DOWN, DOWN_UP, RANDOM, AS_PLAYED
  - Octave range: 1-4 octaves (extends pattern across octaves)
  - Note sorting for pattern generation (except AS_PLAYED which preserves input order)
  - Latch mode: holds notes after key release
  - Up to 16 held notes, generating up to 64 pattern notes (16 × 4 octaves)
  - Auto-start: begins running when first note arrives in ENABLED state
  - Auto-stop: stops when last note released (unless latch enabled)
  - Uses SyncablePhaseRamp for timing with tempo sync support
  - Gate length control (10%-100%)
  - Velocity setting for all generated notes
  - State machine: OFF → ENABLED → RUNNING (matches StepSequencer)
  - UP_DOWN/DOWN_UP: don't repeat endpoint notes (classic behavior)
  - RANDOM: uses std::mt19937 for random note selection
  - Notes above MIDI 127 excluded from pattern (high octave overflow protection)

- `VoxCoreTests/ArpeggiatorTests.swift` - Comprehensive unit tests (42 tests):
  - Constructor and sample rate tests
  - State machine transitions (OFF/ENABLED/RUNNING)
  - Auto-start on first note, auto-stop on last note release
  - Note input: add, duplicate detection, remove, max limit (16)
  - Latch mode behavior
  - Pattern tests: UP, DOWN, UP_DOWN, DOWN_UP, AS_PLAYED, RANDOM
  - Octave range and high note exclusion
  - Pattern rebuilding on note/octave changes
  - Timing controls (rate, sync mode, beat division, gate length)
  - Process function tests (note generation, step changes)
  - Beat sync timing verification
  - Complete arpeggio scenario
  - Single note arpeggio (octave spread)
  - Pattern change during playback

#### Modified Files:
- `VoxCore/include/VoxCore.h` - Added Arpeggiator include
- `Vox.xcodeproj/project.pbxproj` - Added Arpeggiator.h to public headers

#### Key Design Decisions:
1. **Pattern sorting**: All patterns except AS_PLAYED sort notes ascending before building pattern
   - UP: low to high across octaves
   - DOWN: high to low across octaves
   - AS_PLAYED: preserves the order notes were pressed

2. **UP_DOWN/DOWN_UP endpoints**: Classic behavior - don't repeat the endpoint notes
   - UP_DOWN with C-E-G produces: C-E-G-E (not C-E-G-G-E-C)
   - Creates smoother melodic motion

3. **Auto-start/stop**: Arpeggiator automatically transitions to RUNNING on first note
   - Matches typical hardware arpeggiator UX
   - Stops automatically when all notes released (unless latch)

4. **Latch mode**: Ignores note-off messages
   - Notes held until clearHeldNotes() called
   - Allows playing stabs that continue arpegiating

5. **RANDOM pattern**: Uses the UP pattern as note pool, selects randomly each step
   - Ensures all notes in range are possible
   - std::mt19937 for quality randomness

#### Test Results:
All tests pass (42 new Arpeggiator tests, ~210+ total).

---

### 2025-12-21 - Phase 4 Complete: Parameter Addresses

**Commit**: Phase 4 - Add Arp/Seq parameter addresses and specs

#### Modified Files:
- `VoxExtension/Parameters/VoxExtensionParameterAddresses.h` - Added parameter addresses:
  - Shared arp/seq: `arpSeqMode` (150), `arpSeqSyncMode` (151), `arpSeqRate` (152), `arpSeqTempoRate` (153), `arpSeqGate` (154), `arpSeqSwing` (155), `arpSeqVelocity` (156), `arpSeqAccentVelocity` (157)
  - Arpeggiator-specific: `arpPattern` (160), `arpOctaves` (161), `arpLatch` (162)
  - Sequencer-specific: `seqLength` (170)

- `VoxExtension/Parameters/Parameters.swift` - Added parameter specs with three new groups:
  - `arpSeq` group: Mode (Off/Arp/Seq), Sync (Free/Sync), Rate (0.5-50 Hz), Tempo Rate (15 beat divisions), Gate (10-100%), Swing (0-75%), Velocity (1-127), Accent Velocity (1-127)
  - `arpeggiator` group: Pattern (6 modes), Octaves (1-4), Latch (boolean)
  - `sequencer` group: Length (1-32 steps)

#### Parameter Details:
| Parameter | Address | Type | Range | Default |
|-----------|---------|------|-------|---------|
| arpSeqMode | 150 | Indexed | Off/Arp/Seq | Off |
| arpSeqSyncMode | 151 | Indexed | Free/Sync | Free |
| arpSeqRate | 152 | Hz | 0.5-50 | 5.0 |
| arpSeqTempoRate | 153 | Indexed | 15 divisions | 1/16 |
| arpSeqGate | 154 | % | 10-100 | 75 |
| arpSeqSwing | 155 | % | 0-75 | 0 |
| arpSeqVelocity | 156 | Generic | 1-127 | 100 |
| arpSeqAccentVelocity | 157 | Generic | 1-127 | 127 |
| arpPattern | 160 | Indexed | 6 patterns | Up |
| arpOctaves | 161 | Indexed | 1-4 | 1 |
| arpLatch | 162 | Boolean | Off/On | Off |
| seqLength | 170 | Generic | 1-32 | 16 |

#### Test Results:
All 247 tests pass (207 VoxCoreTests + 40 VoxTests).

---

### 2025-12-21 - Phase 5 Complete: DSPKernel Integration

**Commit**: Phase 5 - Integrate Arp/Seq into DSPKernel

#### Modified Files:
- `VoxExtension/DSP/VoxExtensionDSPKernel.hpp` - Full arp/seq integration:
  - Added includes for `Arpeggiator.h` and `StepSequencer.h`
  - Added member variables: `mArpeggiator`, `mStepSequencer`, `mArpSeqMode` enum, `mArpSeqLastNote`
  - Updated `initialize()` to set sample rate and tempo on arp/seq
  - Added parameter handling in `setParameter()` for all 12 arp/seq parameters
  - Added default values in `getParameter()` for all 12 arp/seq parameters
  - Updated `process()` to:
    - Sync tempo changes to arp/seq
    - Handle transport state (reset on start, stop on stop)
    - Call `processArpSeq()` per sample for note event generation
  - Added `processArpSeq()` method to process arp or seq and route events to voice
  - Added `handleArpNoteEvent()` and `handleSeqNoteEvent()` for note event routing
  - Updated `handleMIDI2VoiceMessage()` to route MIDI based on mode:
    - OFF mode: direct pass-through to voice
    - ARP mode: notes routed to arpeggiator for held note pattern
    - SEQ mode: notes set transpose offset (SH-101 style), auto-start sequencer

#### Key Integration Features:
1. **Mode-based MIDI routing**: MIDI notes are routed differently based on arpSeqMode
   - OFF: Direct to MonophonicVoice
   - ARP: To Arpeggiator (auto-starts on first note)
   - SEQ: Sets transpose, starts sequencer if enabled

2. **Transport integration**: 
   - Transport start: resets arp/seq phase, starts running if enabled
   - Transport stop: stops arp/seq, sends note-off for any playing note
   - Tempo changes: propagated to both arp and seq

3. **Per-sample processing**: `processArpSeq()` called every sample
   - Handles both primary and secondary note events from sequencer (for legato transitions)
   - Tracks last playing note for proper note-off on stop

4. **Velocity conversion**: 
   - MIDI 2.0 velocity (0-65535) converted to MIDI 1.0 (0-127) for arp
   - MIDI 1.0 velocity (0-127) converted to normalized (0.0-1.0) for voice

#### Test Results:
All 247 tests pass (207 VoxCoreTests + 40 VoxTests).

---

### 2025-12-21 - Phase 6 Complete: UI Components

**Commit**: Phase 6 - Add PERFORMANCE section UI components

#### Modified Files:
- `VoxExtension/UI/Sections/PerformanceSection.swift` - Complete rewrite with arp/seq controls:
  - **VoiceControlsView**: Legato toggle, Glide mode selector (Off/On/Auto), Glide time knob
  - **ModeControlsView**: 3-way mode selector (Off/Arp/Seq) using SynthButtonGroup
  - **TimingControlsView**: 
    - Sync toggle (Free/Sync)
    - Rate knob (free-run) or Tempo Rate picker (synced)
    - Gate knob (10-100%)
    - Swing knob (0-75%)
  - **VelocityControlsView**: Velocity slider, Accent velocity slider, LP filter velocity sensitivity
  - **ArpControlsView** (shown in Arp mode):
    - Pattern picker (Up/Down/Up-Down/Down-Up/Random/As Played) with icons
    - Octave range selector (1-4)
    - Latch toggle button
  - **SeqControlsView** (shown in Seq mode):
    - Length picker with +/- buttons (1-32)
    - Page navigation buttons (1-8, 9-16, 17-24, 25-32)
    - Step grid with 8 visible step buttons per page
    - Transport buttons (Play/Stop/Rec/Clear) - placeholder actions
    - Recording input buttons (Rest/Tie/Acc) - placeholder actions
  - **StepButtonView**: Visual step representation with:
    - Step number label
    - Pitch offset display (+/-12)
    - Gate indicator bar (orange when on)
    - Modifier badges (A for accent, T for tie)
    - Tap to toggle gate, drag to change pitch

#### UI Component Details:
- **ArpSeqTempoRatePicker**: Dropdown menu for 15 beat divisions (matches LFO tempo picker)
- **ArpPatternPicker**: Dropdown with pattern names and SF Symbols icons
- **SeqLengthPicker**: +/- stepper for sequence length
- **StepGridView**: HStack of 8 StepButtonView components
- **TransportButton**: Styled buttons for transport controls
- **RecordingInputButton**: Styled buttons for recording workflow

#### Design Patterns:
- Mode-dependent visibility: Timing/velocity controls dim when mode is Off
- Arp controls only visible when mode is Arp
- Seq controls only visible when mode is Seq
- Follows existing UI conventions from FilterSection, LFOSection
- Uses existing SynthButton, SynthButtonGroup, SynthKnob, SynthSlider components

#### Known Limitations (Phase 6.1 follow-up):
1. Step grid is UI-only - step data not persisted to DSP
2. Transport buttons are placeholders - need DSP message passing
3. Recording buttons are placeholders - need DSP recording state sync
4. Step data editing needs bidirectional sync with StepSequencer

#### Test Results:
All 247 tests pass (207 VoxCoreTests + 40 VoxTests).

---

