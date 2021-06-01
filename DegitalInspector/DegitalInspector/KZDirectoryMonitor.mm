//
//  KZDirectoryMonitor.m
//  DegitalInspector
//
//  Created by uchiyama_Macmini on 2019/07/17.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//
#import "KZFilePresenter.h"
#import "KZDirectoryMonitor.h"


#define kZPoll_Interval 0.2
#define kZPoll_Retry 5

typedef void (^KZDirectoryMonitorBlock)(NSString *changedPath, BOOL isRemove);

@interface KZDirectoryMonitor ()
@property (nonatomic) dispatch_source_t source;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic, retain) NSMutableArray *previousFiles;
@property (nonatomic, retain) NSMutableArray *arWatcher;
@property (nonatomic, copy) KZDirectoryMonitorBlock callback;
@end

@implementation KZDirectoryMonitor

- (instancetype)initWithPath:(NSString *)path
{
    self = [super init];
    if (self) {
        _monitorPath = [path copy];
        _queue = dispatch_queue_create("KZDirectoryMonitorQueue", 0);
        _previousFiles = [NSMutableArray array];
        _arWatcher = [NSMutableArray array];
    }
    return self;
}

+ (KZDirectoryMonitor *)folderMonitorAtPath:(NSString *)path startImmediately:(BOOL)startImmediately callback:(KZDirectoryMonitorBlock)cb
{
    NSAssert(path != nil, @"The directory to watch must not be nil");
    
    KZDirectoryMonitor *monitor = [[KZDirectoryMonitor alloc] initWithPath:path];
    monitor.callback = cb;
    
    if (NEQ_STR(monitor.monitorPath, @"")) {
        monitor.previousFiles = [[KZLibs getFileList:monitor.monitorPath deep:NO onlyDir:NO onlyFile:NO isAllFullPath:YES] mutableCopy];
        if (startImmediately) {
            if (![monitor startMonitoring]) {
                return nil;
            }
        }
    }
    
    
    
    return monitor;
}

+ (KZDirectoryMonitor *)folderMonitorAtPath:(NSString *)path callback:(KZDirectoryMonitorBlock)cb
{
    return [KZDirectoryMonitor folderMonitorAtPath:path startImmediately:YES callback:cb];
}

#pragma mark -
#pragma mark - Public methods

- (BOOL)startMonitoring
{
    // Already monitoring
    if (_source != nil) {
        return NO;
    }
    
    // Open an event-only file descriptor associated with the directory
    int fd = open([_monitorPath fileSystemRepresentation], O_EVTONLY);
    if (fd < 0) {
        return NO;
    }
    
    void (^cleanup)(void) = ^{
        close(fd);
    };
    
    // Get a low priority queue
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    
    // Monitor the directory for writes
    _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, // Monitors a file descriptor
                                     fd, // our file descriptor
                                     DISPATCH_VNODE_WRITE, // The file-system object data changed.
                                     queue); // the queue to dispatch on
    
    if (!_source) {
        cleanup();
        return NO;
    }
    
    __weak __typeof__(self) _weakSelf = self;
    // Call directoryDidChange on event callback
    dispatch_source_set_event_handler(_source, ^{
        [_weakSelf directoryDidChange];
    });
    
    // Dispatch source destructor
    dispatch_source_set_cancel_handler(_source, cleanup);
    
    // Sources are create in suspended state, so resume it
    dispatch_resume(_source);
    
    // Everything was OK
    return YES;
}

- (BOOL)stopMonitoring
{
    if (_source != nil) {
        dispatch_source_cancel(_source);
        _source = NULL;
        return YES;
    }
    return NO;
}

#pragma mark -
#pragma mark - Private methods

- (NSArray *)diffFiles:(BOOL*)isRemove
{
    NSArray *tmpCur = [NSArray array];
    NSArray *dfFiles = [NSArray array];
    NSMutableArray *currentFiles = [[KZLibs getFileList:_monitorPath deep:NO onlyDir:NO onlyFile:NO isAllFullPath:YES] mutableCopy];
    tmpCur = [currentFiles copy];
    
    if ([currentFiles isEqualToArray:_previousFiles]) {
        return nil;
    }
    else {
        // 以前の内容との差分を返す
        if (currentFiles.count < _previousFiles.count) {
            *isRemove = YES;
            for (NSString *cur in currentFiles) {
                [_previousFiles removeObject:cur];
            }
            dfFiles = [_previousFiles copy];
        }
        else {
            *isRemove = NO;
            for (NSString *pre in _previousFiles) {
                [currentFiles removeObject:pre];
            }
            dfFiles = [currentFiles copy];
        }

        return dfFiles;
    }
}

- (bool)isReadable:(NSString*)path
{
    int fdes = open([path fileSystemRepresentation], O_NONBLOCK | O_SHLOCK);
    if (fdes == -1) {
        return false;
    }
    else {
        close(fdes);
        return true;
    }
}



- (void)checkChangesAfterDelay:(NSTimeInterval)timeInterval
{
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, timeInterval * NSEC_PER_SEC);
    dispatch_after(popTime, _queue, ^(void){
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        NSArray *contents = [fileManager contentsOfDirectoryAtPath:_monitorPath
                                                             error:nil];
        
        for (NSString *fileName in contents) {
            if (NEQ_STR(fileName, @".DS_Store") ) {
                NSString *filePath = [_monitorPath stringByAppendingPathComponent:fileName];
                
                
                _callback(filePath, NO);
                
                /*KZFilePresenter *presenter = [[KZFilePresenter alloc] initWithURL:[NSURL fileURLWithPath:filePath]];
                NSFileCoordinator *corrd = [[NSFileCoordinator alloc] initWithFilePresenter:presenter];*/
                //__block BOOL isReadable = NO;
                //while (!isReadable) {
                    /*
                    [corrd coordinateWritingItemAtURL:[NSURL fileURLWithPath:filePath]
                                              options:NSFileCoordinatorWritingForDeleting | NSFileCoordinatorWritingForMoving | NSFileCoordinatorWritingForMerging | NSFileCoordinatorWritingForReplacing
                                                error:nil byAccessor:^(NSURL *newURL) {
                                                        isReadable = YES;
                                                        _callback([newURL.path lastPathComponent], NO);
                                                }];
                     */
                //}
            }
        }
        
        /*dispatch_async(dispatch_get_main_queue(), ^{
            BOOL isRemove = NO;
            NSArray *ardf = [self diffFiles:&isRemove];
            _callback(ardf, isRemove);
            _previousFiles = [[KZLibs getFileList:_monitorPath deep:NO onlyDir:NO onlyFile:NO isAllFullPath:YES] mutableCopy];
        });*/
        
    });
}

+ (NSOperationQueue *)opqueue {
    static NSOperationQueue *queue;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
    });
    
    return queue;
}

- (void)directoryDidChange
{
    BOOL isRemove;
    NSArray* ardf = [self diffFiles:&isRemove];
    _previousFiles = [[KZLibs getFileList:_monitorPath deep:NO onlyDir:NO onlyFile:NO isAllFullPath:YES] mutableCopy];
    if (!isRemove) {
        for(NSString* p in ardf) {
            NSURL *fileURL = [NSURL fileURLWithPath:p];
            KZFilePresenter *presenter = [[KZFilePresenter alloc] initWithURL:fileURL];
            NSFileCoordinator *coord = [[NSFileCoordinator alloc] initWithFilePresenter:presenter];
            [coord coordinateReadingItemAtURL:fileURL options:0 error:nil byAccessor:^(NSURL *newURL) {
                NSFileManager *fileManager = [[NSFileManager alloc] init];
                NSString *movePath = [[_monitorPath stringByAppendingPathComponent:@"Processing"] stringByAppendingPathComponent:[newURL.path lastPathComponent]];
                [fileManager moveItemAtURL:newURL toURL:[NSURL fileURLWithPath:movePath] error:nil];
                _callback(newURL.path, isRemove);
            }];
            
            /*
            __block NSURL *fileURL = [NSURL fileURLWithPath:p];
            BOOL isFileURLSecurityScoped;
            if([fileURL startAccessingSecurityScopedResource]) {
                isFileURLSecurityScoped = YES;
            }
            NSFileCoordinator *coo = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            NSFileAccessIntent *readingIntent = [NSFileAccessIntent readingIntentWithURL:fileURL options:NSFileCoordinatorReadingWithoutChanges];

            [coo coordinateAccessWithIntents:@[readingIntent] queue:[KZDirectoryMonitor opqueue] byAccessor:^(NSError *error) {
                if (!error) {
                    NSURL *safeURL = readingIntent.URL;
                    NSFileManager *fileManager = [[NSFileManager alloc] init];
                    NSString *movePath = [[_monitorPath stringByAppendingPathComponent:@"Processing"] stringByAppendingPathComponent:[safeURL.path lastPathComponent]];
                    [fileManager moveItemAtURL:safeURL toURL:[NSURL fileURLWithPath:movePath] error:&error];
                    _callback(safeURL.path, isRemove);
                }
                [fileURL stopAccessingSecurityScopedResource];
            }];*/
        }
    }
}


@end
