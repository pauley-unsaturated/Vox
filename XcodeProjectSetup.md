# Xcode Project Setup for Vox AUv3

## Project Configuration

1. Create a new Xcode project with the following settings:
   - Template: Audio Unit Extension
   - Product Name: Vox
   - Organization Name: Your organization
   - Bundle Identifier: com.yourorganization.Vox
   - Language: Objective-C++/Swift
   - Include UI Extension: Yes

2. Configure targets:
   - Main application target (contains the AUv3 extension)
   - AUv3 extension target
   - Test target

## File Organization

Organize the project to use our existing directory structure:
- Source/AudioUnit/* - Core AUv3 implementation files
- Source/DSP/* - DSP components (oscillators, filters, etc.)
- Source/AUExtensions/* - Parameter handling and utilities
- Tests/* - Test files for the plugin

## Test Target Setup

1. Add a new target with "Unit Testing Bundle" template
2. Name it "VoxTests"
3. Add our test files to this target:
   - Tests/FilterTests.cpp
   - Tests/EnvelopeTests.cpp
   - Tests/LFOTests.cpp
   - Tests/VoiceTests.cpp
   - Tests/ArpeggiatorTests.cpp

4. Configure test target to link with Google Test framework:
   - Add GoogleTest as a dependency
   - Configure include paths
   - Set up test runner

## Build Configuration

1. Configure build settings for AUv3:
   - Set deployment target (macOS 10.15+)
   - Configure code signing
   - Set up entitlements
   - Configure Info.plist with AudioComponent registration

2. Set up build phases:
   - Compile sources
   - Link frameworks (AudioToolbox, AVFoundation, CoreAudio)
   - Copy extension into app bundle

## Integration with Build Scripts

Ensure the project works with our existing build.sh and test.sh scripts.