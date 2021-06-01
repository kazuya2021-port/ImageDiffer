//
//  KZDiffView.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/09.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZDiffView.h"
#import "KZKeyHookTable.h"
#import "KZArrayController.h"
#import "KZManualSaveView.h"
#import "KZOptionSaveView.h"
#import "NSOperationQueue+SharedQueue.h"
#import "KZCellView.h"
#import <DiffImgCV/DiffImgCV.h>

@interface KZDiffView ()<NSTableViewDataSource, NSTableViewDelegate, KZKeyHookTableDelegate, DiffImgCVDelegate>
{
    id beforeObserver;
    id afterObserver;
    NSArray *arKeys;
    NSString *defaultSavePath;
    BOOL isCompaering;
}

@property (nonatomic, weak) IBOutlet KZArrayController *beforeController;
@property (nonatomic, weak) IBOutlet KZArrayController *afterController;
@property (nonatomic, weak) IBOutlet KZKeyHookTable *beforeTable;
@property (nonatomic, weak) IBOutlet KZKeyHookTable *afterTable;
@property (nonatomic, weak) IBOutlet NSButton *startBtn;
@property (nonatomic, weak) IBOutlet NSButton *stopBtn;
@property (nonatomic, weak) IBOutlet NSButton *clearBtn;
@property (nonatomic, weak) IBOutlet NSButton *deleteBtn;
@property (nonatomic, strong) NSMutableArray *beforeDataSource;
@property (nonatomic, strong) NSMutableArray *afterDataSource;
@property (nonatomic, strong) NSOperationQueue *workQueue;
@property (nonatomic, weak) IBOutlet KZManualSaveView *manualView;
@property (nonatomic, weak) IBOutlet KZOptionSaveView *optionView;

- (void)registerObserver;
- (void)changeArrayControllerAtIndex:(NSUInteger)index value:(id)value key:(NSString*)key;
- (void)onChangeSaveFolder:(id)obj keyPath:(NSString*)keyPath change:(NSDictionary*)change;
- (void)onChangeSaveFolderName:(id)obj keyPath:(NSString*)keyPath change:(NSDictionary*)change;
- (void)onChangePresetName:(id)obj keyPath:(NSString*)keyPath change:(NSDictionary*)change;

- (IBAction)stopDiff:(id)sender;
- (IBAction)go:(id)sender;
- (IBAction)clearTable:(id)sender;
- (IBAction)deleteRow:(id)sender;
@end

@implementation KZDiffView

static NSString * NSTableRowType = @"table.row";


#pragma mark -
#pragma mark Init/Dealloc/Finalize

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        defaultSavePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        arKeys = @[@"time", @"pageRange", @"nPage", @"path", @"fileName", @"icon", @"fileSize", @"progress", @"status", @"maxprogress"];
        
        _beforeDataSource = [NSMutableArray array];
        _afterDataSource = [NSMutableArray array];
        isCompaering = NO;
    }
    return self;
}

- (void)awakeFromNib
{
}

- (void)loadView
{
    [super loadView];
    
    NSNib *cell = [[NSNib alloc] initWithNibNamed:@"KZViewCell" bundle:nil];
    NSSortDescriptor *descripter = [[NSSortDescriptor alloc] initWithKey:@"fileName" ascending:YES selector:@selector(compare:)];
    [_beforeTable setDelegate:self];
    [_beforeTable setDataSource:self];
    [_beforeTable setTarget:self];
    [_beforeTable registerForDraggedTypes:@[NSFilenamesPboardType, NSTableRowType]];
    [_beforeTable setDelegateKey:self];
    [_beforeTable registerNib:cell forIdentifier:@"KZViewCell"];
    [_beforeTable setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [_beforeTable setSortDescriptors:@[descripter]];
    _beforeTable.rowSizeStyle = NSTableViewRowSizeStyleCustom;
    _beforeTable.rowHeight = 50.0;
    
    [_afterTable setDelegate:self];
    [_afterTable setDataSource:self];
    [_afterTable setTarget:self];
    [_afterTable registerForDraggedTypes:@[NSFilenamesPboardType, NSTableRowType]];
    [_afterTable setDelegateKey:self];
    [_afterTable registerNib:cell forIdentifier:@"KZViewCell"];
    [_afterTable setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [_afterTable setSortDescriptors:@[descripter]];
    _afterTable.rowSizeStyle = NSTableViewRowSizeStyleCustom;
    _afterTable.rowHeight = 50.0;
    
    [_beforeController bind:NSContentArrayBinding toObject:self withKeyPath:@"self.beforeDataSource" options:nil];
    [_afterController bind:NSContentArrayBinding toObject:self withKeyPath:@"self.afterDataSource" options:nil];
    _beforeController.keys = arKeys;
    _afterController.keys = arKeys;
    
    NSDictionary *tblSetting = KZSetting.sharedSetting.settingVal;
    
    _workQueue = [[NSOperationQueue alloc] init];
    _workQueue.maxConcurrentOperationCount = [tblSetting[@"maxThread"] integerValue];
    
    KZFolderNameSource.sharedFolderNameSource.values = [tblSetting[@"folderNames"] mutableCopy];
    _optionView.folderSelect.dataSource = KZFolderNameSource.sharedFolderNameSource;
    _optionView.folderSelect.stringValue = tblSetting[@"makeFolderName"];
    
    if (EQ_STR(tblSetting[@"makeFolderPlace"], NSLocalizedStringFromTable(@"SaveFilePlaceSelect", @"Preference", nil))) {
        [_manualView appearView];
        [_optionView hideView];
    }
    else {
        [_manualView hideView];
        [_optionView appearView];
    }
    
    [self registerObserver];
    
    _diffImg = [[DiffImgCV alloc] init];
    _diffImg.delegate = self;
}
#pragma mark -
#pragma mark Action
- (IBAction)stopDiff:(id)sender
{
    for(NSOperation *op in  _workQueue.operations)
    {
        [op cancel];
    }
    _stopBtn.enabled = NO;
    isCompaering = NO;
}

- (IBAction)go:(id)sender
{
    _startBtn.enabled = NO;
    _stopBtn.enabled = YES;
    isCompaering = YES;
    
    [_diffImg registerSetting:[KZSetting convertToJSON]];
    
    _workQueue.maxConcurrentOperationCount = [KZSetting.sharedSetting.settingVal[@"maxThread"] integerValue];
    
    NSAlert *al = [[NSAlert alloc] init];
    NSUInteger bCount = [_beforeController.arrangedObjects count];
    NSUInteger aCount = [_afterController.arrangedObjects count];
    
    if (aCount != bCount) {
        al.messageText = NSLocalizedStringFromTable(@"NotMatchDiffFileCount", @"ErrorText", nil);
        [al beginSheetModalForWindow:[KZLibs getMainWindow] completionHandler:^(NSModalResponse returnCode) {
            _startBtn.enabled = YES;
            _stopBtn.enabled = NO;
        }];
        return;
    }
    
    NSMutableArray *arOpsInspec = [NSMutableArray array];
    //dispatch_queue_t main = dispatch_get_main_queue();
    //dispatch_queue_t sub = dispatch_queue_create("com.asahi.kazuya.diff", DISPATCH_QUEUE_CONCURRENT);
    
    for (NSUInteger i = 0; i < bCount; i++) {
        
        KZCellView *oldRow = [_beforeTable viewAtColumn:0 row:i makeIfNecessary:YES];
        KZCellView *newRow = [_afterTable viewAtColumn:0 row:i makeIfNecessary:YES];
        
        NSString *oldPath = [oldRow.pathInfo stringValue];
        NSString *newPath = [newRow.pathInfo stringValue];
        NSString *rngOld = [oldRow.pageRange stringValue];
        NSString *rngNew = [newRow.pageRange stringValue];
        
        NSString *savePath = [self makeSavePath:oldPath newFilePath:newPath];
        
        NSMutableDictionary *param = [@{@"Index":[NSNumber numberWithUnsignedInteger:i],
                                        @"OldPath":oldPath
                                        } mutableCopy];

        NSOperation *inspectOp = [_diffImg diffStart:oldPath
                                              target:newPath
                                                save:savePath
                                              object:param
                                        pageRangeOLD:rngOld
                                        pageRangeNEW:rngNew];
        
        [arOpsInspec addObject:inspectOp];
    }

    [_workQueue addOperations:arOpsInspec waitUntilFinished:NO];
}

- (IBAction)clearTable:(id)sender
{
    [_beforeController removeObjects:_beforeController.arrangedObjects];
    [_afterController removeObjects:_afterController.arrangedObjects];
    _startBtn.enabled = NO;
    _stopBtn.enabled = NO;
}

- (IBAction)deleteRow:(id)sender
{
    NSIndexSet *bidxs = _beforeTable.selectedRowIndexes;
    NSIndexSet *aidxs = _afterTable.selectedRowIndexes;
    [_beforeController removeObjectsAtArrangedObjectIndexes:bidxs];
    [_afterController removeObjectsAtArrangedObjectIndexes:aidxs];
    [self setStartBtnState];
}



#pragma mark -
#pragma mark Local Funcs
- (NSTextView*)getLogView
{
    NSScrollView *scview;
    NSClipView *cView;
    
    for (id vw in _logContentView.subviews) {
        if (EQ_STR(NSStringFromClass([vw class]), @"NSScrollView")) {
            scview = vw;
            break;
        }
    }
    if (!scview) return nil;
    for (id vw in scview.subviews) {
        if (EQ_STR(NSStringFromClass([vw class]), @"NSClipView")) {
            cView = vw;
            break;
        }
    }
    if (!cView) return nil;
    
    NSDate *n = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"MM/dd HH:mm";
    NSString *date24 = [dateFormatter stringFromDate:n];
    
    NSTextView *tv = cView.documentView;
    tv.font = [NSFont fontWithName:@"Osaka-Mono" size:12];
    NSMutableString *str = [tv.string mutableCopy];
    [str appendFormat:@"%@ ",date24];
    tv.string = [str copy];
    //[scview scrollToEndOfDocument:self];
    return tv;
}

- (void)registerObserver
{
    NSClipView *cVBef = (NSClipView*)_beforeTable.superview;
    NSClipView *cVAft = (NSClipView*)_afterTable.superview;
    
    cVBef.postsBoundsChangedNotifications = YES;
    cVAft.postsBoundsChangedNotifications = YES;
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    beforeObserver = [center addObserverForName:NSViewBoundsDidChangeNotification
                                         object:cVBef
                                          queue:[NSOperationQueue mainQueue]
                                     usingBlock:^(NSNotification *note) {
                                         if([_afterController.arrangedObjects count])
                                         {
                                             [cVAft setBoundsOrigin:cVBef.visibleRect.origin];
                                             [cVAft setNeedsDisplay:YES];
                                         }
                                     }];
    
    afterObserver = [center addObserverForName:NSViewBoundsDidChangeNotification
                                         object:cVAft
                                          queue:[NSOperationQueue mainQueue]
                                     usingBlock:^(NSNotification *note) {
                                         if([_beforeController.arrangedObjects count])
                                         {
                                             [cVBef setBoundsOrigin:cVAft.visibleRect.origin];
                                             [cVBef setNeedsDisplay:YES];
                                         }
                                     }];
    
    [KZSetting.sharedSetting addObserver:self
                              forKeyPath:@"settingVal.makeFolderPlace"
                                 options:NSKeyValueObservingOptionNew
                                 context:@selector(onChangeSaveFolder:keyPath:change:)];
    [KZSetting.sharedSetting addObserver:self
                              forKeyPath:@"settingVal.folderNames"
                                 options:NSKeyValueObservingOptionNew
                                 context:@selector(onChangeSaveFolderName:keyPath:change:)];
    [KZSetting.sharedSetting addObserver:self
                              forKeyPath:@"latestPreset"
                                 options:NSKeyValueObservingOptionNew
                                 context:@selector(onChangePresetName:keyPath:change:)];
    
    
    [_workQueue addObserver:self
                 forKeyPath:@"operations"
                    options:NSKeyValueObservingOptionNew
                    context:@selector(onChangeOperationCount:keyPath:change:)];
}

- (NSUInteger)getIndexFromOldPath:(NSString*)oldPath
{
    NSUInteger retIdx = 0;
    for (NSUInteger i = 0; i < [_beforeController.arrangedObjects count]; i++) {
        BOOL isFoundIndex = NO;
        NSMutableDictionary *d = _beforeController.arrangedObjects[i];
        for (NSString *key in [d allKeys]) {
            if (EQ_STR(oldPath, d[@"path"])) {
                isFoundIndex = YES;
                break;
            }
        }
        if (isFoundIndex) {
            retIdx = i;
            break;
        }
    }
    
    return retIdx;
}

- (void)changeArrayControllerAtIndex:(NSUInteger)index value:(id)value key:(NSString*)key
{
    NSMutableDictionary *muB = [_beforeController.arrangedObjects objectAtIndex:index];
    NSMutableDictionary *muA = [_afterController.arrangedObjects objectAtIndex:index];
    
    BOOL isChangeA = NO;
    BOOL isChangeB = NO;
    if ([muB.allKeys containsObject:key]) {
        [muB setValue:value forKey:key];
        isChangeB = YES;
    }
    
    if ([muA.allKeys containsObject:key]) {
        [muA setValue:value forKey:key];
        isChangeA = YES;
    }
    
    if (isChangeB)
        [_beforeController rearrangeObjects];
    
    if (isChangeA)
        [_afterController rearrangeObjects];
}

- (NSMutableDictionary*)getFileInfo:(NSString*)path
{
    NSString *file = [KZLibs getFileName:path];
    NSString *ext = [KZLibs getFileExt:path];
    NSString *orgExt = [path pathExtension];
    
    ext = [ext lowercaseStringWithLocale:[NSLocale currentLocale]];
    orgExt = [orgExt lowercaseStringWithLocale:[NSLocale currentLocale]];
    
    if([KZLibs isEqual:orgExt compare:@""] || !orgExt)
    {
        file = [file stringByAppendingPathExtension:ext];
    }
    else
    {
        file = [file stringByReplacingOccurrencesOfString:orgExt withString:ext];
    }
    
    NSUInteger allPageCount = 1;
    NSString *pageRange = @"1";
    
    if([KZLibs isEqual:ext compare:@"pdf"])
    {
        allPageCount = [KZLibs getPDFPageCount:path];
    }
    else if ([KZLibs isEqual:ext compare:@"tif"] || [KZLibs isEqual:ext compare:@"tiff"])
    {
        allPageCount = [KZLibs getTIFFPageCount:path];
    }
    pageRange = [NSString stringWithFormat:@"1-%lu",allPageCount];
    
    NSString *fileSize = [KZLibs getFileSize:path];
    
    return [
            @{@"time" : [KZLibs getFileModificateDate:path],
              @"pageRange" : pageRange,
              @"nPage" : [NSString stringWithFormat:@"%lu",allPageCount],
              @"path" : path,
              @"fileName" : file,
              @"icon" : [KZLibs getIcon:path isFileTypeIcon:YES],
              @"fileSize" : fileSize,
              @"progress" : @0.0,
              @"status" : @"",
              @"maxprogress" : @0.0} mutableCopy];
}

- (BOOL)isContainsFile:(NSString*)path arrayController:(KZArrayController*)arCon
{
    NSMutableSet *set = [[NSMutableSet alloc] init];
    const NSUInteger count = [arCon.arrangedObjects count];
    BOOL isDup = NO;
    for(NSUInteger i = 0; i < count; i++)
    {
        NSDictionary *tbl = arCon.arrangedObjects[i];
        
        if([set containsObject:path])
        {
            isDup = YES;
            break;
        }
        else
        {
            [set addObject:tbl[@"path"]];
        }
    }
    if([set containsObject:path])
    {
        isDup = YES;
    }
    return isDup;
}

- (NSString*)makeSavePath:(NSString*)oldFilePath newFilePath:(NSString*)newFilePath
{
    NSDictionary *tblSetting = KZSetting.sharedSetting.settingVal;
    NSString *savePath;
    NSString *folName;
    NSString *strNow;
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setLocale:[NSLocale currentLocale]];
    [df setDateFormat:@"yyyy_MMdd_HHmm"];
    NSDate *now = [NSDate date];
    strNow = [df stringFromDate:now];
    
    NSString *makeFolder = tblSetting[@"makeFolderName"];
    NSString *makePlace = tblSetting[@"makeFolderPlace"];
    BOOL isEmptyFolderName = !makeFolder || [KZLibs isEqual:makeFolder compare:@""];
    BOOL isEmptyFolderPlace = !makePlace || [KZLibs isEqual:makePlace compare:@""];
    if(isEmptyFolderName && isEmptyFolderPlace)
    {
        savePath = defaultSavePath;
        folName = [strNow stringByAppendingString:NSLocalizedStringFromTable(@"HikakuBaseName", @"Localizable", nil)];
        savePath = [savePath stringByAppendingPathComponent:folName];
    }
    else
    {
        if(isEmptyFolderName)
        {
            folName = [strNow stringByAppendingString:NSLocalizedStringFromTable(@"HikakuBaseName", @"Localizable", nil)];
        }
        else
        {
            folName = makeFolder;
        }
        
        if(isEmptyFolderPlace)
        {
            savePath = defaultSavePath;
            savePath = [savePath stringByAppendingPathComponent:folName];
        }
        else
        {
            if([KZLibs isEqual:makePlace compare:NSLocalizedStringFromTable(@"SaveFilePlaceOLD", @"Preference", nil)])
            {
                if([KZLibs isEqual:oldFilePath compare:@""])
                {
                    savePath = defaultSavePath;
                    if(![KZLibs isEqual:folName compare:@"None"])
                    {
                        savePath = [savePath stringByAppendingPathComponent:folName];
                    }
                }
                else
                {
                    oldFilePath = [oldFilePath stringByDeletingLastPathComponent];
                    if(![KZLibs isEqual:folName compare:@"None"])
                    {
                        savePath = [oldFilePath stringByAppendingPathComponent:folName];
                    }
                    else
                    {
                        savePath = oldFilePath;
                    }
                }
            }
            else if([KZLibs isEqual:makePlace compare:NSLocalizedStringFromTable(@"SaveFilePlaceNEW", @"Preference", nil)])
            {
                if([KZLibs isEqual:newFilePath compare:@""])
                {
                    savePath = defaultSavePath;
                    if(![KZLibs isEqual:folName compare:@"None"])
                    {
                        savePath = [savePath stringByAppendingPathComponent:folName];
                    }
                }
                else
                {
                    newFilePath = [newFilePath stringByDeletingLastPathComponent];
                    if(![KZLibs isEqual:folName compare:@"None"])
                    {
                        savePath = [newFilePath stringByAppendingPathComponent:folName];
                    }
                    else
                    {
                        savePath = newFilePath;
                    }
                }
            }
            if (EQ_STR(makePlace, NSLocalizedStringFromTable(@"SaveFilePlaceSelect", @"Preference", nil))) {
                if ([KZLibs isEqual:_manualView.saveFolderField.stringValue compare:@""]) {
                    savePath = defaultSavePath;
                    if (![KZLibs isEqual:folName compare:@"None"]) {
                        savePath = [savePath stringByAppendingPathComponent:folName];
                    }
                }
                else {
                    if (![KZLibs isEqual:folName compare:@"None"]) {
                        savePath = [_manualView.saveFolderField.stringValue stringByAppendingPathComponent:folName];
                    }
                    else {
                        savePath = _manualView.saveFolderField.stringValue;
                    }
                }
            }
        }
    }
    return savePath;
}

- (void)setStartBtnState
{
    NSUInteger bCount = [_beforeController.arrangedObjects count];
    NSUInteger aCount = [_afterController.arrangedObjects count];
    if (bCount == 0 || aCount == 0) {
        _startBtn.enabled = NO;
        _stopBtn.enabled = NO;
    }
    else if (aCount > 0 && bCount > 0) {
        if (bCount == aCount) {
            _startBtn.enabled = YES;
            _stopBtn.enabled = NO;
        }
        else {
            _startBtn.enabled = NO;
            _stopBtn.enabled = NO;
        }
    }
    else {
        _startBtn.enabled = NO;
        _stopBtn.enabled = YES;
    }
}

- (void)appendTableFromDelegate:(id)object setInfo:(NSDictionary*)info
{
    NSMutableDictionary *nObj = object;
    if (!nObj) return;

    dispatch_sync(
                  dispatch_get_main_queue(), ^{
                      NSString *oldPath = nObj[@"OldPath"];
                      NSUInteger index = [self getIndexFromOldPath:oldPath];
                      for (NSString *k in [info allKeys]) {
                          [self changeArrayControllerAtIndex:index value:info[k] key:k];
                      }

                      [_beforeTable reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
                      [_afterTable reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];

                      if (EQ_STR(info[@"status"], @"ERROR") || EQ_STR(info[@"status"], @"CANCEL")) {
                          NSTextView *tv = [self getLogView];
                          NSMutableString *content = [tv.string mutableCopy];
                          [content appendString:info[@"message"]];
                          tv.string = [content copy];
                      }
                  });
}

#pragma mark -
#pragma mark Public Funcs
- (void)setFocus
{
    NSDictionary *tblSetting = KZSetting.sharedSetting.settingVal;
    if (EQ_STR(tblSetting[@"makeFolderPlace"], NSLocalizedStringFromTable(@"SaveFilePlaceSelect", @"Preference", nil))) {
        [_manualView appearView];
        [_optionView hideView];
        [self.view.window makeFirstResponder:_manualView.saveFolderField];
    }
    else {
        [_manualView hideView];
        [_optionView appearView];
        [self.view.window makeFirstResponder:_optionView.folderSelect];
    }
}

#pragma mark -
#pragma mark DataSource
- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    if([KZLibs isEqual:tableView.identifier compare:@"before"])
    {
        [_afterTable setSortDescriptors:tableView.sortDescriptors];
    }
    else if([KZLibs isEqual:tableView.identifier compare:@"after"])
    {
        [_beforeTable setSortDescriptors:tableView.sortDescriptors];
    }
}

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSData *indexSetWithData = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
    [item setData:indexSetWithData forType:NSTableRowType];
    [pboard writeObjects:@[item]];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    KZArrayController *tmpArrayCon;
    
    if ([KZLibs isEqual:tableView.identifier compare:@"before"]) {
        tmpArrayCon = _beforeController;
    }
    else if ([KZLibs isEqual:tableView.identifier compare:@"after"]) {
        tmpArrayCon = _afterController;
    }
    
    if (row > [tmpArrayCon.arrangedObjects count] || row < 0) {
        return NSDragOperationNone;
    }
    
    if (!info.draggingSource) {
        return NSDragOperationCopy;
    }
    else if (info.draggingSource == self) {
        return NSDragOperationNone;
    }
    else if (info.draggingSource == tableView) {
        [tableView setDropRow:row dropOperation:NSTableViewDropAbove];
        return NSDragOperationMove;
    }
    
    return NSDragOperationCopy;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
    KZKeyHookTable *dragSourceTable = info.draggingSource;
    if (dragSourceTable != NULL) {
        if (![KZLibs isEqual:dragSourceTable.identifier compare:tableView.identifier]) {
            return NO;
        }
    }
    
    NSPasteboard *pboard = info.draggingPasteboard;
    NSArray *dataTypes = [pboard types];
    __block KZArrayController *tmpArrayCon;
    
    if ([KZLibs isEqual:tableView.identifier compare:@"before"]) {
        tmpArrayCon = _beforeController;
    }
    else if ([KZLibs isEqual:tableView.identifier compare:@"after"]) {
        tmpArrayCon = _afterController;
    }
    
    for (NSString *type in dataTypes)
    {
        if ([KZLibs isEqual:type compare:NSFilenamesPboardType]) {
            NSData *data = [pboard dataForType:NSFilenamesPboardType];
            NSError *error;
            NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
            NSMutableArray *theFiles = [[NSPropertyListSerialization propertyListWithData:data
                                                                                  options:(NSPropertyListReadOptions)NSPropertyListImmutable
                                                                                  format:&format
                                                                                   error:&error]mutableCopy];
            [theFiles sortUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
                NSString *f1 = [KZLibs getFileName:obj1];
                NSString *f2 = [KZLibs getFileName:obj2];
                return [f1 compare:f2];
            }];

            if (error) {
                LogF(@"get file property error : %@", error.description);
                break;
            }
            if (!theFiles || theFiles.count == 0) {
                Log(@"get file property error");
                break;
            }
            
            NSArray *supported = [DiffImgCV isSupported];
            dispatch_group_t group = dispatch_group_create();
            dispatch_queue_t main = dispatch_get_main_queue();
            dispatch_queue_t sub = dispatch_queue_create("com.asahi.kazuya.diff", DISPATCH_QUEUE_SERIAL);
            
            for (NSUInteger i = 0; i < theFiles.count; i++) {
                BOOL isDirectory = [KZLibs isDirectory:theFiles[i]];
                if (isDirectory) {
                    NSArray *arAllFile = [KZLibs getFileList:theFiles[0] deep:NO onlyDir:NO onlyFile:NO isAllFullPath:YES];
                    
                    if (arAllFile.count == 0) {
                        continue;
                    }
                    dispatch_group_t group_d = dispatch_group_create();
                    for (NSString *f in arAllFile) {
                        dispatch_group_async(group_d, sub, ^{
                            NSString *ext = nil;
                            BOOL isNotSupport = NO;
                            NSMutableArray *arFileInfos = [NSMutableArray array];
                            NSDictionary *param = nil;
                            if ([KZLibs isDirectory:f]) return;
                            ext = [[KZLibs getFileExt:f] lowercaseString];
                            if ([supported containsObject:ext]) {
                                NSMutableDictionary *tblInfo = [self getFileInfo:f];
                                if (![self isContainsFile:tblInfo[@"path"] arrayController:tmpArrayCon]) {
                                    [arFileInfos addObject:tblInfo];
                                }
                            }
                            else {
                                isNotSupport = YES;
                            }
                            
                            if (arFileInfos.count == 1) {
                                param = @{@"Data" : arFileInfos[0],
                                          @"Datas" : NSNull.null};
                            }
                            else if (arFileInfos.count > 1) {
                                param = @{@"Data" : NSNull.null,
                                          @"Datas" : [arFileInfos copy]};
                            }
                            dispatch_async(main, ^{
                                if (param) {
                                    if (param[@"Data"] != NSNull.null) {
                                        [tmpArrayCon addObject:param[@"Data"]];
                                    }
                                    else {
                                        [tmpArrayCon addObjects:param[@"Datas"]];
                                    }
                                }
                                
                                if (isNotSupport) {
                                    NSAlert *al = [[NSAlert alloc] init];
                                    al.messageText = NSLocalizedStringFromTable(@"NotSupportFileError", @"ErrorText", nil);
                                    [al beginSheetModalForWindow:[KZLibs getMainWindow] completionHandler:^(NSModalResponse returnCode) {
                                    }];
                                    return;
                                }
                            });
                        });
                    }
                    dispatch_group_notify(group_d, main, ^{
                        [self setStartBtnState];
                    });
                }
                else {
                    dispatch_group_async(group, sub, ^{
                        BOOL isNotSupport = NO;
                        NSDictionary *param = nil;
                        NSString *ext = nil;
                        ext = [[KZLibs getFileExt:theFiles[i]] lowercaseString];
                        if ([supported containsObject:ext]) {
                            NSMutableDictionary *tblInfo = [self getFileInfo:theFiles[i]];
                            if (![self isContainsFile:tblInfo[@"path"] arrayController:tmpArrayCon]) {
                                param = @{@"Data" : tblInfo,
                                          @"Datas" : NSNull.null};
                            }
                            else {
                                isNotSupport = YES;
                            }
                        }
                        dispatch_async(main, ^{
                            if (param) {
                                if (param[@"Data"] != NSNull.null) {
                                    [tmpArrayCon addObject:param[@"Data"]];
                                }
                            }
                            
                            if (isNotSupport) {
                                NSAlert *al = [[NSAlert alloc] init];
                                al.messageText = NSLocalizedStringFromTable(@"NotSupportFileError", @"ErrorText", nil);
                                [al beginSheetModalForWindow:[KZLibs getMainWindow] completionHandler:^(NSModalResponse returnCode) {
                                }];
                                return;
                            }
                        });
                    });
                    
                }
            }
            
            dispatch_group_notify(group, main, ^{
                [self setStartBtnState];
            });
            return YES;
        }
        else if ([KZLibs isEqual:type compare:NSTableRowType]) {
            NSData *data = [pboard dataForType:NSTableRowType];
            NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            NSInteger dragRow = [rowIndexes firstIndex];
            
            NSMutableDictionary *moveDic = [[NSMutableDictionary alloc] initWithDictionary:tmpArrayCon.arrangedObjects[dragRow] copyItems:YES];
            
            [tmpArrayCon removeObjectAtArrangedObjectIndex:dragRow];
            NSInteger insertRow = (row <= 0) ? 0 : row - 1;
            [tmpArrayCon insertObject:moveDic atArrangedObjectIndex:insertRow];
            
            [tableView reloadData];
            [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertRow] byExtendingSelection:YES];
            [tableView scrollRowToVisible:insertRow];
            return YES;
        }
    }
    return NO;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    NSUInteger theCount = 0;
    if ([KZLibs isEqual:tableView.identifier compare:@"before"]) {
        theCount = [_beforeController.arrangedObjects count];
        return theCount;
    }
    else if ([KZLibs isEqual:tableView.identifier compare:@"after"]) {
        theCount = [_afterController.arrangedObjects count];
        return theCount;
    }
    return 0;
}

#pragma mark -
#pragma mark TableView Delegates

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    KZKeyHookTable *table = notification.object;
    NSIndexSet *rowIndexes = table.selectedRowIndexes;
    NSUInteger maxIdx = rowIndexes.lastIndex;
    
    if (maxIdx == NSNotFound) return;
    
    if ([KZLibs isEqual:table.identifier compare:@"before"]) {
        if (maxIdx + 1 > _afterTable.numberOfRows) {
            [_afterTable deselectAll:_afterTable.selectedRowIndexes];
        }
        else {
            [_afterTable selectRowIndexes:rowIndexes byExtendingSelection:YES];
        }
    }
    else if ([KZLibs isEqual:table.identifier compare:@"after"]) {
        if (maxIdx + 1 > _beforeTable.numberOfRows) {
            [_beforeTable deselectAll:_beforeTable.selectedRowIndexes];
        }
        else {
            [_beforeTable selectRowIndexes:rowIndexes byExtendingSelection:YES];
        }
    }
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *identifier = tableColumn.identifier;
    KZCellView *cell = nil;
    cell = [tableView makeViewWithIdentifier:identifier owner:self];
    KZArrayController *tmpArrayCon;
    
    if ([KZLibs isEqual:tableView.identifier compare:@"before"]) {
        tmpArrayCon = _beforeController;
    }
    else if ([KZLibs isEqual:tableView.identifier compare:@"after"]) {
        tmpArrayCon = _afterController;
    }
    
    cell.identifier = [NSString stringWithFormat:@"%lu", row];
    NSArray *arFileInfo = tmpArrayCon.arrangedObjects;
    NSDictionary *theFileInfo = arFileInfo[row];
    
    cell.pathInfo.stringValue = theFileInfo[@"path"];
    cell.toolTip = [cell.pathInfo stringValue];
    cell.progress.hidden = YES;
    cell.progressView.hidden = YES;
    
    if ([KZLibs isEqual:theFileInfo[@"status"] compare:@"SETMAX"]) {
        cell.progress.hidden = NO;
        cell.progress.indeterminate = NO;
        cell.progress.maxValue = [theFileInfo[@"maxprogress"] doubleValue];
        cell.progDetail.stringValue = [NSString stringWithFormat:@"1 / %d", (int)cell.progress.maxValue];
        [cell showProgress];
    }
    else if ([KZLibs isEqual:theFileInfo[@"status"] compare:@"COUNT"]) {
        cell.progress.hidden = NO;
        cell.progress.indeterminate = NO;
        cell.progress.maxValue = [theFileInfo[@"maxprogress"] doubleValue];
        cell.progress.doubleValue = [theFileInfo[@"progress"] doubleValue];
        cell.progDetail.stringValue = [NSString stringWithFormat:@"%d / %d", (int)cell.progress.doubleValue,(int)cell.progress.maxValue];
        [cell showProgress];
    }
    else if ([KZLibs isEqual:theFileInfo[@"status"] compare:@"ERROR"]) {
        cell.wantsLayer = YES;
        cell.alphaValue = 0.5;
        cell.layer.backgroundColor = [[NSColor colorWithDeviceRed:180.0 green:0.0 blue:0.0 alpha:0.5] CGColor];
    }
    else if ([KZLibs isEqual:theFileInfo[@"status"] compare:@"CANCEL"]) {
        cell.wantsLayer = YES;
        cell.alphaValue = 0.5;
        cell.layer.backgroundColor = [[NSColor colorWithDeviceRed:255.0 green:164.0 blue:0.0 alpha:0.5] CGColor];
    }
    else if ([KZLibs isEqual:theFileInfo[@"status"] compare:@"SKIP"]) {
        cell.wantsLayer = YES;
        cell.alphaValue = 0.5;
        cell.layer.backgroundColor = [[NSColor colorWithDeviceRed:0.0 green:255.0 blue:255.0 alpha:1.0] CGColor];
    }
    else if ([KZLibs isEqual:theFileInfo[@"status"] compare:@"START_CONVERT"]) {
        cell.progress.hidden = NO;
        cell.progress.indeterminate = YES;
        cell.progress.usesThreadedAnimation = YES;
        [cell.progress startAnimation:nil];
        cell.progDetail.stringValue = NSLocalizedStringFromTable(@"CellProgressStringStartConvert", @"MainUI", nil);
        [cell showProgress];
    }
    else if ([KZLibs isEqual:theFileInfo[@"status"] compare:@"END_CONVERT"]) {
        cell.progress.hidden = NO;
        cell.progress.indeterminate = YES;
        cell.progress.usesThreadedAnimation = YES;
        [cell.progress startAnimation:nil];
        cell.progDetail.stringValue = NSLocalizedStringFromTable(@"CellProgressStringEndConvert", @"MainUI", nil);
        [cell showProgress];
    }
    else if ([KZLibs isEqual:theFileInfo[@"status"] compare:@"START_INSPECT"]) {
        cell.progress.hidden = NO;
        cell.progress.indeterminate = YES;
        cell.progress.usesThreadedAnimation = YES;
        [cell.progress startAnimation:nil];
        cell.progDetail.stringValue = NSLocalizedStringFromTable(@"CellProgressStringStartInspect", @"MainUI", nil);
        [cell showProgress];
    }
    else if ([KZLibs isEqual:theFileInfo[@"status"] compare:@"END_INSPECT"]) {
        cell.progress.hidden = NO;
        cell.progress.indeterminate = YES;
        cell.progress.usesThreadedAnimation = YES;
        [cell.progress startAnimation:nil];
        cell.progDetail.stringValue = NSLocalizedStringFromTable(@"CellProgressStringFinish", @"MainUI", nil);
        [cell showProgress];
    }
    else if ([KZLibs isEqual:theFileInfo[@"status"] compare:@"FINISH"]) {
        cell.wantsLayer = YES;
        cell.alphaValue = 0.5;
        cell.layer.backgroundColor = [[NSColor colorWithDeviceRed:0.0 green:255.0 blue:0.0 alpha:0.5] CGColor];
    }
    
    return cell;
    
}

#pragma mark TableView Key Delegates

- (void)tableViewDeleteKeyPressedOnRows:(KZKeyHookTable *)table index:(NSIndexSet *)idx
{
    if ([KZLibs isEqual:table.identifier compare:@"before"]) {
        LogF(@"%lu : DeleteKey old table", idx.firstIndex);
    }
    else if ([KZLibs isEqual:table.identifier compare:@"after"]) {
        LogF(@"%lu : DeleteKey new table", idx.firstIndex);
    }
}

- (void)tableViewEnterKeyPressedOnRows:(KZKeyHookTable *)table index:(NSIndexSet *)idx
{
    if ([KZLibs isEqual:table.identifier compare:@"before"]) {
        LogF(@"%lu : Enter old table", idx.firstIndex);
    }
    else if ([KZLibs isEqual:table.identifier compare:@"after"]) {
        LogF(@"%lu : Enter new table", idx.firstIndex);
    }
}

#pragma mark Delegate From DiffImgCV

- (void)tooManyDiff:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage
{
    [self appendTableFromDelegate:object setInfo:@{@"status" : @"SKIP"}];
}

- (void)startConvert:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage
{
    [self appendTableFromDelegate:object setInfo:@{@"status" : @"START_CONVERT"}];
}

- (void)endConvert:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage
{
    [self appendTableFromDelegate:object setInfo:@{@"status" : @"END_CONVERT"}];
}

- (void)startInspect:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage
{
    [self appendTableFromDelegate:object setInfo:@{@"status" : @"START_INSPECT"}];
}

- (void)endInspect:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage
{
    [self appendTableFromDelegate:object setInfo:@{@"status" : @"END_INSPECT"}];
}

- (void)completeSaveFile:(id)object
{
    NSMutableDictionary *nObj = object;
    if (!nObj) return;

    
    dispatch_sync(
                  dispatch_get_main_queue(), ^{
                      NSString *oldPath = nObj[@"OldPath"];
                      NSUInteger index = [self getIndexFromOldPath:oldPath];
                      [_beforeController removeObjectAtArrangedObjectIndex:index];
                      [_afterController removeObjectAtArrangedObjectIndex:index];
                      
                      [_beforeController rearrangeObjects];
                      [_afterController rearrangeObjects];
                      
                      [_beforeTable reloadData];
                      [_afterTable reloadData];
                  });
    
}

- (void)maxDiffAreas:(int)count object:(id)object
{
    [self appendTableFromDelegate:object setInfo:@{@"status" : @"SETMAX",
                                                   @"progress" : @0u,
                                                   @"maxprogress" : [NSNumber numberWithUnsignedInteger:count]}];
}

- (void)notifyProcess:(id)object
{
    NSMutableDictionary *nObj = object;
    if (!nObj) return;
    NSString *oldPath = nObj[@"OldPath"];
    NSUInteger index = [self getIndexFromOldPath:oldPath];
    
    NSMutableDictionary *muB = [_beforeController.arrangedObjects objectAtIndex:index];
    NSMutableDictionary *muA = [_afterController.arrangedObjects objectAtIndex:index];
    
    NSUInteger curA = [muA[@"progress"] unsignedIntegerValue];
    NSUInteger curB = [muB[@"progress"] unsignedIntegerValue];
    curA++;
    curB++;
    [self appendTableFromDelegate:object setInfo:@{@"status" : @"COUNT",
                                                   @"progress" : [NSNumber numberWithUnsignedInteger:curB]}];
}

- (void)skipProcess:(id)object errMessage:(NSString*)msg
{
    [self appendTableFromDelegate:object setInfo:@{@"status" : @"ERROR",
                                                   @"message" : msg,
                                                   }];
}

- (void)logProcess:(NSString*)msg
{
    dispatch_sync(
      dispatch_get_main_queue(), ^{
          NSTextView *tv = [self getLogView];
          NSMutableString *content = [tv.string mutableCopy];
          [content appendString:msg];
          tv.string = [content copy];
      });
}

- (void)cancelProcess:(id)object message:(NSString*)msg
{
    [self appendTableFromDelegate:object setInfo:@{@"status" : @"CANCEL",
                                                   @"message" : msg,
                                                   }];
}

#pragma mark -
#pragma mark Notify
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSMethodSignature *sig = [[self class] instanceMethodSignatureForSelector:(SEL)context];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setTarget:self];
    [inv setSelector:(SEL)context];
    [inv setArgument:&object atIndex:2];
    [inv setArgument:&keyPath atIndex:3];
    [inv setArgument:&change atIndex:4];
    [inv invoke];
}

- (void)onChangeSaveFolder:(id)obj keyPath:(NSString*)keyPath change:(NSDictionary*)change
{
    if(!isCompaering)
    {
        NSString *makeFolderPlace = change[@"new"];
        if (EQ_STR(makeFolderPlace, NSLocalizedStringFromTable(@"SaveFilePlaceSelect", @"Preference", nil))) {
            [_manualView appearView];
            [_optionView hideView];
        }
        else
        {
            [_manualView hideView];
            [_optionView appearView];
        }
    }
}

- (void)onChangeSaveFolderName:(id)obj keyPath:(NSString*)keyPath change:(NSDictionary*)change
{
    if(!isCompaering)
    {
        NSArray *folderNames = change[@"new"];
        KZFolderNameSource.sharedFolderNameSource.values = [folderNames mutableCopy];
        _optionView.folderSelect.stringValue = KZSetting.sharedSetting.settingVal[@"makeFolderName"];
    }
}

- (void)onChangePresetName:(id)obj keyPath:(NSString*)keyPath change:(NSDictionary*)change
{
    if(!isCompaering)
    {
        [self setFocus];
    }
}

- (void)onChangeOperationCount:(id)obj keyPath:(NSString*)keyPath change:(NSDictionary*)change
{
    NSUInteger opCount = [change[@"new"] count];
    if (opCount == 0 && [NSThread isMainThread]) {
        [self setStartBtnState];
        isCompaering = NO;
    }
    else if (opCount == 0 && ![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setStartBtnState];
        });
        isCompaering = NO;
    }
    
}
@end
