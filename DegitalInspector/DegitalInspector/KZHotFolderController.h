//
//  KZHotFolderController.h
//  DegitalInspector
//
//  Created by uchiyama_Macmini on 2019/07/11.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>

#define PROCESS_FOLDER @"Processing" // この名前のフォルダに入ったものを入れたら比較しない
#define PROCESS_NG_FOLDER @"Abort" // この名前のフォルダに入ったものを入れたら比較しない

@interface KZHotFolderController : NSObject
@property (nonatomic, copy) NSNumber *isRunning;
+ (instancetype)sharedHotFolder;
- (void)startHotFolder;
- (void)stopHotFolder;
@end
