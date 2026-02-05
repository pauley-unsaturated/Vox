//
//  OscillatorWrapper.h
//  VoxExtension
//
//  Created by Claude on 5/16/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Forward declarations for C++ classes we'll wrap
class SinOscillator;

// Enumeration for oscillator types - will expand as we implement more
typedef NS_ENUM(NSInteger, OscillatorType) {
    OscillatorTypeSine,
    OscillatorTypePolyBLEPSaw,
    OscillatorTypeDPWSaw,
    OscillatorTypeSquare,
    OscillatorTypeTriangle,
    OscillatorTypeNoise
};

// Objective-C wrapper for C++ oscillators to expose to Swift
@interface OscillatorWrapper : NSObject

// Factory method to create the proper oscillator type
+ (instancetype)oscillatorWithType:(OscillatorType)type sampleRate:(double)sampleRate;

// Initialize with sample rate
- (instancetype)initWithSampleRate:(double)sampleRate;

// Parameter controls
- (void)setFrequency:(double)frequency;
- (double)frequency;

// Processing
- (double)process;

@end

NS_ASSUME_NONNULL_END