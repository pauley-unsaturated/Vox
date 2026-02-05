#import "VoxSynthAudioUnit.h"
#import "VoxSynthDSPKernel.hpp"
#import "../AUExtensions/AUParameterTreeExt.h"

@interface VoxSynthAudioUnit ()

@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBus *inputBus;
@property VoxSynthDSPKernel kernel;

@end

@implementation VoxSynthAudioUnit {
    // Buffers for parameters that may be ramped
    std::unique_ptr<AUParameterListenerToken> _parameterObserverToken;
}

@synthesize parameterTree = _parameterTree;
@synthesize outputBusArray = _outputBusArray;
@synthesize inputBusArray = _inputBusArray;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription
                                     options:(AudioComponentInstantiationOptions)options
                                       error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) { return nil; }
    
    // Initialize the kernel
    _kernel.init(44100.0);
    
    // Create audio bus
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                             busType:AUAudioUnitBusTypeOutput
                                                              busses:@[_outputBus]];
    
    // Create parameter objects
    [self setupParameterTree:defaultFormat];
    
    // Set up sample rate and block size
    self.maximumFramesToRender = 4096;
    
    return self;
}

- (void)setupParameterTree:(AVAudioFormat *)format {
    // Create parameter objects
    AUParameter *oscMixParam = [AUParameterTree createParameterWithIdentifier:@"oscMix"
                                                                         name:@"Oscillator Mix"
                                                                      address:0
                                                                          min:0.0
                                                                          max:1.0
                                                                         unit:kAudioUnitParameterUnit_Generic
                                                                     unitName:nil
                                                                        flags:0
                                                                 valueStrings:nil
                                                          dependentParameters:nil];
    
    AUParameter *filterCutoffParam = [AUParameterTree createParameterWithIdentifier:@"filterCutoff"
                                                                               name:@"Filter Cutoff"
                                                                            address:1
                                                                                min:20.0
                                                                                max:20000.0
                                                                               unit:kAudioUnitParameterUnit_Hertz
                                                                           unitName:nil
                                                                              flags:0
                                                                       valueStrings:nil
                                                                dependentParameters:nil];
    
    AUParameter *filterResonanceParam = [AUParameterTree createParameterWithIdentifier:@"filterResonance"
                                                                                  name:@"Filter Resonance"
                                                                               address:2
                                                                                   min:0.0
                                                                                   max:1.0
                                                                                  unit:kAudioUnitParameterUnit_Generic
                                                                              unitName:nil
                                                                                 flags:0
                                                                          valueStrings:nil
                                                                   dependentParameters:nil];
    
    // Initialize with default values
    oscMixParam.value = 0.5;
    filterCutoffParam.value = 1000.0;
    filterResonanceParam.value = 0.1;
    
    // Create parameter tree
    _parameterTree = [AUParameterTree createTreeWithChildren:@[
        oscMixParam,
        filterCutoffParam,
        filterResonanceParam
    ]];
    
    // Set parameter change handlers
    __weak VoxSynthAudioUnit *weakSelf = self;
    _parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        [weakSelf setParameter:param value:value];
    };
    
    _parameterTree.implementorValueProvider = ^(AUParameter *param) {
        return [weakSelf getParameter:param];
    };
}

- (AUValue)getParameter:(AUParameter *)parameter {
    // Return the current value of the parameter
    AUValue value = 0.0;
    
    switch (parameter.address) {
        case 0: // oscMix
            value = _kernel.getOscMix();
            break;
        case 1: // filterCutoff
            value = _kernel.getFilterCutoff();
            break;
        case 2: // filterResonance
            value = _kernel.getFilterResonance();
            break;
        default:
            break;
    }
    
    return value;
}

- (void)setParameter:(AUParameter *)parameter value:(AUValue)value {
    // Set the parameter in the kernel
    switch (parameter.address) {
        case 0: // oscMix
            _kernel.setOscMix(value);
            break;
        case 1: // filterCutoff
            _kernel.setFilterCutoff(value);
            break;
        case 2: // filterResonance
            _kernel.setFilterResonance(value);
            break;
        default:
            break;
    }
}

- (AUInternalRenderBlock)internalRenderBlock {
    // Get reference to kernel
    VoxSynthDSPKernel *kernel = &_kernel;
    
    return ^AUAudioUnitStatus(
                              AudioUnitRenderActionFlags *actionFlags,
                              const AudioTimeStamp *timestamp,
                              AVAudioFrameCount frameCount,
                              NSInteger outputBusNumber,
                              AudioBufferList *outputData,
                              const AURenderEvent *realtimeEventListHead,
                              AURenderPullInputBlock pullInputBlock) {
        
        // Process audio and MIDI events
        kernel->process(timestamp, frameCount, outputData);
        
        return noErr;
    };
}

// MARK: - AUAudioUnit (AUAudioUnitImplementation)

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    if (![super allocateRenderResourcesAndReturnError:outError]) {
        return NO;
    }
    
    _kernel.reset();
    
    return YES;
}

- (void)deallocateRenderResources {
    _kernel.reset();
    
    [super deallocateRenderResources];
}

- (AUAudioUnitStatus)resetWithComponentDescription:(AudioComponentDescription)desc
                                           options:(AudioComponentInstantiationOptions)options
                                             error:(NSError **)outError {
    return [super resetWithComponentDescription:desc options:options error:outError];
}

@end