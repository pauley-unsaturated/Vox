# Paradigm 2: Parameter Space Navigator

> *"Don't adjust parameters. Travel through sound."*

## Core Concept

Map the high-dimensional parameter space onto navigable 2D surfaces. Instead of tweaking individual knobs, the performer **moves through timbral space**. Position equals timbre. Movement equals expression.

**Philosophy:** Exploration over precision. Discovery over specification. The journey is the performance.

---

## Musician Support

### ✅ Strong Support

**Xenakis** ⭐⭐⭐⭐⭐
> *"Sound masses moving through geometric space..."*

Xenakis thought architecturally about sound—masses, trajectories, densities in space. He'd love:
- The mathematical elegance of dimension reduction
- Sound as navigation through probability space
- Formal mapping between gesture and stochastic outcome
- The implicit structure that emerges from spatial relationships

**Radigue/Eno** ⭐⭐⭐⭐⭐
> *"I want to set something in motion and let it drift."*

The ambient masters work with slow, intentional gestures. They'd appreciate:
- Single-point control of complex timbre
- The ability to "park" in a region and let it evolve
- Gesture recording for repeatable slow morphs
- Minimal interface, maximal sonic result

**Holly Herndon** ⭐⭐⭐⭐
> *"The interface should capture my intention, not just my finger position."*

Herndon values expressive, embodied control. She'd appreciate:
- Path recording as gesture capture
- Multi-touch possibilities (one finger per XY pad)
- The implicit collaboration between mapping algorithm and performer
- Space for discovery and surprise

### ⚠️ Partial Support

**Curtis Roads** ⭐⭐⭐
> *"Useful for exploration, but I need to know what's underneath."*

Roads would appreciate it as a discovery tool but want:
- Visible axis mappings
- Ability to "pin" and edit specific parameter sets
- Export discovered positions to traditional parameters

### ❌ Limited Support

**Aphex Twin** ⭐⭐
> *"I want to control the specific thing, not a vague area."*

Richard would find the abstraction frustrating when he needs precision:
- Hidden complexity feels like loss of control
- "Why can't I just turn the F1 knob?"
- Might use it for initial exploration, then switch to Traditional Panel

---

## Hypothetical Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ HEADER                                                                       │
│ [≡ Preset ▾] [← →]     V O X     [◉ Record] [▶ Play]     [▁▂▃▄ Meters]    │
├───────────────────────────────────────────────┬─────────────────────────────┤
│                                               │                             │
│     ┌─────────────────────────────────────┐   │   AXIS CONFIGURATION        │
│     │                                     │   │                             │
│     │            BRIGHT                   │   │   X-Axis: "Brightness"      │
│     │               ↑                     │   │   ├─ Vowel Morph    [40%]   │
│     │               │                     │   │   ├─ F1/F2 Ratio    [30%]   │
│     │               │                     │   │   └─ Harmonics      [30%]   │
│     │    SPARSE ────┼──── DENSE           │   │                             │
│     │               │                     │   │   Y-Axis: "Density"         │
│     │               │    ◉ ←cursor        │   │   ├─ Grain Density  [50%]   │
│     │               │                     │   │   ├─ Chaos Amount   [30%]   │
│     │               ↓                     │   │   └─ Stoch Scatter  [20%]   │
│     │             DARK                    │   │                             │
│     │                                     │   │   [Edit Mappings...]        │
│     │   ┌───────────────────────────┐     │   │                             │
│     │   │ A ·   ·   ·   · B        │     │   ├─────────────────────────────┤
│     │   │                           │     │   │                             │
│     │   │ ·    PATH    ·            │     │   │   SNAPSHOTS                 │
│     │   │      ~~~~                 │     │   │                             │
│     │   │ ·   ·   ·   · ·          │     │   │   [A]────────[B]            │
│     │   │                           │     │   │    │╲      ╱│              │
│     │   │ C ·   ·   ·   · D        │     │   │    │ ╲    ╱ │              │
│     │   └───────────────────────────┘     │   │    │  ╲  ╱  │              │
│     │     ↑ Snapshot positions (A-D)      │   │    │   ╳   │              │
│     └─────────────────────────────────────┘   │    │  ╱  ╲  │              │
│                                               │    │ ╱    ╲ │              │
│                 PRIMARY NAVIGATOR             │   [C]────────[D]            │
│                                               │                             │
├───────────────────────────────────────────────┤   Position morphs between   │
│                                               │   snapshot states           │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐   │                             │
│  │   MOD     │ │   SPACE   │ │   CHAOS   │   ├─────────────────────────────┤
│  │    XY     │ │    XY     │ │    XY     │   │                             │
│  │  ┌─────┐  │ │  ┌─────┐  │ │  ┌─────┐  │   │   GESTURE LIBRARY           │
│  │  │  ◉  │  │ │  │  ◉  │  │ │  │  ◉  │  │   │                             │
│  │  └─────┘  │ │  └─────┘  │ │  └─────┘  │   │   ▶ Slow Rise (4 bars)      │
│  │ LFO rate  │ │ Width vs  │ │ Lorenz vs │   │   ▶ Spiral Inward (8 bars)  │
│  │ vs depth  │ │ movement  │ │ Hénon     │   │   ▶ Random Walk (loop)      │
│  └───────────┘ └───────────┘ └───────────┘   │   ▶ Vowel Sweep (2 bars)    │
│                                               │                             │
│      SECONDARY NAVIGATORS (assignable)        │   [+ Record New Gesture]    │
│                                               │                             │
└───────────────────────────────────────────────┴─────────────────────────────┘
```

---

## Interaction Patterns

### Primary Navigator
- **Click + drag**: Move cursor, change timbre in real-time
- **Multi-touch**: Two fingers = two cursors (blend between them)
- **Double-click**: Drop a temporary marker
- **Right-click**: Set as snapshot position (A, B, C, or D)
- **Scroll wheel**: Zoom in/out of parameter space

### Gesture Recording
- **Record button**: Start capturing cursor movement
- **Play button**: Replay captured gesture as automation
- **Loop toggle**: Continuously loop the gesture
- **Speed knob**: Playback speed (0.25x - 4x)

### Snapshots
- **Click snapshot letter**: Jump to that position
- **Drag between snapshots**: Morph along that edge
- **Cmd + click**: Edit snapshot's underlying parameters
- **Shift + click**: Randomize within snapshot's neighborhood

### Secondary Navigators
- Smaller XY pads for focused parameter pairs
- Can be reassigned via dropdown
- Useful for keeping primary navigator on timbre while adjusting modulation

---

## Mapping Algorithms

### Preset Mappings

| Mapping Name | X-Axis | Y-Axis | Best For |
|--------------|--------|--------|----------|
| **Timbral** | Brightness (formant, harmonics) | Density (grains, chaos) | General exploration |
| **Vowel Space** | Front↔Back (F1 frequency) | Open↔Closed (F2 frequency) | Voice-like sounds |
| **Texture** | Sparse↔Dense (grain count) | Static↔Moving (LFO, drift) | Ambient textures |
| **Energy** | Calm↔Aggressive (chaos, scatter) | Smooth↔Rough (duty cycle) | Dynamic performance |

### Custom Mapping Editor
- Drag parameters onto X or Y axis
- Adjust contribution weight per parameter
- Set curve type (linear, exponential, s-curve)
- Preview changes in real-time

---

## Visual Feedback

- **Cursor trail**: Fading path shows recent movement
- **Heatmap mode**: Show time spent in each region
- **Ripples**: Sonic intensity shown as ripples from cursor
- **Snapshot gravity**: Visual pull toward nearby snapshots
- **Axis labels**: Dynamic labels based on current mapping

---

## Pros & Cons

### Pros
- ✅ Highly performable with minimal controls
- ✅ Encourages exploration and discovery
- ✅ Gesture recording captures expression
- ✅ Snapshots enable preset morphing
- ✅ Multi-touch capable
- ✅ Works great with hardware controllers (Lemur, Sensel Morph)

### Cons
- ❌ Hidden parameter complexity
- ❌ Mapping quality depends on good presets
- ❌ Precision control difficult
- ❌ Learning curve for mapping editor
- ❌ What you see ≠ what parameters are changing

---

## Integration Notes

This paradigm shines as the **exploration/discovery mode**. When you find something you like:
1. Drop a snapshot
2. Switch to Traditional Panel to see exact values
3. Fine-tune specific parameters
4. Return to Navigator with updated snapshot

Consider: The primary navigator could be an **overlay** on other paradigms—always available via a keyboard shortcut.

---

## Hardware Integration

| Controller | Mapping |
|------------|---------|
| **Sensel Morph** | Full surface = primary navigator, pressure = Z-axis |
| **Lemur/TouchOSC** | Custom XY pads, gesture recording |
| **Roli Seaboard** | Pitch = X, slide = Y, pressure = intensity |
| **Standard MIDI** | CC1/CC2 = X/Y, mod wheel = gesture speed |
