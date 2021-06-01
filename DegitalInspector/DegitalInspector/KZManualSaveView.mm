//
//  KZManualSaveView.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/10.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZManualSaveView.h"


@interface KZManualSaveView()
@property (nonatomic, weak) IBOutlet NSView *view;
@property (nonatomic, weak) IBOutlet NSButton *selectFolder;
- (IBAction)openFolder:(id)sender;
@end

@implementation KZManualSaveView

#pragma mark -
#pragma mark Initialize

- (instancetype)init
{
    self = [super init];
    if(!self) return nil;
    
    _selectFolder.hidden = NO;
    return self;
}

- (void)appearView
{
    [_saveFolderField setSelectable:YES];
    _saveFolderField.stringValue = @"";
    [_saveFolderField.cell setPlaceholderString:NSLocalizedStringFromTable(@"ManualSavePlaceholder", @"MainUI", nil)];
    _view.hidden = NO;
}

- (void)hideView
{
    _view.hidden = YES;
}

- (IBAction)openFolder:(id)sender
{
    NSArray *paths = [KZLibs openFileDialog:NSLocalizedStringFromTable(@"OpenFileDialogTitle", @"MainUI", nil) multiple:NO selectFile:NO selectDir:YES];
    NSString *path = nil;
    if(paths.count == 0) path = @"";
    else path = paths[0];
    _saveFolderField.stringValue = path;
}
@end
