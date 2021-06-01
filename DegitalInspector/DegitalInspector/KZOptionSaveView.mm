//
//  KZOptionSaveView.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/10.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZOptionSaveView.h"

@interface KZOptionSaveView()<NSComboBoxDelegate, NSControlTextEditingDelegate>
{
    NSString *currentSelectName;
}
@property (nonatomic, weak) IBOutlet NSView *view;
@property (nonatomic, weak) IBOutlet NSPopUpButton *labelPlace;
- (IBAction)popSelect:(id)sender;
- (IBAction)folderSelect:(id)sender;
@end

@implementation KZOptionSaveView

#pragma mark -
#pragma mark Initialize

- (instancetype)init
{
    self = [super init];
    if(!self) return nil;
    
    _folderSelect.delegate = self;
    return self;
}

- (void)appearView
{
    NSDictionary *tblSetting = KZSetting.sharedSetting.settingVal;
    [_labelPlace.menu removeAllItems];
    [_labelPlace.menu addItemWithTitle:NSLocalizedStringFromTable(@"SaveFilePlaceOLD", @"Preference", nil) action:nil keyEquivalent:@""];
    [_labelPlace.menu addItemWithTitle:NSLocalizedStringFromTable(@"SaveFilePlaceNEW", @"Preference", nil) action:nil keyEquivalent:@""];
    [_labelPlace selectItemWithTitle:tblSetting[@"makeFolderPlace"]];
    _view.hidden = NO;
}

- (void)hideView
{
    _view.hidden = YES;
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
    NSComboBox *cb = notification.object;
    NSInteger idx = [cb indexOfSelectedItem];
    currentSelectName = KZFolderNameSource.sharedFolderNameSource.values[idx];
    NSMutableDictionary *muDic = [KZSetting.sharedSetting.settingVal mutableCopy];
    muDic[@"makeFolderName"] = currentSelectName;
    KZSetting.sharedSetting.settingVal = [muDic copy];
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    NSMutableArray *tmp = KZFolderNameSource.sharedFolderNameSource.values;
    
    if([KZLibs isEqual:control.stringValue compare:@""])
    {
        [tmp removeObject:currentSelectName];
        if(tmp.count == 0)
        {
            _folderSelect.stringValue = @"";
        }
        else
        {
            _folderSelect.stringValue = control.stringValue;
        }
    }
    else
    {
        [tmp addObject:control.stringValue];
        tmp = [[KZLibs distinctArray:[tmp copy]] mutableCopy];
        NSMutableDictionary *muDic = [KZSetting.sharedSetting.settingVal mutableCopy];
        muDic[@"folderNames"] = [tmp copy];
        KZSetting.sharedSetting.settingVal = [muDic copy];
        _folderSelect.stringValue = control.stringValue;
    }

    return YES;
}

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
{
    currentSelectName = control.stringValue;
    return YES;
}

- (IBAction)folderSelect:(id)sender
{
    NSComboBox *box = sender;
    
}

- (IBAction)popSelect:(id)sender
{
    NSPopUpButton *btn = sender;
    NSMutableDictionary *muDic = [KZSetting.sharedSetting.settingVal mutableCopy];
    muDic[@"makeFolderPlace"] = btn.title;
    KZSetting.sharedSetting.settingVal = [muDic copy];
}

@end
