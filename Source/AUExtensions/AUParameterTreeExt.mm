#import "AUParameterTreeExt.h"

@implementation AUParameterTree (Extensions)

+ (AUParameter *)createParameterWithIdentifier:(NSString *)identifier
                                          name:(NSString *)name
                                       address:(AUParameterAddress)address
                                           min:(AUValue)min
                                           max:(AUValue)max
                                          unit:(AudioUnitParameterUnit)unit
                                      unitName:(NSString *)unitName
                                         flags:(AudioUnitParameterOptions)flags
                                  valueStrings:(NSArray *)valueStrings
                           dependentParameters:(NSArray *)dependentParameters {
    
    AudioUnitParameterOptions paramOptions = flags;
    paramOptions |= kAudioUnitParameterFlag_IsReadable;
    paramOptions |= kAudioUnitParameterFlag_IsWritable;
    
    AUParameterAddress paramAddress = address;
    
    AUParameter *param = [AUParameterTree createParameterWithIdentifier:identifier
                                                                   name:name
                                                                address:paramAddress
                                                                    min:min
                                                                    max:max
                                                                   unit:unit
                                                               unitName:unitName
                                                                  flags:paramOptions
                                                           valueStrings:valueStrings
                                                    dependentParameters:dependentParameters];
    
    return param;
}

@end