//
//  VoxApp.swift
//  Vox
//
//  Created by Mark Pauley on 5/16/25.
//

import SwiftUI

@main
struct VoxApp: App {
    @State private var hostModel = AudioUnitHostModel()

    var body: some Scene {
        WindowGroup {
            ContentView(hostModel: hostModel)
        }
    }
}
