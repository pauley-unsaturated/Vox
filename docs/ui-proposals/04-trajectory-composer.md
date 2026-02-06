# Paradigm 4: Trajectory Composer

> *"Don't perform parameters in real-time. Compose their journeys in advance."*

## Core Concept

Pre-design how parameters evolve over time using a multi-track timeline. Performance becomes **triggering and manipulating trajectories** rather than controlling individual parameters. Think: DAW automation lanes as instrument interface.

**Philosophy:** Compositional control for complex evolution. Front-load the complexity into design time; performance becomes gesture-triggering.

---

## Musician Support

### ✅ Strong Support

**Curtis Roads** ⭐⭐⭐⭐⭐
> *"Parameter trajectories are essential for pulsar synthesis composition."*

This is exactly how Roads approaches pulsar synthesis. He'd appreciate:
- Pre-composed parameter envelopes (as described in Microsound)
- Cloud-level control via trajectories rather than grain-level tweaking
- The ability to design complex evolving textures
- Score-like visualization of sonic evolution

**Radigue/Eno** ⭐⭐⭐⭐⭐
> *"I compose processes, not notes."*

Radigue's hours-long drones and Eno's generative systems work this way. They'd embrace:
- Very long trajectories (minutes to hours)
- Slow, subtle parameter changes
- Set-and-forget: design trajectory, let it unfold
- Multiple overlapping timescales
- The meditative act of designing slow evolution

**Xenakis** ⭐⭐⭐⭐
> *"Time is the canvas on which stochastic events are painted."*

Xenakis thought compositionally about time structures. He'd value:
- Formal control over temporal organization
- Probability distributions that evolve over trajectory duration
- The ability to compose "sound masses" with defined lifespans
- Integration of stochastic elements within deterministic time frames

### ⚠️ Partial Support

**Holly Herndon** ⭐⭐⭐
> *"Composition is important, but where is the live response?"*

Herndon values real-time interaction. She'd want:
- Trajectories that respond to performer input
- The ability to scrub/warp trajectories live
- Multiple trajectories that can be cross-faded in performance
- But might find it too "fixed" for her collaborative approach

### ❌ Limited Support

**Aphex Twin** ⭐⭐
> *"I want to react NOW, not play back something I designed earlier."*

Richard's live sets are improvisational. He'd find:
- Too much planning, not enough spontaneity
- Useful for studio work but not live performance
- Would want extreme tempo/scrub control to make it feel "live"
- Might use very short trajectories (< 1 bar) as "gestures"

---

## Hypothetical Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ HEADER                                                                       │
│ [≡ Preset ▾]  V O X  [⏮][⏪][▶][⏩][⏭] ⏱ 0:00.000 / 4:00.000  [🔁 Loop]  │
├─────────────────────────────────────────────────────────────────────────────┤
│ PLAYHEAD MODES    [Free] [Note-Sync] [Loop] [Scrub]   BPM: [120.0]         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TIMELINE                    1       2       3       4       5       6      │
│  ─────────────────────────────┼───────┼───────┼───────┼───────┼───────┼──── │
│                               │       │       │       │       │       │     │
│  ┌─ Vowel Morph ──────────────┼───────┼───────┼───────┼───────┼───────┼───┐ │
│  │  [A]    ╱‾‾‾‾‾‾╲    [E]   │ [I]  ╱│╲      │       │   [O] │ [U]   │   │ │
│  │      ╱          ╲        ╱ │   ╲  │  ╲    │      ╱│      ╲│       │   │ │
│  │    ╱              ╲    ╱   │     ╲│   ‾‾‾‾│    ╱  │        ╲      │   │ │
│  │  ╱                  ╲╱     │      │       │  ╱    │          ‾‾‾‾‾│   │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│  [S] [M] [✎] [×]        Curve: [Smooth ▾]   Via: [None ▾]                  │
│                                                                              │
│  ┌─ Grain Density ────────────┼───────┼───────┼───────┼───────┼───────┼───┐ │
│  │                            │       │       │       │       │       │   │ │
│  │  ‾‾‾‾‾‾‾╲                  │       │  ╱‾‾‾‾‾‾‾‾╲   │       │       │   │ │
│  │          ╲                 │      ╱│ ╱          ╲  │       │  ╱‾‾‾‾│   │ │
│  │           ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾│‾‾‾‾╱  │╱            ╲ │       │╱      │   │ │
│  │                            │╱      │              ‾│‾‾‾‾‾‾‾│       │   │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│  [S] [M] [✎] [×]        Curve: [Stepped ▾]   Via: [Velocity ▾]             │
│                                                                              │
│  ┌─ Chaos Amount ─────────────┼───────┼───────┼───────┼───────┼───────┼───┐ │
│  │                            │       │       │       │  ╱╲   │       │   │ │
│  │         ╱‾‾‾‾╲             │       │       │       │ ╱  ╲  │       │   │ │
│  │       ╱      ╲            │       │       │      ╱│╱    ╲ │       │   │ │
│  │  ____╱        ╲___________│_______│_______│_____╱ │      ╲│_______│   │ │
│  │                            │       │       │       │       │       │   │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│  [S] [M] [✎] [×]        Curve: [Exponential ▾]   Via: [Aftertouch ▾]       │
│                                                                              │
│  ┌─ Formant Sweep ────────────┼───────┼───────┼───────┼───────┼───────┼───┐ │
│  │ F1: ‾‾‾╲    ╱‾‾‾          │       │       │       │       │       │   │ │
│  │         ╲  ╱               │       │       │       │       │       │   │ │
│  │          ╳                 │       │       │       │       │       │   │ │
│  │         ╱  ╲               │       │       │       │       │       │   │ │
│  │ F2: ___╱    ╲___           │       │       │       │       │       │   │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│  [S] [M] [✎] [×]        Curve: [S-Curve ▾]   Link: [F1 ⟷ F2 inverse]       │
│                                                                              │
│  [+ Add Lane...]   Parameters: [Drift Rate ▾] [Scatter ▾] [Pan ▾] [...]    │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TRIGGERS                              │  TRAJECTORY LIBRARY                 │
│                                        │                                     │
│  Note On → [Start ▾]                   │  📁 Factory                         │
│  Velocity → [Speed ▾] (50%-200%)       │     └─ 🌅 Dawn Rise (slow brighten) │
│  Aftertouch → [Scrub Position ▾]       │     └─ 🌊 Wave Cycle (periodic)     │
│  Mod Wheel → [Trajectory Blend ▾]      │     └─ 💫 Starburst (explosive)     │
│  CC#73 → [Loop Length ▾]               │     └─ 🎭 Vowel Phrase (A→E→I→O→U)  │
│                                        │  📁 User                            │
│  [Edit Trigger Mappings...]            │     └─ My Trajectory 1              │
│                                        │     └─ [+ Save Current...]          │
│                                        │                                     │
└────────────────────────────────────────┴─────────────────────────────────────┘
```

---

## Interaction Patterns

### Timeline Editing

| Action | Gesture | Result |
|--------|---------|--------|
| **Add point** | Double-click on lane | Insert automation point |
| **Move point** | Click + drag | Reposition in time/value |
| **Delete point** | Right-click or select + Delete | Remove point |
| **Curve segment** | Click segment + drag up/down | Change curve type |
| **Select multiple** | Click + drag marquee | Multi-select points |
| **Copy/paste** | Cmd+C/V | Duplicate selection |
| **Stretch** | Select + drag edge | Time-stretch selection |

### Lane Operations

| Button | Function |
|--------|----------|
| **[S]** | Solo this lane (mute others) |
| **[M]** | Mute this lane |
| **[✎]** | Enable editing (vs. locked) |
| **[×]** | Delete this lane |

### Playhead Modes

| Mode | Behavior |
|------|----------|
| **Free** | Time-based playback at set BPM |
| **Note-Sync** | Restart from beginning on each note |
| **Loop** | Cycle through trajectory continuously |
| **Scrub** | Manual position control via MIDI/touch |

---

## Curve Types

| Type | Shape | Use Case |
|------|-------|----------|
| **Linear** | / | Constant rate of change |
| **Exponential** | ⌒ | Fast start, slow finish |
| **Logarithmic** | ⌓ | Slow start, fast finish |
| **S-Curve** | ∿ | Smooth acceleration/deceleration |
| **Stepped** | ┐ | Quantized changes |
| **Stochastic** | ⚡ | Random within bounds |

---

## Via Modulation for Trajectories

Each lane can have a "via" source that scales the trajectory amount:

| Via Source | Effect |
|------------|--------|
| **None** | Trajectory plays at full designed amount |
| **Velocity** | Higher velocity = more trajectory influence |
| **Aftertouch** | Pressure scales trajectory depth |
| **Mod Wheel** | Manual scaling control |
| **LFO** | Rhythmic trajectory depth modulation |
| **Chaos** | Unpredictable trajectory influence |

---

## Trajectory Presets

### Factory Trajectories

**🌅 Dawn Rise** (16 bars, slow)
- Vowel: A → E → I (gradual brighten)
- Density: 20% → 80% (filling in)
- Chaos: 0% → 15% (subtle movement emerges)
- Best for: Opening textures, ambient intros

**🌊 Wave Cycle** (4 bars, looping)
- Vowel: E → O → E (periodic)
- Density: Sine wave 40-60%
- Formant: F1/F2 crossover
- Best for: Rhythmic, pulsing textures

**💫 Starburst** (2 bars, one-shot)
- Density: 100% → 10% (explosive scatter)
- Chaos: 80% → 0% (settle down)
- Scatter: Maximum → Minimum
- Best for: Dramatic moments, transitions

**🎭 Vowel Phrase** (8 bars, expressive)
- Vowel: A (0-2) → E (2-4) → I (4-5) → O (5-7) → U (7-8)
- Human-like vowel articulation timing
- Best for: Voice-like textures, speech-esque sounds

---

## Pros & Cons

### Pros
- ✅ Complex evolving textures without real-time multitasking
- ✅ Reproducible performances
- ✅ Fine control over temporal evolution
- ✅ Score-like visualization
- ✅ Excellent for studio composition
- ✅ Can design textures impossible to perform live

### Cons
- ❌ Less spontaneous than real-time control
- ❌ Setup time before performance
- ❌ Can feel "locked in" during playback
- ❌ Complex UI for timeline editing
- ❌ Not ideal for improvisational contexts

---

## Integration Notes

Trajectory Composer is the **compositional powerhouse**. Integration strategies:

1. **Record from other paradigms**: Perform in Parameter Space Navigator, capture as trajectory
2. **Export to automation**: Send trajectory as DAW automation for final mix
3. **Trigger library**: Use trajectories as "gestures" from other paradigms
4. **Hybrid mode**: Real-time control modulates trajectory playback

Consider: Trajectory Composer could be a **separate window** that opens from any paradigm when you want to design evolution over time.

---

## Advanced Features

### Trajectory Stacking
- Multiple trajectories can be active simultaneously
- Blend between them with crossfader or MIDI control
- Each trajectory affects different parameter subsets

### Conditional Branching
- Trajectories can have branch points
- Branch taken depends on MIDI input or random choice
- Creates non-linear, responsive compositions

### Trajectory Morphing
- Interpolate between two trajectories
- Creates "in-between" evolutions
- Morph position controlled by MIDI or automation

### Micro-Trajectories
- Very short (< 1 bar) trajectories as "gestures"
- Triggered per-note
- Velocity/pitch/aftertouch modifies trajectory on trigger
