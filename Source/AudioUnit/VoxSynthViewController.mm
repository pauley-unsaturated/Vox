#import "VoxSynthViewController.h"
#import "VoxSynthAudioUnit.h"

@interface VoxSynthViewController ()

// UI controls will be added here

@end

@implementation VoxSynthViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set up UI controls and connect to parameters
    // This will be implemented in detail later
}

- (void)setAudioUnit:(AUAudioUnit *)audioUnit {
    _audioUnit = audioUnit;
    
    if (!audioUnit) {
        return;
    }
    
    // Connect UI to the parameters
    // This will be implemented in detail later
}

@end