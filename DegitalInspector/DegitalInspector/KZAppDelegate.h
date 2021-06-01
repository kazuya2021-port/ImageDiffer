//
//  KZAppDelegate.h
//  DegitalInspector
//
//  Created by 内山和也 on 2019/03/29.
//  Copyright (c) 2019年 ___FULLUSERNAME___. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KZPreferenceWindowController.h"
@class KZPreferenceWindowController;

@interface KZAppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) KZPreferenceWindowController *prefWindow;
- (IBAction)showPreference:(id)sender;
@end
