//
//  NoiseLevelDetectionAppDelegate.h
//  NoiseDetection
//
//  Created by Frank on 6/6/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NoiseLevelDetectionViewController;

@interface NoiseLevelDetectionAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UINavigationController *navigationController;
@property (strong, nonatomic) NoiseLevelDetectionViewController *viewController;

@end
