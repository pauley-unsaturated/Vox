//
//  ModMatrixActivityObserver.swift
//  VoxExtension
//
//  Phase 8.10: Polls modulation matrix activity levels from the audio unit
//  and exposes per-route activity intensities for glow visualization.
//
//  The ModulationMatrix in C++ stores source values and route amounts.
//  This observer reads the computed destination modulation values at ~15 Hz
//  and exposes them as normalized glow intensities for the UI.
//
//  Lock-free: reads atomic-friendly values from the audio unit.
//  When full kernel integration is ready, this will read from a ring buffer
//  or atomic array written by the audio thread.
//

import SwiftUI

/// Number of mod sources and destinations (mirrors C++ ModulationMatrix).
enum ModMatrixConstants {
    static let sourceCount = 12
    static let destCount = 16  // Updated for Phase 7 additions
    static let totalRoutes = sourceCount * destCount
}

/// Observable object that polls modulation matrix activity levels.
/// Provides per-destination activity intensity for glow effects.
@Observable
@MainActor
final class ModMatrixActivityObserver {
    /// Per-destination activity level (0.0 = inactive, 1.0 = max modulation).
    /// Index corresponds to ModDest enum values.
    var destinationActivity: [Float] = Array(repeating: 0, count: ModMatrixConstants.destCount)

    /// Overall matrix activity (0.0 = nothing active, 1.0 = heavy modulation).
    var overallActivity: Float = 0.0

    /// Number of currently active routes.
    var activeRouteCount: Int = 0

    private weak var audioUnit: VoxExtensionAudioUnit?
    private var timer: Timer?
    private var lastUpdateTime: CFTimeInterval = 0
    private let updateInterval: CFTimeInterval = 1.0 / 15.0

    /// Smoothing factor for activity decay (exponential moving average).
    private let smoothingUp: Float = 0.6    // Fast attack
    private let smoothingDown: Float = 0.92  // Slow decay for nice glow trail

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
                self?.updateActivity()
            }
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func updateActivity() {
        guard let au = audioUnit else { return }

        let now = CACurrentMediaTime()
        guard now - lastUpdateTime >= updateInterval else { return }
        lastUpdateTime = now

        // Read activity levels from the audio unit.
        // When kernel integration is complete, this will read from an atomic buffer.
        // For now, read what's available through the audio unit API.
        let levels = au.getModMatrixActivityLevels()
        let routeCount = au.getModMatrixActiveRouteCount()

        var totalActivity: Float = 0.0
        for i in 0..<min(levels.count, destinationActivity.count) {
            let target = abs(levels[i])
            let current = destinationActivity[i]
            // Exponential smoothing: fast attack, slow decay
            if target > current {
                destinationActivity[i] = current + (target - current) * smoothingUp
            } else {
                destinationActivity[i] = current * smoothingDown
            }
            // Clamp tiny values to zero to avoid perpetual micro-glow
            if destinationActivity[i] < 0.001 {
                destinationActivity[i] = 0.0
            }
            totalActivity += destinationActivity[i]
        }

        let newOverall = min(totalActivity / Float(ModMatrixConstants.destCount), 1.0)
        if abs(newOverall - overallActivity) > 0.001 {
            overallActivity = newOverall
        }
        if routeCount != activeRouteCount {
            activeRouteCount = routeCount
        }
    }

    // Note: stopPolling() must be called before this object is discarded.
    // deinit is nonisolated and cannot access @MainActor-isolated timer.
}
