//
//  KZPreferenceWindowController.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/01.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZPreferenceWindowController.h"
#import "KZDisplaySetting.h"

@interface KZPreferenceWindowController () <NSOutlineViewDelegate, NSOutlineViewDataSource, NSWindowDelegate>
@property (nonatomic, weak) IBOutlet NSOutlineView *sourceList;
@property (nonatomic, weak) IBOutlet NSTabView *settingTab;
@property (nonatomic, retain) NSArray *sourceListItems;
@property (nonatomic, weak) IBOutlet KZDisplaySetting *settingVals;
@end

@implementation KZPreferenceWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        _sourceListItems = [NSArray array];
    }
    return self;
}

- (void)awakeFromNib
{
    self.window.delegate = self;
    _sourceListItems = @[
                          @{@"title" : NSLocalizedStringFromTable(@"GroupNameDiffView", @"Preference", nil),
                            @"identifier" : @"GroupNameDiffView"},
                          @{@"title" : NSLocalizedStringFromTable(@"GroupNameDiff", @"Preference", nil),
                            @"identifier" : @"GroupNameDiff"},
                          @{@"title" : NSLocalizedStringFromTable(@"GroupNameRaster", @"Preference", nil),
                            @"identifier" : @"GroupNameRaster"},
                          @{@"title" : NSLocalizedStringFromTable(@"GroupNameFile", @"Preference", nil),
                            @"identifier" : @"GroupNameFile"},
                          @{@"title" : NSLocalizedStringFromTable(@"GroupNameApplication", @"Preference", nil),
                            @"identifier" : @"GroupNameApplication"},
                          @{@"title" : NSLocalizedStringFromTable(@"GroupNamePreview", @"Preference", nil),
                            @"identifier" : @"GroupNamePreview"}
                         ];
    
    [_sourceList setDataSource:self];
    [_sourceList setDelegate:self];
    
    self.window.title = NSLocalizedStringFromTable(@"ToolBarSettingString", @"MainUI", nil);
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [_settingVals appendUIFromSetting];
}

- (void)showWindow:(id)sender
{
    [super showWindow:sender];
}

- (void)windowWillClose:(NSNotification *)notification
{
    if (EQ_STR(KZSetting.sharedSetting.latestPreset, @"Default")) {
        return;
    }
    NSDictionary *diffDic = [_settingVals getSettingChanged];
    if (diffDic.allKeys.count != 0) {
        if (diffDic.allKeys.count == 1 && EQ_STR(diffDic.allKeys[0], @"makeFolderName")) {
            // 作成フォルダのみの変更なら無視
            return;
        }
        else {
            NSAlert *al = [[NSAlert alloc] init];
            [al addButtonWithTitle:@"OK"];
            [al addButtonWithTitle:@"Cancel"];
            NSMutableString *message = [NSMutableString string];
            [message appendString:NSLocalizedStringFromTable(@"DifferenceSettingWarn", @"ErrorText", nil)];
            for (NSString* key in diffDic.allKeys) {
                if (NEQ_STR(key, @"makeFolderName")) {
                    [message appendString:NSLocalizedStringFromTable(key, @"Preference", nil)];
                    [message appendString:@"\n"];
                }
            }
            al.messageText = [message copy];
            NSModalResponse returnCode = [al runModal];
            if (returnCode == NSAlertFirstButtonReturn) {
                [_settingVals appendSettingFromUI];
            }else if (returnCode == NSAlertSecondButtonReturn) {
                [_settingVals appendUIFromSetting];
            }
            
        }
        
    }
}

#pragma mark -
#pragma mark SourceList DataSource / Delegate

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (!item) {
        return [_sourceListItems objectAtIndex:index];
    }
    else {
        return nil;
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (!item) {
        return [_sourceListItems count];
    }
    else {
        return 0;
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return NO;
}


- (NSView*)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableCellView *view = nil;
    NSString *columnIdentifier = tableColumn.identifier;
    if (EQ_STR(columnIdentifier, @"settingTitle")) {
        view = [outlineView makeViewWithIdentifier:@"DataCell" owner:self];
        view.imageView.image = nil;
        view.textField.stringValue = item[@"title"];
    }
    
    return view;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    NSOutlineView *list = (NSOutlineView*)[notification object];
    NSIndexSet *selectedIndexese = [list selectedRowIndexes];
    if ([selectedIndexese count] == 1) {
        NSDictionary *item = _sourceListItems[selectedIndexese.firstIndex];
        [_settingTab selectTabViewItemWithIdentifier:item[@"identifier"]];
    }
}
@end
