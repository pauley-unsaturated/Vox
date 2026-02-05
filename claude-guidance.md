# CLAUDE.md - Guidance for Synthesizer Plugin Development

## Project Overview
This project is a subtractive synthesizer AudioUnit plugin inspired by classic mono-synths like the SH-101 and Pro-One, implementing algorithms from Välimäki and Huovilainen's paper "Oscillator and Filter Algorithms for Virtual Analog Synthesis" from Computer Music Journal Vol. 20, No. 2.

## How Claude Can Help

### DSP Algorithm Implementation
- Provide optimized implementations of the described algorithms
- Ensure proper anti-aliasing techniques are used
- Help with coefficient calculations for filters
- Suggest best practices for audio processing

### AudioUnit Development
- Guide through the AU v3 framework setup
- Provide templates for parameter handling
- Assist with MIDI implementation
- Suggest best practices for realtime audio processing

### Code Organization
- Suggest optimal class hierarchy
- Help maintain separation of concerns
- Ensure thread safety in audio processing
- Provide patterns for efficient voice management

### Performance Optimization
- Identify potential bottlenecks
- Suggest SIMD optimizations where applicable
- Help with benchmarking and profiling tools
- Ensure minimal allocations in audio thread

### UI Development
- Suggest approaches for custom UI components
- Help with parameter binding to UI elements
- Guide through CoreGraphics/Metal optimization

## Technical Reference

### Oscillator Implementation
The oscillator should be implemented using PolyBLEP or similar techniques to avoid aliasing. Key functionality:
- Multiple waveforms (saw, square/pulse, triangle, sine)
- Phase accumulation with anti-aliasing
- Hard sync between oscillators
- Pulse width modulation for square waves
- Sub-oscillator at -1 or -2 octaves

### Filter Implementation
Implement the Huovilainen Zero-Delay Feedback filter approach:
- Moog ladder topology with nonlinear processing
- Multiple filter modes (LP, BP, HP)
- Selectable slopes (12dB/oct, 24dB/oct)
- Resonance compensation
- Keyboard tracking

### Voice Architecture
- Monophonic with last/low/high note priority options
- Glide/portamento with multiple modes
- Simple but efficient envelope processing
- Modulation routing using a fixed topology for simplicity

### Development Workflow
1. Start with minimal viable implementation of core DSP components
2. Create unit tests for each component
3. Integrate components into a voice architecture
4. Connect voice to AudioUnit framework
5. Implement UI after core functionality is working
6. Optimize performance
7. Add additional features (arpeggiator, sequencer)

## Code Organization

```
Synthesizer/
├── Source/
│   ├── DSP/
│   │   ├── Oscillators/
│   │   │   ├── Oscillator.h/cpp (Base class)
│   │   │   ├── SawtoothOscillator.h/cpp
│   │   │   ├── SquareOscillator.h/cpp
│   │   │   ├── TriangleOscillator.h/cpp
│   │   │   ├── SineOscillator.h/cpp
│   │   │   ├── SubOscillator.h/cpp
│   │   │   └── NoiseGenerator.h/cpp
│   │   ├── Filters/
│   │   │   ├── Filter.h/cpp (Base class)
│   │   │   └── MoogLadderFilter.h/cpp
│   │   ├── Envelopes/
│   │   │   └── ADSREnvelope.h/cpp
│   │   ├── Modulation/
│   │   │   └── LFO.h/cpp
│   │   ├── Voice/
│   │   │   ├── Voice.h/cpp
│   │   │   └── VoiceManager.h/cpp
│   │   └── Utilities/
│   │       ├── Parameters.h/cpp
│   │       ├── MathUtilities.h/cpp
│   │       └── MIDI.h/cpp
│   ├── PluginProcessor.h/cpp
│   └── PluginEditor.h/cpp
├── Tests/
│   ├── OscillatorTests.cpp
│   ├── FilterTests.cpp
│   └── ...
└── Resources/
    ├── Presets/
    └── UI/
```

## Performance Considerations
- Use vectorized operations (SIMD) where possible
- Minimize memory allocations in audio thread
- Pre-compute expensive calculations when parameters change
- Use lookup tables for trigonometric functions when appropriate
- Consider block-based processing for efficiency

## Debugging Tips
- Use an oscilloscope plugin after yours in the chain to visualize output
- Add debug outputs for parameter values
- Test with sine sweeps to identify aliasing issues
- Test with impulses to verify filter behavior
- Use a spectrum analyzer to identify unwanted artifacts

## Testing Strategy
- Unit tests for each DSP component
- Integration tests for full voice architecture
- AU validation tool for compatibility
- Manual testing across multiple DAWs

## Resources
- AudioUnit v3 Documentation: [Apple Developer Documentation](https://developer.apple.com/documentation/audiounit)
- The Välimäki and Huovilainen paper for algorithm details
- Will Pirkle's "Designing Software Synthesizer Plug-Ins in C++" book for reference
