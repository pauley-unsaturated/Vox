# Vox

A subtractive synthesizer AudioUnit v3 plugin for macOS, inspired by classic mono-synths like the Roland SH-101 and Sequential Pro-One.

![Vox Interface](VoxInterface_v2.png)

## Features

- **Dual Oscillators** with Saw, Square, Triangle, and Sine waveforms, plus pulse width modulation
- **Sub Oscillator** and **White Noise** generator for fuller sounds
- **Moog-style Ladder Filter** with resonance, key tracking, and velocity sensitivity
- **Dual ADSR Envelopes** for amplitude and filter modulation
- **LFO** with multiple waveforms, tempo sync, and flexible routing
- **Arpeggiator & Step Sequencer** (SH-101 inspired workflow)
- **Legato & Glide** for expressive monophonic performance
- **Preset Management** with save/load functionality

## Requirements

- macOS 12.0+
- Xcode 15.0+
- Compatible with Logic Pro, MainStage, GarageBand, and other AUv3 hosts

## Building

```bash
# Build the plugin (Debug)
./build.sh

# Run all tests
./test.sh

# Validate AudioUnit with auval
./validate.sh
```

Build logs are saved to `build/logs/` with timestamps.

## Architecture

```
Vox/              # Host app (Swift/SwiftUI)
VoxExtension/     # AUv3 plugin (Swift + C++)
VoxCore/          # DSP framework (C++ only)
  └── DSP/
      ├── Oscillators/    # PolyBLEP anti-aliased oscillators
      ├── Filters/        # Moog ladder, HP/LP filters
      ├── Envelopes/      # ADSR envelope generator
      ├── Voice/          # Monophonic voice management
      ├── Sequencer/      # Arpeggiator/step sequencer
      └── Utilities/      # DC blocker, etc.
```

### Technology

- **DSP**: C++ with anti-aliased oscillators (PolyBLEP/DPW algorithms)
- **Filter**: Huovilainen Zero-Delay Feedback Moog ladder implementation
- **UI**: SwiftUI with a dark theme and amber accents
- **Plugin Format**: AudioUnit v3 (`aumu Atng nSat`)

## Parameters

The synthesizer exposes 36 parameters organized into sections:

| Section | Parameters |
|---------|-----------|
| **Oscillator 1/2** | Waveform, Level, Octave, Detune, Pulse Width, Sync (Osc2) |
| **Sub/Noise** | Level controls |
| **Filter** | Cutoff, Resonance, Key Tracking, Envelope Amount, Velocity |
| **Amp Envelope** | Attack, Decay, Sustain, Release |
| **Filter Envelope** | Attack, Decay, Sustain, Release |
| **LFO** | Rate, Waveform, Tempo Sync, Phase, Retrigger, Delay, Mod Depths |
| **Performance** | Legato, Glide, Arpeggiator, Velocity Sensitivity |
| **Master** | Volume |

See [VoxParameters.md](VoxParameters.md) for full details.

## Development

### Issue Tracking

This project uses [Beads](https://github.com/sourcegraph/beads) for issue tracking:

```bash
bd list              # List open issues
bd create -t "Title" # Create new issue
bd close <id>        # Close issue
```

### Key Documentation

- [CLAUDE.md](CLAUDE.md) – Development guide and conventions
- [claude-guidance.md](claude-guidance.md) – DSP implementation details
- [UI-Design.md](UI-Design.md) – Interface design specification
- [ArpeggiatorSequencer-Design.md](ArpeggiatorSequencer-Design.md) – Sequencer feature spec

## License

Copyright © 2025 Unsaturated. All rights reserved.
