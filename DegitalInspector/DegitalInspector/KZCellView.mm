//
//  KZCellView.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/03/29.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZCellView.h"

@interface KZCellView()
@property (nonatomic, weak) IBOutlet NSTextField *pageEnd;
@end

@implementation KZCellView

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self)
    {
        self.progressView.hidden = YES;
        self.progress.wantsLayer = YES;
    }
    return self;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.progressView.hidden = YES;
        self.progress.wantsLayer = YES;
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)showProgress
{
    self.progressView.hidden = NO;
}

@end
