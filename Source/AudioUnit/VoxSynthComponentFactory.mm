#import "VoxSynthComponentFactory.h"
#import "VoxSynthAudioUnit.h"

/**
 This is the factory function to create instances of our custom AudioUnit.
 It is exported in the bundle's binary.
 */
AudioComponentPlugInInterface* VISIBLE_EXPORT VoxSynthComponentFactory(const AudioComponentDescription* inDesc) {
    // Verify that the requested component type matches our AUv3
    if (inDesc->componentType != kAudioUnitType_MusicDevice || 
        inDesc->componentSubType != 'voxs' || 
        inDesc->componentManufacturer != 'nSat') {
        return nullptr;
    }
    
    return AUPluginBase::Factory<VoxSynthAudioUnit>();
}