# C++ Interoperability Configuration Guide

This document outlines the steps needed to configure Xcode for Swift-C++ interoperability in the Vox project.

## Build Settings Configuration

1. Open the project in Xcode.
2. Select the project file in the Navigator.
3. Select the "VoxExtension" target.
4. Go to the "Build Settings" tab.

### Required Settings

#### 1. Enable C++ Interoperability
- Set "Other Swift Flags" to include `-enable-experimental-cxx-interop`
- Alternatively, if using Swift 5.9+, set "Enable C++ Interoperability" to "YES"

#### 2. Set Header Search Paths
- Add `/Users/markpauley/Programs/Vox/VoxExtension/DSP` to "User Header Search Paths"
- Make sure "Always Search User Paths" is set to "YES"

#### 3. Module Map Configuration
- Set "Module Map File" to `$(SRCROOT)/VoxExtension/DSP/module.modulemap`

#### 4. Import Paths
- Add `/Users/markpauley/Programs/Vox/VoxExtension/DSP` to "Swift Import Paths"

#### 5. Other Linker Flags
- If needed, add `-lc++` to "Other Linker Flags" to link against the C++ standard library

## Swift File Updates

After configuring the build settings, update the import statements in Swift files to use the new wrappers:

```swift
// Old import
import VoxExtension

// New import (for direct access to C++ types)
internal import VoxDSP 

// Or use the new Swift wrappers
// These are already properly importing VoxDSP
```

## Test Configuration

To update the tests to use the new Swift wrappers:

1. Add the Swift wrapper files to the test target
2. Update import statements in test files
3. Run the tests to verify the new wrappers work correctly

## In Case of Issues

If you encounter issues with the C++ interop:

1. Check the module map path is correct
2. Verify header search paths include all necessary directories
3. Make sure all C++ headers use `#pragma once` or proper include guards
4. Use explicit `public` or `private` visibility for C++ class members
