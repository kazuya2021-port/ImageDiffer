//
//  AppDelegate.m
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/07/31.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "AppDelegate.h"
#import "DVTabViewController.h"
#import "DVToolBarController.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet DVTabViewController * dv;
@property (nonatomic, weak) IBOutlet DVToolBarController *toolBar;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    _arOpenFiles = [NSMutableArray array];
    [_dv loadView];
    
    _prefWindow = [[DVSettingWindow alloc] initWithWindowNibName:@"DVSettingWindow"];
    [_toolBar setUpUI];
    
    _toolBar.wincon = _prefWindow;
    
    [_window setToolbar:_toolBar.toolbar];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}
@end
