//
//  SequencerPlayheadObserver.swift
//  VoxExtension
//
//  Phase 8.9: Polls the current sequencer step position from the audio unit
//  and exposes it for UI playhead visualization.
//  Follows the same pattern as OutputLevelObserver — timer-based polling,
//  lock-free read from the audio unit, rate-limited SwiftUI updates.
//

import SwiftUI

/// Observable object that polls the step sequencer's current playback position.
/// The audio unit exposes a simple atomic-friendly `getSequencerCurrentStep()`.
/// This observer reads it at ~30 Hz and updates the published property only on change.
@Observable
@MainActor
final class SequencerPlayheadObserver {
    /// Current step index (0-based). Drives playhead highlight in the step grid.
    var currentStep: Int = -1

    /// Whether the sequencer is actively playing (has advanced at least once).
    var isPlaying: Bool = false

    private weak var audioUnit: VoxExtensionAudioUnit?
    private var timer: Timer?
    private var lastUpdateTime: CFTimeInterval = 0
    private let updateInterval: CFTimeInterval = 1.0 / 15.0  // 15 fps UI update cap

    init(audioUnit: VoxExtensionAudioUnit? = nil) {
        self.audioUnit = audioUnit
    }

    func setAudioUnit(_ audioUnit: VoxExtensionAudioUnit?) {
        self.audioUnit = audioUnit
    }

    func startPolling() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlayhead()
            }
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
    }

    private func updatePlayhead() {
        guard let au = audioUnit else { return }

        let now = CACurrentMediaTime()
        guard now - lastUpdateTime >= updateInterval else { return }
        lastUpdateTime = now

        let newStep = au.getSequencerCurrentStep()
        if newStep != currentStep {
            currentStep = newStep
            if !isPlaying { isPlaying = true }
        }
    }

    // Note: stopPolling() must be called before this object is discarded.
    // deinit is nonisolated and cannot access @MainActor-isolated timer.
}
