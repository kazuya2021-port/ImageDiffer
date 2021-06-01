//
//  KZMainViewControll.h
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/09.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KZMainViewControll : NSObject
@property (nonatomic, weak) IBOutlet NSWindow *window;
@property (nonatomic, weak) IBOutlet NSWindow *logTextWindow;
- (void)loadView;
- (void)stopEngine;

@end
