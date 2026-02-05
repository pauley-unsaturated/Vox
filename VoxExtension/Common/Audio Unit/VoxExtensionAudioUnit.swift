//
//  VoxExtensionAudioUnit.swift
//  VoxExtension
//
//  Vox Pulsar Synthesizer Audio Unit
//

import AVFoundation
import os.log
internal import VoxCore

private let auLog = OSLog(subsystem: "com.unsaturated.Vox", category: "AudioUnit")

public class VoxExtensionAudioUnit: AUAudioUnit, @unchecked Sendable
{
    // C++ Objects
    var kernel = VoxExtensionDSPKernel()
    var processHelper: AUProcessHelper?

    private var outputBus: AUAudioUnitBus?
    private var _outputBusses: AUAudioUnitBusArray!
    private var _inputBusses: AUAudioUnitBusArray!

    private var format: AVAudioFormat

    // Lazy parameter tree initialization flag
    private var parameterTreeInitialized = false

    @objc override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
        os_log(.info, log: auLog, "VoxExtensionAudioUnit init() called")
        self.format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        try super.init(componentDescription: componentDescription, options: options)
        outputBus = try AUAudioUnitBus(format: self.format)
        outputBus?.maximumChannelCount = 2
        _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [outputBus!])
        _inputBusses = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.input, busses: [])
        processHelper = AUProcessHelper(&kernel)
        os_log(.info, log: auLog, "VoxExtensionAudioUnit init() complete")
    }
    
    // MARK: - Channel Capabilities
    // Synth: no input, stereo output
    public override var channelCapabilities: [NSNumber]? {
        return [0, 2]  // 0 inputs, 2 outputs (stereo)
    }

    public override var inputBusses: AUAudioUnitBusArray {
        return _inputBusses
    }
    
    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusses
    }
    
    public override var maximumFramesToRender: AUAudioFrameCount {
        get {
            return kernel.maximumFramesToRender()
        }
        set {
            kernel.setMaximumFramesToRender(newValue)
        }
    }

    public override var shouldBypassEffect: Bool {
        get {
            return kernel.isBypassed()
        }
        set {
            kernel.setBypass(newValue)
        }
    }

    // MARK: - MIDI
    public override var audioUnitMIDIProtocol: MIDIProtocolID {
        return kernel.AudioUnitMIDIProtocol()
    }

    // MARK: - Rendering
    public override var internalRenderBlock: AUInternalRenderBlock {
        return processHelper!.internalRenderBlock()
    }

    public override func allocateRenderResources() throws {
        os_log(.info, log: auLog, "allocateRenderResources() called")
        
        // Call super first so the host can set up the bus formats
        os_log(.info, log: auLog, "About to call super.allocateRenderResources()")
        try super.allocateRenderResources()
        os_log(.info, log: auLog, "super.allocateRenderResources() complete")
        
        // Ensure parameter tree is initialized before rendering
        ensureParameterTree()
        os_log(.info, log: auLog, "Parameter tree ensured")
        
        let outputFormat = self.outputBusses[0].format
        let outputChannelCount = outputFormat.channelCount
        let sampleRate = outputFormat.sampleRate
        os_log(.info, log: auLog, "Output format: channels=%d, sampleRate=%f", outputChannelCount, sampleRate)
        
        kernel.setMusicalContextBlock(self.musicalContextBlock)
        kernel.setTransportStateBlock(self.transportStateBlock)
        os_log(.info, log: auLog, "About to initialize kernel")
        kernel.initialize(Int32(outputChannelCount), sampleRate)
        os_log(.info, log: auLog, "Kernel initialized")

        processHelper?.setChannelCount(0, outputChannelCount)
        os_log(.info, log: auLog, "Process helper configured")

        // Switch to scheduled parameter updates during rendering for thread safety
        setupRenderingParameterObserver()
        os_log(.info, log: auLog, "allocateRenderResources() complete")
    }

    public override func deallocateRenderResources() {
        // Switch back to direct parameter setting when not rendering
        setupParameterCallbacks()
        
        kernel.deInitialize()
        
        super.deallocateRenderResources()
    }

    public func setupParameterTree(_ parameterTree: AUParameterTree) {
        guard !parameterTreeInitialized else { return }
        initializeParameterTree(parameterTree)
    }

    private func ensureParameterTree() {
        guard !parameterTreeInitialized else { return }
        let tree = VoxExtensionParameterSpecs.createAUParameterTree()
        initializeParameterTree(tree)
    }

    private func initializeParameterTree(_ parameterTree: AUParameterTree) {
        parameterTreeInitialized = true
        self.parameterTree = parameterTree

        // Set parameter default values
        for param in parameterTree.allParameters {
            kernel.setParameter(param.address, param.value)
        }

        setupParameterCallbacks()
    }
    
    deinit {
        parameterTree?.implementorValueObserver = { _, _ in }
        parameterTree?.implementorValueProvider = { _ in 0.0 }
        parameterTree?.implementorStringFromValueCallback = { _, _ in "" }
        processHelper = nil
    }

    private func setupParameterCallbacks() {
        parameterTree?.implementorValueObserver = { [weak self] param, value -> Void in
            self?.kernel.setParameter(param.address, value)
        }

        parameterTree?.implementorValueProvider = { [weak self] param in
            return self!.kernel.getParameter(param.address)
        }

        parameterTree?.implementorStringFromValueCallback = { param, valuePtr in
            guard let value = valuePtr?.pointee else {
                return "-"
            }
            return NSString.localizedStringWithFormat("%.f", value) as String
        }
    }
    
    private func setupRenderingParameterObserver() {
        let scheduleParameterBlock = self.scheduleParameterBlock
        let rampTime = AUAudioFrameCount(0.02 * outputBusses[0].format.sampleRate)
        
        parameterTree?.implementorValueObserver = { param, value in
            scheduleParameterBlock(AUEventSampleTimeImmediate, rampTime, param.address, value)
        }
    }
    
    // MARK: - State Persistence

    public override var fullState: [String : Any]? {
        get {
            ensureParameterTree()

            var state = super.fullState ?? [:]
            if let paramTree = parameterTree {
                var parameterData: [String: Float] = [:]
                for param in paramTree.allParameters {
                    parameterData["\(param.address)"] = param.value
                }
                state["VoxParameters"] = parameterData
            }

            return state
        }
        set {
            super.fullState = newValue

            ensureParameterTree()

            if let paramTree = parameterTree,
               let rawParamData = newValue?["VoxParameters"] {

                func getValue(for address: AUParameterAddress) -> Any? {
                    if let stringDict = rawParamData as? [String: Any] {
                        return stringDict["\(address)"]
                    }
                    if let intDict = rawParamData as? [Int: Any] {
                        return intDict[Int(address)]
                    }
                    if let anyDict = rawParamData as? [AnyHashable: Any] {
                        return anyDict["\(address)"] ?? anyDict[Int(address)]
                    }
                    return nil
                }

                for param in paramTree.allParameters {
                    if let value = getValue(for: param.address) {
                        let floatValue: Float
                        if let f = value as? Float {
                            floatValue = f
                        } else if let d = value as? Double {
                            floatValue = Float(d)
                        } else if let n = value as? NSNumber {
                            floatValue = n.floatValue
                        } else {
                            continue
                        }
                        kernel.setParameter(param.address, floatValue)
                        param.value = floatValue
                    }
                }
            }
        }
    }

    public override var fullStateForDocument: [String : Any]? {
        get { return fullState }
        set { fullState = newValue }
    }

    public override var supportsUserPresets: Bool { true }

    // MARK: - Factory Presets

    public override var factoryPresets: [AUAudioUnitPreset] {
        return FactoryPresetLoader.shared.presets
    }

    private var _currentPreset: AUAudioUnitPreset?

    public override var currentPreset: AUAudioUnitPreset? {
        get { return _currentPreset }
        set {
            guard let preset = newValue else {
                _currentPreset = nil
                return
            }

            if preset.number >= 0 {
                loadFactoryPreset(number: preset.number)
                _currentPreset = preset
            } else {
                do {
                    let presetState = try self.presetState(for: preset)
                    self.fullStateForDocument = presetState
                    _currentPreset = preset
                } catch {
                    print("Vox: Unable to restore user preset '\(preset.name)': \(error)")
                }
            }
        }
    }

    private func loadFactoryPreset(number: Int) {
        guard let state = FactoryPresetLoader.shared.loadPresetState(number: number) else {
            print("Vox: Factory preset \(number) not found")
            return
        }
        self.fullStateForDocument = state
    }
    
    // MARK: - Output Level Metering
    
    public func getOutputLevel() -> Float {
        return kernel.getOutputLevel()
    }
    
    public func getOutputPeakHold() -> Float {
        return kernel.getOutputPeakHold()
    }
    
    // MARK: - Sequencer Step Methods
    // TODO: Implement proper kernel integration when sequencer DSP is ready
    
    private var sequencerSteps: [(pitch: Int, gate: Bool, tie: Bool, accent: Bool)] = Array(repeating: (pitch: 0, gate: true, tie: false, accent: false), count: 32)
    private var currentSequencerStep: Int = 0
    
    public func setSequencerStepPitch(_ index: Int, pitch: Int) {
        guard index >= 0 && index < sequencerSteps.count else { return }
        sequencerSteps[index].pitch = pitch
    }
    
    public func getSequencerStepPitch(_ index: Int) -> Int {
        guard index >= 0 && index < sequencerSteps.count else { return 0 }
        return sequencerSteps[index].pitch
    }
    
    public func setSequencerStepGate(_ index: Int, gate: Bool) {
        guard index >= 0 && index < sequencerSteps.count else { return }
        sequencerSteps[index].gate = gate
    }
    
    public func getSequencerStepGate(_ index: Int) -> Bool {
        guard index >= 0 && index < sequencerSteps.count else { return true }
        return sequencerSteps[index].gate
    }
    
    public func setSequencerStepTie(_ index: Int, tie: Bool) {
        guard index >= 0 && index < sequencerSteps.count else { return }
        sequencerSteps[index].tie = tie
    }
    
    public func getSequencerStepTie(_ index: Int) -> Bool {
        guard index >= 0 && index < sequencerSteps.count else { return false }
        return sequencerSteps[index].tie
    }
    
    public func setSequencerStepAccent(_ index: Int, accent: Bool) {
        guard index >= 0 && index < sequencerSteps.count else { return }
        sequencerSteps[index].accent = accent
    }
    
    public func getSequencerStepAccent(_ index: Int) -> Bool {
        guard index >= 0 && index < sequencerSteps.count else { return false }
        return sequencerSteps[index].accent
    }
    
    public func getSequencerCurrentStep() -> Int {
        return currentSequencerStep
    }
    
    public func clearSequencerSteps() {
        sequencerSteps = Array(repeating: (pitch: 0, gate: true, tie: false, accent: false), count: 32)
        currentSequencerStep = 0
    }
}
