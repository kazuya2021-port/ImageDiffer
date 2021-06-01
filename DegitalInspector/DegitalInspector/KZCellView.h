//
//  KZCellView.h
//  DegitalInspector
//
//  Created by 内山和也 on 2019/03/29.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KZTransparentView.h"

@interface KZCellView : NSTableCellView
@property (nonatomic, weak) IBOutlet NSTextField *pageRange;
@property (nonatomic, weak) IBOutlet NSTextField *fileName;
@property (nonatomic, weak) IBOutlet NSTextField *progDetail;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *progress;
@property (nonatomic, weak) IBOutlet KZTransparentView *progressView;
@property (nonatomic, weak) IBOutlet NSTextField *pathInfo;
-(void)showProgress;
@end
