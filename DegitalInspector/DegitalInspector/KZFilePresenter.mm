//
//  KZFilePresenter.m
//  DegitalInspector
//
//  Created by uchiyama_Macmini on 2019/07/16.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "KZFilePresenter.h"

@implementation KZFilePresenter
- (void)presentedItemDidGainVersion:(NSFileVersion *)version
{
    LogF(@"Update file at %@\n",version.modificationDate);
}

- (void)presentedItemDidLoseVersion:(NSFileVersion *)version
{
    LogF(@"Lose file version at %@\n",version.modificationDate);
}

- (void)presentedSubitemAtURL:(NSURL *)url didGainVersion:(NSFileVersion *)version
{
    BOOL isDir = NO;
    if ([NSFileManager.defaultManager fileExistsAtPath:url.path isDirectory:&isDir]) {
        if (isDir) {
            LogF(@"Gain directory version (%@) at %@\n", url.path, version.modificationDate);
        }
        else {
            LogF(@"Gain file version (%@) at %@\n", url.path, version.modificationDate);
        }
    }
}

- (void)relinquishPresentedItemToWriter:(void (^)(void (^)()))writer
{
    Log(@"relinquishPresentedItemToWriter");
    writer(^{
    });
}

- (void)relinquishPresentedItemToReader:(void (^)(void (^)()))reader
{
    Log(@"relinquishPresentedItemToReader");
    reader(^{
    });
}

- (void)presentedSubitemAtURL:(NSURL *)url didLoseVersion:(NSFileVersion *)version
{
    BOOL isDir = NO;
    if ([NSFileManager.defaultManager fileExistsAtPath:url.path isDirectory:&isDir]) {
        if (isDir) {
            LogF(@"Lose directory version (%@) at %@\n", url.path, version.modificationDate);
        }
        else {
            LogF(@"Lose file version (%@) at %@\n", url.path, version.modificationDate);
        }
    }
}

- (void)accommodatePresentedItemDeletionWithCompletionHandler:(void (^)(NSError *))completionHandler
{
    Log(@"accommodatePresentedItemDeletionWithCompletionHandler");
}

- (void)accommodatePresentedSubitemDeletionAtURL:(NSURL *)url completionHandler:(void (^)(NSError *))completionHandler
{
    Log(@"accommodatePresentedSubitemDeletionAtURL");
    LogF(@"url:%@",url.path);
}

- (void)presentedSubitemDidAppearAtURL:(NSURL *)url
{
    Log(@"presentedSubitemDidAppearAtURL");
    LogF(@"url:%@",url.path);
}

- (void)presentedSubitemAtURL:(NSURL *)url didResolveConflictVersion:(NSFileVersion *)version
{
    Log(@"didResolveConflictVersion");
    LogF(@"url:%@",url.path);
}

- (void)savePresentedItemChangesWithCompletionHandler:(void (^)(NSError *))completionHandler
{
    Log(@"savePresentedItemChangesWithCompletionHandler");
    completionHandler(nil);
}

// ファイル/ディレクトリの内容変更の通知
- (void)presentedSubitemDidChangeAtURL:(NSURL *)url
{
    //NSLog(@"SubitemDidChangeAtURL %@",url.path);
}


- (id)initWithURL:(NSURL*)path
{
    if(self = [super init])
    {
        _isPresenting = NO;
        _presentedItemURL = path;
        _presentedItemOperationQueue = [[NSOperationQueue alloc] init];
        [NSFileCoordinator addFilePresenter:self];
    }
    return self;
}
@end
