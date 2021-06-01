//
//  KZSlider.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/03/29.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZSlider.h"

@implementation KZSlider

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    CGFloat delta = theEvent.deltaY;
    double perTick = (self.maxValue - self.minValue) / (self.numberOfTickMarks - 1);
    
    if(delta < 0 && self.doubleValue >= perTick)
    {
        self.doubleValue -= perTick;
    }
    else if (delta > 0 && self.doubleValue <= self.maxValue - perTick)
    {
        self.doubleValue += perTick;
    }
    else return;
    
    NSDictionary *bInfo = [self infoForBinding:@"value"];
    NSString *keyPath = bInfo[@"NSObservedKeyPath"];
    NSObjectController *bindObj = bInfo[@"NSObservedObject"];
    [bindObj setValue:[NSNumber numberWithDouble:self.doubleValue] forKeyPath:keyPath];
    
    [super scrollWheel:theEvent];
}

@end
