//
//  SettingsViewController.h
//  NoiseDetection
//
//  Created by Frank on 6/13/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import <UIKit/UIKit.h>
 
@protocol SettingsViewControllerDelegate;

@interface SettingsViewController : UIViewController

@property (nonatomic, weak) id <SettingsViewControllerDelegate> delegate;
@property (nonatomic, strong) NSArray* parameters;

-(IBAction)updateSettings:(id)sender;
-(IBAction)updateSliderValue:(id)sender;

@end

@protocol SettingsViewControllerDelegate <NSObject>

-(void)updateParameters:(NSArray*)params;

@end