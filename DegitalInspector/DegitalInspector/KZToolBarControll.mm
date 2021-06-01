//
//  KZToolBarControll.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/22.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZToolBarControll.h"
#import "KZPreferenceWindowController.h"

@interface KZToolBarControll () <NSToolbarDelegate>
@property (nonatomic, weak) IBOutlet NSWindow *window;
@property (nonatomic, weak) IBOutlet NSTabView *tabView;
@end

@implementation KZToolBarControll

static NSString *SettingIdentifier = @"SettingApplication";
static NSString *LogIdentifier = @"LogView";
static NSString *PresetIdentifier = @"PresetSelect";

#pragma mark -
#pragma mark Initialize

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return nil;
    }

    _curPreset = @"Default";
    
    return self;
}

#pragma mark -
#pragma mark Loal Funcs
- (NSArray*) makePresetMenuItems
{
    NSArray *arNames = KZSetting.sharedSetting.presetNames;
    NSMutableArray *arMenuItems = [NSMutableArray array];
    
    for (int i = 0; i < arNames.count; i++) {
        NSString *name = arNames[i];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:name action:nil keyEquivalent:@""];
        [arMenuItems addObject:item];
    }
    
    return [arMenuItems copy];
}

- (NSArray*)validToolBarItems
{
    return @[LogIdentifier,
             NSToolbarFlexibleSpaceItemIdentifier,
             SettingIdentifier,
             PresetIdentifier,
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
    
    [KZSetting.sharedSetting addObserver:self
                              forKeyPath:@"presetNames"
                                 options:NSKeyValueObservingOptionNew
                                 context:@selector(onChangePresetList:keyPath:change:)];
    [KZSetting.sharedSetting addObserver:self
                              forKeyPath:@"latestPreset"
                                 options:NSKeyValueObservingOptionNew
                                 context:@selector(onChangeLatestPreset:keyPath:change:)];
}

#pragma mark -
#pragma mark ToolBar Funcs
- (void)apperLog:(id)sender
{
    [_logPanel makeKeyAndOrderFront:self];
}

- (void)apperSetting:(id)sender
{
    [_wincon showWindow:self];
}

- (void)selectPreset:(id)sender
{
    NSString *latest = [(NSPopUpButton*)sender selectedItem].title;
    [KZSetting replaceLatestPresetNameOnly:latest];
    if ([KZSetting loadFromPresetName:latest]) {
        KZSetting.sharedSetting.latestPreset = latest;
        [KZHotFolderController.sharedHotFolder stopHotFolder];
        NSDictionary *tbl = KZSetting.sharedSetting.settingVal;
        if ([tbl[@"isStartFolderWakeOn"] boolValue] == YES) {
            [KZHotFolderController.sharedHotFolder startHotFolder];
        }
    }
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
    
    if ([KZLibs isEqual:itemIdentifier compare:LogIdentifier]) {
        [item setLabel:NSLocalizedStringFromTable(@"ToolBarLogString", @"MainUI", nil)];
        [item setImage:[NSImage imageNamed:@"Log"]];
        [item setAction:@selector(apperLog:)];
    }
    
    if ([KZLibs isEqual:itemIdentifier compare:SettingIdentifier]) {
        [item setLabel:NSLocalizedStringFromTable(@"ToolBarSettingString", @"MainUI", nil)];
        [item setImage:[NSImage imageNamed:@"Setting"]];
        [item setAction:@selector(apperSetting:)];
    }
    
    if ([KZLibs isEqual:itemIdentifier compare:PresetIdentifier]) {
        NSMenu *presetMenu = [[NSMenu alloc] initWithTitle:@"PresetMenu"];
        NSArray *arItems = [self makePresetMenuItems];
        for (int i = 0; i < arItems.count; i++) {
            [presetMenu insertItem:arItems[i] atIndex:i];
        }
        _presetBox = [[NSPopUpButton alloc] init];
        
        [_presetBox setMenu:presetMenu];
        [_presetBox setFrameOrigin:NSMakePoint(0, 0)];
        [_presetBox setFrameSize:NSMakeSize(200, 25)];
        [_presetBox selectItemWithTitle:KZSetting.sharedSetting.latestPreset];
        [_presetBox setTarget:self];
        [_presetBox setAction:@selector(selectPreset:)];
        
        NSRect cellFrame = [_presetBox frame];
        
        [item setLabel:NSLocalizedStringFromTable(@"ToolBarPresetString", @"MainUI", nil)];
        [item setPaletteLabel:[item label]];
        [item setView:_presetBox];
        [item setMinSize:cellFrame.size];
        [item setMaxSize:cellFrame.size];
    }
    return item;
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

- (void)onChangePresetList:(id)obj keyPath:(NSString*)keyPath change:(NSDictionary*)change
{
    NSArray *list = change[@"new"];
    
    [_presetBox.menu removeAllItems];
    for (int i = 0; i < list.count; i++) {
        NSMenuItem *insertItem = [[NSMenuItem alloc] initWithTitle:list[i] action:nil keyEquivalent:@""];
        insertItem.tag = i;
        [_presetBox.menu addItem:insertItem];
    }
    
    [_presetBox selectItemWithTitle:KZSetting.sharedSetting.latestPreset];
}

- (void)onChangeLatestPreset:(id)obj keyPath:(NSString*)keyPath change:(NSDictionary*)change
{
    NSString *latest = change[@"new"];
    [_presetBox selectItemWithTitle:latest];
}

@end
