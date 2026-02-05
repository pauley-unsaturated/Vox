//
//  Parameters.swift
//  VoxExtension
//
//  Vox Pulsar Synthesizer Parameters
//

import Foundation
import AudioToolbox
internal import VoxCore

let VoxExtensionParameterSpecs = ParameterTreeSpec {
    // MASTER SECTION
    ParameterGroupSpec(identifier: "master", name: "Master") {
        ParameterSpec(
            address: .masterVolume,
            identifier: "masterVolume",
            name: "Master Volume",
            units: .decibels,
            valueRange: -60.0...0.0,
            defaultValue: -6.0,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_IsHighResolution, .flag_CanRamp]
        )
    }
    
    // PULSAR OSCILLATOR SECTION
    ParameterGroupSpec(identifier: "pulsarOsc", name: "Pulsar Oscillator") {
        ParameterSpec(
            address: .pulsaretShape,
            identifier: "pulsaretShape",
            name: "Pulsaret Shape",
            units: .indexed,
            valueRange: 0...3,
            defaultValue: 1,
            valueStrings: ["Gaussian", "Raised Cos", "Sine", "Triangle"]
        )
        ParameterSpec(
            address: .dutyCycle,
            identifier: "dutyCycle",
            name: "Duty Cycle",
            units: .percent,
            valueRange: 1.0...100.0,
            defaultValue: 20.0,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_IsHighResolution, .flag_CanRamp]
        )
    }
    
    // FORMANT FILTER SECTION
    ParameterGroupSpec(identifier: "formantFilter", name: "Formant Filter") {
        ParameterSpec(
            address: .useVowelMorph,
            identifier: "useVowelMorph",
            name: "Vowel Mode",
            units: .boolean,
            valueRange: 0...1,
            defaultValue: 1
        )
        ParameterSpec(
            address: .vowelMorph,
            identifier: "vowelMorph",
            name: "Vowel",
            units: .generic,
            valueRange: 0.0...1.0,
            defaultValue: 0.0,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_IsHighResolution, .flag_CanRamp]
        )
        ParameterSpec(
            address: .formant1Freq,
            identifier: "formant1Freq",
            name: "Formant 1 Freq",
            units: .hertz,
            valueRange: 100.0...4000.0,
            defaultValue: 800.0,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_IsHighResolution, .flag_CanRamp]
        )
        ParameterSpec(
            address: .formant2Freq,
            identifier: "formant2Freq",
            name: "Formant 2 Freq",
            units: .hertz,
            valueRange: 100.0...4000.0,
            defaultValue: 1200.0,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_IsHighResolution, .flag_CanRamp]
        )
        ParameterSpec(
            address: .formant1Q,
            identifier: "formant1Q",
            name: "Formant 1 Q",
            units: .generic,
            valueRange: 1.0...30.0,
            defaultValue: 10.0,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_IsHighResolution, .flag_CanRamp]
        )
        ParameterSpec(
            address: .formant2Q,
            identifier: "formant2Q",
            name: "Formant 2 Q",
            units: .generic,
            valueRange: 1.0...30.0,
            defaultValue: 10.0,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_IsHighResolution, .flag_CanRamp]
        )
        ParameterSpec(
            address: .formantMix,
            identifier: "formantMix",
            name: "Formant Mix",
            units: .percent,
            valueRange: 0.0...100.0,
            defaultValue: 100.0,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_IsHighResolution, .flag_CanRamp]
        )
    }
    
    // AMP ENVELOPE SECTION
    ParameterGroupSpec(identifier: "ampEnvelope", name: "Amp Envelope") {
        ParameterSpec(
            address: .ampAttack,
            identifier: "ampAttack",
            name: "Attack",
            units: .milliseconds,
            valueRange: 1.0...5000.0,
            defaultValue: 10.0,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_IsHighResolution, .flag_CanRamp]
        )
        ParameterSpec(
            address: .ampDecay,
            identifier: "ampDecay",
            name: "Decay",
            units: .milliseconds,
            valueRange: 1.0...5000.0,
            defaultValue: 100.0,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_IsHighResolution, .flag_CanRamp]
        )
        ParameterSpec(
            address: .ampSustain,
            identifier: "ampSustain",
            name: "Sustain",
            units: .percent,
            valueRange: 0.0...100.0,
            defaultValue: 70.0,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_IsHighResolution, .flag_CanRamp]
        )
        ParameterSpec(
            address: .ampRelease,
            identifier: "ampRelease",
            name: "Release",
            units: .milliseconds,
            valueRange: 1.0...10000.0,
            defaultValue: 300.0,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_IsHighResolution, .flag_CanRamp]
        )
    }
    
    // PERFORMANCE SECTION
    ParameterGroupSpec(identifier: "performance", name: "Performance") {
        ParameterSpec(
            address: .glideEnabled,
            identifier: "glideEnabled",
            name: "Glide",
            units: .boolean,
            valueRange: 0...1,
            defaultValue: 0
        )
        ParameterSpec(
            address: .glideTime,
            identifier: "glideTime",
            name: "Glide Time",
            units: .milliseconds,
            valueRange: 1.0...2000.0,
            defaultValue: 100.0,
            flags: [.flag_IsWritable, .flag_IsReadable, .flag_IsHighResolution, .flag_CanRamp]
        )
        ParameterSpec(
            address: .pitchBendRange,
            identifier: "pitchBendRange",
            name: "Pitch Bend Range",
            units: .generic,
            valueRange: 1...24,
            defaultValue: 2,
            flags: [.flag_IsWritable, .flag_IsReadable]
        )
    }
}

extension ParameterSpec {
    init(
        address: VoxExtensionParameterAddress,
        identifier: String,
        name: String,
        units: AudioUnitParameterUnit,
        valueRange: ClosedRange<AUValue>,
        defaultValue: AUValue,
        unitName: String? = nil,
        flags: AudioUnitParameterOptions = [AudioUnitParameterOptions.flag_IsWritable, AudioUnitParameterOptions.flag_IsReadable],
        valueStrings: [String]? = nil,
        dependentParameters: [NSNumber]? = nil
    ) {
        self.init(address: address.rawValue,
                  identifier: identifier,
                  name: name,
                  units: units,
                  valueRange: valueRange,
                  defaultValue: defaultValue,
                  unitName: unitName,
                  flags: flags,
                  valueStrings: valueStrings,
                  dependentParameters: dependentParameters)
    }
}
