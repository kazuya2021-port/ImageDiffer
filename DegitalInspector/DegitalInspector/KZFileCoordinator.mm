//
//  KZFileCoordinator.m
//  DegitalInspector
//
//  Created by uchiyama_Macmini on 2019/07/16.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "KZFileCoordinator.h"

@implementation KZFileCoordinator

- (void)removeFilePresenterIfNeeded
{
    if (_isPresenting) {
        _isPresenting = NO;
        [NSFileCoordinator removeFilePresenter:self];
    }
}

- (NSURL*)presentedItemURL
{
    return self.presentedItemURL;
}

- (NSOperationQueue*)presentedItemOperationQueue
{
    return [NSOperationQueue new];
}

// ファイル/ディレクトリが移動した時の通知
- (void)presentedSubitemAtURL:(NSURL *)oldURL didMoveToURL:(NSURL *)newURL
{
    BOOL isDir = NO;
    if ([NSFileManager.defaultManager fileExistsAtPath:newURL.path isDirectory:&isDir]) {
        if (isDir) {
            LogF(@"Move directory from (%@) to (%@)\n", oldURL.path, newURL.path);
        }
        else {
            LogF(@"Move file from (%@) to (%@)\n", oldURL.path, newURL.path);
        }
    }
}

/// 以下はファイルを監視する場合に有効
/*
// 提示された項目の内容または属性が変更されたことを伝える。
- (void)presentedItemDidChange
{
    Log(@"Item Changed\n");
}

// ファイルまたはファイルパッケージの新しいバージョンが追加されたことをデリゲートに通知する
- (void)presentedItemDidGainVersion:(NSFileVersion *)version
{
    LogF(@"Update file at %@\n",version.modificationDate);
}

// ファイルまたはファイルパッケージのバージョンが消えたことをデリゲートに通知する
- (void)presentedItemDidLoseVersion:(NSFileVersion *)version
{
    LogF(@"Lose file version at %@\n",version.modificationDate);
}
 
 // 何したら呼ばれるのか
 - (void)accommodatePresentedItemDeletionWithCompletionHandler:(void (^)(NSError *))completionHandler
 {
 Log(@"accommodatePresentedItemDeletionWithCompletionHandler");
 }
*/

// ディレクトリ内のアイテムが新しいバージョンになった（更新された）時の通知
- (void)presentedSubitemAtURL:(NSURL *)url didGainVersion:(NSFileVersion *)version
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

// ファイル/ディレクトリの内容変更の通知
- (void)presentedSubitemDidChangeAtURL:(NSURL *)url
{
    BOOL isDir = NO;
    if (NEQ_STR([url.path lastPathComponent], @".DS_Store")) {
        
        /*
        if ([NSFileManager.defaultManager fileExistsAtPath:url.path isDirectory:&isDir]) {
            if(self.delegate) {
                if ([_delegate respondsToSelector:@selector(onDirectoryChanged:file:isRemoved:)]) {
                    [_delegate onDirectoryChanged:self file:url isRemoved:NO];
                }
            }
        }
        else {
            if(self.delegate) {
                if ([_delegate respondsToSelector:@selector(onDirectoryChanged:file:isRemoved:)]) {
                    [_delegate onDirectoryChanged:self file:url isRemoved:YES];
                }
            }
        }*/
    }
    
}



// 何したら呼ばれるのか
- (void)accommodatePresentedSubitemDeletionAtURL:(NSURL *)url completionHandler:(void (^)(NSError *))completionHandler
{
    Log(@"accommodatePresentedSubitemDeletionAtURL");
    LogF(@"url:%@",url.path);
}

// 何したら呼ばれるのか
- (void)presentedSubitemDidAppearAtURL:(NSURL *)url
{
    Log(@"presentedSubitemDidAppearAtURL");
    LogF(@"url:%@",url.path);
}

- (void)presentedSubitemAtURL:(NSURL *)url
    didResolveConflictVersion:(NSFileVersion *)version
{
    Log(@"didResolveConflictVersion");
    LogF(@"url:%@",url.path);
}
- (id)initWithPath:(NSString*)path
{
    if(self = [super init])
    {
        _corrd = [[NSFileCoordinator alloc] initWithFilePresenter:self];
        //[self addFilePresenterIfNeeded];
        presentedItemOperationQueue = [[NSOperationQueue alloc] init];
        self.presentedItemURL = [NSURL fileURLWithPath:path];
        _isDirEntered = NO;
    }
    return self;
}

@synthesize presentedItemOperationQueue;

@end
