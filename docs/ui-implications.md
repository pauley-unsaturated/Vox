# UI Implications for Phase 7 Features

*Document for Mark to review before UI implementation*

---

## New Parameters Added in Phase 7

### 1. Pulsaret Envelope Section

| Parameter | Type | Range | UI Suggestion |
|-----------|------|-------|---------------|
| `pulsaretEnvelope` | Enum | 5 types | Segmented control or dropdown |
| `envelopeParam` | Float | 0.0-1.0 | Rotary knob with visual feedback |

**Envelope Types:**
- Rectangular (default) - Hard edges
- Gaussian - Smooth bell curve
- ExpDecay - FOF-style decay
- LinearAttack - Percussive ramp
- FOF - Classic formant shape

**Visual Feedback Idea:**
Show a small waveform preview of the current envelope shape. The preview would update in real-time as `envelopeParam` changes.

**Grouping:**
Could be part of the Pulsar Engine section, perhaps as an expandable "Advanced" panel.

---

### 2. Formant Track

| Parameter | Type | Range | UI Suggestion |
|-----------|------|-------|---------------|
| `formantTrack` | Float | 0.0-1.0 | Slider or knob with labels |

**Labels:**
- 0.0 = "Robot" 🤖
- 0.5 = "Hybrid"
- 1.0 = "Natural" 🗣️

**Interaction:**
When set to 0.0 (robot), the implicit formant stays fixed regardless of pitch.
When set to 1.0 (natural), formant tracks pitch like a real voice.

**Visual Feedback:**
Could show the current implicit formant frequency (fd = fp / dutyCycle).

---

### 3. Edge Factor

| Parameter | Type | Range | UI Suggestion |
|-----------|------|-------|---------------|
| `edgeFactor` | Float | 0.0-1.0 | Slider or knob |

**Labels:**
- 0.0 = "Soft" 
- 1.0 = "Hard"

**Technical Note:**
This affects aliasing at high duty cycles. Soft edges reduce aliasing but also reduce brightness.

---

### 4. Pulse Masking Section

This is a more complex feature that could justify its own panel or section.

| Parameter | Type | Range | UI Suggestion |
|-----------|------|-------|---------------|
| `maskingEnabled` | Bool | on/off | Toggle switch |
| `burstLength` | Int | 1-32 | Stepper or number field |
| `restLength` | Int | 0-32 | Stepper or number field |
| `stochasticMaskProb` | Float | 0.0-1.0 | Slider with % display |

**Visual Ideas:**

1. **Pattern Visualizer:** Show the burst pattern as a grid:
   ```
   ████░░████░░████░░████░░
   burst  rest  burst  rest
   ```

2. **Subharmonic Indicator:** Show the calculated subharmonic factor:
   - b=4, r=2 → "Subharmonic: fp × 0.67"

3. **Stochastic Preview:** When stochasticProb < 1.0, animate the pattern to show random dropouts.

---

## Modulation Matrix Updates

Four new destinations were added:

| Destination | What It Controls |
|-------------|------------------|
| PulsaretEnvParam | Envelope shape parameter |
| FormantTrack | Robot ↔ Natural |
| EdgeFactor | Edge crossfade |
| MaskProb | Stochastic dropout probability |

**UI Consideration:**
The matrix is now 12×16 (12 sources, 16 destinations). May need scrolling or pagination on smaller screens.

---

## Recommended UI Paradigms

### Option A: Grouped by Feature
```
┌─────────────────────────────────────────┐
│ PULSAR ENGINE                           │
├─────────────────────────────────────────┤
│ Shape: [●○○○]  Duty: ████░░░░           │
│                                         │
│ ▼ Advanced                              │
│   Envelope: [Gaussian ▼]                │
│   Env Param: ████░░░░                   │
│   Formant Track: ░░░░████ (Natural)     │
│   Edge Factor: ████░░░░ (Hard)          │
├─────────────────────────────────────────┤
│ ▼ Masking                               │
│   [●] Enabled                           │
│   Burst: 4  Rest: 2  → fp × 0.67        │
│   Dropout: 100%                         │
│   ████░░████░░████░░████░░              │
└─────────────────────────────────────────┘
```

### Option B: Roads Mode Toggle
A "Roads Mode" or "Classic Pulsar" toggle that shows/hides the advanced Roads parameters. For users who just want basic pulsar synthesis, hide the complexity.

### Option C: Preset-Driven
Create presets that configure these parameters for common use cases:
- "Robot Voice" → formantTrack=0, rectangular envelope
- "Natural Voice" → formantTrack=1, Gaussian envelope
- "Rhythmic Pulsar" → masking enabled, burst pattern
- "Analog Feel" → stochasticProb=0.9

---

## Questions for Mark

1. Should these parameters be visible by default or hidden in "Advanced"?
2. Preferred UI control type for envelope selection?
3. How to handle the 16-destination modulation matrix on mobile?
4. Interest in the pattern visualizer for masking?

---

*Created: Phase 7 Implementation, Feb 2026*
