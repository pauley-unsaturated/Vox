# CLAUDE.md - Vox Synthesizer Plugin Development Guide

## Project Understanding

This project aims to create a subtractive synthesizer using the AudioUnit v3 (AUv3) framework, inspired by classic mono-synths like the SH-101 and Pro-One. The implementation will follow algorithms from Välimäki and Huovilainen's paper "Oscillator and Filter Algorithms for Virtual Analog Synthesis" from Computer Music Journal Vol. 20, No. 2.

## Key Documents
- [claude-code-process.md](/Users/markpauley/Programs/Vox/claude-code-process.md): Outlines the development workflow, task structure, and technical guidelines for implementation
- [claude-guidance.md](/Users/markpauley/Programs/Vox/claude-guidance.md): Contains technical details about oscillator and filter implementation, voice architecture, and performance considerations

## Implementation Plan

Following the structure in the guidance documents, development will proceed through these main phases:

1. **Core DSP Components**: Implementing oscillators with anti-aliasing (PolyBLEP/DPW), Moog ladder filter, envelopes, and modulation
2. **Voice Architecture**: Building the monophonic voice system with portamento and modulation routing
3. **AUv3 Integration**: Implementing the AudioUnit v3 plugin architecture, MIDI handling, and parameter management
4. **Performance Features**: Adding arpeggiator and sequencer functionality
5. **UI Development**: Creating an intuitive interface for all synth parameters using AUv3 parameters and views

## Technical Approach

- Use PolyBLEP or similar techniques for anti-aliased oscillator implementation
- Implement Huovilainen Zero-Delay Feedback filter approach for Moog ladder filter
- Follow real-time audio best practices (no allocations in audio thread, denormal prevention)
- Optimize with SIMD and block-based processing where appropriate
- Maintain thorough test coverage for all components
- Utilize Apple's AUv3 framework for plugin architecture instead of JUCE

## Parameter Design Decisions

### Filter Cutoff Parameter

**IMPORTANT DECISION**: The filter cutoff parameter is intentionally kept as a linear percentage value (0-100%) in the AudioUnit parameter space, NOT as Hz values. 

**Rationale**:
- AudioUnit parameters should use simple, linear ranges for automation compatibility
- The exponential Hz conversion (20Hz-20kHz) is performed in the DSP processing layer
- UI layer will handle the frequency display conversion for user-friendly Hz readouts
- This separation of concerns keeps the parameter system clean and predictable

**Implementation**:
- Parameter: 0.0-100.0% (linear, for automation)
- DSP Conversion: `freq = 20.0 * std::pow(1000.0, normalizedValue)` where normalizedValue = param/100.0
- UI Display: Will show computed Hz values derived from the percentage parameter

This approach ensures proper DAW automation behavior while providing intuitive frequency controls in the UI.

## Issue Tracking with Beads

This project uses **beads** (`bd`) for issue and task tracking. Issues are stored in `.beads/issues.jsonl`.

### Beads Quick Reference

```bash
# View issues
bd list                    # List all open issues
bd list -a                 # List all issues including closed
bd show <id>               # Show details of a specific issue
bd search <query>          # Search issues by text

# Create and manage issues
bd create -t "Title" -b "Body text"    # Create new issue
bd create -t "Title" -l bug,P1         # Create with labels
bd update <id> -t "New title"          # Update issue title
bd close <id> -r "Reason"              # Close with reason

# Workflow
bd ready <id>              # Mark issue as ready to work on
bd blocked <id> -r "Why"   # Mark as blocked with reason
bd status                  # Show current workflow status
bd sync                    # Sync issues with JSONL file
```

### Common Labels
- `P1`, `P2`, `P3` - Priority levels
- `bug`, `feature`, `enhancement` - Issue types
- `unit-test`, `ui`, `dsp` - Component areas

## Development Process

For each component, I will follow this workflow:
1. Select next task from beads (`bd list`)
2. Implement the feature with appropriate anti-aliasing and optimizations
3. Create unit tests to verify functionality
4. Build and test until passing
5. Self-review and refine implementation
6. Document implementation decisions
7. Commit changes with descriptive message
8. Close issue in beads (`bd close <id>`) and move to next task

## Commands to Run

**IMPORTANT: Always use these scripts for building, testing, and validation:**

Build plugin: `./build.sh`
Run tests: `./test.sh`
Validate AudioUnit: `./validate.sh`

These are the ONLY build, test, and validation commands to use. Do NOT use xcodebuild or auval directly.
The scripts internally handle all the proper xcodebuild configuration including project, scheme, and derived data path settings.

### Build and Test Logging

Both build.sh and test.sh automatically save their output to timestamped log files in the `build/logs/` directory:
- Build logs: `build/logs/build-YYYYMMDD-HHMMSS.log`
- Test logs: `build/logs/test-YYYYMMDD-HHMMSS.log`

This allows you to review build errors and test failures in detail after the fact. The output is still displayed to the console via `tee`, so you can watch the build/test progress in real-time.

## Build Error Parsing Guide

When using xcodebuild through the build scripts, error and warning messages follow this pattern:

```
<file_name>:<line_num>:<col>: error: <error output>
<file_name>:<line_num>:<col>: warning: <warning output>
```

To efficiently parse build output:

1. Look for "error:" or "warning:" in the build output
2. Identify the source file, line number, and column where the issue occurs
3. Read the error message to understand the specific problem
4. For multiple errors, prioritize addressing them in order from top to bottom
5. After fixing each error, rebuild to ensure the fix works and doesn't introduce new issues
6. Address all errors before moving on to warnings

Example error patterns to watch for:
- "No such file or directory": Missing include or file reference
- "Undefined symbol": Missing implementation or linking issue
- "Expected <X>": Syntax error in code
- "Cannot initialize a variable of type <X> with an lvalue of type <Y>": Type mismatch

## Audio Testing Guidelines

### RMS Measurement for Audio Signals

When measuring RMS (Root Mean Square) values of audio signals for testing purposes, use appropriate sample window sizes:

- **Minimum**: 1000 samples (~23ms at 44.1kHz) - sufficient for multiple waveform cycles
- **Recommended**: 4410 samples (~100ms at 44.1kHz) - good balance of accuracy and test speed  
- **High accuracy**: 11025 samples (~250ms at 44.1kHz) - very stable measurements

**Why this matters**: At 44.1kHz sample rate, 100 samples is only ~2.3ms, which barely covers one cycle of a 440Hz tone. RMS measurements need multiple complete cycles to be meaningful and stable.

**Example usage**:
```swift
// Good: 1000+ samples for reliable RMS
var samples: [Double] = []
for _ in 0..<1000 {
    samples.append(voice.process())
}
let rms = sqrt(samples.map { $0 * $0 }.reduce(0.0, +) / Double(samples.count))
```

### When to Use Different Window Sizes

- **1000 samples**: Quick tests, basic envelope continuity checks
- **4410 samples**: Standard RMS comparisons, frequency analysis
- **11025+ samples**: High-precision measurements, long-term stability tests

### Pitch and Frequency Analysis

When testing pitch modulation (LFO pitch effects, vibrato, etc.), work in **note space**, not frequency space:

**Why**: Musical pitch perception is logarithmic. Each semitone is a factor of 2^(1/12) ≈ 1.059, so taking arithmetic means of frequencies gives incorrect results.

**Conversion**: `note = 69 + 12 * log2(frequency / 440)`
- Note 69 = A4 = 440Hz
- Note 60 = C4 = ~261.63Hz  
- Note 72 = C5 = ~523.25Hz

**Example usage**:
```swift
// Convert frequencies to note values for correct averaging
var noteValues: [Double] = []
for freq in frequencies {
    let noteValue = 69.0 + 12.0 * log2(freq / 440.0)
    noteValues.append(noteValue)
}
let centerNote = noteValues.reduce(0.0, +) / Double(noteValues.count)
#expect(centerNote > 68.9 && centerNote < 69.1) // Should center around A4
```

## Synthesizer Identifiers

- The audio unit identifier for the Vox synthesizer is "aumu Atng nSat"

## Next Steps

1. Check open issues with `bd list`
2. Pick the highest priority issue to work on
3. Follow the development process workflow above
