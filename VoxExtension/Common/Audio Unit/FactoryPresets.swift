//
//  FactoryPresets.swift
//  VoxExtension
//
//  Factory preset loader - loads .aupreset files from the app bundle.
//

import Foundation
import AudioToolbox

/// Manages factory presets loaded from .aupreset files in the bundle
final class FactoryPresetLoader: @unchecked Sendable {

    /// Shared instance
    static let shared = FactoryPresetLoader()

    /// Cached list of available factory presets
    private(set) var presets: [AUAudioUnitPreset] = []

    /// Cached preset file URLs, indexed by preset number
    private var presetURLs: [Int: URL] = [:]

    /// Bundle subdirectory containing factory presets
    private let presetsDirectory = "Factory Presets"

    private init() {
        loadPresetList()
    }

    /// Scan bundle for factory preset files and build the preset list
    private func loadPresetList() {
        // Find the bundle - could be the extension bundle or main app bundle
        let bundle = Bundle(for: FactoryPresetLoader.self)

        guard let presetsURL = bundle.url(forResource: presetsDirectory, withExtension: nil) else {
            print("Vox: Factory Presets directory not found in bundle")
            // Create default "Init" preset if no factory presets found
            createDefaultInitPreset()
            return
        }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: presetsURL,
                includingPropertiesForKeys: [.nameKey],
                options: [.skipsHiddenFiles]
            )

            // Filter for .aupreset files and sort by name
            let presetFiles = fileURLs
                .filter { $0.pathExtension == "aupreset" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            // Build preset list
            for (index, fileURL) in presetFiles.enumerated() {
                let name = fileURL.deletingPathExtension().lastPathComponent
                // Remove leading number prefix if present (e.g., "00 Init" -> "Init")
                let displayName = removeNumberPrefix(from: name)

                let preset = AUAudioUnitPreset()
                preset.number = index
                preset.name = displayName
                presets.append(preset)
                presetURLs[index] = fileURL
            }

            if presets.isEmpty {
                print("Vox: No .aupreset files found in Factory Presets directory")
                createDefaultInitPreset()
            } else {
                print("Vox: Loaded \(presets.count) factory presets")
            }

        } catch {
            print("Vox: Error reading Factory Presets directory: \(error)")
            createDefaultInitPreset()
        }
    }

    /// Remove optional number prefix from preset name (e.g., "00 Init" -> "Init", "01_Bass" -> "Bass")
    private func removeNumberPrefix(from name: String) -> String {
        // Match patterns like "00 Name", "01_Name", "1-Name"
        let pattern = #"^\d+[\s_\-]+"#
        if let range = name.range(of: pattern, options: .regularExpression) {
            return String(name[range.upperBound...])
        }
        return name
    }

    /// Create a minimal default Init preset when no factory presets are found
    private func createDefaultInitPreset() {
        let initPreset = AUAudioUnitPreset()
        initPreset.number = 0
        initPreset.name = "Init"
        presets = [initPreset]
        // No URL for this one - loadPresetState will return nil and we'll use defaults
    }

    /// Load the state dictionary for a factory preset
    /// - Parameter number: The preset number (index)
    /// - Returns: The preset state dictionary, or nil if not found
    func loadPresetState(number: Int) -> [String: Any]? {
        guard let url = presetURLs[number] else {
            print("Vox: No URL for factory preset \(number)")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            var format: PropertyListSerialization.PropertyListFormat = .xml
            let plist = try PropertyListSerialization.propertyList(
                from: data,
                options: 0,
                format: &format
            )

            guard let state = plist as? [String: Any] else {
                print("Vox: Factory preset \(number) is not a valid dictionary")
                return nil
            }

            return state

        } catch {
            print("Vox: Error loading factory preset \(number): \(error)")
            return nil
        }
    }
}
