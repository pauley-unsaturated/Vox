//
//  PresetManager.swift
//  VoxExtension
//
//  Observable wrapper for preset management.
//  Provides a unified interface for factory and user presets.
//

import SwiftUI
import AudioToolbox

/// Observable manager for preset selection, saving, and loading
@MainActor
@Observable
final class PresetManager {

    // MARK: - Published State

    /// Currently selected preset (nil if no preset selected)
    var currentPreset: AUAudioUnitPreset? {
        didSet {
            if let preset = currentPreset {
                audioUnit?.currentPreset = preset
            }
        }
    }

    /// Display name for current preset
    var currentPresetName: String {
        currentPreset?.name ?? "Default"
    }

    /// Index of current preset in the combined list (-1 if none)
    var currentPresetIndex: Int {
        guard let current = currentPreset else { return -1 }
        return allPresets.firstIndex { $0.number == current.number && $0.name == current.name } ?? -1
    }

    /// All available presets (factory + user)
    var allPresets: [AUAudioUnitPreset] {
        factoryPresets + userPresets
    }

    /// Factory presets from the AudioUnit
    private(set) var factoryPresets: [AUAudioUnitPreset] = []

    /// User presets from the AudioUnit
    private(set) var userPresets: [AUAudioUnitPreset] = []

    /// Whether user presets are supported
    var supportsUserPresets: Bool {
        audioUnit?.supportsUserPresets ?? false
    }

    /// Error message to display (clears after a few seconds)
    var errorMessage: String?

    // MARK: - Private

    private weak var audioUnit: AUAudioUnit?

    // MARK: - Initialization

    init(audioUnit: AUAudioUnit?) {
        self.audioUnit = audioUnit
        refreshPresetLists()

        // Load current preset from AU
        self.currentPreset = audioUnit?.currentPreset
    }

    // MARK: - Preset Navigation

    /// Select the previous preset in the list
    func selectPreviousPreset() {
        let presets = allPresets
        guard !presets.isEmpty else { return }

        let currentIndex = currentPresetIndex
        let newIndex: Int

        if currentIndex <= 0 {
            // Wrap to last preset
            newIndex = presets.count - 1
        } else {
            newIndex = currentIndex - 1
        }

        currentPreset = presets[newIndex]
    }

    /// Select the next preset in the list
    func selectNextPreset() {
        let presets = allPresets
        guard !presets.isEmpty else { return }

        let currentIndex = currentPresetIndex
        let newIndex: Int

        if currentIndex < 0 || currentIndex >= presets.count - 1 {
            // Wrap to first preset
            newIndex = 0
        } else {
            newIndex = currentIndex + 1
        }

        currentPreset = presets[newIndex]
    }

    /// Select a preset by its number
    func selectPreset(_ preset: AUAudioUnitPreset) {
        currentPreset = preset
    }

    // MARK: - User Preset Management

    /// Save current state as a new user preset
    func saveUserPreset(name: String) {
        guard let au = audioUnit else {
            showError("AudioUnit not available")
            return
        }

        guard au.supportsUserPresets else {
            showError("User presets not supported")
            return
        }

        // Find next available negative number for user preset
        let existingNumbers = userPresets.map { $0.number }
        var nextNumber = -1
        while existingNumbers.contains(nextNumber) {
            nextNumber -= 1
        }

        let newPreset = AUAudioUnitPreset()
        newPreset.number = nextNumber
        newPreset.name = name

        do {
            try au.saveUserPreset(newPreset)
            refreshPresetLists()
            currentPreset = newPreset
        } catch {
            showError("Failed to save preset: \(error.localizedDescription)")
        }
    }

    /// Delete a user preset
    func deleteUserPreset(_ preset: AUAudioUnitPreset) {
        guard let au = audioUnit else { return }
        guard preset.number < 0 else {
            showError("Cannot delete factory preset")
            return
        }

        do {
            try au.deleteUserPreset(preset)
            refreshPresetLists()

            // If we deleted the current preset, clear selection
            if currentPreset?.number == preset.number {
                currentPreset = nil
            }
        } catch {
            showError("Failed to delete preset: \(error.localizedDescription)")
        }
    }

    // MARK: - Refresh

    /// Refresh the preset lists from the AudioUnit
    func refreshPresetLists() {
        factoryPresets = audioUnit?.factoryPresets ?? []
        userPresets = audioUnit?.userPresets ?? []
    }

    // MARK: - Helpers

    private func showError(_ message: String) {
        errorMessage = message

        // Clear error after delay
        Task {
            try? await Task.sleep(for: .seconds(3))
            if errorMessage == message {
                errorMessage = nil
            }
        }
    }
}
