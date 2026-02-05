//
//  FilterWrapper.mm
//  VoxExtension
//
//  Stubbed Objective-C++ wrapper - actual DSP uses VoxVoice
//

#import "FilterWrapper.h"
#import <cmath>
#import <algorithm>

@interface FilterWrapper () {
    double _sampleRate;
    double _cutoff;
    double _resonance;
    FilterWrapperMode _mode;
    int _poles;
    // Simple one-pole filter state
    float _y1;
    float _y2;
}
@end

@implementation FilterWrapper

- (instancetype)initWithSampleRate:(double)sampleRate {
    self = [super init];
    if (self) {
        _sampleRate = sampleRate;
        _cutoff = 1000.0;
        _resonance = 0.5;
        _mode = FilterWrapperModeLowpass;
        _poles = 4;
        _y1 = 0.0f;
        _y2 = 0.0f;
    }
    return self;
}

- (void)setCutoff:(double)cutoff {
    _cutoff = std::max(20.0, std::min(cutoff, _sampleRate * 0.49));
}

- (double)cutoff {
    return _cutoff;
}

- (void)setResonance:(double)resonance {
    _resonance = std::max(0.0, std::min(resonance, 1.0));
}

- (double)resonance {
    return _resonance;
}

- (void)setMode:(FilterWrapperMode)mode {
    _mode = mode;
}

- (FilterWrapperMode)mode {
    return _mode;
}

- (void)setPoles:(int)poles {
    _poles = std::max(1, std::min(poles, 4));
}

- (int)poles {
    return _poles;
}

- (double)processWithInput:(double)input {
    // Simple one-pole lowpass filter coefficient
    float omega = 2.0f * M_PI * (float)_cutoff / (float)_sampleRate;
    float alpha = omega / (1.0f + omega);
    
    float in = (float)input;
    
    switch (_mode) {
        case FilterWrapperModeLowpass:
            _y1 = _y1 + alpha * (in - _y1);
            return (double)_y1;
            
        case FilterWrapperModeHighpass:
            _y1 = _y1 + alpha * (in - _y1);
            return input - (double)_y1;
            
        case FilterWrapperModeBandpass:
            _y1 = _y1 + alpha * (in - _y1);
            _y2 = _y2 + alpha * (_y1 - _y2);
            return (double)(_y1 - _y2);
            
        default:
            return input;
    }
}

- (void)reset {
    _y1 = 0.0f;
    _y2 = 0.0f;
}

@end
