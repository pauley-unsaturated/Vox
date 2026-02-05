//
//  AudioUnitViewController.swift
//  VoxExtension
//
//  Created by Mark Pauley on 5/16/25.
//

import Combine
import CoreAudioKit
import os
import SwiftUI

private let log = Logger(subsystem: "com.unsaturated.VoxExtension", category: "AudioUnitViewController")

@MainActor
public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    var audioUnit: AUAudioUnit?
    
    var hostingController: HostingController<VoxExtensionMainView>?
    
    private var observation: NSKeyValueObservation?
    
    private static let pluginSize = CGSize(width: 1200, height: 800)
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        // Set preferred content size immediately on init
        self.preferredContentSize = Self.pluginSize
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.preferredContentSize = Self.pluginSize
    }

	/* iOS View lifcycle
	public override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		// Recreate any view related resources here..
	}

	public override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		// Destroy any view related content here..
	}
	*/

	/* macOS View lifcycle
	public override func viewWillAppear() {
		super.viewWillAppear()
		
		// Recreate any view related resources here..
	}

	public override func viewDidDisappear() {
		super.viewDidDisappear()

		// Destroy any view related content here..
	}
	*/

	deinit {
        // Clean up the key-value observation
        observation?.invalidate()
        observation = nil
        
        // Clean up hosting controller
        if let hostingController = self.hostingController {
            Task { @MainActor in
                hostingController.removeFromParent()
                hostingController.view.removeFromSuperview()
            }
        }
	}

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set preferred content size early so hosts get the correct dimensions
        self.preferredContentSize = Self.pluginSize
        
        // Set minimum size constraints on the view for hosts like Ableton that need explicit sizing
        self.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.pluginSize.width).isActive = true
        self.view.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.pluginSize.height).isActive = true
        
        // Accessing the `audioUnit` parameter prompts the AU to be created via createAudioUnit(with:)
        guard let audioUnit = self.audioUnit else {
            return
        }
        configureSwiftUIView(audioUnit: audioUnit)
    }
    
	nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
		return try DispatchQueue.main.sync {
			
			audioUnit = try VoxExtensionAudioUnit(componentDescription: componentDescription, options: [])
			
			guard let audioUnit = self.audioUnit as? VoxExtensionAudioUnit else {
				log.error("Unable to create VoxExtensionAudioUnit")
				return audioUnit!
			}
			
			defer {
				// Configure the SwiftUI view after creating the AU, instead of in viewDidLoad,
				// so that the parameter tree is set up before we build our @AUParameterUI properties
				DispatchQueue.main.async {
					self.configureSwiftUIView(audioUnit: audioUnit)
				}
			}
			
			audioUnit.setupParameterTree(VoxExtensionParameterSpecs.createAUParameterTree())
			
			self.observation = audioUnit.observe(\.allParameterValues, options: [.new]) { object, change in
				guard let tree = audioUnit.parameterTree else { return }
				
				// This insures the Audio Unit gets initial values from the host.
				for param in tree.allParameters { param.value = param.value }
			}
			
			guard audioUnit.parameterTree != nil else {
				log.error("Unable to access AU ParameterTree")
				return audioUnit
			}
			
			return audioUnit
		}
	}
    
    private func configureSwiftUIView(audioUnit: AUAudioUnit) {
        if let host = hostingController {
            host.removeFromParent()
            host.view.removeFromSuperview()
        }
        
        guard let observableParameterTree = audioUnit.observableParameterTree else {
            return
        }
        let analogThingAU = audioUnit as? VoxExtensionAudioUnit
        let content = VoxExtensionMainView(parameterTree: observableParameterTree, audioUnit: analogThingAU)
        let host = HostingController(rootView: content)
        self.addChild(host)
        self.view.addSubview(host.view)
        hostingController = host
        
        // Make sure the SwiftUI view fills the full area provided by the view controller
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        self.view.bringSubviewToFront(host.view)
        
        // Set preferred content size to give the host a hint about our desired size
        self.preferredContentSize = Self.pluginSize
    }
    
}

// Factory function for AUv3 components
@MainActor @_cdecl("VoxExtensionViewControllerFactory")
public func VoxExtensionViewControllerFactory(componentDescription: AudioComponentDescription) -> AUAudioUnitFactory {
    return AudioUnitViewController()
}
