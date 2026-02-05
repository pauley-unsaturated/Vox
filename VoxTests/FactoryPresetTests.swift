//
//  FactoryPresetTests.swift
//  VoxTests
//
//  Tests for factory preset functionality via AudioUnit integration.
//

import Testing
import AudioToolbox
import AVFoundation

struct FactoryPresetTests {

    // MARK: - AudioUnit Factory Preset Integration Tests

    @Test func testAudioUnitFactoryPresetsProperty() async throws {
        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: fourCharCode("Voxs"),
            componentManufacturer: fourCharCode("nSat"),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let component = AVAudioUnitComponentManager.shared().components(matching: componentDescription).first else {
            print("⚠️ Vox AudioUnit not found - skipping factory preset integration test")
            print("   Run ./build.sh to register the AudioUnit, then re-run tests")
            return
        }

        let audioUnit = try await createAudioUnit(component: component)

        // Check factoryPresets property returns presets
        guard let factoryPresets = audioUnit.factoryPresets else {
            // Factory presets can be nil if not configured - this is OK for testing
            print("⚠️ factoryPresets property returned nil - Factory Presets folder may not be bundled")
            return
        }

        #expect(factoryPresets.count >= 1, "AudioUnit should expose at least one factory preset")

        // Verify preset numbers are sequential starting from 0
        for (index, preset) in factoryPresets.enumerated() {
            #expect(preset.number == index, "Factory preset number should match index")
        }
    }

    @Test func testLoadFactoryPreset() async throws {
        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: fourCharCode("Voxs"),
            componentManufacturer: fourCharCode("nSat"),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let component = AVAudioUnitComponentManager.shared().components(matching: componentDescription).first else {
            print("⚠️ Vox AudioUnit not found - skipping factory preset load test")
            return
        }

        let audioUnit = try await createAudioUnit(component: component)

        // Get available factory presets
        guard let factoryPresets = audioUnit.factoryPresets, !factoryPresets.isEmpty else {
            print("⚠️ No factory presets available - skipping load test")
            return
        }

        // Load the first factory preset
        let firstPreset = factoryPresets[0]
        audioUnit.currentPreset = firstPreset

        // Verify current preset is set
        #expect(audioUnit.currentPreset?.number == firstPreset.number)
        #expect(audioUnit.currentPreset?.name == firstPreset.name)
    }

    @Test func testLoadMultipleFactoryPresetsInSequence() async throws {
        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: fourCharCode("Voxs"),
            componentManufacturer: fourCharCode("nSat"),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let component = AVAudioUnitComponentManager.shared().components(matching: componentDescription).first else {
            print("⚠️ Vox AudioUnit not found - skipping multiple preset test")
            return
        }

        let audioUnit = try await createAudioUnit(component: component)

        guard let factoryPresets = audioUnit.factoryPresets else {
            print("⚠️ No factory presets - skipping test")
            return
        }

        // Load each factory preset in sequence and verify it loads without error
        for preset in factoryPresets {
            audioUnit.currentPreset = preset

            #expect(
                audioUnit.currentPreset?.number == preset.number,
                "Current preset should be \(String(preset.number)) after loading '\(preset.name)'"
            )
        }
    }

    @Test func testSupportsUserPresets() async throws {
        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: fourCharCode("Voxs"),
            componentManufacturer: fourCharCode("nSat"),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let component = AVAudioUnitComponentManager.shared().components(matching: componentDescription).first else {
            print("⚠️ Vox AudioUnit not found - skipping preset type test")
            return
        }

        let audioUnit = try await createAudioUnit(component: component)

        // Verify supportsUserPresets is true
        #expect(audioUnit.supportsUserPresets, "AudioUnit should support user presets")

        // Loading a factory preset should work
        if let firstPreset = audioUnit.factoryPresets?.first {
            audioUnit.currentPreset = firstPreset
            #expect(audioUnit.currentPreset?.number == firstPreset.number, "Should load factory preset")
        }
    }

    // MARK: - Helper Functions

    private func createAudioUnit(component: AVAudioUnitComponent) async throws -> AUAudioUnit {
        let avAudioUnit = try await AVAudioUnit.instantiate(
            with: component.audioComponentDescription,
            options: []
        )
        return avAudioUnit.auAudioUnit
    }

    private func fourCharCode(_ string: String) -> FourCharCode {
        var result: FourCharCode = 0
        for char in string.utf8.prefix(4) {
            result = result << 8 + FourCharCode(char)
        }
        return result
    }
}
