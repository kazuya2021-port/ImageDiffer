//
//  KZTransparentView.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/03/29.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZTransparentView.h"

@implementation KZTransparentView

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

- (void)awakeFromNib
{
    self.wantsLayer = YES;
}

- (BOOL)wantsUpdateLayer
{
    return YES;
}

- (void)updateLayer
{
    self.layer.backgroundColor = [NSColor colorWithCalibratedWhite:50.0 alpha:0.7].CGColor;
    self.layer.shouldRasterize = YES;
}
@end
