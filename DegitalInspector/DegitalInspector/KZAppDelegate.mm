//
//  KZAppDelegate.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/03/29.
//  Copyright (c) 2019年 ___FULLUSERNAME___. All rights reserved.
//

#import "KZAppDelegate.h"
#import "KZMainViewControll.h"
#import "KZToolBarControll.h"

@interface KZAppDelegate() <NSWindowDelegate>
@property (nonatomic, weak) IBOutlet KZMainViewControll *mainView;
@property (nonatomic, weak) IBOutlet NSWindow *window;
@property (nonatomic, weak) IBOutlet KZToolBarControll *toolBar;
@property (nonatomic, weak) IBOutlet NSPanel *logView;
@property (nonatomic, strong) IBOutlet NSTextView *logTextView;

@property (nonatomic, assign) NSPoint dragCursorStartPos;
@property (nonatomic, strong) NSTimer *dragWindowTimer;

- (IBAction)clearLog:(id)sender;
- (IBAction)saveLog:(id)sender;

@end

@implementation KZAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [KZSetting loadFromFile];
    [_mainView loadView];
    
    [_window setDelegate:self];
    [[NSUserDefaults standardUserDefaults] setBool:YES  forKey:@"NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints"];
    _prefWindow = [[KZPreferenceWindowController alloc] initWithWindowNibName:@"KZPreferenceWindowController"];
    [_toolBar setUpUI];
    
    _toolBar.wincon = _prefWindow;
    
    [_window setToolbar:_toolBar.toolbar];
    
    //_toolBar.wincon = _prefWindow;
    
    NSDictionary *tbl = KZSetting.sharedSetting.settingVal;
    if ([tbl[@"isStartFolderWakeOn"] boolValue] == YES) {
        [KZHotFolderController.sharedHotFolder startHotFolder];
    }
    
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (IBAction)showPreference:(id)sender
{

    [_prefWindow showWindow:self];
}

- (IBAction)clearLog:(id)sender
{
    _logTextView.string = @"";
}

- (IBAction)saveLog:(id)sender
{
    __block NSArray* folderPaths = nil;
    __block NSMutableArray* retPath = [NSMutableArray array];
    NSOpenPanel* opnPanel = [NSOpenPanel openPanel];
    opnPanel.canChooseDirectories = YES;
    opnPanel.canChooseFiles = NO;
    opnPanel.canCreateDirectories = YES;
    opnPanel.allowsMultipleSelection = NO;
    
    [opnPanel beginSheetModalForWindow:_logView completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSFileHandlingPanelOKButton) {
            folderPaths = [opnPanel URLs];
            for (NSURL* url in folderPaths) {
                [retPath addObject:[url path]];
            }
            NSString *savePath = retPath[0];
            NSDate *now = [NSDate date];
            NSDateFormatter *form = [[NSDateFormatter alloc] init];
            form.dateFormat = @"yyyy-MM-dd";
            NSString *date24 = [form stringFromDate:now];
            savePath = [savePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_Log.txt",date24]];
            [_logTextView.string writeToFile:savePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
        else {
            retPath = nil;
        }
    }];
}


- (void)windowWillClose:(NSNotification *)notification
{
    if(_prefWindow.isWindowLoaded)
    {
        [_prefWindow close];
    }
}

- (void)moveLogMethod
{
    NSUInteger btn = [NSEvent pressedMouseButtons];
    
    if (btn == 0) {
        [_dragWindowTimer invalidate];
        _dragWindowTimer = NULL;
    }
    NSPoint curPos = [NSEvent mouseLocation];
    NSPoint dPos = NSMakePoint(curPos.x - _dragCursorStartPos.x,
                               curPos.y - _dragCursorStartPos.y);
    
    [_logView setFrameOrigin:NSMakePoint(_window.frame.origin.x + _window.frame.size.width + dPos.x,
                                         _window.frame.origin.y + dPos.y)];
}

- (void)windowWillMove:(NSNotification *)notification
{
    _dragCursorStartPos = [NSEvent mouseLocation];
    const NSTimeInterval dragDelay = 0.01;
    _dragWindowTimer = [NSTimer scheduledTimerWithTimeInterval:dragDelay
                                                        target:self
                                                      selector:@selector(moveLogMethod)
                                                      userInfo:nil
                                                       repeats:YES];
}
- (void)windowDidMove:(NSNotification *)notification
{
    if (_dragWindowTimer != NULL) {
        [_dragWindowTimer invalidate];
        _dragWindowTimer = NULL;
    }
}

- (void)windowDidResize:(NSNotification *)notification
{
    NSView *content = _window.contentView;
    NSRect contentRect = content.frame;
    [_logView setContentSize:NSMakeSize(contentRect.size.width * 0.6, contentRect.size.height)];
    [_logView setFrameOrigin:NSMakePoint(_window.frame.origin.x + _window.frame.size.width,
                                         _window.frame.origin.y)];
}

- (IBAction)tet:(id)sender
{
    /*
    KZImage *imgutil = [[KZImage alloc] init];
    
    ConvertSetting *set_cnv = [[ConvertSetting alloc] init];
    
    set_cnv.toSpace = KZColorSpace::SRGB;
    set_cnv.Resolution = (float)168;
    set_cnv.isSaveColor = YES;
    set_cnv.isSaveLayer = YES;
    set_cnv.isResize = YES;
    set_cnv.isForceAdjustSize = NO;
    
    
    [imgutil startEngine];
    
    NSArray *arFol = [KZLibs getFileList:@"/Users/uchiyama_macmini/Desktop/PS比較サンプル/PSDサンプル" deep:NO onlyDir:NO onlyFile:YES isAllFullPath:YES];
    NSMutableArray *arLayerInfo =[NSMutableArray array];

    for (NSString *path in arFol) {
        if ([path hasSuffix:@"png"]) {
            NSNumber *isMerge = @NO;
            NSNumber *isHidden = @NO;
            if (EQ_STR([KZLibs getFileName:path], @"比較結果") ||
                EQ_STR([KZLibs getFileName:path], @"NEW")) {
                isMerge = @YES;
            }
            if (EQ_STR([KZLibs getFileName:path], @"OLD")) {
                isHidden = @YES;
            }
            NSDictionary *info = @{@"path" : path,
                                   @"label" : [KZLibs getFileName:path],
                                   @"opaque" : (EQ_STR([KZLibs getFileName:path], @"比較結果"))? @0.7 : @1.0,
                                   @"isMerge" : isMerge,
                                   @"isHidden" : isHidden
                                   };
            [arLayerInfo addObject:info];
        }
    }
    
    [imgutil makePSDDiff:arLayerInfo savePath:@"/Users/uchiyama_macmini/Desktop/PS比較サンプル/PSDサンプル/test.psd"  setting:set_cnv];
    
    */
    /*
    KZImage *imgutil = [[KZImage alloc] init];
    
    ConvertSetting *set_cnv = [[ConvertSetting alloc] init];
    
    set_cnv.toSpace = KZColorSpace::SRGB;
    set_cnv.Resolution = (float)168;
    set_cnv.isSaveColor = YES;
    set_cnv.isSaveLayer = YES;
    set_cnv.isResize = YES;
    set_cnv.isForceAdjustSize = NO;

    [imgutil startEngine];
    //NSArray *arLay = [imgutil getLayerImageFrom:@"/Users/uchiyama_macmini/Desktop/PS比較サンプル/くも/比較_04072062_1F.psd" setting:set_cnv];
    NSArray *arLay = [imgutil getLayerImageFrom:@"/Users/uchiyama_macmini/Desktop/PS比較サンプル/PSDサンプル/test.psd" setting:set_cnv];
    int laycount = 0;
    if (arLay) {
        for (NSDictionary *d in arLay) {
            [d[@"data"] writeToFile:[NSString stringWithFormat:@"/tmp/%@.png",d[@"name"]] atomically:YES];
            laycount++;
        }
    }
    */
}


@end
