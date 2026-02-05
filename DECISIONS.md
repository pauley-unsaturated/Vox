# Vox Design Decisions Log

## 2026-02-04

### Pitch Floor: 20Hz minimum
**Decision:** Fundamental pitch clamped at 20Hz
**Rationale:** Sub-audio pitches create rhythmic effects, but that's better achieved through:
- LFO → duty cycle modulation (creates rhythmic brightness changes)
- LFO → amplitude (tremolo)
- Envelope shape variations

This keeps "pitch" meaning "pitch" and "rhythm" coming from modulation sources.

---

### MIDI Learn: Not needed
**Decision:** Skip MIDI learn implementation
**Rationale:** DAWs (Logic, Ableton, etc.) provide their own parameter automation and MIDI mapping. Building it into the plugin is redundant.


### Output: Stereo (with future multichannel potential)
**Decision:** Stereo output, design with multichannel in mind
**Rationale:** Mono voice → stereo field gives spatial options (width, pan). Could expand to surround/Atmos later.

