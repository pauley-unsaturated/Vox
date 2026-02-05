#pragma once

#import <AudioToolbox/AudioToolbox.h>

/**
 Factory function for creating the AudioComponent instances.
 This function is referenced in the Info.plist for the AUv3 extension.
 */
extern "C" {
    AudioComponentPlugInInterface* VISIBLE_EXPORT VoxSynthComponentFactory(const AudioComponentDescription* inDesc);
}