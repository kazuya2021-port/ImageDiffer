//
//  KZHotFolderController.m
//  DegitalInspector
//
//  Created by uchiyama_Macmini on 2019/07/11.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#include <CoreServices/CoreServices.h>
#import "KZHotFolderController.h"
#import <DiffImgCV/DiffImgCV.h>
#import "KZDirectoryObserver.h"

@interface KZHotFolderController()<DiffImgCVDelegate>

@property (assign) BOOL isCompaering;
@property (assign) BOOL isPresenting;
@property (nonatomic, strong) DiffImgCV *diffImg;
@property (nonatomic, strong) KZDirectoryObserver *bHot;
@property (nonatomic, strong) KZDirectoryObserver *aHot;
@property (nonatomic, strong) NSMutableSet *arOldFiles;
@property (nonatomic, strong) NSMutableSet *arNewFiles;
@property (nonatomic, strong) NSOperationQueue *workQueue;
@property (nonatomic, strong) NSString *oFolder;
@property (nonatomic, strong) NSString *nFolder;

- (void)startDiffBefore:(NSString*)before After:(NSString*)after;
@end

@implementation KZHotFolderController
#pragma mark -
#pragma mark Initialize

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return nil;
    }

    _arOldFiles = [NSMutableSet set];
    _arNewFiles = [NSMutableSet set];
    _isRunning = @NO;
    _isCompaering = NO;
    
    [self initHotFolder];
    
    return self;
}

- (void)initHotFolder
{
    NSMutableDictionary *d = [KZSetting.sharedSetting.settingVal mutableCopy];
    if (!d) {
        [KZSetting loadFromFile];
        d = [KZSetting.sharedSetting.settingVal mutableCopy];
    }
    if (d[@"oldHotFolderPath"] && d[@"newHotFolderPath"]) {
        
        if ([NSFileManager.defaultManager fileExistsAtPath:d[@"oldHotFolderPath"]] && [NSFileManager.defaultManager fileExistsAtPath:d[@"newHotFolderPath"]]) {
            
            _bHot = [[KZDirectoryObserver alloc] initWithDirectoryPath:d[@"oldHotFolderPath"] latency:1 callback:^(NSString * _Nonnull changedPath, BOOL isRemove) {
                if (!isRemove && ![KZLibs isDirectory:changedPath]) {
                    NSString *processedFile = [self hotFolderAdded:d[@"oldHotFolderPath"] changedFile:changedPath];
                    if (processedFile) {
                        [_arOldFiles addObject:processedFile];
                        [self processIfRegisteredFileBefore];
                    }
                }
                else if (isRemove) {
                    NSString *foundPath = nil;
                    for (NSString* file in _arOldFiles) {
                        if (EQ_STR([file lastPathComponent], [changedPath lastPathComponent])) {
                            foundPath = file;
                            break;
                        }
                    }
                    if (foundPath) {
                        [_arOldFiles removeObject:foundPath];
                    }
                }
            }];
            
            _aHot = [[KZDirectoryObserver alloc] initWithDirectoryPath:d[@"newHotFolderPath"] latency:1 callback:^(NSString * _Nonnull changedPath, BOOL isRemove) {
                if (!isRemove && ![KZLibs isDirectory:changedPath]) {
                    NSString *processedFile = [self hotFolderAdded:d[@"newHotFolderPath"] changedFile:changedPath];
                    if (processedFile) {
                        [_arNewFiles addObject:processedFile];
                        [self processIfRegisteredFileBefore];
                    }
                }
                else if (isRemove) {
                    NSString *foundPath = nil;
                    for (NSString* file in _arNewFiles) {
                        if (EQ_STR([file lastPathComponent], [changedPath lastPathComponent])) {
                            foundPath = file;
                            break;
                        }
                    }
                    if (foundPath) {
                        [_arNewFiles removeObject:foundPath];
                    }
                }
            }];
            
            _workQueue = [[NSOperationQueue alloc] init];
            _workQueue.maxConcurrentOperationCount = [d[@"maxThread"] integerValue];
            _diffImg = [[DiffImgCV alloc] init];
            _diffImg.delegate = self;
            [_diffImg registerSetting:[KZSetting convertToJSON]];
            
        }
        else {
            d[@"oldHotFolderPath"] = @"";
            d[@"newHotFolderPath"] = @"";
            if (NEQ_STR(KZSetting.sharedSetting.latestPreset, @"Default"))
                [KZSetting saveToFile];
        }
        
    }
}

#pragma mark -
#pragma mark Public Funcs
+ (instancetype)sharedHotFolder
{
    static KZHotFolderController *_sharedFolder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedFolder = [[KZHotFolderController alloc] init];
    });
    return _sharedFolder;
}

- (void)startHotFolder
{
    if (_bHot && _aHot) {
        if (_isRunning == [NSNumber numberWithBool:NO]) {
            [_bHot startObserving];
            [_aHot startObserving];
            _isRunning = @YES;
            [NSNotificationCenter.defaultCenter postNotificationName:@"NotifyChangeHotFolderState" object:_isRunning];
        }
    }
    else {
        [self initHotFolder];
    }
}
- (void)stopHotFolder
{
    if (_bHot && _aHot) {
        if (_isRunning == [NSNumber numberWithBool:YES]) {
            [_bHot stopObserving];
            [_aHot stopObserving];
            _isRunning = @NO;
            [NSNotificationCenter.defaultCenter postNotificationName:@"NotifyChangeHotFolderState" object:_isRunning];
        }
    }
    else {
        [self initHotFolder];
    }
}

#pragma mark -
#pragma mark Local Funcs

- (NSString*)hotFolderAdded:(NSString*)hotPath changedFile:(NSString*)changedPath
{
    NSString *movedPath = @"";
    NSError *error = nil;
    NSString *curFolder = [hotPath stringByAppendingPathComponent:PROCESS_FOLDER];
    [NSFileManager.defaultManager createDirectoryAtPath:curFolder withIntermediateDirectories:YES attributes:nil error:nil];
    movedPath = [curFolder stringByAppendingPathComponent:[changedPath lastPathComponent]];
    if ([NSFileManager.defaultManager fileExistsAtPath:movedPath]) {
        [NSFileManager.defaultManager removeItemAtPath:movedPath error:nil];
    }
    [NSFileManager.defaultManager moveItemAtPath:changedPath toPath:movedPath error:&error];
    if (!error)
        return movedPath;
    else {
        NSLog(@"%@", error.localizedDescription);
        return nil;
    }
}

- (void)processIfRegisteredFileBefore
{
    BOOL ret = NO;
    NSString *before = nil;
    NSString *after = nil;
    
    NSArray *arNew = [_arNewFiles allObjects];
    NSArray *arOld = [_arOldFiles allObjects];
    for (NSString* nfile in arNew) {
        for (NSString* ofile in arOld) {
            NSString *oldName = [KZLibs getFileName:ofile];
            NSString *newName = [KZLibs getFileName:nfile];
            NSString *longerName = (oldName.length > newName.length)? oldName : newName;
            NSString *shorterName = (oldName.length > newName.length)? newName : oldName;
            
            if (EQ_STR(newName, oldName)) {
                before = ofile;
                after = nfile;
                ret = YES;
                break;
            }
            else {
                if([longerName containsString:shorterName]) {
                    before = ofile;
                    after = nfile;
                    ret = YES;
                    break;
                }
            }
            
        }
        if (ret) {
            break;
        }
    }
    
    if (ret) {
        [self startDiffBefore:before After:after];
    }
}

#pragma mark -
#pragma mark Diff
- (void)startDiffBefore:(NSString*)before After:(NSString*)after
{
    [_arOldFiles removeObject:before];
    [_arNewFiles removeObject:after];
    
    NSString *saveFile = [KZLibs getFileName:[after lastPathComponent]];
    if([KZSetting.sharedSetting.settingVal[@"saveType"] intValue] == (int)KZFileFormat::PSD_FORMAT) {
        saveFile = [saveFile stringByAppendingString:@".psd"];
    }
    else if([KZSetting.sharedSetting.settingVal[@"saveType"] intValue] == (int)KZFileFormat::PNG_FORMAT) {
        saveFile = [saveFile stringByAppendingString:@".png"];
    }
    else if([KZSetting.sharedSetting.settingVal[@"saveType"] intValue] == (int)KZFileFormat::GIF_FORMAT) {
        saveFile = [saveFile stringByAppendingString:@".gif"];
    }
    
    if (!KZSetting.sharedSetting.settingVal[@"hotFolderSavePath"] && EQ_STR(KZSetting.sharedSetting.settingVal[@"hotFolderSavePath"], @"")) {
        saveFile = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:saveFile];
    }
    else {
        saveFile = [KZSetting.sharedSetting.settingVal[@"hotFolderSavePath"] stringByAppendingPathComponent:saveFile];
    }
    NSError *error = nil;
    NSString *rngPageOLD = @"1-1";
    NSString *rngPageNEW = @"1-1";
    NSUInteger page_old = 0, page_new = 0;
    if ([[before lastPathComponent] hasSuffix:@"pdf"]) {
        page_old = [KZLibs getPDFPageCount:before];
        if (page_old != 1) {
            rngPageOLD = [NSString stringWithFormat:@"1-%ld",page_old];
        }
    }
    if ([[after lastPathComponent] hasSuffix:@"pdf"]) {
        page_new = [KZLibs getPDFPageCount:after];
        if (page_new != 1) {
            rngPageNEW = [NSString stringWithFormat:@"1-%ld",page_new];
        }
    }
    
    NSString *ngOldFolder = [KZSetting.sharedSetting.settingVal[@"oldHotFolderPath"] stringByAppendingPathComponent:PROCESS_NG_FOLDER];
    NSString *ngNewFolder = [KZSetting.sharedSetting.settingVal[@"newHotFolderPath"] stringByAppendingPathComponent:PROCESS_NG_FOLDER];
    NSString *ngBFile = [[KZLibs getCurDir:before] stringByAppendingPathComponent:[before lastPathComponent]];
    NSString *ngAFile = [[KZLibs getCurDir:after] stringByAppendingPathComponent:[after lastPathComponent]];
    if (page_old != page_new) {
        [NSFileManager.defaultManager createDirectoryAtPath:ngOldFolder withIntermediateDirectories:YES attributes:nil error:nil];
        [NSFileManager.defaultManager createDirectoryAtPath:ngNewFolder withIntermediateDirectories:YES attributes:nil error:nil];
        [NSFileManager.defaultManager moveItemAtPath:before toPath:ngBFile error:&error];
        if (error) {
            Log(error.description);
        }
        [NSFileManager.defaultManager moveItemAtPath:after toPath:ngAFile error:&error];
        if (error) {
            Log(error.description);
        }
    }
    else if (KZSetting.sharedSetting.settingVal[@"hotFolderSavePath"] && NEQ_STR(KZSetting.sharedSetting.settingVal[@"hotFolderSavePath"], @"")) {
        NSMutableDictionary *param = [@{@"OldPath":before,
                                        @"NewPath":after
                                        } mutableCopy];
        [_workQueue addOperation:
            [_diffImg diffStart:before
                         target:after
                           save:KZSetting.sharedSetting.settingVal[@"hotFolderSavePath"]
                         object:param
                   pageRangeOLD:rngPageOLD
                   pageRangeNEW:rngPageNEW]
        ];
    }
    else {
        [NSFileManager.defaultManager createDirectoryAtPath:ngOldFolder withIntermediateDirectories:YES attributes:nil error:nil];
        [NSFileManager.defaultManager createDirectoryAtPath:ngNewFolder withIntermediateDirectories:YES attributes:nil error:nil];
        [NSFileManager.defaultManager moveItemAtPath:before toPath:ngBFile error:&error];
        if (error) {
            Log(error.description);
        }
        [NSFileManager.defaultManager moveItemAtPath:after toPath:ngAFile error:&error];
        if (error) {
            Log(error.description);
        }
    }
}

- (void)maxDiffAreas:(int)count object:(id)object { 

}

- (void)notifyProcess:(id)object { 

}

- (void)skipProcess:(id)object errMessage:(NSString*)msg
{
    
}

- (void)logProcess:(NSString*)msg
{
    
}

- (void)cancelProcess:(id)object message:(NSString*)msg
{
    
}

- (void)tooManyDiff:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage
{
    
}

- (void)startConvert:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage
{
    
}

- (void)endConvert:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage
{
    
}

- (void)startInspect:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage
{
    
}

- (void)endInspect:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage
{
    
}

- (void)completeSaveFile:(id)object
{
    NSMutableDictionary *nObj = object;
    if (!nObj) return;
    
    BOOL isRemove = [KZSetting.sharedSetting.settingVal[@"isTrashCompleteItem"] boolValue];
    
    if (isRemove) {
        NSString *bPath = nObj[@"OldPath"];
        NSString *aPath = nObj[@"NewPath"];
        
        [NSFileManager.defaultManager trashItemAtURL:[NSURL fileURLWithPath:bPath] resultingItemURL:nil error:nil];
        [NSFileManager.defaultManager trashItemAtURL:[NSURL fileURLWithPath:aPath] resultingItemURL:nil error:nil];
    }
}
@end
