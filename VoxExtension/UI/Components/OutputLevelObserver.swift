//
//  OutputLevelObserver.swift
//  VoxExtension
//
//  Polls output level from DSP kernel for UI meter display.
//  This is NOT a parameter - just read-only metering data.
//

import SwiftUI

@Observable
class OutputLevelObserver {
    var level: Float = 0.0       // Current level for bar display (0.0-1.0)
    var peakHold: Float = 0.0    // Peak hold for LED indicator (0.0-1.0)
    var isPeaking: Bool = false  // True when peak > 0.99 (clipping)
    
    private weak var audioUnit: VoxExtensionAudioUnit?
    private var timer: Timer?
    
    // Rate limiting: only update SwiftUI at ~15fps to reduce redraw overhead
    private var lastUpdateTime: CFTimeInterval = 0
    private let updateInterval: CFTimeInterval = 1.0 / 15.0  // 15fps for UI updates
    
    init(audioUnit: VoxExtensionAudioUnit? = nil) {
        self.audioUnit = audioUnit
    }
    
    func setAudioUnit(_ audioUnit: VoxExtensionAudioUnit?) {
        self.audioUnit = audioUnit
    }
    
    func startPolling() {
        guard timer == nil else { return }
        
        // 30Hz is sufficient for smooth meter animation and halves CPU cost
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.updateLevels()
        }
        // Ensure timer fires during UI interactions (scrolling, dragging)
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateLevels() {
        guard let au = audioUnit else { return }
        
        // Rate limit UI updates to reduce SwiftUI redraw overhead
        let now = CACurrentMediaTime()
        guard now - lastUpdateTime >= updateInterval else { return }
        lastUpdateTime = now
        
        let newLevel = au.getOutputLevel()
        let newPeakHold = au.getOutputPeakHold()
        let newIsPeaking = newPeakHold > 0.99
        
        // Only update if values changed (avoids redundant SwiftUI invalidations)
        if newLevel != level {
            level = newLevel
        }
        if newPeakHold != peakHold {
            peakHold = newPeakHold
        }
        if newIsPeaking != isPeaking {
            isPeaking = newIsPeaking
        }
    }
    
    deinit {
        stopPolling()
    }
}
