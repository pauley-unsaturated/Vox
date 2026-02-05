# Claude Code Development Process for Synthesizer Plugin

This document outlines the development workflow for Claude Code to follow when implementing the subtractive synthesizer AudioUnit plugin.

## Initial Setup

1. Create a Git repository for the project
2. Set up the Xcode project structure with appropriate targets:
   - Main AudioUnit plugin target
   - Test target for unit testing
3. Create build and test scripts:
   ```bash
   # build.sh - Build the plugin
   #!/bin/bash
   xcodebuild -project SynthesizerPlugin.xcodeproj -scheme SynthesizerPlugin -configuration Debug build
   ```
   
   ```bash
   # test.sh - Run the tests
   #!/bin/bash
   xcodebuild -project SynthesizerPlugin.xcodeproj -scheme SynthesizerPluginTests -configuration Debug test
   ```
4. Make the scripts executable: `chmod +x build.sh test.sh`

## Development Loop

For each item on the todo list, follow this process:

1. **Task Selection**: Select the next item from the todo list
2. **Implementation**: Implement the feature or component
3. **Unit Test**: Create unit test(s) to verify functionality
4. **Build & Test**: Run build and test scripts
5. **Iteration**: Fix any issues and repeat steps 2-4 until tests pass
6. **Self Review**: Perform a critical code review
7. **Refinement**: Implement improvements from self-review
8. **Documentation**: Create implementation notes
9. **Commit**: Commit changes with descriptive message
10. **Update Todo**: Mark the item as complete in todo list
11. **Proceed**: Move to the next item

## Task Tracking

Maintain a TODO.md file in the repository with this structure:

```markdown
# Synthesizer Plugin Development Tasks

## In Progress
- [ ] Current task description

## Upcoming
- [ ] Next task
- [ ] Future task

## Completed
- [x] Finished task
```

## Implementation Notes Template

For each completed task, create a note in the `docs/implementation/` folder:

```markdown
# Implementation Notes: [Task Name]

## Overview
Brief description of the implemented component/feature

## Technical Decisions
- Decision 1: Rationale
- Decision 2: Rationale

## Files Modified
- `path/to/file1.cpp`: Description of changes
- `path/to/file2.h`: Description of changes

## Testing Approach
Description of how the component was tested

## Future Considerations
Notes on potential improvements or related tasks
```

## Commit Message Format

Use this format for commit messages:

```
[Component] Implement <feature/component name>

- Added implementation of X
- Created unit tests for Y
- Fixed issue with Z

Part of #TaskID
```

## Self-Review Checklist

When reviewing implementation, consider:

1. **Correctness**: Does the implementation match the requirements?
2. **Performance**: Is the code efficient, especially for real-time audio?
3. **Clarity**: Is the code easily understandable?
4. **Consistency**: Does it follow the established patterns?
5. **Error Handling**: Are edge cases properly handled?
6. **Memory Management**: Are there potential leaks or unnecessary allocations?
7. **Testability**: Is the code properly tested?

## Initial Todo List

```markdown
# Synthesizer Plugin Development Tasks

## In Progress
- [ ] Project Setup (Xcode project, build scripts, folder structure)

## Upcoming
### Core DSP Components
- [ ] Base Oscillator Interface
- [ ] PolyBLEP Sawtooth Oscillator
- [ ] DPW Sawtooth Oscillator
- [ ] Oscillator Comparison Tool
- [ ] PolyBLEP & DPW Square/Pulse Oscillator with PWM
- [ ] Sub-Oscillator Implementation
- [ ] Oscillator Sync Capability
- [ ] Noise Generator
- [ ] Moog Ladder Filter Implementation
- [ ] ADSR Envelope Generator
- [ ] LFO Implementation

### Voice Architecture
- [ ] Monophonic Voice Implementation
- [ ] Voice Manager with Portamento
- [ ] Modulation Router
- [ ] Simple Mixer

### AudioUnit Integration
- [ ] AudioUnit Plugin Shell
- [ ] Parameter Management
- [ ] MIDI Handling
- [ ] Audio Processing Loop

### Performance Features
- [ ] Arpeggiator
- [ ] Simple Sequencer

### UI Development
- [ ] Basic UI Framework
- [ ] Oscillator Section UI
- [ ] Filter Section UI
- [ ] Envelope Section UI
- [ ] LFO Section UI
- [ ] Performance Section UI
- [ ] Master Section UI
- [ ] Preset Management

## Completed
```

## Best Practices

1. **Incremental Development**: Implement one small piece at a time
2. **Test-Driven Development**: Write tests before or alongside implementation
3. **Early Integration**: Integrate components as soon as they're functional
4. **Continuous Validation**: Ensure audio output remains clean and performant
5. **Detailed Documentation**: Document design decisions and implementation details
6. **Version Control Discipline**: Make atomic commits with clear messages

## Technical Guidelines

1. **Real-Time Safety**: Avoid memory allocations in the audio thread
2. **Profiling**: Profile code regularly to identify bottlenecks
3. **Denormals**: Implement denormal prevention for all audio processing
4. **Thread Safety**: Ensure proper thread safety for parameter changes
5. **Sample Accuracy**: Implement sample-accurate parameter automation
6. **Buffer Processing**: Operate on blocks of samples when possible for efficiency

By following this process consistently, Claude Code can maintain focus, track progress effectively, and build a high-quality synthesizer plugin incrementally without losing context between sessions.
