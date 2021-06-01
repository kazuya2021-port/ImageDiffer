//
//  KZDirectoryObserver.h
//  DegitalInspector
//
//  Created by uchiyama_Macmini on 2019/07/16.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KZDirectoryObserver : NSObject
- (id _Nonnull )initWithDirectoryPath:(NSString * _Nonnull)path latency:(NSTimeInterval)late callback:(void(^_Nonnull)(NSString * _Nonnull changedPaths, BOOL isRemove))cb;
- (void)startObserving;
- (void)stopObserving;
@property (nonatomic) NSTimeInterval latency;
@end
