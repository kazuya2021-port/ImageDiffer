//
//  KZDiffView.h
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/09.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DiffImgCV;

@interface KZDiffView : NSViewController
- (void)setFocus;
@property (nonatomic, strong) DiffImgCV *diffImg;
@property (nonatomic, weak) NSView *logContentView;
@end
