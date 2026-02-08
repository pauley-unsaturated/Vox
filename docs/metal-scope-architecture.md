# Metal Scope & Real-Time Visualization Architecture

*Atomic ring buffer + Metal shaders for grain-level visual feedback*

## Problem

Phase 8 visualization tasks (pulsaret scope, grain cloud, chaos plot, etc.) require
**audio-rate data** rendered at **display refresh rate**. SwiftUI Path/Canvas can't
keep up with per-grain rendering at high densities. We need:

1. Lock-free audio→UI data transfer (no priority inversion)
2. GPU-accelerated rendering for thousands of points per frame
3. A pattern that works for ALL the Phase 8 viz components

## Architecture

### 1. Atomic Ring Buffer (Audio Thread → GPU)

```
┌──────────────────┐        ┌──────────────────────┐        ┌──────────────┐
│   Audio Thread   │        │   Lock-Free Ring Buf  │        │  Metal View  │
│                  │        │                       │        │              │
│  PulsarOsc ──────┼──write─┼→ [sample][sample]... │──read──┼→ MTKView     │
│  Envelope ───────┼──write─┼→ [adsr_pos][level].. │──read──┼→ GPU Shader  │
│  Grain Events ───┼──write─┼→ [grain_info]...     │──read──┼→ Vertex Buf  │
│                  │        │                       │        │              │
│  ⚠️ NO LOCKS     │        │  Atomic read/write    │        │  60fps draw  │
│  ⚠️ NO ALLOC     │        │  heads (relaxed order) │       │              │
└──────────────────┘        └──────────────────────┘        └──────────────┘
```

#### Ring Buffer Design

```swift
/// Lock-free SPSC ring buffer for audio→UI data transfer.
/// Audio thread writes, render thread reads. No locks, no allocations.
final class AtomicScopeBuffer<T> {
    private let capacity: Int
    private let buffer: UnsafeMutableBufferPointer<T>
    private let writeHead = ManagedAtomic<Int>(0)  // swift-atomics
    private let readHead = ManagedAtomic<Int>(0)
    
    /// Called from audio thread — must be lock-free, allocation-free
    func write(_ value: T) {
        let w = writeHead.load(ordering: .relaxed)
        buffer[w % capacity] = value
        writeHead.store(w &+ 1, ordering: .releasing)
    }
    
    /// Called from render thread — drains available samples into Metal buffer
    func drainInto(_ metalBuffer: UnsafeMutablePointer<T>, maxCount: Int) -> Int {
        let w = writeHead.load(ordering: .acquiring)
        let r = readHead.load(ordering: .relaxed)
        let available = min(w &- r, maxCount)
        for i in 0..<available {
            metalBuffer[i] = buffer[(r &+ i) % capacity]
        }
        readHead.store(r &+ available, ordering: .releasing)
        return available
    }
}
```

#### Data Types for Each Scope

```swift
// Pulsaret scope — raw waveform + grain boundaries
struct ScopeSample {
    var amplitude: Float    // raw audio sample
    var grainPhase: Float   // 0-1 within current grain (for coloring)
    var isGrainStart: Bool  // grain boundary marker
}

// Grain cloud scatter — per-grain event
struct GrainEvent {
    var frequency: Float    // fundamental freq
    var formant: Float      // formant freq
    var amplitude: Float    // grain amplitude
    var dutyCycle: Float    // duty cycle ratio
    var timestamp: UInt64   // mach_absolute_time for animation
}

// Chaos attractor — phase space point
struct ChaosPoint {
    var x: Float  // e.g., Lorenz x
    var y: Float  // e.g., Lorenz y
    var age: Float // for trail fade
}

// Envelope trace — real-time position
struct EnvelopeState {
    var phase: UInt8     // attack/decay/sustain/release/idle
    var level: Float     // current envelope output 0-1
    var elapsed: Float   // time in current phase
}
```

### 2. Metal Rendering Layer

Each visualization is a **Metal shader + MTKView** wrapped for SwiftUI via `UIViewRepresentable`.

```
┌─────────────────────────────────────────────────┐
│  MetalScopeView : MTKView, MTKViewDelegate      │
│                                                  │
│  draw(in:) called at display refresh rate        │
│    1. Drain ring buffer → staging MTLBuffer      │
│    2. Encode render pass                         │
│    3. Vertex shader positions samples            │
│    4. Fragment shader colors by grain phase      │
│    5. Present drawable                           │
│                                                  │
│  Shaders:                                        │
│    pulsaret_scope.metal   — oscilloscope trace   │
│    grain_cloud.metal      — 2D scatter plot      │
│    chaos_attractor.metal  — phase space trails   │
│    spectrum_display.metal — FFT bars + markers   │
│    level_meter.metal      — VU bars              │
└─────────────────────────────────────────────────┘
```

#### Example: Pulsaret Scope Shader

```metal
#include <metal_stdlib>
using namespace metal;

struct ScopeVertex {
    float amplitude;
    float grainPhase;
    uint  isGrainStart;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut scope_vertex(
    const device ScopeVertex* samples [[buffer(0)]],
    constant float2& viewport [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    VertexOut out;
    float x = (float(vid) / viewport.x) * 2.0 - 1.0;  // normalize to NDC
    float y = samples[vid].amplitude;                     // already -1..1
    out.position = float4(x, y, 0, 1);
    
    // Color by grain phase: cyan at start → dark at end
    float phase = samples[vid].grainPhase;
    out.color = float4(0.0, 1.0 - phase * 0.7, 1.0 - phase * 0.5, 1.0);
    
    // Bright marker at grain boundaries
    if (samples[vid].isGrainStart) {
        out.color = float4(1.0, 0.5, 0.0, 1.0);  // orange flash
    }
    
    return out;
}

fragment float4 scope_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}
```

### 3. SwiftUI Integration

```swift
struct MetalScopeWrapper: UIViewRepresentable {
    let buffer: AtomicScopeBuffer<ScopeSample>
    
    func makeUIView(context: Context) -> MetalScopeView {
        let view = MetalScopeView(buffer: buffer)
        view.preferredFramesPerSecond = 60
        view.isPaused = false
        return view
    }
    
    func updateUIView(_ uiView: MetalScopeView, context: Context) {}
}

// In the main synth UI:
MetalScopeWrapper(buffer: audioEngine.scopeBuffer)
    .frame(height: 120)
    .clipShape(RoundedRectangle(cornerRadius: 8))
```

## Validation Strategy

### How do we know it's working?

#### Level 1: Unit Tests (no GPU needed)

```swift
// Ring buffer correctness
func testRingBufferSPSC() {
    let buf = AtomicScopeBuffer<Float>(capacity: 1024)
    // Write from one thread, read from another, verify ordering
    // Test wrap-around behavior
    // Test drain count accuracy
}

func testRingBufferOverflow() {
    // Write more than capacity, verify no crash, old data overwritten
}

func testRingBufferEmpty() {
    // Drain empty buffer returns 0
}
```

#### Level 2: Audio Thread Safety

```swift
// Verify no allocations/locks on audio thread
func testAudioThreadRealtime() {
    // Use os_signpost / mach_absolute_time to verify write() < 100ns
    // Run under Thread Sanitizer to verify no races
}
```

#### Level 3: Integration — Synthetic Data

```swift
// Feed known waveform (sine, saw) into ring buffer,
// capture Metal texture output, verify visual correctness
func testScopeRendersKnownWaveform() {
    let buf = AtomicScopeBuffer<ScopeSample>(capacity: 2048)
    // Write one cycle of sine at 440Hz
    for i in 0..<2048 {
        buf.write(ScopeSample(
            amplitude: sin(Float(i) / 2048.0 * .pi * 2),
            grainPhase: Float(i % 256) / 256.0,
            isGrainStart: i % 256 == 0
        ))
    }
    // Render one frame, read back texture, verify non-black
}
```

#### Level 4: Screenshot Validation (Agent Feedback Loop)

See "Agent UI Feedback" section below — this is how we validate the VISUAL output.

---

## Agent UI Feedback Architecture

### The Problem

Sub-agent workers building UI code can't see what the UI looks like. They write SwiftUI/Metal
code blind, with no visual feedback. This is especially bad for:
- Scope rendering (is the waveform actually showing?)  
- Layout/spacing (does it look right?)
- Color/theme consistency
- Animation smoothness

### Proposed Solutions

#### Method 1: Headless Screenshot Pipeline (Recommended Primary)

```
┌─────────────┐     ┌──────────┐     ┌──────────────┐     ┌──────────┐
│ Agent writes │────►│ xcodebuild│────►│ Launch AU    │────►│ Screenshot│
│ Swift code   │     │ (build)   │     │ host app +   │     │ via       │
│              │     │           │     │ send MIDI    │     │ screencap │
└─────────────┘     └──────────┘     └──────────────┘     └──────────┘
                                                                │
                                                          ┌─────▼──────┐
                                                          │ Agent sees  │
                                                          │ screenshot  │
                                                          │ + evaluates │
                                                          └────────────┘
```

**Components needed:**
1. **Standalone host app** (or extend existing test host)
   - Loads the AU plugin
   - Sends configurable MIDI notes (so scopes have data)
   - Runs headless or with a window
2. **Screenshot script** (`scripts/capture-ui.sh`)
   - Builds the project
   - Launches host app
   - Waits for UI to render + audio to produce scope data
   - Captures window screenshot via `screencapture -l <windowID>`
   - Kills the app
   - Returns image path
3. **MIDI stimulus file** (`test-fixtures/ui-test-notes.mid` or JSON)
   - A short phrase that exercises various grain shapes
   - Chords for polyphony testing
   - Various velocities for envelope testing

**Usage by agent worker:**
```bash
# Build, launch, screenshot in one command
./scripts/capture-ui.sh --midi test-fixtures/scope-test.json --delay 2 --output /tmp/vox-ui.png
```

#### Method 2: SwiftUI Preview Snapshots

```swift
// Snapshot tests using swift-snapshot-testing
func testPulsaretScopeAppearance() {
    let view = MetalScopeWrapper(buffer: mockBuffer)
        .frame(width: 400, height: 120)
    assertSnapshot(matching: view, as: .image)
}
```

**Pros:** Fast, no app launch needed, CI-friendly
**Cons:** Metal views may not render correctly in snapshot tests (no GPU context)

#### Method 3: Peekaboo (macOS UI Automation)

Using the `peekaboo` skill already installed:
```bash
# Capture specific window
peekaboo capture --app "Vox" --format png --output /tmp/vox-ui.png

# Or capture entire screen
peekaboo screen --output /tmp/screen.png
```

**Best for:** Verifying the plugin inside Logic/AU Lab where we can't control the host.

#### Method 4: XCUITest + Screenshots

```swift
// UI test that launches, plays notes, captures
func testScopeVisualization() {
    let app = XCUIApplication()
    app.launch()
    // Trigger MIDI notes via virtual MIDI
    sleep(2)
    let screenshot = app.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.lifetime = .keepAlways
    add(attachment)
}
```

### Recommended Agent Worker Flow

```
┌─────────────────────────────────────────────────────────┐
│                 AGENT UI DEVELOPMENT LOOP                │
│                                                          │
│  1. Read task spec + current code                        │
│  2. Write/modify Swift code                              │
│  3. Build: xcodebuild (check for compile errors)         │
│  4. Run tests: xcodebuild test (check logic)             │
│  5. Screenshot: ./scripts/capture-ui.sh                  │
│  6. Analyze screenshot (vision model)                    │
│  7. Does it look right?                                  │
│     ├─ YES → commit, move to next task                   │
│     └─ NO  → adjust code, go to step 3                   │
│                                                          │
│  Max iterations: 5 (then escalate to human)              │
└─────────────────────────────────────────────────────────┘
```

### What We Need to Build First

1. **`scripts/capture-ui.sh`** — the screenshot pipeline script
2. **Test host app** improvements — MIDI input, headless mode, window positioning
3. **`scripts/send-test-midi.sh`** — sends known MIDI patterns via CoreMIDI
4. **Reference screenshots** — "golden" images for comparison
5. **Agent instructions** (`AGENTS.md` in Vox repo) — how sub-agents should use the feedback loop

### Giving Agents Agency for UI Work

The key insight: **agents need a tight build→see→adjust loop**, not just build→test.

**In the agent task prompt, include:**
```
You have access to a visual feedback loop:
1. After code changes, run: ./scripts/capture-ui.sh --output /tmp/vox-ui.png
2. Analyze the screenshot to verify your changes look correct
3. The screenshot shows the synth UI with active audio (scopes should be moving)
4. Compare against the design spec in docs/ui-proposals/
5. If the screenshot is blank or wrong, check build errors first
```

**What this enables:**
- Agent can iterate on visual appearance without human in the loop
- Agent can verify Metal shaders produce visible output
- Agent can check layout, spacing, colors match the design
- Agent can catch regressions (scope stopped drawing, etc.)
