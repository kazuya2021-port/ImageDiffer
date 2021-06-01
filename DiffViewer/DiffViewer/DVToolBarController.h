//
//  DVToolBarController.h
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/08/01.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

@class DVSettingWindow;

@protocol DVToolBarControllerDelegate <NSObject>
- (void)appearSingleView;
- (void)appearDoubleView;
@end

@interface DVToolBarController : NSObject
@property (nonatomic, strong) NSToolbar *toolbar;
@property (nonatomic, weak) IBOutlet DVSettingWindow *wincon;
@property (nonatomic, strong) id <DVToolBarControllerDelegate> delegate;
- (void)setUpUI;
@end
