//
//  NoiseLevelChartView.m
//  NoiseDetection
//
//  Created by Frank on 6/13/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import "NoiseLevelChartView.h"

@interface NoiseLevelChartView()

@property (nonatomic) float samplingTimeInterval;
@property (nonatomic) float recordingTimeInterval;
@property (nonatomic) int maxDisplaySamples;
@property (nonatomic, strong) NSMutableArray *dataArray;

@end

@implementation NoiseLevelChartView

@synthesize samplingTimeInterval;
@synthesize recordingTimeInterval;
@synthesize maxDisplaySamples;
@synthesize dataArray;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.samplingTimeInterval = 0.03;
        self.recordingTimeInterval = 2.0;
        self.maxDisplaySamples = 10.0 / self.samplingTimeInterval;
        self.dataArray = [[NSMutableArray alloc] initWithCapacity:self.maxDisplaySamples];
        self.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.65];
    }
    return self;
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 1.5);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = {0.0, 0.0, 0.0, 0.7};
    CGColorRef color = CGColorCreate(colorspace, components);
    CGContextSetStrokeColorWithColor(context, color);
    

    int width = self.frame.size.width;
    int height = self.frame.size.height;
    
    float margin = 20.0;
    float paddingy = height * 0.05;
    
    // vertical ruler
    CGContextMoveToPoint(context, margin, paddingy);
    CGContextAddLineToPoint(context, margin, paddingy+height*0.85);
    CGContextStrokePath(context);

    CGContextMoveToPoint(context, width - margin, paddingy);
    CGContextAddLineToPoint(context, width - margin, paddingy+height*0.85);
    CGContextStrokePath(context);

    
    float delta = height * 0.85 / 10.0;
    for(int i=0; i<10; i++) {
        float len = i % 2 == 0?4:3;
        CGContextMoveToPoint(context, margin-len, paddingy + delta*i);
        CGContextAddLineToPoint(context, margin, paddingy + delta*i);
        CGContextStrokePath(context);
    }
    
    for(int i=0; i<10; i++) {
        float len = i % 2 == 0?4:3;
        CGContextMoveToPoint(context, width - margin+len, paddingy + delta*i);
        CGContextAddLineToPoint(context, width - margin, paddingy + delta*i);
        CGContextStrokePath(context);
    }
    
    CGContextSelectFont (context, // 3
                         "Helvetica-Bold",
                         15,
                         kCGEncodingMacRoman);
    float fontSize = 10;
    float delta2 = height * 0.85 / 5.0;
    float paddingy2 = paddingy + 5;
    for(int i=0; i<5; i++) {
        int val = 90 - i*20;
        CGPoint location = CGPointMake(2, paddingy2 + delta2*i);
        NSString *text = [NSString stringWithFormat:@"%d", val];
        [text drawAtPoint:location withFont:[UIFont fontWithName:@"Helvetica" size:fontSize]];
    }
    
    for(int i=0; i<5; i++) {
        int val = 90 - i*20;
        CGPoint location = CGPointMake(width-margin+7, paddingy2 + delta2*i);
        NSString *text = [NSString stringWithFormat:@"%d", val];
        [text drawAtPoint:location withFont:[UIFont fontWithName:@"Helvetica" size:fontSize]];
    }
    
    
    // horizontal ruler
    CGContextMoveToPoint(context, margin, paddingy+height*0.85);
    CGContextAddLineToPoint(context, width-margin, paddingy+height*0.85);
    CGContextStrokePath(context);
    
    
    // draw data
    float graphicHeight = height*0.85;
    CGFloat components2[] = {0.0, 0.0, 1.0, 0.7};
    CGContextSetLineWidth(context, 3.0);
    CGColorRef color2 = CGColorCreate(colorspace, components2);
    CGContextSetStrokeColorWithColor(context, color2);
    
    if ([self.dataArray count] > 1) {
        float dx = (width-margin*2) / self.maxDisplaySamples;
        float dy = paddingy + (100.0 - [[self.dataArray objectAtIndex:0] floatValue]) * graphicHeight / 100.0;
        CGContextMoveToPoint(context, margin, dy);
        //NSLog(@"i=0, dy=%f", dy);
        
        for(int i=1; i<[self.dataArray count]; i++) {
            float dy1 = paddingy + (100.0 - [[self.dataArray objectAtIndex:i] floatValue]) * graphicHeight / 100.0;
            CGContextAddLineToPoint(context, margin + dx* i, dy1);
            
            //NSLog(@"i=%d, dyy=%f, dx=%f, val=%f", i, dy1, (margin + dx* i), [[self.dataArray objectAtIndex:i] floatValue] );
        }
        
        CGContextStrokePath(context);
    }
    
    CGColorSpaceRelease(colorspace);
    CGColorRelease(color);
}

-(void)addNoiseLevelData:(float)level
{
    if ([self.dataArray count] > self.maxDisplaySamples) {
        [self.dataArray removeObjectAtIndex:0];
    }
    [self.dataArray addObject:[NSNumber numberWithFloat:level]];
    [self setNeedsDisplay];
}

-(void)setSamplingTimeInterval:(float)sampling andRecordingTimeInterval:(float)recording
{
    if (sampling>0.0 && sampling < recording) {
        self.recordingTimeInterval = recording;
        self.samplingTimeInterval  = sampling;
        self.maxDisplaySamples = 10.0/self.samplingTimeInterval; // 10 seconds
    }
}

-(void)clearChart
{
    [self.dataArray removeAllObjects];
}

@end
