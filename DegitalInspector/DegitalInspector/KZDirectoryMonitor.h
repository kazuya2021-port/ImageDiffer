//
//  KZDirectoryMonitor.h
//  DegitalInspector
//
//  Created by uchiyama_Macmini on 2019/07/17.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KZDirectoryMonitor : NSObject
@property (nonatomic, readwrite, copy) NSString * _Nonnull monitorPath;
+ (KZDirectoryMonitor * _Nonnull)folderMonitorAtPath:(NSString * _Nonnull)path startImmediately:(BOOL)startImmediately callback:(void(^_Nullable)(NSString * _Nullable changedPath, BOOL isRemove))cb;
+ (KZDirectoryMonitor * _Nonnull)folderMonitorAtPath:(NSString * _Nonnull)path callback:(void(^_Nullable)(NSString * _Nullable changedPath, BOOL isRemove))cb;
- (BOOL)startMonitoring;
- (BOOL)stopMonitoring;
@end
