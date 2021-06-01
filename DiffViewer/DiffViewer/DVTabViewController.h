//
//  DVTabViewController.h
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/07/31.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

@interface DVTabViewController : NSObject
@property (nonatomic, weak) IBOutlet NSWindow *window;
- (void)loadView;
- (void)addNewDiff:(OpenedFile*)file;
@end
