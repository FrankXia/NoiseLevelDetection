//
//  NoiseLevelDetectionViewController.m
//  NoiseDetection
//
//  Created by Frank on 6/6/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudioTypes.h>

#import "NoiseLevelDetectionViewController.h"
#import "NoiseLevelChartView.h"
#import "SettingsViewController.h"
#import "SRWebSocket.h"



#define WORLD_STREET_MAP @"http://services.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer"
#define WORLD_TOPO_MAP @"http://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer"
#define WORLD_IMAGERY_MAP @"http://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer"
#define WS_SERVICE_URL @"ws://ec2-54-224-16-41.compute-1.amazonaws.com:8080/noise-ws";
#define WS_SERVICE_TEST_URL @"wss://echo.websocket.org/"
#define WS_SERVICE_TEST_URL2 @"ws://localhost:8787/jWebSocket/jWebSocket"

@interface NoiseLevelDetectionViewController () <AGSMapViewTouchDelegate,AGSFeatureLayerQueryDelegate,AGSFeatureLayerEditingDelegate,CLLocationManagerDelegate,SettingsViewControllerDelegate,SRWebSocketDelegate>
{
    NSDateFormatter *_dateFormatter;
    NSMutableArray *_cumulatedNoiseLevels;
}

@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) NSTimer *levelTimer;
@property (nonatomic, strong) NSTimer *recordingTimer;
@property (nonatomic) double maxNoiseLevel;
@property (nonatomic) int count;
@property (nonatomic) BOOL recordingStarted;
@property (nonatomic) BOOL gpsStarted;

@property (nonatomic) double latitude;
@property (nonatomic) double longitude;
@property (nonatomic) NSString *username;
@property (nonatomic) NSString *notes;

@property (nonatomic, strong) NSString *serviceURL;
@property (nonatomic, strong) SRWebSocket *webSocket;

@property (nonatomic, strong) NoiseLevelChartView *chartView;

@property (nonatomic, strong) IBOutlet AGSMapView *mapView;
@property (nonatomic, strong) IBOutlet UIButton *gpsButton;
@property (nonatomic, strong) IBOutlet UIButton *noiseButton;
@property (nonatomic, strong) IBOutlet UIButton *settingsButton;
@property (nonatomic, strong) IBOutlet UITextField *noiseLevelFd;
@property (nonatomic, strong) IBOutlet UIView *mapViewCover;

@property (nonatomic, strong) SettingsViewController *settingsViewController;
@property (nonatomic, strong) CLLocationManager *locationManager;

@property (nonatomic) float noiseScale;

-(void)levelTimerCallback:(NSTimer*)timer;

@end

@implementation NoiseLevelDetectionViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.mapView.touchDelegate = self;
    self.samplingTimeInterval = 0.03; // sampling interval 0.03 second
    self.recordingTimeInterval = 1.0; // recording interval 1 seconds
    self.serviceURL = WS_SERVICE_URL;
    
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    _cumulatedNoiseLevels = [[NSMutableArray alloc] initWithCapacity:20];
    
    NSURL *url = [NSURL fileURLWithPath:@"/dev/null"];
    
	NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSNumber numberWithFloat: 44100.0],                 AVSampleRateKey,
							  [NSNumber numberWithInt: kAudioFormatAppleLossless], AVFormatIDKey,
							  [NSNumber numberWithInt: 1],                         AVNumberOfChannelsKey,
							  [NSNumber numberWithInt: AVAudioQualityMax],         AVEncoderAudioQualityKey,
							  nil];
    
	NSError *error;
    
	self.recorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:&error];
    
	if (self.recorder) {
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        [audioSession setActive:YES error:nil];
        
		[self.recorder prepareToRecord];
		self.recorder.meteringEnabled = YES;
	} else
		NSLog(@"%@", [error description]);
    
    self.noiseLevelFd.text = @"";
    self.username = @"Esri Staff";
    self.notes = @"2013 Esri International User Conference";
    
    //add the base map.
    NSURL *mapUrl = [NSURL URLWithString:WORLD_STREET_MAP];
    AGSTiledMapServiceLayer *tiledLyr = [AGSTiledMapServiceLayer tiledMapServiceLayerWithURL:mapUrl];
    tiledLyr.opacity = 0.9999;
    [self.mapView addMapLayer:tiledLyr withName:@"World Street Map"];
    self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeOff;
    
    
    CGRect chartFrame = [[UIScreen mainScreen] bounds];
    chartFrame.size.height = 150.0;
    chartFrame.origin.y = 150;
    self.chartView = [[NoiseLevelChartView alloc] initWithFrame:chartFrame];
    self.chartView.hidden = NO;
    [self.view addSubview:self.chartView];
    
    self.navigationItem.title = @"Back";
    self.navigationController.navigationBar.hidden = YES;
    self.mapViewCover.hidden = NO;
    
    self.webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.serviceURL]]];
    self.webSocket.delegate = self;
    [self.webSocket open];
    
    self.noiseScale = 1.0;
}

-(void)viewWillAppear:(BOOL)animated
{
    self.navigationController.navigationBar.hidden = YES;
    NSLog(@"mapview.hidden=%@, cover=%@", self.mapView.hidden?@"true":@"false", self.mapViewCover.hidden?@"true":@"false");
}
- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
    self.webSocket.delegate = nil;
    [self.webSocket close];
    self.webSocket = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)levelTimerCallback:(NSTimer*)timer
{
    // for real testing, comment the following line and activate the block after the following line
//    [self simulatingNoiseLevel];


    [self.recorder updateMeters];
    
    // not sure what this does for me
//	const double ALPHA = 0.05;
//	double peakPowerForChannel = pow(10, (0.05 * [recorder peakPowerForChannel:0]));
//	lowPassResults = ALPHA * peakPowerForChannel + (1.0 - ALPHA) * lowPassResults;
	
    double currentLevel = [self.recorder peakPowerForChannel:0];
    //NSLog(@"Original level=%f", currentLevel);
    currentLevel += 90;
    currentLevel *= self.noiseScale;
    if(currentLevel > self.maxNoiseLevel)self.maxNoiseLevel = currentLevel;
    
    int noiseLevel = (int) self.maxNoiseLevel;
    self.noiseLevelFd.text = [NSString stringWithFormat:@"%d",  noiseLevel];
    [self.chartView addNoiseLevelData:self.maxNoiseLevel];

}

-(void)startTimerCallback:(NSTimer*)timer
{
    NSLog(@"startTimerCallback");
    
//    recordingStarted = !recordingStarted;
//	if (recorder) {
//        [recorder stop];
//        [levelTimer invalidate];
//    }
    
    AGSLocation *currentLocation = self.mapView.locationDisplay.location;
    [self addCurrentNoiseLevel:currentLocation.point];
}

- (IBAction)gpsModeChanged:(id)sender {
    self.gpsButton.selected = !self.gpsButton.selected;
    
    if(!self.locationManager)
    {
        //create the location manager.
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        
        //set the preferences that was configured using the settings view.
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        self.locationManager.distanceFilter =  10;
    }
    
    if(self.gpsButton.selected) {
        [self.locationManager startUpdatingLocation];
    }else {
        [self.locationManager stopUpdatingLocation];
    }
    
    switch (self.mapView.locationDisplay.autoPanMode) {
        case AGSLocationDisplayAutoPanModeOff:
            [self.mapView centerAtPoint:self.mapView.locationDisplay.mapLocation animated:YES];
            self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;
            //Set a wander extent equal to 75% of the map's envelope
            //The map will re-center on the location symbol only when
            //the symbol moves out of the wander extent
            self.mapView.locationDisplay.wanderExtentFactor = 0.75;
            self.mapView.locationDisplay.navigationPointHeightFactor = 0.05;
            self.mapView.locationDisplay.alpha = 0.5f;
            
            if(!self.mapView.locationDisplay.dataSourceStarted)
                [self.mapView.locationDisplay startDataSource];
            break;
            
        case AGSLocationDisplayAutoPanModeDefault:
            self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeOff;
            //Position the location symbol near the bottom of the map
            //A value of 1 positions it at the top edge, and 0 at bottom edge
            self.mapView.locationDisplay.wanderExtentFactor = 0.25;
            self.mapView.locationDisplay.navigationPointHeightFactor = 0.05;
            self.mapView.locationDisplay.alpha = 0.5f;
            
            if(self.mapView.locationDisplay.dataSourceStarted)
                [self.mapView.locationDisplay stopDataSource];
            break;
        default:
            break;
    }

}

- (IBAction)startStopRecordNoiseLevel:(id)sender
{
    self.noiseButton.selected = !self.noiseButton.selected;
    
    self.recordingStarted = !self.recordingStarted;
	if (self.recorder) {
        if (self.recordingStarted) {
            self.chartView.hidden = NO;
            
            self.recordingTimer = [NSTimer scheduledTimerWithTimeInterval: self.recordingTimeInterval target:self selector: @selector(startTimerCallback:) userInfo: nil repeats: YES]; 
            
            [self.recorder record];     
            self.levelTimer = [NSTimer scheduledTimerWithTimeInterval: self.samplingTimeInterval target:self selector: @selector(levelTimerCallback:) userInfo: nil repeats: YES];
            
            [self reconnectWebSocket];
        } else {
            [self.recorder stop];
        }
    }
    if (!self.recordingStarted) {
        if (self.recordingTimer) {
            [self.recordingTimer invalidate];
        } 
        self.recordingTimer = nil;

        if(self.levelTimer){
            [self.levelTimer invalidate];
        }
        self.levelTimer = nil;
        
        if(self.webSocket) {
            [self.webSocket close];
        }
    }else {
        [self.chartView clearChart];
    }
}

- (void)reconnectWebSocket;
{
    if(self.webSocket){
        if (self.webSocket.readyState == SR_OPEN) {
            return;
        }
        self.webSocket.delegate = nil;
        [self.webSocket close];
    }
    self.webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.serviceURL]]];
    self.webSocket.delegate = self;
    
    NSLog(@"Opening Websocket Connection ...");
    [self.webSocket open];
}

- (void)simulatingNoiseLevel
{
    if (self.recordingStarted) {
        NSInteger randomNumber = arc4random() % 90;
        if(randomNumber<0) randomNumber = randomNumber*(-1);
        while (randomNumber<50) {
            randomNumber = arc4random() % 90;
            if(randomNumber<0) randomNumber = randomNumber*(-1);
        }
        
        [self.chartView addNoiseLevelData:randomNumber];
        self.noiseLevelFd.text = [NSString stringWithFormat: @"%d", randomNumber];
        self.maxNoiseLevel = randomNumber;
        
        [self addCurrentNoiseLevel:self.mapView.visibleAreaEnvelope.center];
        
//        NSLog(@"simulated level=%d", randomNumber);
    }
}

- (IBAction)settingsTapped:(id)sender
{
    if (!self.settingsViewController) {
        self.settingsViewController = [[SettingsViewController alloc] initWithNibName:@"SettingsViewController" bundle:nil];
        self.settingsViewController.delegate = self;
        NSLog(@"main view height=%f", self.view.frame.size.height);
        CGRect frame = CGRectMake(0, 0, 320, self.view.frame.size.height-44);
        self.settingsViewController.view.frame = frame;
    }
    
    NSArray *params = [[NSArray alloc] initWithObjects: [NSString stringWithFormat:@"%@",self.serviceURL], [NSString stringWithFormat:@"%d",self.mapViewCover.hidden], [NSString stringWithFormat:@"%f", self.samplingTimeInterval],  [NSString stringWithFormat:@"%f", self.recordingTimeInterval], self.username, self.notes, [NSString stringWithFormat:@"%.2f",self.noiseScale], nil];
    
    self.settingsViewController.parameters = params;
    
    [self.navigationController pushViewController:self.settingsViewController animated:YES];
}

#pragma mark
#pragma mark SettingsViewControllerDelegate
#pragma mark

-(void)updateParameters:(NSArray*)params
{
    if (params && [params count]==7) {
        NSString *url = [params objectAtIndex:0];
        if(url && [url hasPrefix:@"ws://"]) {
            self.serviceURL = url;
            if(self.webSocket) {
                [self.webSocket close];
                self.webSocket = nil;
            }
        }
        
        NSLog(@"      [[params objectAtIndex:1] boolValue]?%@, service url=%@",[[params objectAtIndex:1] boolValue]?@"true":@"false", self.serviceURL);
        self.mapViewCover.hidden = [[params objectAtIndex:1] boolValue];
        [self.view setNeedsDisplay];
        
        NSString* tmp = [params objectAtIndex:2];
        if(tmp && ![tmp isEqualToString:@""]){
            float sampleInterval = [tmp floatValue];
            self.samplingTimeInterval = sampleInterval;
        }
        
        tmp = [params objectAtIndex:3];
        if(tmp && ![tmp isEqualToString:@""]){
            float recordingInterval = [tmp floatValue];
            self.recordingTimeInterval = recordingInterval;
        }
        
        tmp = [params objectAtIndex:4];
        if(tmp && ![tmp isEqualToString:@""]){
            self.username = tmp;
        }
        
        tmp = [params objectAtIndex:5];
        if(tmp && ![tmp isEqualToString:@""]){
            self.notes = tmp;
        }
        
        tmp = [params objectAtIndex:6];
        if(tmp && ![tmp isEqualToString:@""]){
            self.noiseScale = [tmp floatValue];
        }
    }
}

#pragma mark
#pragma mark AGSFeatureLayerEditingDelegate
#pragma mark

//Called when we have successfully posted a set of features. Once an inspection has finished posting, we then
//need to post the attachments for the particular feature (if there are any)
- (void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation *)op didFeatureEditsWithResults:(AGSFeatureLayerEditResults *)editResults {
    
}

- (void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation *)op didFailFeatureEditsWithError:(AGSFeatureLayerEditResults *)editResults {

}


#pragma mark
#pragma mark AGSFeatureLayerQueryDelegate
#pragma mark


- (void) featureLayer:(AGSFeatureLayer *)featureLayer
            operation:(NSOperation *)op didQueryFeaturesWithFeatureSet:	(AGSFeatureSet *)featureSet
{

}


#pragma mark
#pragma mark AGSMapViewTouchDelegate
#pragma mark

- (void)mapView:(AGSMapView *) mapView didClickAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mappoint graphics:(NSDictionary *) graphics
{
    //if the graphics is selected then dont show the story point view controller.
    for (NSString *key in graphics.keyEnumerator) {
        NSArray *graphicsArray = [graphics objectForKey:key];
        if([graphicsArray count] > 0)
            return;
    }
    
    [self addCurrentNoiseLevel:mappoint];
}

-(void)addCurrentNoiseLevel:(AGSPoint*)mappoint
{
    
//    NSLog(@"noise level=%f", self.maxNoiseLevel);
    if(self.maxNoiseLevel==0.0)return;
    
    AGSGeometryEngine *geometryEngine = [AGSGeometryEngine defaultGeometryEngine];
    AGSPoint *latlon = (AGSPoint*)[geometryEngine projectGeometry:mappoint toSpatialReference:[AGSSpatialReference spatialReferenceWithWKID:4326]];
    
    //send noise level to server via web socket, todo
    int noiseLevel = (int) self.maxNoiseLevel;
    NSString *timeStamp = [_dateFormatter stringFromDate:[NSDate date]];
    NSString *message = [NSString stringWithFormat:@"{\"noiseDecibel\":%d,\"timestamp\":\"%@\",\"user\":\"%@\", \"notes\":\"%@\", \"longitude\":%f, \"latitude\":%f}", noiseLevel, timeStamp, self.username, self.notes, latlon.x, latlon.y];
//    NSLog(@"<message=%@>", message);
    
    [_cumulatedNoiseLevels addObject:message];
    
    if(self.webSocket.readyState == SR_OPEN){
        for (int i=0; i<[_cumulatedNoiseLevels count]; i++) {
            [self.webSocket send:[_cumulatedNoiseLevels objectAtIndex:i]];
            NSLog(@"sending message=%@", [_cumulatedNoiseLevels objectAtIndex:i]);
        }
        [_cumulatedNoiseLevels removeAllObjects];
    }
    
    self.maxNoiseLevel = 0.0;

    
}

- (BOOL)mapView:(AGSMapView *) mapView shouldProcessClickAtPoint:(CGPoint) screen mapPoint:(AGSPoint *) mappoint
{
    return YES;
}

#pragma mark
#pragma mark - SRWebSocketDelegate
#pragma mark 

- (void)webSocketDidOpen:(SRWebSocket *)webSocket;
{
    NSLog(@"Websocket Connected, state=%d, service url=%@", webSocket.readyState, self.serviceURL);
    
    //testing connection
//    NSString *timeStamp = [_dateFormatter stringFromDate:[NSDate date]];
//    NSString *message = [NSString stringWithFormat:@"{\"noiseDecibel\":%f,\"timestamp\":%@,\"user\":\"%@\", \"notes\":\"%@\", \"longitude\":%f, \"latitude\":%f", self.maxNoiseLevel, timeStamp, self.username, self.notes, self.longitude, self.latitude];
//
//    [self.webSocket send:message];
    
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
{
    NSLog(@":( Websocket Failed With Error %@, service url=%@", error, self.serviceURL);
    self.webSocket = nil;
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message;
{
    NSLog(@"Received \"%@\"", message);
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
{
    NSLog(@"WebSocket closed");
    self.webSocket = nil;
}

@end
