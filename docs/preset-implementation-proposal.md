# Preset Implementation Proposal

## Overview

This document proposes the implementation of preset functionality for Vox using the AUv3 preset system.

## AUv3 Preset System Summary

| Type | Number | Storage | Behavior |
|------|--------|---------|----------|
| Factory Presets | >= 0 | In code/bundle | Read-only, immutable |
| User Presets | < 0 | Managed by AUAudioUnit | User can save/delete |

### Key APIs

- **`factoryPresets`**: Override to return array of `AUAudioUnitPreset(number:name:)`
- **`currentPreset`**: Set by host to load a preset; getter returns current
- **`fullState`**: Dictionary containing all serializable state (parameters + sequencer)
- **`supportsUserPresets`**: Already `true` in our implementation
- **`userPresets`**: Read-only list of user presets (auto-managed)
- **`saveUserPreset(_:)`**: Save current state as user preset
- **`deleteUserPreset(_:)`**: Remove a user preset
- **`presetState(for:)`**: Get saved state dictionary for a user preset

## Current State

**What's Working:**
- `supportsUserPresets = true` - hosts can manage user presets
- `currentPreset` setter loads user presets via `presetState(for:)` + `fullStateForDocument`
- `fullState` serializes all 58 parameters + sequencer step data
- State restoration handles plist format variations

**What's Missing:**
- No factory presets defined (empty list)
- UI is placeholder-only (dropdown, save/load buttons non-functional)
- No preset navigation (prev/next)

## Implementation Plan

### Phase 1: Factory Presets (AudioUnit Layer)

1. **Define factory preset data structure**
   ```swift
   private let factoryPresetData: [[String: AUValue]] = [
       // Preset 0: "Init"
       ["masterVolume": -6.0, "osc1Waveform": 0, ...],
       // Preset 1: "Classic Lead"
       ["masterVolume": -6.0, "osc1Waveform": 1, ...],
       // etc.
   ]
   ```

2. **Override `factoryPresets` property**
   ```swift
   public override var factoryPresets: [AUAudioUnitPreset] {
       return [
           AUAudioUnitPreset(number: 0, name: "Init"),
           AUAudioUnitPreset(number: 1, name: "Classic Lead"),
           AUAudioUnitPreset(number: 2, name: "Fat Bass"),
           // ... 10-15 factory presets
       ]
   }
   ```

3. **Handle factory preset loading in `currentPreset` setter**
   ```swift
   if preset.number >= 0 {
       // Factory preset - apply from factoryPresetData
       let data = factoryPresetData[Int(preset.number)]
       applyPresetData(data)
   }
   ```

### Phase 2: UI Integration

1. **Create `PresetManager` observable class**
   - Wraps audioUnit preset operations
   - Provides combined list of factory + user presets
   - Handles preset selection, save, delete

2. **Wire up `PresetControls` view**
   - Replace placeholder dropdown with actual Menu/Picker
   - Connect prev/next buttons to navigation
   - Implement SAVE button (prompts for name, calls `saveUserPreset`)
   - LOAD button optional (dropdown serves same purpose)

3. **Pass PresetManager through view hierarchy**
   - From `AudioUnitViewController` through `VoxExtensionMainView` to `MainSection`

### Phase 3: Initial Factory Presets (Sound Design)

Create 10-15 factory presets showcasing the synth:
1. Init (clean default)
2. Classic Lead
3. Fat Bass
4. Acid Squelch
5. Soft Pad
6. Punchy Pluck
7. SH-101 Style
8. Pro-One Lead
9. Vintage Strings
10. Resonant Sweep

## File Changes Required

| File | Changes |
|------|---------|
| `VoxExtensionAudioUnit.swift` | Add factoryPresets, factory preset data, update currentPreset setter |
| `MainSection.swift` | Wire PresetControls to actual functionality |
| `PresetManager.swift` (new) | Observable wrapper for preset operations |
| `VoxExtensionMainView.swift` | Pass preset manager to sections |

## Considerations

1. **Sequencer data in presets**: Factory presets should include interesting sequencer patterns
2. **Preset naming convention**: Use descriptive names that hint at sound character
3. **User preset storage**: Handled automatically by AUAudioUnit framework
4. **Standalone app**: May need additional file-based preset management (future enhancement)

## Estimated Scope

- **Phase 1**: ~2-3 files modified, ~150 lines new code
- **Phase 2**: ~3-4 files modified, ~200 lines new code
- **Phase 3**: Sound design work (parameter tuning)

## Risks

- SwiftUI Menu may have focus/click issues in plugin context (test early)
- User preset save/load relies on host implementation; test across DAWs
