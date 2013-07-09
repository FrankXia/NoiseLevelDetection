//
//  NoiseLevelChartView.h
//  NoiseDetection
//
//  Created by Frank on 6/13/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NoiseLevelChartView : UIView

-(void)setSamplingTimeInterval:(float)sampling andRecordingTimeInterval:(float)recording;
-(void)addNoiseLevelData:(float)level;
-(void)clearChart;

@end
