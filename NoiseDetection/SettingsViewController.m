//
//  SettingsViewController.m
//  NoiseDetection
//
//  Created by Frank on 6/13/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import "SettingsViewController.h"

#define kVerticalMove 150

@interface SettingsViewController () <UITextViewDelegate, UITextFieldDelegate>

@property (nonatomic) BOOL showMap;

@property (nonatomic, strong) IBOutlet UISwitch *showMapSwitch;
@property (nonatomic, strong) IBOutlet UITextField *serviceURLFd;
@property (nonatomic, strong) IBOutlet UITextField *samplingTimeIntervalFd;
@property (nonatomic, strong) IBOutlet UITextField *recordingTimeIntervalFd;
@property (nonatomic, strong) IBOutlet UITextField *usernameFd;
@property (nonatomic, strong) IBOutlet UITextView  *notesView;
@property (nonatomic, strong) IBOutlet UISlider *noiseScaleSlider;
@property (nonatomic, strong) IBOutlet UILabel *noiseScaleLabel;

@property (nonatomic, strong) IBOutlet UIScrollView *settingContainer;

@end

@implementation SettingsViewController

@synthesize delegate;
@synthesize parameters;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStylePlain target:self action:@selector(closeKeyboard:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    self.navigationController.navigationBar.hidden = NO;
    self.samplingTimeIntervalFd.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    self.recordingTimeIntervalFd.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardWillHideNotification object:nil];
 
    self.notesView.delegate = self;
    self.usernameFd.delegate = self;
    
    self.noiseScaleSlider.minimumValue = 0.1;
    self.noiseScaleSlider.maximumValue = 1.0;
    self.noiseScaleSlider.value = 1.0;
    
    self.settingContainer.scrollEnabled = YES;
    
    CGRect frame = CGRectMake(0, 66, 320, self.view.frame.size.height-66);
    self.settingContainer.frame = frame;
    self.settingContainer.contentSize = CGSizeMake(320, 548);
    
    NSLog(@"scroll view width=%f, height=%f, view height=%f", self.settingContainer.frame.size.width, self.settingContainer.frame.size.height, self.view.frame.size.height);
}

-(void)viewWillAppear:(BOOL)animated {
     self.navigationController.navigationBar.hidden = NO;
    [self fillParameters];
}

-(void)keyboardWillShow:(id)sender
{
    //NSLog(@"keyboardWillShow %@", sender);
}
-(void)keyboardDidHide:(id)sender
{
    NSLog(@"keyboardDidHide");
}
-(void)closeKeyboard:(id)sender
{
    NSLog(@"closeKeyboard");
    
    [self.serviceURLFd resignFirstResponder];
    [self.samplingTimeIntervalFd resignFirstResponder];
    [self.recordingTimeIntervalFd resignFirstResponder];
    [self.usernameFd resignFirstResponder];
    [self.notesView resignFirstResponder];
    
    [self updateSettings:sender];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)updateSettings:(id)sender
{
    NSLog(@"!self.showMapSwitch.selected?%@",!self.showMapSwitch.on?@"true":@"false");
    NSArray *params = [[NSArray alloc] initWithObjects: self.serviceURLFd.text, [NSString stringWithFormat:@"%d",self.showMapSwitch.on], self.samplingTimeIntervalFd.text,  self.recordingTimeIntervalFd.text, self.usernameFd.text, self.notesView.text, [NSString stringWithFormat:@"%f",self.noiseScaleSlider.value], nil];
    [delegate updateParameters:params];
}

-(IBAction)updateSliderValue:(id)sender
{
    self.noiseScaleLabel.text = [NSString stringWithFormat:@"%.2f", self.noiseScaleSlider.value];
}

-(void)fillParameters
{
    if (self.parameters && [self.parameters count] == 7) {
        self.serviceURLFd.text = [self.parameters objectAtIndex:0];
        if ([[self.parameters objectAtIndex:1] boolValue]) {
            self.showMapSwitch.on = YES;
        }else{
            self.showMapSwitch.on = NO;
        }
        
        self.samplingTimeIntervalFd.text = [self.parameters objectAtIndex:2];
        self.recordingTimeIntervalFd.text = [self.parameters objectAtIndex:3];
        
        self.usernameFd.text = [self.parameters objectAtIndex:4];
        self.notesView.text = [self.parameters objectAtIndex:5];
        
        NSString *noiseScale = [self.parameters objectAtIndex:6];
        [self.noiseScaleSlider setValue:[noiseScale floatValue]];
        self.noiseScaleLabel.text = noiseScale;
    }
}

#pragma mark
#pragma mark UITextViewDelegate
#pragma mark

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    NSLog(@"textViewDidBeginEditing");
    CGRect frame = self.settingContainer.frame;
    frame.origin.y -= kVerticalMove;
    
    [UIView animateWithDuration:0.5
                          delay:0.01
                        options: UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.settingContainer.frame = frame;
                     }
                     completion:^(BOOL finished){
                         NSLog(@"Done!");
                     }];
    

}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    NSLog(@"textViewDidEndEditing");
    CGRect frame = self.settingContainer.frame;
    frame.origin.y += kVerticalMove;
    [UIView animateWithDuration:0.5
                          delay:0.01
                        options: UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.settingContainer.frame = frame;
                     }
                     completion:^(BOOL finished){
                         NSLog(@"Done!");
                     }];
}


#pragma mark
#pragma mark UITextFieldDelegate
#pragma mark

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    NSLog(@"textFieldDidBeginEditing");
    if(self.usernameFd == textField) {
        CGRect frame = self.settingContainer.frame;
        frame.origin.y -= kVerticalMove;
        
        [UIView animateWithDuration:0.5
                              delay:0.01
                            options: UIViewAnimationOptionCurveEaseIn
                         animations:^{
                             self.settingContainer.frame = frame;
                         }
                         completion:^(BOOL finished){
                             NSLog(@"Done!");
                         }];
    }
    
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    NSLog(@"textFieldDidEndEditing");
    if(self.usernameFd == textField) {
        CGRect frame = self.settingContainer.frame;
        frame.origin.y += kVerticalMove;
        [UIView animateWithDuration:0.5
                              delay:0.01
                            options: UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             self.settingContainer.frame = frame;
                         }
                         completion:^(BOOL finished){
                             NSLog(@"Done!");
                         }];
    }
}


@end
