//
//  DVToolBarController.m
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/08/01.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//
#import "DVTabViewController.h"
#import "DVToolBarController.h"
#import "DVSettingWindow.h"

@interface DVToolBarController () <NSToolbarDelegate>
@property (nonatomic, weak) IBOutlet NSWindow *window;
@property (nonatomic, weak) IBOutlet DVTabViewController *tabBar;
@end

@implementation DVToolBarController
static NSString *SettingIdentifier = @"SettingApplication";
static NSString *SingleViewIdentifier = @"SingleView";
static NSString *DoubleViewIdentifier = @"DoubleView";
static NSString *OpenFileIdentifier = @"OpenFile";

#pragma mark -
#pragma mark Initialize

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return nil;
    }
    return self;
}

#pragma mark -
#pragma mark Loal Funcs

- (NSArray*)validToolBarItems
{
    return @[OpenFileIdentifier,
             NSToolbarFlexibleSpaceItemIdentifier,
             SingleViewIdentifier,
             DoubleViewIdentifier,
             //SettingIdentifier,
             NSToolbarCustomizeToolbarItemIdentifier];
}

#pragma mark -
#pragma mark Public Funcs

- (void)setUpUI
{
    _toolbar = [[NSToolbar alloc] initWithIdentifier:@"toolBarMain"];
    _toolbar.delegate = self;
    _toolbar.allowsUserCustomization = YES;
    [_toolbar setSizeMode:NSToolbarSizeModeSmall];
}

#pragma mark -
#pragma mark ToolBar Funcs

- (void)openFile:(id)sender
{
    __block NSArray* filePaths = nil;
    NSOpenPanel* opnPanel = [NSOpenPanel openPanel];
    opnPanel.canChooseDirectories = NO;
    opnPanel.canChooseFiles = YES;
    opnPanel.canCreateDirectories = YES;
    opnPanel.allowsMultipleSelection = YES;
    __block NSMutableString *erString = [NSMutableString string];
    [opnPanel beginSheetModalForWindow:_window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSFileHandlingPanelOKButton) {
            filePaths = [opnPanel URLs];
            
            for (NSURL* url in filePaths) {
                NSError *error = nil;
                NSString *theFile = [url path];
                AppDelegate *del = NSApplication.sharedApplication.delegate;
                OpenedFile *f = [OpenedFile initWithPath:theFile error:&error];
                if (error) {
                    [erString appendString:error.userInfo[@"message"]];
                    [erString appendString:@"\n"];
                    continue;
                }
                else {
                    [del.arOpenFiles addObject:f];
                    [_tabBar addNewDiff:f];
                }
            }
            if (NEQ_STR([erString copy], @"")) {
                NSAlert *al = [[NSAlert alloc] init];
                al.messageText = NSLocalizedStringFromTable(@"OpenReason", @"Error", nil);
                al.informativeText = [erString copy];
                al.alertStyle = NSCriticalAlertStyle;
                [al runModal];
            }
        }
    }];
}

- (void)apperSetting:(id)sender
{
    [_wincon showWindow:self];
}

- (void)apperSingle:(id)sender
{
    [_delegate appearSingleView];
}

- (void)apperDouble:(id)sender
{
    [_delegate appearDoubleView];
}

#pragma mark -
#pragma mark Toolbar Delegate

- (NSArray*)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [self validToolBarItems];
}

- (NSArray*)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [self validToolBarItems];
}

- (NSArray*)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return [self validToolBarItems];
}

- (NSToolbarItem*)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    [item setTarget:self];
    
    if (EQ_STR(itemIdentifier, OpenFileIdentifier)) {
        [item setLabel:NSLocalizedStringFromTable(@"ToolBarOpenString", @"MainUI", nil)];
        [item setImage:[NSImage imageNamed:@"Open"]];
        [item setAction:@selector(openFile:)];
    }
    
    if (EQ_STR(itemIdentifier, SingleViewIdentifier)) {
        [item setLabel:NSLocalizedStringFromTable(@"ToolBarSingleString", @"MainUI", nil)];
        [item setImage:[NSImage imageNamed:@"SingleGrid"]];
        [item setAction:@selector(apperSingle:)];
    }
    
    if (EQ_STR(itemIdentifier, DoubleViewIdentifier)) {
        [item setLabel:NSLocalizedStringFromTable(@"ToolBarDoubleString", @"MainUI", nil)];
        [item setImage:[NSImage imageNamed:@"DoubleGrid"]];
        [item setAction:@selector(apperDouble:)];
    }
    
    if (EQ_STR(itemIdentifier, SettingIdentifier)) {
        [item setLabel:NSLocalizedStringFromTable(@"ToolBarSettingString", @"MainUI", nil)];
        [item setImage:[NSImage imageNamed:@"Setting"]];
        [item setAction:@selector(apperSetting:)];
    }

    return item;
}

@end
