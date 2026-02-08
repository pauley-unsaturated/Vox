# Vox UI Capture Pipeline

Scripts for AI agents to get visual feedback during UI development.

## Quick Start

```bash
# Full pipeline: build → launch → MIDI → screenshot → kill
./scripts/capture-ui.sh

# Quick re-capture (skip build)
./scripts/capture-ui.sh --no-build --delay 2

# Keep app running for manual inspection
./scripts/capture-ui.sh --keep
```

## Agent UI Development Loop

When working on Vox UI code, follow this tight feedback loop:

1. **Make code changes** (SwiftUI views, Metal shaders, etc.)
2. **Run the capture pipeline:**
   ```bash
   ./scripts/capture-ui.sh --output /tmp/vox-ui.png
   ```
3. **Analyze the screenshot** using vision model to verify changes look correct
4. **Iterate** — if something's wrong, adjust and re-run
5. **Max 5 iterations** before escalating to human

### What to check in screenshots:
- UI elements are visible and properly laid out
- Scopes/meters show data (not flat/blank) when MIDI is sent
- Colors match the synth theme (cyan accents, dark background)
- No layout clipping or overlapping elements
- Metal views render (not black rectangles)

## Scripts

### `capture-ui.sh`

| Flag | Default | Description |
|------|---------|-------------|
| `--output PATH` | `/tmp/vox-ui.png` | Screenshot save path |
| `--delay SECONDS` | `5` | Wait after launch before capture |
| `--no-midi` | off | Skip MIDI test notes |
| `--keep` | off | Leave app running after capture |
| `--no-build` | off | Skip xcodebuild step |

### `send-test-midi.sh`

Sends a C major chord (C3-E3-G3) via `sendmidi`, holds 2 seconds, then releases.
Auto-detects Vox virtual MIDI port or falls back to IAC Driver.

## Troubleshooting

**"Could not find Vox window"**
- The app may not have launched. Increase `--delay`.
- Check if the build actually succeeded (look for errors above).

**"No Vox or IAC MIDI port found"**
- Open Audio MIDI Setup → Show MIDI Studio → enable IAC Driver
- The Vox app may need to be running before MIDI ports appear

**Build failures**
- Run `xcodebuild -project Vox.xcodeproj -scheme Vox -configuration Debug build` manually to see full errors
- Check that Xcode command line tools are installed: `xcode-select -p`

**Black/blank screenshot**
- The AU extension may have crashed. Check Console.app for "Vox" crash logs.
- Try increasing the delay: `--delay 8`

**MIDI notes not producing sound**
- The AU may not have finished loading. Increase delay.
- Check that the synth is in a playable state (not muted, volume up).
