//
//  KZDirectoryObserver.m
//  DegitalInspector
//
//  Created by uchiyama_Macmini on 2019/07/16.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//
#include <string>
#include <stdio.h>
#include <iostream>
#include <launch.h>
#import "KZDirectoryObserver.h"

typedef void (^KZDirectoryObserverBlock)(NSString *changedPath, BOOL isRemove);

@interface KZDirectoryObserver()
@property (nonatomic, copy) KZDirectoryObserverBlock callback;
@end

void fs_event_callback(FSEventStreamRef streamRef,
                       void *clientCallBackInfo,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[])
{
    char **paths = (char **)eventPaths;
    const char * flags[] = {
        "MustScanSubDirs",
        "UserDropped",
        "KernelDropped",
        "EventIdsWrapped",
        "HistoryDone",
        "RootChanged",
        "Mount",
        "Unmount",
        "ItemCreated",
        "ItemRemoved",
        "ItemInodeMetaMod",
        "ItemRenamed",
        "ItemModified",
        "ItemFinderInfoMod",
        "ItemChangeOwner",
        "ItemXattrMod",
        "ItemIsFile",
        "ItemIsDir",
        "ItemIsSymlink",
        "OwnEvent"
    };
    dispatch_queue_t queue = dispatch_queue_create("KZDirectoryObserverQueue", 0);
    KZDirectoryObserver *observer = (__bridge KZDirectoryObserver *)clientCallBackInfo;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, observer.latency * NSEC_PER_SEC);
    for (int i = 0 ; i < numEvents ; i++) {
        BOOL isHistory = NO;
        BOOL isCreated = NO;
        BOOL isChangeOwner = NO;
        BOOL isDir = NO;
        BOOL isFile = NO;
        BOOL isRenamed = NO;
        long bit = 1 ;
        std::string path(paths[ i ]);
        if (path.find(".DS_Store") != std::string::npos) {
            continue;
        }
        //std::cout << "path:" << path << std::endl;
        
        for ( int index=0, count = sizeof( flags ) / sizeof( flags[0]); index < count; ++index ) {
            if ( ( eventFlags[i] & bit ) != 0 ) {
                if (!strcmp(flags[ index ], "ItemIsDir")) {
                    isDir = YES;
                }
                if (!strcmp(flags[ index ], "ItemIsFile")) {
                    isFile = YES;
                }
                if (!strcmp(flags[ index ], "ItemRenamed")) {
                    isRenamed = YES;
                }
                if (!strcmp(flags[ index ], "ItemCreated")) {
                    isCreated = YES;
                }
                if (!strcmp(flags[ index ], "ItemChangeOwner")) {
                    isChangeOwner = YES;
                }
                if (!strcmp(flags[ index ], "HistoryDone")) {
                    isHistory = YES;
                }
                //std::cout << "flag:" << flags[ index ] << std::endl;
            }
            bit <<= 1 ;
        }
        
        NSString *theFile = [NSString stringWithUTF8String:(char*)(path.c_str())];
        
        if (isChangeOwner) {
            dispatch_after(popTime, queue, ^(void){
                observer.callback(theFile, NO);
            });
        } else if (isRenamed) {
            if (![NSFileManager.defaultManager fileExistsAtPath:theFile]) {
                dispatch_after(popTime, queue, ^(void){
                    observer.callback(theFile, YES);
                });
            }
        }
    }
    FSEventStreamFlushSync( streamRef ) ;
}

@implementation KZDirectoryObserver
{
    NSString *_path;
    FSEventStreamRef _stream;
}

- (id)initWithDirectoryPath:(NSString *)path latency:(NSTimeInterval)late callback:(void(^)(NSString * changedPaths, BOOL isRemove))cb
{
    if(self = [super init])
    {
        _path = path;
        _callback = cb;
        _latency = late;
    }
    return self;
}
- (void)startObserving
{
    if(_stream)
        return;
    
    FSEventStreamContext context = {0};
    context.info = (__bridge void *)self;
    
    CFTimeInterval latency = 1; /*監視間隔*/
    _stream = FSEventStreamCreate(NULL,
                                  (FSEventStreamCallback)fs_event_callback, /*コールバック*/
                                  &context, /*ユーザーデータのため*/
                                  (__bridge CFArrayRef)@[_path], /*監視するパス*/
                                  kFSEventStreamEventIdSinceNow,//lastEventId, /*よくわかりません*/
                                  (CFTimeInterval)_latency,
                                  kFSEventStreamCreateFlagFileEvents);
    
    FSEventStreamScheduleWithRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamStart(_stream);
}
- (void)stopObserving
{
    if(_stream == NULL)
        return;
    
    FSEventStreamStop(_stream);
    FSEventStreamUnscheduleFromRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamInvalidate(_stream);
    FSEventStreamRelease(_stream);
    _stream = NULL;
}

@end
