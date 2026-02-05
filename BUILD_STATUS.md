# Vox Build Status - Phase 1 MVP

## ✅ Completed

### DSP Implementation
- **PulsarOscillator** (`VoxCore/DSP/Oscillators/PulsarOscillator.h`)
  - All 4 pulsaret shapes: Gaussian, Raised Cosine, Sine, Triangle
  - Duty cycle control (0.01 to 1.0)
  - Frequency from MIDI notes
  - Phase control and reset
  - ✅ Compiles successfully

- **FormantFilter** (`VoxCore/DSP/Filters/FormantFilter.h`)
  - Two parallel resonant bandpass filters
  - Vowel morph (A-E-I-O-U)
  - Adjustable Q/resonance
  - ✅ Compiles successfully

- **ADSREnvelope** (`VoxCore/DSP/Envelopes/ADSREnvelope.h`)
  - Analog-style exponential curves
  - Attack: 1ms - 4s
  - Decay: 1ms - 4s
  - Sustain: 0 - 100%
  - Release: 1ms - 8s
  - ✅ Compiles successfully

- **VoxVoice** (`VoxCore/DSP/Voice/VoxVoice.h`)
  - Integrates PulsarOscillator + FormantFilter + ADSR
  - MIDI note handling
  - Velocity support
  - Pitch bend
  - Glide/portamento
  - ✅ Compiles successfully

### Audio Unit Integration
- **VoxExtensionDSPKernel** - Connects VoxVoice to AU
- **Parameters** - Phase 1 minimal set implemented:
  - `masterVolume` - Output level
  - `pulsaretShape` - 0-3 (Gaussian, RaisedCos, Sine, Triangle)
  - `dutyCycle` - 1-100%
  - `vowelMorph` - 0-1 (A→U)
  - `formant1Freq`, `formant2Freq` - Hz
  - `formant1Q`, `formant2Q` - Q factor
  - `formantMix` - Dry/wet
  - `ampAttack`, `ampDecay`, `ampSustain`, `ampRelease` - ADSR
  - `glideEnabled`, `glideTime` - Portamento
  - `pitchBendRange` - Semitones

### Project Structure
- ✅ Renamed from AnalogThing → Vox
- ✅ All file references updated
- ✅ Bundle IDs: `com.unsaturated.Vox`
- ✅ AU identifier: `aumu Vox SYNC`

## ⚠️ Needs Manual Setup

### Code Signing
The project needs provisioning profiles created. Open `Vox.xcodeproj` in Xcode and:

1. Select **Vox** target → Signing & Capabilities
   - Set Team to your Apple Developer account
   - Create `VoxApp` provisioning profile

2. Select **VoxExtension** target → Signing & Capabilities
   - Set Team to your Apple Developer account
   - Create `VoxExtension` provisioning profile

3. Select **VoxCore** target → Signing & Capabilities
   - Verify Team is set correctly

Then run:
```bash
./build.sh
```

## 🎯 To Validate

After successful build:
```bash
auval -v aumu Vox SYNC
```

## 📋 Phase 2 TODO

1. **2x Oversampling** - Anti-aliasing for low duty cycles
2. **LFO** - Modulation source for duty, vowel, pitch
3. **Parameter smoothing** - 10ms smoothing to prevent zipper noise
4. **UI Polish** - SwiftUI parameter sections
5. **Preset system** - Save/load sounds

## Files Modified

- `Vox.xcodeproj/project.pbxproj` - Build settings
- `VoxCore/include/PulsarOscillator.h` - New oscillator
- `VoxCore/include/FormantFilter.h` - New filter
- `VoxCore/include/VoxVoice.h` - New voice
- `VoxExtension/DSP/VoxExtensionDSPKernel.hpp` - AU integration
- `VoxExtension/Parameters/Parameters.swift` - New params
- `VoxExtension/Parameters/VoxExtensionParameterAddresses.h` - Param IDs
