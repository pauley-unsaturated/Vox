//
//  SequencerStepModel.swift
//  VoxExtension
//
//  Observable model for step sequencer data, bridging UI and DSP kernel.
//

import SwiftUI
import AudioToolbox

/// Observable model for a single sequencer step
@MainActor
@Observable
final class SequencerStep {
    let index: Int
    weak var audioUnit: VoxExtensionAudioUnit?

    var pitchOffset: Int {
        didSet {
            audioUnit?.setSequencerStepPitch(index, pitch: pitchOffset)
        }
    }

    var gate: Bool {
        didSet {
            audioUnit?.setSequencerStepGate(index, gate: gate)
        }
    }

    var tie: Bool {
        didSet {
            audioUnit?.setSequencerStepTie(index, tie: tie)
        }
    }

    var accent: Bool {
        didSet {
            audioUnit?.setSequencerStepAccent(index, accent: accent)
        }
    }

    init(index: Int, audioUnit: VoxExtensionAudioUnit?) {
        self.index = index
        self.audioUnit = audioUnit

        // Load initial values from the audio unit
        if let au = audioUnit {
            self.pitchOffset = au.getSequencerStepPitch(index)
            self.gate = au.getSequencerStepGate(index)
            self.tie = au.getSequencerStepTie(index)
            self.accent = au.getSequencerStepAccent(index)
        } else {
            self.pitchOffset = 0
            self.gate = true
            self.tie = false
            self.accent = false
        }
    }

    /// Refresh values from the audio unit
    func refresh() {
        guard let au = audioUnit else { return }
        pitchOffset = au.getSequencerStepPitch(index)
        gate = au.getSequencerStepGate(index)
        tie = au.getSequencerStepTie(index)
        accent = au.getSequencerStepAccent(index)
    }
}

/// Observable model for the entire step sequencer (32 steps)
@MainActor
@Observable
final class SequencerModel {
    static let maxSteps = 32

    private(set) var steps: [SequencerStep] = []
    weak var audioUnit: VoxExtensionAudioUnit?

    /// Current step being played (for highlighting in UI)
    var currentStep: Int = 0

    init(audioUnit: VoxExtensionAudioUnit?) {
        self.audioUnit = audioUnit
        self.steps = (0..<Self.maxSteps).map { SequencerStep(index: $0, audioUnit: audioUnit) }
    }

    /// Refresh all steps from the audio unit
    func refresh() {
        for step in steps {
            step.refresh()
        }
        currentStep = audioUnit?.getSequencerCurrentStep() ?? 0
    }

    /// Clear all steps (reset to defaults)
    func clearAllSteps() {
        audioUnit?.clearSequencerSteps()
        refresh()
    }

    /// Get step at index
    func step(at index: Int) -> SequencerStep? {
        guard index >= 0 && index < steps.count else { return nil }
        return steps[index]
    }
}
