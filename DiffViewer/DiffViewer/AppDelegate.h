//
//  AppDelegate.h
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/07/31.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "DVSettingWindow.h"
#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) DVSettingWindow *prefWindow;
@property (nonatomic, retain) NSMutableArray *arOpenFiles;
@property (nonatomic, retain) OpenedFile *currentFile;
@end

