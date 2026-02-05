#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>

@interface VoxSynthViewController : NSViewController

// Property to provide connection to the audio unit
@property (nonatomic) AUAudioUnit *audioUnit;

@end