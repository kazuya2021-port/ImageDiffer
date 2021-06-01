//
//  KZToolBarControll.h
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/22.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import <Foundation/Foundation.h>

@class KZPreferenceWindowController;

@interface KZToolBarControll : NSObject
@property (nonatomic, strong) NSToolbar *toolbar;
@property (nonatomic, copy) NSString *curPreset;
@property (nonatomic, strong) NSPopUpButton *presetBox;
@property (nonatomic, weak) IBOutlet KZPreferenceWindowController *wincon;
@property (nonatomic, weak) IBOutlet NSPanel *logPanel;
- (void)setUpUI;
@end
