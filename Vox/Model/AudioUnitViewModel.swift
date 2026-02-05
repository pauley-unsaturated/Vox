//
//  AudioUnitViewModel.swift
//  Vox
//
//  Created by Mark Pauley on 5/16/25.
//

import SwiftUI
import AudioToolbox
internal import CoreAudioKit

struct AudioUnitViewModel {
    var showAudioControls: Bool = false
    var showMIDIContols: Bool = false
    var title: String = "-"
    var message: String = "No Audio Unit loaded.."
    var viewController: ViewController?
}
