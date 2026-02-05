#pragma once

#import <AudioToolbox/AudioToolbox.h>

@interface AUParameterTree (Extensions)

+ (AUParameter *)createParameterWithIdentifier:(NSString *)identifier
                                          name:(NSString *)name
                                       address:(AUParameterAddress)address
                                           min:(AUValue)min
                                           max:(AUValue)max
                                          unit:(AudioUnitParameterUnit)unit
                                      unitName:(NSString *)unitName
                                         flags:(AudioUnitParameterOptions)flags
                                  valueStrings:(NSArray *)valueStrings
                           dependentParameters:(NSArray *)dependentParameters;

@end