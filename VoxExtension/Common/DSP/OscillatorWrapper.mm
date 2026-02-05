//
//  OscillatorWrapper.mm
//  VoxExtension
//
//  Created by Claude on 5/16/25.
//

#import "OscillatorWrapper.h"
#import <VoxCore/VoxCore.h>

// Private class extension for implementation details
@interface OscillatorWrapper () {
    SinOscillator *_oscillator;
    double _frequency;
    double _sampleRate;
}
@end

@implementation OscillatorWrapper

+ (instancetype)oscillatorWithType:(OscillatorType)type sampleRate:(double)sampleRate {
    // Factory method to create different oscillator types
    // Currently only supports sine oscillator, will expand as we implement more
    return [[OscillatorWrapper alloc] initWithSampleRate:sampleRate];
}

- (instancetype)initWithSampleRate:(double)sampleRate {
    self = [super init];
    if (self) {
        _sampleRate = sampleRate;
        _frequency = 440.0; // Default to A4
        _oscillator = new SinOscillator(sampleRate);
        _oscillator->setFrequency(_frequency);
    }
    return self;
}

- (void)dealloc {
    delete _oscillator;
}

- (void)setFrequency:(double)frequency {
    _frequency = frequency;
    _oscillator->setFrequency(frequency);
}

- (double)frequency {
    return _frequency;
}

- (double)process {
    return _oscillator->process();
}

@end
