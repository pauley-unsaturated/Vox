#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface VoxSynthAudioUnit : AUAudioUnit

// Properties for parameters
@property (nonatomic, readonly) AUParameterTree *parameterTree;
@property AUAudioUnitBusArray *outputBusArray;
@property AUAudioUnitBusArray *inputBusArray;

@end