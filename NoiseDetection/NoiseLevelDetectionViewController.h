//
//  NoiseLevelDetectionViewController.h
//  NoiseDetection
//
//  Created by Frank on 6/6/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface NoiseLevelDetectionViewController : UIViewController

@property (nonatomic) float samplingTimeInterval;
@property (nonatomic) float recordingTimeInterval;

- (IBAction)gpsModeChanged:(id)sender;
- (IBAction)startStopRecordNoiseLevel:(id)sender;
- (IBAction)settingsTapped:(id)sender;

@end
