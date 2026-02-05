# VoxCore Framework

This framework contains the pure C++ DSP components for the Vox synthesizer. It provides a clean separation between the core audio processing code and the Swift-based AudioUnit extension.

## Architecture

The framework is organized as follows:

### C++ Core DSP Components

Located in the `DSP` directory:

- **Filters**: Digital filters implementation, including the Moog Ladder Filter
- **Oscillators**: Various oscillator implementations (Sine, PolyBLEP, DPW, etc.)

These components are written in C++ for performance and efficiency.

## Usage

### Adding to Xcode Project

1. Add the framework target to your Xcode project
2. Configure build settings for C++ interoperability
3. Add the framework as a dependency to both the extension and test targets

### Using in Code

In Swift code through Swift-C++ interop:

```swift
import VoxCore

// Direct C++ usage through C++ interop
let filter = MoogLadderFilter(44100.0)
filter.setCutoff(1000.0)
filter.setResonance(0.8)
filter.setMode(FilterMode.LOWPASS)

// Process audio
let output = filter.process(input)
```

The recommended way is to use the Swift wrappers found in the VoxExtension:

```swift
import VoxExtension

// Using Swift wrappers
let filter = FilterWrapper(sampleRate: 44100.0)
filter.setCutoff(1000.0)
filter.setResonance(0.8)
filter.setMode(.lowpass)

// Process audio
let output = filter.process(withInput: input)
```

## Benefits of Framework Approach

1. **Shared Code**: Both the extension and tests can link against the same C++ framework
2. **Clear Separation**: Pure C++ DSP code is separate from Swift wrapper and AudioUnit implementation
3. **Improved Testing**: Direct testing of DSP components without wrapper overhead
4. **Better Organization**: Clean architecture with proper separation of concerns
5. **Simplified Maintenance**: Core DSP code can evolve independently of Swift wrappers and UI/extension
6. **Performance**: C++ code can be optimized for performance without Swift overhead

## C++ Interoperability

This framework is designed to be used with Swift's C++ interoperability features, allowing direct use of C++ classes from Swift code without an intermediate Objective-C++ layer.

Key files for C++ interop:
- `module.modulemap`: Defines module structure for C++ interop
- `ModuleHeaders.h`: Umbrella header for C++ headers
- `VoxCore.h`: Framework header that exposes public C++ headers