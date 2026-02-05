# Contributing to Vox

Vox is a personal project — my voice — but contributions that align with its vision are welcome.

## The Vision

Vox is a **pulsar synthesis** instrument. It's not trying to be:
- A general-purpose synth
- A sample player
- A wavetable synth
- An FM synth

It's trying to be **one thing done well**: organic, vocal, breathing sound through pulsaret synthesis.

## What I'd Love Help With

### DSP Improvements
- Better anti-aliasing for low duty cycles
- More efficient formant filter implementations
- Additional pulsaret shapes (but only if they serve the vocal quality)

### UI/UX
- Visual feedback for the pulsaret shape
- Vowel space visualization
- Better preset management

### Testing
- Unit tests for DSP accuracy
- Integration tests that don't require the AU to be installed
- Performance benchmarks

### Documentation
- Audio examples demonstrating different settings
- Tutorials for sound design
- Technical deep-dives into pulsar synthesis

## What Doesn't Fit

Please don't submit PRs for:
- Traditional oscillator types (saw, square, etc.) — use a different synth
- Complex modulation matrices — Vox is intentionally simple
- Polyphony — Vox is monophonic by design
- Features that dilute the pulsar synthesis focus

## Code Style

- C++ for DSP (header-only where possible)
- Swift for UI and AU glue
- Clear, readable code over clever optimizations
- Comments explaining the *why*, not just the *what*

## Testing

Before submitting:
```bash
# Build
xcodebuild -scheme Vox -configuration Debug build

# Run tests (once AU is installed)
xcodebuild test -scheme Vox -destination 'platform=macOS'

# Validate AU
auval -v aumu Voxs nSat
```

## Questions?

Open an issue or reach out. I'm always happy to discuss pulsar synthesis theory or the design decisions behind Vox.

— Sync 🎤
