//
//  FilterWrapper.h
//  VoxExtension
//
//  Created by Claude on 5/16/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Forward declarations for C++ classes
class MoogLadderFilter;

// Enum for filter modes
typedef NS_ENUM(NSInteger, FilterWrapperMode) {
    FilterWrapperModeLowpass,
    FilterWrapperModeBandpass,
    FilterWrapperModeHighpass
};

@interface FilterWrapper : NSObject

// Initialize with sample rate
- (instancetype)initWithSampleRate:(double)sampleRate;

// Parameter controls
- (void)setCutoff:(double)cutoff;
- (double)cutoff;

- (void)setResonance:(double)resonance;
- (double)resonance;

- (void)setMode:(FilterWrapperMode)mode;
- (FilterWrapperMode)mode;

- (void)setPoles:(int)poles;
- (int)poles;

// Processing
- (double)processWithInput:(double)input;

// Reset
- (void)reset;

@end

NS_ASSUME_NONNULL_END