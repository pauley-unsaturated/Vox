# Solving AUv3 synthesizer parameter issues in Logic Pro

Your AUv3 plugin faces two critical issues that plague many audio developers: parameters displaying as integers instead of decimals, and automation breaking when engaged. After extensive research across Apple documentation, developer communities, and professional implementations, here are the definitive solutions.

## The maxFramesToRender bug breaks automation

The most critical issue causing parameter automation to stop working is a **bug in Apple's Xcode AUv3 template**. Logic Pro requests different buffer sizes depending on track selection:
- **Selected tracks**: Receive your I/O Buffer Size setting (e.g., 256 frames)
- **Unselected tracks**: Always receive 1024 frames regardless of settings

The Xcode template sets `maxFramesToRender = 512`, causing render failures on unselected tracks. **This single line fix resolves most automation issues**:

```cpp
// In DSPKernel.hpp or equivalent
// Change from default 512 to 1024
static const UInt32 maxFramesToRender = 1024;
```

## Linear gain parameters require specific configuration

For parameters to display as decimals (0.0-1.0) instead of integers in Logic Pro, you need precise parameter configuration:

```swift
let gainParameter = AUParameter(
    identifier: "gain",
    name: "Gain",
    address: gainParameterAddress,
    min: 0.0,
    max: 1.0,
    unit: .linearGain,  // Critical: Use the correct unit type
    unitName: nil,
    flags: [.flag_IsReadable, .flag_IsWritable, .flag_CanRamp, .flag_IsHighResolution],
    valueStrings: nil,
    dependentParameters: nil
)
```

**Key requirements for decimal display**:
- Use `.linearGain` unit type (not `.generic` or `.indexed`)
- Set **flag_IsHighResolution** - without this, Logic Pro quantizes values to ~100-128 levels
- Include proper min/max range (0.0-1.0)
- Consider using `.percent` or `.decibels` as alternatives if `.linearGain` continues showing integers

## Parameter automation requires thread-safe implementation

Your parameterTree stops receiving updates because of incorrect observer configuration during rendering. Implement this dual-mode pattern:

```objc
- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    // CRITICAL: Switch to scheduled parameter updates during rendering
    __block AUScheduleParameterBlock scheduleParameter = self.scheduleParameterBlock;
    __block AUAudioFrameCount rampTime = AUAudioFrameCount(0.02 * self.outputBus.format.sampleRate);
    
    // While rendering, schedule all parameter changes for thread safety
    self.parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        scheduleParameter(AUEventSampleTimeImmediate, rampTime, param.address, value);
    };
    
    return YES;
}

- (void)deallocateRenderResources {
    // Switch back to direct parameter setting when not rendering
    __block InstrumentDSPKernel *kernel = &_kernel;
    self.parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        kernel->setParameter(param.address, value);
    };
}
```

## Professional parameter ramping implementation

The `flag_canRamp` option enables smooth automation curves. Here's how to implement it properly:

```objc
// In your render block - handle parameter events
const AURenderEvent *event = realtimeEventListHead;
while (event != NULL) {
    if (event->head.eventType == AURenderEventParameter ||
        event->head.eventType == AURenderEventParameterRamp) {
        
        const AUParameterEvent *paramEvent = &event->parameter;
        
        if (event->head.eventType == AURenderEventParameterRamp) {
            // Ramped parameter change - smooth transition
            StartParameterRamp(paramEvent->parameterAddress,
                             paramEvent->value,
                             paramEvent->rampDurationSampleFrames);
        } else {
            // Immediate parameter change
            SetParameter(paramEvent->parameterAddress, paramEvent->value);
        }
    }
    event = event->head.next;
}
```

## Critical Logic Pro automation recording fix

For automation to record properly in Logic Pro's touch/latch modes, you **must** implement gesture signaling:

```swift
// In your UI parameter change handlers
func sliderTouchDown(_ slider: UISlider) {
    let param = audioUnit.parameterTree?.parameter(withAddress: sliderAddress)
    param?.setValue(slider.value, originator: nil, atHostTime: 0, 
                   eventType: .touch)
}

func sliderTouchUp(_ slider: UISlider) {
    let param = audioUnit.parameterTree?.parameter(withAddress: sliderAddress)
    param?.setValue(slider.value, originator: nil, atHostTime: 0, 
                   eventType: .release)
}
```

## Common pitfalls causing parameter issues

**Thread safety violations** crash plugins during automation:
```objc
// WRONG - Not realtime safe
tree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
    NSLog(@"Parameter changed"); // Logging in audio thread
    [self.delegate parameterChanged:value]; // Objective-C calls
};

// CORRECT - Realtime safe
tree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
    // Only atomic operations and simple assignments
    if (param.address < MAX_PARAMETERS) {
        parameterValues[param.address] = value;
    }
};
```

**Missing parameter flags** prevent proper host integration:
- Without `flag_IsHighResolution`: Parameters quantize to integer-like steps
- Without `flag_CanRamp`: No smooth automation curves
- Without proper read/write flags: Parameters won't automate at all

## Implementing robust parameter trees

Professional plugins use this pattern for reliable parameter handling:

```swift
// Parameter tree with proper grouping
let parameterTree = AUParameterTree.createTree(withChildren: [
    AUParameterGroup.createGroup(
        withIdentifier: "oscillator",
        name: "Oscillator",
        children: [frequencyParam, gainParam]
    ),
    AUParameterGroup.createGroup(
        withIdentifier: "filter",
        name: "Filter", 
        children: [cutoffParam, resonanceParam]
    )
])

// Essential observer setup
parameterTree.implementorValueObserver = { param, value in
    // Update audio unit state
    audioUnit.setParameterValue(value, for: param.address)
}

parameterTree.implementorValueProvider = { param in
    // Return current parameter value
    return audioUnit.getParameterValue(for: param.address)
}
```

## Testing and validation checklist

1. **Verify buffer size handling**: Test with both selected and unselected tracks in Logic Pro
2. **Check parameter display**: Confirm decimal values show correctly in automation lanes
3. **Test automation modes**: Verify touch, latch, and read modes all work properly
4. **Validate with auval**: Run `auval -v aufx YourType YourManuf` to check for issues
5. **Test gesture recording**: Ensure parameter changes record when automating

## Conclusion

The core solutions to your issues are straightforward: fix the maxFramesToRender bug for automation, use proper parameter unit types with high-resolution flags for decimal display, and implement thread-safe parameter handling with scheduled updates during rendering. These changes, derived from extensive developer experience and professional implementations, will resolve both the integer display and automation breaking issues in your AUv3 synthesizer plugin.