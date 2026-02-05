# Level Meter Implementation Specification

## Current State Analysis

### Visual Issues (from screenshot)
1. **Too Wide**: The horizontal level meter occupies ~40% of the MAIN panel width, disproportionate to other controls
2. **Static Display**: Shows color gradient but no actual movement - not connected to audio
3. **Layout Mismatch**: Current implementation uses `LevelMeter(orientation: .vertical, ...)` in code but displays horizontally in UI

### Implementation Issues

1. **No Data Pipeline**: The `LevelMeter.swift` component has an `updateLevel()` method but nothing calls it
2. **No DSP Metering**: `VoxExtensionDSPKernel.hpp` doesn't calculate output levels
3. **No Communication Path**: No mechanism exists to pass real-time level data from the render thread to the UI
4. **Isolated State**: `LevelMeter` uses `@State private var level: Double = 0.0` which can't receive external updates

---

## Architecture Design

### Key Design Decision: NOT a Parameter

**This is NOT an AUParameter.** Output level is:
- Read-only observational data
- Not user-controllable
- Not automatable by the DAW
- Not saved in presets

We bypass the entire parameter system and use direct atomic reads.

### Data Flow

```
DSP Kernel (render thread)
    │
    ├─ Calculate peak per buffer
    ├─ Store in std::atomic<float>  ← Lock-free, wait-free
    │
    ▼
Swift Bridge (AudioUnit)
    │
    ├─ kernel.getOutputPeakLevel()  ← Direct C++ call
    │
    ▼
UI Timer (main thread ~60Hz)
    │
    ├─ Poll atomic value
    │
    ▼
LevelMeter View
    │
    └─ Update display
```

### Thread Safety Requirements

- DSP runs on real-time audio thread - no locks, no allocations
- UI runs on main thread at ~60fps
- Using `volatile float` instead of `std::atomic<float>`:
  - `std::atomic` breaks Swift/C++ interop (makes class non-copyable)
  - On ARM64/x86_64, aligned float reads/writes are naturally atomic
  - Volatile prevents compiler optimization of the writes
  - Acceptable for display-only metering where occasional tearing is fine

---

## Detailed Component Specifications

### 1. DSP Kernel Changes (`VoxExtensionDSPKernel.hpp`)

#### Two Distinct Values

| Value | Purpose | Behavior |
|-------|---------|----------|
| `mOutputLevel` | Bar meter display | Fast attack, ~50ms decay |
| `mOutputPeakHold` | Peak LED indicator | Instant attack, ~1.5s decay |

```cpp
// Add to member variables:
std::atomic<float> mOutputLevel{0.0f};      // Current level for bar display
std::atomic<float> mOutputPeakHold{0.0f};   // Peak hold for LED indicator

// Internal working values (not atomic - only used on audio thread)
float mCurrentLevel = 0.0f;
float mPeakHoldValue = 0.0f;
float mLevelDecayCoeff = 0.0f;      // ~50ms decay for bar
float mPeakHoldDecayCoeff = 0.0f;   // ~1.5s decay for peak LED

// Add to initialize():
// Decay coefficients: coeff = exp(-1 / (sampleRate * decayTimeSeconds))
mLevelDecayCoeff = expf(-1.0f / (static_cast<float>(mSampleRate) * 0.05f));      // 50ms
mPeakHoldDecayCoeff = expf(-1.0f / (static_cast<float>(mSampleRate) * 1.5f));    // 1.5s

// Add after the sample loop in process():
// Find peak in this buffer
float bufferPeak = 0.0f;
for (UInt32 i = 0; i < frameCount; ++i) {
    float absSample = fabsf(outputBuffers[0][i]);
    if (absSample > bufferPeak) {
        bufferPeak = absSample;
    }
}

// Update current level (fast attack, moderate decay)
if (bufferPeak > mCurrentLevel) {
    mCurrentLevel = bufferPeak;  // Instant attack
} else {
    // Apply decay per-buffer (approximate for efficiency)
    float decayFrames = powf(mLevelDecayCoeff, static_cast<float>(frameCount));
    mCurrentLevel *= decayFrames;
}

// Update peak hold (instant attack, slow decay)
if (bufferPeak > mPeakHoldValue) {
    mPeakHoldValue = bufferPeak;
} else {
    float decayFrames = powf(mPeakHoldDecayCoeff, static_cast<float>(frameCount));
    mPeakHoldValue *= decayFrames;
}

// Store atomically for UI access
mOutputLevel.store(mCurrentLevel, std::memory_order_relaxed);
mOutputPeakHold.store(mPeakHoldValue, std::memory_order_relaxed);

// Add getter methods:
float getOutputLevel() const {
    return mOutputLevel.load(std::memory_order_relaxed);
}

float getOutputPeakHold() const {
    return mOutputPeakHold.load(std::memory_order_relaxed);
}
```

### 2. AudioUnit Swift Bridge (`VoxExtensionAudioUnit.swift`)

```swift
// Add public accessors:
public func getOutputLevel() -> Float {
    return kernel.getOutputLevel()
}

public func getOutputPeakHold() -> Float {
    return kernel.getOutputPeakHold()
}
```

### 3. UI Model (`OutputLevelObserver.swift` - new file)

```swift
import SwiftUI

@Observable
class OutputLevelObserver {
    var level: Float = 0.0       // Current level for bar display
    var peakHold: Float = 0.0    // Peak hold for LED
    var isPeaking: Bool = false  // True when peak > 0.99 (clipping)
    
    private weak var audioUnit: VoxExtensionAudioUnit?
    private var timer: Timer?
    
    init(audioUnit: VoxExtensionAudioUnit?) {
        self.audioUnit = audioUnit
    }
    
    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateLevels()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateLevels() {
        guard let au = audioUnit else { return }
        level = au.getOutputLevel()
        peakHold = au.getOutputPeakHold()
        isPeaking = peakHold > 0.99
    }
}
```

### 4. LevelMeter View Updates (`LevelMeter.swift`)

The LevelMeter needs to be simplified - remove internal state/timers and accept level as a simple parameter:

```swift
struct LevelMeter: View {
    // Accept level directly (0.0 to 1.0)
    let level: Double
    
    let orientation: Orientation
    let segmentCount: Int
    let width: CGFloat
    let height: CGFloat
    
    enum Orientation {
        case vertical
        case horizontal
    }
    
    init(
        level: Double = 0.0,
        orientation: Orientation = .vertical,
        segmentCount: Int = 12,
        width: CGFloat = 20,
        height: CGFloat = 120
    ) {
        self.level = max(0.0, min(1.0, level))
        self.orientation = orientation
        self.segmentCount = segmentCount
        self.width = width
        self.height = height
    }
    
    // Remove updateLevel() method - no longer needed
    // Remove @State level and peakLevel
    // Remove Timer logic
    // Keep segmentColor() and shouldShowSegment() logic
}
```

### 5. MainSection Integration (`MainSection.swift`)

```swift
struct MasterControls: View {
    @State var volumeParam: ObservableAUParameter
    var levelObserver: OutputLevelObserver
    
    var body: some View {
        VStack(spacing: 8) {
            Text("MASTER")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.synthSecondary)
            
            HStack(spacing: 12) {
                // Master volume knob
                VStack(spacing: 4) {
                    SynthKnob(param: volumeParam, size: 50)
                    Text("VOLUME")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.synthSecondary)
                }
                
                // Output level meter
                VStack(spacing: 4) {
                    Text("OUT")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.synthSecondary)
                    
                    // Single mono meter (synth is mono)
                    LevelMeter(
                        level: Double(levelObserver.level),
                        orientation: .vertical,
                        segmentCount: 10,
                        width: 12,
                        height: 60
                    )
                    
                    PeakIndicator(size: 10, color: .red)
                        .opacity(levelObserver.isPeaking ? 1.0 : 0.3)
                }
            }
        }
    }
}
```

---

## Visual Specifications

### Meter Dimensions
- **Orientation**: Vertical (matching analog synth aesthetics)
- **Segment Width**: 8px each (16px total for stereo pair)
- **Height**: 60px (matching knob diameter)
- **Segment Count**: 10 segments
- **Segment Gap**: 1px

### Color Scheme
| Level Range | Color   | Segments |
|-------------|---------|----------|
| 0-60%       | Green   | 1-6      |
| 60-80%      | Yellow  | 7-8      |
| 80-90%      | Orange  | 9        |
| 90-100%     | Red     | 10       |

### Animation
- **Meter Movement**: 60fps updates
- **Peak Hold**: 1 second hold, then 2 second decay
- **Peak LED**: Illuminate on any sample > 99%, hold 500ms

---

## Implementation Phases

### Phase 1: DSP Level Measurement (C++)
1. Add atomic level storage to kernel
2. Calculate peak per buffer in `process()`
3. Add decay for smooth metering
4. Add getter methods

### Phase 2: Swift Bridge
1. Add `getOutputPeakLevel()` to AudioUnit
2. Create `OutputLevelObserver` class
3. Wire timer-based polling

### Phase 3: UI Integration
1. Update `LevelMeter` to accept external level binding
2. Fix dimensions (narrow vertical meter)
3. Update `MasterControls` to use observer
4. Wire peak indicator

### Phase 4: Testing & Polish
1. Verify no audio glitches from metering
2. Test CPU impact
3. Fine-tune decay/hold times
4. Ensure responsive UI updates

---

## Testing Checklist

- [ ] Meter responds to audio output
- [ ] Peak indicator lights on clipping
- [ ] No audio thread blocking
- [ ] Smooth 60fps animation
- [ ] Correct color thresholds
- [ ] Peak hold/decay behavior
- [ ] Layout fits MAIN section properly
- [ ] Works in standalone and as AUv3

---

## Risk Considerations

1. **Thread Safety**: Using `std::atomic` with relaxed ordering is safe for single-producer/single-consumer scenarios
2. **CPU Overhead**: Peak calculation per sample is O(n) - negligible compared to DSP
3. **UI Responsiveness**: Timer-based polling at 60Hz is ~16ms intervals, well within frame budget
