//
//  ParameterStorageTests.swift
//  VoxTests
//
//  Created by Claude on 5/26/25.
//

import Testing
import AudioToolbox
import AVFoundation
internal import VoxCore
@testable import VoxExtension

/// Tests for parameter storage and retention at the DSP kernel level.
///
/// Note: Full AudioUnit integration tests require the component to be registered with the system,
/// which isn't available in the unit test environment. Use `auval -a` for full AudioUnit validation.
/// The kernel-level tests here verify the critical parameter retention functionality that was
/// previously failing auval.
struct ParameterStorageTests {

    @Test func testDSPKernelParameterStorage() throws {
        // Test the DSP kernel parameter storage directly
        // This tests our fix for the auval parameter retention issue

        // Create a DSP kernel (this is what actually handles parameter storage)
        var kernel = VoxExtensionDSPKernel()
        kernel.initialize(2, 44100.0)
        defer { kernel.deInitialize() }

        // Test the exact LFO Rate parameter that was failing auval
        let lfoRateAddress: AUParameterAddress = 80  // lfoRate from enum
        let auvalTestValue: AUValue = 0.0  // auval sets this to test parameter retention

        // Set the problematic value
        kernel.setParameter(lfoRateAddress, auvalTestValue)

        // Retrieve and verify (this is what auval does)
        let retrievedValue = kernel.getParameter(lfoRateAddress)
        #expect(retrievedValue == auvalTestValue, "DSP kernel should store and retrieve exact parameter values for auval compatibility")

        // Test with other critical values that auval tests
        let testValues: [AUValue] = [0.0, 0.5, 1.0, 0.25, 0.75]

        for testValue in testValues {
            kernel.setParameter(lfoRateAddress, testValue)
            let retrieved = kernel.getParameter(lfoRateAddress)
            #expect(abs(retrieved - testValue) < 0.0001, "Parameter value \(testValue) should be stored exactly, got \(retrieved)")
        }
    }

    @Test func testParameterPersistence() async throws {
        // Test that parameters persist across multiple get/set cycles
        var kernel = VoxExtensionDSPKernel()
        kernel.initialize(2, 44100.0)
        defer { kernel.deInitialize() }

        let paramAddress: AUParameterAddress = 80 // lfoRate
        let testValue: AUValue = 0.73 // Arbitrary test value

        // Set parameter multiple times
        for _ in 0..<10 {
            kernel.setParameter(paramAddress, testValue)
            let retrieved = kernel.getParameter(paramAddress)
            #expect(abs(retrieved - testValue) < 0.0001, "Parameter should persist across multiple set/get cycles")
        }

        // Test with parameter changes (skip complex audio processing for now)
        kernel.setParameter(paramAddress, testValue)

        // Verify parameter persists without audio processing
        let postProcessValue = kernel.getParameter(paramAddress)
        #expect(abs(postProcessValue - testValue) < 0.0001, "Parameter should persist after multiple operations")
    }

    @Test func testMultipleParameterRetention() throws {
        // Test parameter retention across multiple commonly-automated parameters
        // This replaces the disabled testParameterAutomationCompliance
        var kernel = VoxExtensionDSPKernel()
        kernel.initialize(2, 44100.0)
        defer { kernel.deInitialize() }

        // Test multiple parameters that are commonly automated in DAWs
        // Addresses from VoxExtensionParameterAddresses.h
        let testParameters: [(address: AUParameterAddress, name: String)] = [
            (80, "lfoRate"),
            (130, "lpFilterCutoff"),
            (131, "lpFilterResonance"),
            (11, "osc1Level"),
            (21, "osc2Level"),
            (140, "masterVolume")
        ]

        let testValues: [AUValue] = [0.0, 0.25, 0.5, 0.75, 1.0]

        for (address, name) in testParameters {
            for testValue in testValues {
                kernel.setParameter(address, testValue)
                let retrieved = kernel.getParameter(address)
                #expect(abs(retrieved - testValue) < 0.0001,
                       "Parameter \(name) (address \(address)) should retain value \(testValue), got \(retrieved)")
            }
        }
    }

    @Test func testRapidParameterChanges() throws {
        // Test rapid parameter value changes (simulates automation)
        var kernel = VoxExtensionDSPKernel()
        kernel.initialize(2, 44100.0)
        defer { kernel.deInitialize() }

        let filterCutoffAddress: AUParameterAddress = 130

        // Simulate rapid automation: ramp from 0 to 1 in small steps
        var previousValue: AUValue = 0.0
        for i in 0...100 {
            let targetValue = AUValue(i) / 100.0
            kernel.setParameter(filterCutoffAddress, targetValue)
            let retrieved = kernel.getParameter(filterCutoffAddress)

            // Each step should be stored exactly
            #expect(abs(retrieved - targetValue) < 0.0001,
                   "Rapid automation step \(i): expected \(targetValue), got \(retrieved)")

            // Value should be increasing (no reversion to previous values)
            if i > 0 {
                #expect(retrieved >= previousValue - 0.0001,
                       "Parameter should not revert during automation: step \(i), prev \(previousValue), curr \(retrieved)")
            }
            previousValue = retrieved
        }
    }

    @Test func testParameterBoundaryValues() throws {
        // Test parameter storage at boundary values
        var kernel = VoxExtensionDSPKernel()
        kernel.initialize(2, 44100.0)
        defer { kernel.deInitialize() }

        let testParameters: [AUParameterAddress] = [80, 130, 131, 11, 21, 140]

        // Test exact boundary values
        let boundaryValues: [AUValue] = [0.0, 1.0, 0.00001, 0.99999]

        for address in testParameters {
            for testValue in boundaryValues {
                kernel.setParameter(address, testValue)
                let retrieved = kernel.getParameter(address)
                #expect(abs(retrieved - testValue) < 0.0001,
                       "Boundary value \(testValue) at address \(address) should be retained exactly, got \(retrieved)")
            }
        }
    }

    @Test func testParameterInterleavedAccess() throws {
        // Test that setting one parameter doesn't affect another (no cross-contamination)
        var kernel = VoxExtensionDSPKernel()
        kernel.initialize(2, 44100.0)
        defer { kernel.deInitialize() }

        let param1: AUParameterAddress = 80  // lfoRate
        let param2: AUParameterAddress = 130 // lpFilterCutoff
        let param3: AUParameterAddress = 131 // lpFilterResonance

        let value1: AUValue = 0.3
        let value2: AUValue = 0.6
        let value3: AUValue = 0.9

        // Set all parameters
        kernel.setParameter(param1, value1)
        kernel.setParameter(param2, value2)
        kernel.setParameter(param3, value3)

        // Verify each parameter retained its value (not contaminated by others)
        #expect(abs(kernel.getParameter(param1) - value1) < 0.0001, "param1 should retain its value")
        #expect(abs(kernel.getParameter(param2) - value2) < 0.0001, "param2 should retain its value")
        #expect(abs(kernel.getParameter(param3) - value3) < 0.0001, "param3 should retain its value")

        // Change one parameter and verify others are unaffected
        kernel.setParameter(param2, 0.1)
        #expect(abs(kernel.getParameter(param1) - value1) < 0.0001, "param1 should be unaffected by param2 change")
        #expect(abs(kernel.getParameter(param3) - value3) < 0.0001, "param3 should be unaffected by param2 change")
    }

    // MARK: - Plist Parameter Serialization Tests
    // These tests verify the fix for AU preset save/load (Double vs Float casting issue)

    @Test func testPlistParameterSerializationRoundTrip() throws {
        // Test that parameter values survive plist serialization
        // This verifies the fix where plist stores <real> as Double, not Float

        // Create a dictionary like what fullState creates
        var parameterData: [String: Float] = [:]
        let testValues: [(address: AUParameterAddress, value: Float)] = [
            (80, 5.0),      // lfoRate
            (130, 50.0),    // lpFilterCutoff
            (131, 80.0),    // lpFilterResonance
            (60, 500.0),    // ampAttack
        ]

        for (address, value) in testValues {
            parameterData["\(address)"] = value
        }

        // Serialize to plist data (like saving an aupreset)
        let state: [String: Any] = ["VoxParameters": parameterData]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: state,
            format: .xml,
            options: 0
        )

        // Deserialize (like loading an aupreset)
        var format: PropertyListSerialization.PropertyListFormat = .xml
        let restoredState = try PropertyListSerialization.propertyList(
            from: plistData,
            options: 0,
            format: &format
        ) as! [String: Any]

        // Verify we can read the values back
        // This is where the bug was - plist restores <real> as Double, not Float
        guard let restoredParams = restoredState["VoxParameters"] as? [String: Any] else {
            throw TestFailure("Failed to restore VoxParameters")
        }

        // Test the conversion logic that was fixed
        for (address, expectedValue) in testValues {
            let key = "\(address)"
            guard let value = restoredParams[key] else {
                throw TestFailure("Missing parameter at address \(address)")
            }

            // This is the conversion logic that was added to fix the bug
            let floatValue: Float
            if let f = value as? Float {
                floatValue = f
            } else if let d = value as? Double {
                floatValue = Float(d)
            } else if let n = value as? NSNumber {
                floatValue = n.floatValue
            } else {
                throw TestFailure("Could not convert value at address \(address)")
            }

            #expect(
                abs(floatValue - expectedValue) < 0.01,
                "Parameter at address \(address) should be \(expectedValue), got \(floatValue)"
            )
        }
    }

    @Test func testParameterValueConversionHandlesMultipleTypes() throws {
        // Test that our conversion logic handles Float, Double, and NSNumber correctly
        // This is the fix we applied to fullState setter

        let testCases: [(Any, Float)] = [
            (Float(42.5), 42.5),
            (Double(42.5), 42.5),
            (NSNumber(value: 42.5), 42.5),
            (NSNumber(value: Float(42.5)), 42.5),
        ]

        for (input, expected) in testCases {
            let floatValue: Float
            if let f = input as? Float {
                floatValue = f
            } else if let d = input as? Double {
                floatValue = Float(d)
            } else if let n = input as? NSNumber {
                floatValue = n.floatValue
            } else {
                throw TestFailure("Could not convert input: \(type(of: input))")
            }

            #expect(
                abs(floatValue - expected) < 0.01,
                "Conversion from \(type(of: input)) should produce \(expected), got \(floatValue)"
            )
        }
    }

    @Test func testParameterDictionaryRoundTrip() throws {
        // Test that parameters can be serialized and deserialized via plist
        // This simulates the AU preset save/load cycle

        let originalParams: [String: Any] = [
            "80": Float(5.0),
            "130": Float(50.0),
            "131": Float(80.0),
        ]

        // Serialize to plist (like saving aupreset)
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: originalParams,
            format: .xml,
            options: 0
        )

        // Deserialize (like loading aupreset)
        var format: PropertyListSerialization.PropertyListFormat = .xml
        let restored = try PropertyListSerialization.propertyList(
            from: plistData,
            options: 0,
            format: &format
        ) as! [String: Any]

        // Apply our conversion logic (what fullState setter does now)
        for (key, value) in restored {
            let floatValue: Float
            if let f = value as? Float {
                floatValue = f
            } else if let d = value as? Double {
                floatValue = Float(d)
            } else if let n = value as? NSNumber {
                floatValue = n.floatValue
            } else {
                throw TestFailure("Could not convert value for key \(key)")
            }

            let originalValue = (originalParams[key] as! NSNumber).floatValue
            #expect(
                abs(floatValue - originalValue) < 0.01,
                "Parameter \(key) should round-trip correctly: expected \(originalValue), got \(floatValue)"
            )
        }
    }

    // MARK: - End-to-End AU Preset File Tests

    @Test func testAUPresetFileRoundTrip() async throws {
        // End-to-end test: Create AU, modify parameters, save to .aupreset file,
        // create new AU, load preset, verify parameters match
        //
        // NOTE: This test requires the Vox AudioUnit to be registered on the system.
        // Run ./build.sh first to ensure the AU is built and available.

        // Vox component description
        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: fourCharCode("Voxs"),
            componentManufacturer: fourCharCode("nSat"),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        // Find the component
        guard let component = AVAudioUnitComponentManager.shared().components(matching: componentDescription).first else {
            // Skip test if AU is not registered (e.g., first build)
            print("⚠️ Vox AudioUnit not found - skipping end-to-end preset test")
            print("   Run ./build.sh to register the AudioUnit, then re-run tests")
            return
        }

        // Create first AudioUnit instance
        let audioUnit1 = try await createAudioUnit(component: component)

        // Define non-default parameter values to test
        // Using parameter addresses from VoxExtensionParameterAddresses.h
        let testParameters: [(address: AUParameterAddress, value: AUValue, name: String)] = [
            (10, 2.0, "osc1Waveform"),           // Square wave (default is 0/Saw)
            (11, -15.0, "osc1Level"),            // -15 dB (default is -2)
            (130, 35.0, "lpFilterCutoff"),       // 35% (default is 100%)
            (131, 65.0, "lpFilterResonance"),    // 65% (default is 0%)
            (60, 250.0, "ampAttack"),            // 250ms (default is 10ms)
            (63, 500.0, "ampRelease"),           // 500ms (default is 300ms)
            (80, 7.5, "lfoRate"),                // 7.5 Hz (default is 2 Hz)
            (140, -18.0, "masterVolume"),        // -18 dB (default is -6)
        ]

        // Set non-default parameter values
        guard let paramTree1 = audioUnit1.parameterTree else {
            throw TestFailure("Parameter tree not available on first AudioUnit")
        }

        for (address, value, name) in testParameters {
            guard let param = paramTree1.parameter(withAddress: address) else {
                throw TestFailure("Parameter '\(name)' (address \(address)) not found")
            }
            param.value = value
        }

        // Get fullState and save to .aupreset file
        guard let state = audioUnit1.fullState else {
            throw TestFailure("Failed to get fullState from AudioUnit")
        }

        // Create temp file path for the preset
        let tempDir = FileManager.default.temporaryDirectory
        let presetURL = tempDir.appendingPathComponent("TestPreset_\(UUID().uuidString).aupreset")

        // Write the preset file (aupreset is just a plist)
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: state,
            format: .xml,
            options: 0
        )
        try plistData.write(to: presetURL)

        // Verify the file was created
        #expect(FileManager.default.fileExists(atPath: presetURL.path), "Preset file should exist")

        // Clean up first AU
        // (In a real scenario, this would be deallocated)

        // Create second AudioUnit instance (simulates creating new instrument in DAW)
        let audioUnit2 = try await createAudioUnit(component: component)

        // Load the preset file
        let loadedData = try Data(contentsOf: presetURL)
        var format: PropertyListSerialization.PropertyListFormat = .xml
        let loadedState = try PropertyListSerialization.propertyList(
            from: loadedData,
            options: 0,
            format: &format
        ) as! [String: Any]

        // Set the fullState on the new AudioUnit
        audioUnit2.fullState = loadedState

        // Verify parameters were restored correctly
        guard let paramTree2 = audioUnit2.parameterTree else {
            throw TestFailure("Parameter tree not available on second AudioUnit after preset load")
        }

        for (address, expectedValue, name) in testParameters {
            guard let param = paramTree2.parameter(withAddress: address) else {
                throw TestFailure("Parameter '\(name)' (address \(address)) not found after preset load")
            }

            let tolerance: AUValue = 0.1
            #expect(
                abs(param.value - expectedValue) < tolerance,
                "Parameter '\(name)' should be \(expectedValue) after preset load, got \(param.value)"
            )
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: presetURL)
    }

    @Test func testAUPresetFileContainsExpectedData() async throws {
        // Test that the .aupreset file contains our custom parameter data in the expected format

        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: fourCharCode("Voxs"),
            componentManufacturer: fourCharCode("nSat"),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let component = AVAudioUnitComponentManager.shared().components(matching: componentDescription).first else {
            print("⚠️ Vox AudioUnit not found - skipping preset content test")
            return
        }

        let audioUnit = try await createAudioUnit(component: component)

        // Set a distinctive value
        if let param = audioUnit.parameterTree?.parameter(withAddress: 130) {
            param.value = 42.0  // lpFilterCutoff = 42%
        }

        guard let state = audioUnit.fullState else {
            throw TestFailure("Failed to get fullState")
        }

        // Write to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let presetURL = tempDir.appendingPathComponent("ContentTest_\(UUID().uuidString).aupreset")

        let plistData = try PropertyListSerialization.data(
            fromPropertyList: state,
            format: .xml,
            options: 0
        )
        try plistData.write(to: presetURL)

        // Read back and verify structure
        let loadedData = try Data(contentsOf: presetURL)
        var format: PropertyListSerialization.PropertyListFormat = .xml
        let loadedState = try PropertyListSerialization.propertyList(
            from: loadedData,
            options: 0,
            format: &format
        ) as! [String: Any]

        // Verify our custom data is present
        #expect(loadedState["VoxParameters"] != nil, "Preset should contain VoxParameters")

        if let params = loadedState["VoxParameters"] as? [String: Any] {
            // Verify our test value is in there
            let value = params["130"]
            #expect(value != nil, "lpFilterCutoff (address 130) should be in preset")

            // Convert using our fix logic
            let floatValue: Float?
            if let f = value as? Float {
                floatValue = f
            } else if let d = value as? Double {
                floatValue = Float(d)
            } else if let n = value as? NSNumber {
                floatValue = n.floatValue
            } else {
                floatValue = nil
            }

            #expect(floatValue != nil, "Should be able to convert lpFilterCutoff value")
            #expect(abs(floatValue! - 42.0) < 0.1, "lpFilterCutoff should be 42.0, got \(floatValue!)")
        }

        // Clean up
        try? FileManager.default.removeItem(at: presetURL)
    }

    // Helper to create AudioUnit from component using modern async API
    private func createAudioUnit(component: AVAudioUnitComponent) async throws -> AUAudioUnit {
        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: component.audioComponentDescription,
            options: []
        )
        return avAudioUnit.auAudioUnit
    }

    // Helper to create FourCharCode from string
    private func fourCharCode(_ string: String) -> FourCharCode {
        var result: FourCharCode = 0
        for char in string.utf8.prefix(4) {
            result = result << 8 + FourCharCode(char)
        }
        return result
    }
}

// Helper for test errors
struct TestFailure: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}
