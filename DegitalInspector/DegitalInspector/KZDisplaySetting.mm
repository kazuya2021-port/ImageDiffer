//
//  KZDisplaySetting.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/01.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZDisplaySetting.h"
#import "KZSlider.h"
#import "KZFolderNameSource.h"


@interface KZDisplaySetting() <NSControlTextEditingDelegate, NSComboBoxDelegate>
{
    NSString *currentSelectFolderName;
}

// Preset
@property (nonatomic, weak) IBOutlet NSPopUpButton *bPreset;
@property (nonatomic, weak) IBOutlet NSTextField *addPresetName;
@property (nonatomic, weak) IBOutlet NSPanel *addPanel;

// Diff
@property (nonatomic, weak) IBOutlet KZSlider *matchThrethSlider;
@property (nonatomic, weak) IBOutlet NSTextField *matchThrethLabel;
@property (nonatomic, weak) IBOutlet KZSlider *threthDiffSlider;
@property (nonatomic, weak) IBOutlet NSTextField *threthDiffLabel;
@property (nonatomic, weak) IBOutlet KZSlider *gapPixSlider;
@property (nonatomic, weak) IBOutlet NSTextField *gapPixLabel;
@property (nonatomic, weak) IBOutlet KZSlider *noiseReductionSlider;
@property (nonatomic, weak) IBOutlet NSTextField *noiseReductionLabel;
@property (nonatomic, weak) IBOutlet NSButton *adjustModePOC;
@property (nonatomic, weak) IBOutlet NSButton *adjustModeFeature;

// DiffView
@property (nonatomic, weak) IBOutlet KZSlider *backConsentrationSlider;
@property (nonatomic, weak) IBOutlet NSTextField *backConsentrationLabel;
@property (nonatomic, weak) IBOutlet NSColorWell *backColorWell;
@property (nonatomic, weak) IBOutlet NSColorWell *addColorWell;
@property (nonatomic, weak) IBOutlet NSButton *allAddColor;
@property (nonatomic, weak) IBOutlet NSColorWell *delColorWell;
@property (nonatomic, weak) IBOutlet NSButton *allDelColor;
@property (nonatomic, weak) IBOutlet NSColorWell *diffColorWell;
@property (nonatomic, weak) IBOutlet NSButton *allDiffColor;
@property (nonatomic, weak) IBOutlet NSPopUpButton *bDiffDispMode;
@property (nonatomic, weak) IBOutlet NSPopUpButton *bAoakaMode;
@property (nonatomic, weak) IBOutlet NSTextField *lineThicknessEdit;
@property (nonatomic, weak) IBOutlet NSButton *fillLine;

// Raster
@property (nonatomic, weak) IBOutlet NSMatrix *rasterColorMode;
@property (nonatomic, weak) IBOutlet KZSlider *rasterDpiSlider;
@property (nonatomic, weak) IBOutlet NSTextField *rasterDpiLabel;
@property (nonatomic, weak) IBOutlet NSButton *btnIsForceResize;

// File
@property (nonatomic, weak) IBOutlet NSPopUpButton *bSavePlace;
@property (nonatomic, weak) IBOutlet NSComboBox *folderSelect;
@property (nonatomic, weak) IBOutlet NSTextField *setPrefix;
@property (nonatomic, weak) IBOutlet NSTextField *setSuffix;
@property (nonatomic, weak) IBOutlet NSPopUpButton *saveFormat;
@property (nonatomic, weak) IBOutlet NSPopUpButton *saveLayer;
@property (nonatomic, weak) IBOutlet NSPopUpButton *saveColor;
@property (nonatomic, weak) IBOutlet NSButton *saveNoChange;

// Application
@property (nonatomic, weak) IBOutlet KZSlider *setThread;
@property (nonatomic, weak) IBOutlet NSTextField *threadLabel;
@property (nonatomic, weak) IBOutlet NSTextField *oHotFolderPath;
@property (nonatomic, weak) IBOutlet NSTextField *nHotFolderPath;
@property (nonatomic, weak) IBOutlet NSTextField *hotFolderSavePath;
@property (nonatomic, weak) IBOutlet NSButton *btnIsTrashCompleteItem;
@property (nonatomic, weak) IBOutlet NSButton *btnIsStartFolderWakeOn;

- (IBAction)applySetting:(id)sender;
- (IBAction)showAddPreset:(id)sender;
- (IBAction)addPreset:(id)sender;
- (IBAction)delPreset:(id)sender;
- (IBAction)updatePreset:(id)sender;
- (IBAction)allAddColor:(id)sender;
- (IBAction)allDelColor:(id)sender;
- (IBAction)allDiffColor:(id)sender;

- (IBAction)startHotFolder:(id)sender;
- (IBAction)stoptHotFolder:(id)sender;

- (IBAction)selectSaveFolder:(id)sender;

- (IBAction)selectSaveType:(id)sender;
- (IBAction)selectPreset:(id)sender;
- (IBAction)openOldHotFolder:(id)sender;
- (IBAction)openNewHotFolder:(id)sender;
- (IBAction)openSaveFolder:(id)sender;

- (IBAction)selectPOC:(id)sender;
- (IBAction)selectFeature:(id)sender;
@end

@implementation KZDisplaySetting

- (void)awakeFromNib
{
    [self initUI];
    [KZSetting.sharedSetting addObserver:self
                              forKeyPath:@"presetNames"
                                 options:NSKeyValueObservingOptionNew
                                 context:@selector(onChangePresetList:keyPath:change:)];
    [KZSetting.sharedSetting addObserver:self
                              forKeyPath:@"latestPreset"
                                 options:NSKeyValueObservingOptionNew
                                 context:@selector(onChangeLatestPreset:keyPath:change:)];
}

- (void)initUI
{
    [_bPreset.menu removeAllItems];
    if(KZSetting.sharedSetting.presetNames.count)
    {
        NSInteger tagIdx = 0;
        for (NSString* pName in KZSetting.sharedSetting.presetNames)
        {
            NSMenuItem *insertItem = [[NSMenuItem alloc] initWithTitle:pName action:nil keyEquivalent:@""];
            insertItem.tag = tagIdx;
            tagIdx++;
            [_bPreset.menu addItem:insertItem];
        }
    }
    [_bPreset selectItemWithTitle:KZSetting.sharedSetting.latestPreset];
    
    NSArray *tmpItems = _bDiffDispMode.menu.itemArray;

    if(tmpItems.count == 0 || tmpItems.count == 1)
    {
        [_bDiffDispMode.menu removeAllItems];
        [_bDiffDispMode.menu addItemWithTitle:NSLocalizedStringFromTable(@"DiffModeArround", @"Preference", nil) action:nil keyEquivalent:@""];
        [_bDiffDispMode.menu addItemWithTitle:NSLocalizedStringFromTable(@"DiffModeRect", @"Preference", nil) action:nil keyEquivalent:@""];
        [_bDiffDispMode.menu addItem:[NSMenuItem separatorItem]];
        [_bDiffDispMode.menu addItemWithTitle:NSLocalizedStringFromTable(@"DiffModeNone", @"Preference", nil) action:nil keyEquivalent:@""];
    }

    tmpItems = _bAoakaMode.menu.itemArray;
    if(tmpItems.count == 0 || tmpItems.count == 1)
    {
        [_bAoakaMode.menu removeAllItems];
        [_bAoakaMode.menu addItemWithTitle:NSLocalizedStringFromTable(@"AoAkaModeCM", @"Preference", nil) action:nil keyEquivalent:@""];
        [_bAoakaMode.menu addItemWithTitle:NSLocalizedStringFromTable(@"AoAkaModeRB", @"Preference", nil) action:nil keyEquivalent:@""];
        [_bAoakaMode.menu addItem:[NSMenuItem separatorItem]];
        [_bAoakaMode.menu addItemWithTitle:NSLocalizedStringFromTable(@"AoAkaModeNone", @"Preference", nil) action:nil keyEquivalent:@""];
    }

    tmpItems = _saveLayer.menu.itemArray;
    if(tmpItems.count == 0 || tmpItems.count == 1)
    {
        [_saveLayer.menu removeAllItems];
        NSMenuItem *itemEnLayer = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTable(@"SaveLayerEnable", @"Preference", nil) action:nil keyEquivalent:@""];
        NSMenuItem *itemDisLayer = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTable(@"SaveLayerDisable", @"Preference", nil) action:nil keyEquivalent:@""];
        
        itemEnLayer.tag = 1;
        itemDisLayer.tag = 0;
        
        [_saveLayer.menu addItem:itemEnLayer];
        [_saveLayer.menu addItem:itemDisLayer];
    }
    
    tmpItems = _saveColor.menu.itemArray;
    if(tmpItems.count == 0 || tmpItems.count == 1)
    {
        [_saveColor.menu removeAllItems];
        NSMenuItem *itemEnColor = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTable(@"SaveColorEnable", @"Preference", nil) action:nil keyEquivalent:@""];
        NSMenuItem *itemEnGray = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTable(@"SaveGrayEnable", @"Preference", nil) action:nil keyEquivalent:@""];
        
        itemEnColor.tag = 1;
        itemEnGray.tag = 0;
        
        [_saveColor.menu addItem:itemEnColor];
        [_saveColor.menu addItem:itemEnGray];
    }
    
    tmpItems = _bSavePlace.menu.itemArray;
    if(tmpItems.count == 0 || tmpItems.count == 1)
    {
        [_bSavePlace.menu removeAllItems];
        [_bSavePlace.menu addItemWithTitle:NSLocalizedStringFromTable(@"SaveFilePlaceOLD", @"Preference", nil) action:nil keyEquivalent:@""];
        [_bSavePlace.menu addItemWithTitle:NSLocalizedStringFromTable(@"SaveFilePlaceNEW", @"Preference", nil) action:nil keyEquivalent:@""];
        [_bSavePlace.menu addItemWithTitle:NSLocalizedStringFromTable(@"SaveFilePlaceSelect", @"Preference", nil) action:nil keyEquivalent:@""];
    }

    tmpItems = _saveFormat.menu.itemArray;
    if(tmpItems.count == 0 || tmpItems.count == 1)
    {
        [_saveFormat.menu removeAllItems];
        NSMenuItem *itemPSD = [[NSMenuItem alloc] initWithTitle:@"PSD" action:nil keyEquivalent:@""];
        NSMenuItem *itemGIF = [[NSMenuItem alloc] initWithTitle:@"GIF" action:nil keyEquivalent:@""];
        NSMenuItem *itemPNG = [[NSMenuItem alloc] initWithTitle:@"PNG" action:nil keyEquivalent:@""];
        
        itemPSD.tag = (NSInteger)KZFileFormat::PSD_FORMAT;
        itemGIF.tag = (NSInteger)KZFileFormat::GIF_FORMAT;
        itemPNG.tag = (NSInteger)KZFileFormat::PNG_FORMAT;
        [_saveFormat.menu addItem:itemPSD];
        [_saveFormat.menu addItem:itemGIF];
        [_saveFormat.menu addItem:itemPNG];
    }
    
    _threthDiffSlider.doubleValue = 0;
    _threthDiffLabel.stringValue = @"0";
    _matchThrethSlider.doubleValue = 0;
    _matchThrethLabel.stringValue = @"0";
    _gapPixSlider.doubleValue = 0;
    _gapPixLabel.stringValue = @"0";
    _noiseReductionSlider.doubleValue = 0;
    NSString *noiseRedStr = NSLocalizedStringFromTable(@"NoizeReductionNone", @"Preference", nil);
    _noiseReductionLabel.stringValue = noiseRedStr;
    
    _adjustModePOC.state = NSOnState;
    _adjustModeFeature.state = NSOffState;
    
    // Diff View
    _backConsentrationSlider.doubleValue = 0;
    _backConsentrationLabel.stringValue = @"0";
    _backColorWell.color = [NSColor blackColor];
    
    _addColorWell.color = [NSColor redColor];
    _delColorWell.color = [NSColor blueColor];
    _diffColorWell.color = [NSColor greenColor];
    _addColorWell.enabled = YES;
    _delColorWell.enabled = YES;
    _diffColorWell.enabled = YES;
    
    
    _allAddColor.state = NSOffState;
    _allAddColor.enabled = YES;
    _allDelColor.state = NSOffState;
    _allDelColor.enabled = YES;
    _allDiffColor.state = NSOffState;
    _allDiffColor.enabled = YES;
    
    [_bDiffDispMode selectItemWithTitle:@""];
    [_bAoakaMode selectItemWithTitle:@""];
    _lineThicknessEdit.stringValue = @"0";
    _fillLine.state = NO;
    
    // Raster
    [_rasterColorMode selectCellWithTag:0];
    _rasterDpiSlider.doubleValue = 0;
    _rasterDpiLabel.stringValue = @"0";
    
    // File
    [_bSavePlace selectItemWithTitle:@""];
    KZFolderNameSource.sharedFolderNameSource.values = [NSMutableArray array];
    _folderSelect.dataSource = (id<NSComboBoxDataSource>)KZFolderNameSource.sharedFolderNameSource;
    _folderSelect.stringValue = @"";
    
    _setPrefix.stringValue = @"";
    _setSuffix.stringValue = @"";
    [_saveFormat selectItemWithTag:0];
    [_saveLayer selectItemWithTag:0];
    [_saveColor selectItemWithTag:0];
    _saveNoChange.state = NSOffState;
    
    // App
    _setThread.doubleValue = 1;
    _threadLabel.stringValue = @"1";
    _oHotFolderPath.stringValue = @"";
    _nHotFolderPath.stringValue = @"";
    _hotFolderSavePath.stringValue = @"";
    [_hotFolderSavePath.cell setPlaceholderString:NSLocalizedStringFromTable(@"ManualSavePlaceholder", @"MainUI", nil)];
    
    _btnIsTrashCompleteItem.state = 0;
    _btnIsStartFolderWakeOn.state = 0;
    _btnIsForceResize.state = 0;
    
}

- (void)appendUI
{
    [self initUI];
    // Diff
    _threthDiffSlider.doubleValue = _threthDiff;
    _threthDiffLabel.stringValue = [NSString stringWithFormat:@"%.0f",_threthDiff];
    _matchThrethSlider.doubleValue = _matchThresh;
    _matchThrethLabel.stringValue = [NSString stringWithFormat:@"%.0f",_matchThresh];
    _gapPixSlider.doubleValue = _gapPix;
    _gapPixLabel.stringValue = [NSString stringWithFormat:@"%.0f",_gapPix];
    _noiseReductionSlider.doubleValue = _noizeReduction;
    NSString *noiseRedStr = NSLocalizedStringFromTable(@"NoizeReductionNone", @"Preference", nil);
    switch ((int)_noizeReduction) {
        case 1:
            noiseRedStr = NSLocalizedStringFromTable(@"NoizeReductionLow", @"Preference", nil);
            break;
            
        case 2:
            noiseRedStr = NSLocalizedStringFromTable(@"NoizeReductionMid", @"Preference", nil);
            break;
            
        case 3:
            noiseRedStr = NSLocalizedStringFromTable(@"NoizeReductionHigh", @"Preference", nil);
            break;
        default:
            break;
    }
    _noiseReductionLabel.stringValue = noiseRedStr;
    if (_adjustMode == 0) {
        _adjustModePOC.state = NSOnState;
        _adjustModeFeature.state = NSOffState;
    }
    else if (_adjustMode == 1) {
        _adjustModePOC.state = NSOffState;
        _adjustModeFeature.state = NSOnState;
    }
    
    // Diff View
    _backConsentrationSlider.doubleValue = _backConsentration;
    _backConsentrationLabel.stringValue = [NSString stringWithFormat:@"%.0f",_backConsentration];
    _backColorWell.color = _backAlphaColor;
    
    _addColorWell.color = _addColor;
    _delColorWell.color = _delColor;
    _diffColorWell.color = _diffColor;
    
    if(_isAllAddColor)
    {
        _allAddColor.state = NSOnState;
        _allDelColor.state = NSOffState;
        _allDiffColor.state = NSOffState;
        _allAddColor.enabled = YES;
        _allDelColor.enabled = NO;
        _allDiffColor.enabled = NO;
        _addColorWell.enabled = YES;
        _delColorWell.enabled = NO;
        _diffColorWell.enabled = NO;
        
    }
    else if(_isAllDelColor)
    {
        _allAddColor.state = NSOffState;
        _allDelColor.state = NSOnState;
        _allDiffColor.state = NSOffState;
        _allAddColor.enabled = NO;
        _allDelColor.enabled = YES;
        _allDiffColor.enabled = NO;
        _addColorWell.enabled = NO;
        _delColorWell.enabled = YES;
        _diffColorWell.enabled = NO;
    }
    else if(_isAllDiffColor)
    {
        _allAddColor.state = NSOffState;
        _allDelColor.state = NSOffState;
        _allDiffColor.state = NSOnState;
        _allAddColor.enabled = NO;
        _allDelColor.enabled = NO;
        _allDiffColor.enabled = YES;
        _addColorWell.enabled = NO;
        _delColorWell.enabled = NO;
        _diffColorWell.enabled = YES;
    }

    [_bDiffDispMode selectItemWithTitle:_diffDispMode];
    [_bAoakaMode selectItemWithTitle:_aoAkaMode];
    _lineThicknessEdit.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)_lineThickness];
    _fillLine.state = (_isFillLine)? YES : NO;
    
    // Raster
    [_rasterColorMode selectCellWithTag:(_colorSpace == KZColorSpace::SRGB)? 1 : 0];
    _rasterDpiSlider.doubleValue = _rasterDpi;
    _rasterDpiLabel.stringValue = [NSString stringWithFormat:@"%.0f",_rasterDpi];
    _btnIsForceResize.state = _isForceResize;
    
    // File
    [_bSavePlace selectItemWithTitle:_makeFolderPlace];
    if (_folderNames.count != 0) {
        KZFolderNameSource.sharedFolderNameSource.values = [_folderNames mutableCopy];
        _folderSelect.stringValue = _makeFolderName;
    }
    if (EQ_STR(_makeFolderPlace, NSLocalizedStringFromTable(@"SaveFilePlaceSelect", @"Preference", nil))) {
        _folderSelect.stringValue = @"None";
        _makeFolderName = _folderSelect.stringValue;
        currentSelectFolderName = _makeFolderName;
    }
    
    _setPrefix.stringValue = _filePrefix;
    _setSuffix.stringValue = _fileSuffix;
    [_saveFormat selectItemWithTag:(NSInteger)_saveType];
    [_saveLayer selectItemWithTag:_isSaveLayered];
    [_saveColor selectItemWithTag:_isSaveColor];
    _saveNoChange.state = _isSaveNoChange;
    
    // App
    _setThread.doubleValue = _maxThread;
    _threadLabel.stringValue = [NSString stringWithFormat:@"%d",(int)_maxThread];
    _oHotFolderPath.stringValue = _oHotPath;
    _nHotFolderPath.stringValue = _nHotPath;
    _hotFolderSavePath.stringValue = _hotSavePath;
    if (NEQ_STR(_oHotFolderPath.stringValue, @"") && NEQ_STR(_nHotFolderPath.stringValue, @"")) {
        _btnIsTrashCompleteItem.enabled = YES;
        _btnIsTrashCompleteItem.state = _isTrashCompleteItem;
        _btnIsStartFolderWakeOn.enabled = YES;
        _btnIsStartFolderWakeOn.state = _isStartFolderWakeOn;
    }
    else {
        _btnIsTrashCompleteItem.enabled = NO;
        _btnIsTrashCompleteItem.state = NO;
        _btnIsStartFolderWakeOn.enabled = NO;
        _btnIsStartFolderWakeOn.state = NO;
    }
    
    
    
    
}

- (NSDictionary*)gatherUIData
{
    if (_adjustModeFeature.state == NSOnState)
        _adjustMode = 1;
    
    if (_adjustModePOC.state == NSOnState)
        _adjustMode = 0;
    return @{
             @"backConsentration" : [NSNumber numberWithDouble:_backConsentrationSlider.doubleValue],
             @"backAlphaColor" : _backColorWell.color,
             @"addColor" : _addColorWell.color,
             @"delColor" : _delColorWell.color,
             @"diffColor" : _diffColorWell.color,
             @"isAllAddColor" : [NSNumber numberWithBool:_allAddColor.state],
             @"isAllDelColor" : [NSNumber numberWithBool:_allDelColor.state],
             @"isAllDiffColor" : [NSNumber numberWithBool:_allDiffColor.state],
             @"aoAkaMode" : [_bAoakaMode selectedItem].title,
             @"diffDispMode" : [_bDiffDispMode selectedItem].title,
             @"colorSpace" : [NSNumber numberWithInt:(int)[_rasterColorMode selectedTag]],
             @"maxThread" : [NSNumber numberWithDouble:_setThread.doubleValue],
             @"rasterDpi" : [NSNumber numberWithDouble:_rasterDpiSlider.doubleValue],
             @"gapPix" : [NSNumber numberWithDouble:_gapPixSlider.doubleValue],
             @"noizeReduction" : [NSNumber numberWithDouble:_noiseReductionSlider.doubleValue],
             @"threthDiff" : [NSNumber numberWithDouble:_threthDiffSlider.doubleValue],
             @"matchThresh" : [NSNumber numberWithDouble:_matchThrethSlider.doubleValue],
             @"adjustMode" : [NSNumber numberWithInteger:_adjustMode],
             @"lineThickness" : [NSNumber numberWithUnsignedInt:(unsigned int)[[_lineThicknessEdit stringValue] intValue]],
             @"isFillLine" : [NSNumber numberWithBool:_fillLine.state],
             @"isSaveNoChange" : [NSNumber numberWithBool:_saveNoChange.state],
             @"folderNames" : KZFolderNameSource.sharedFolderNameSource.values,
             @"makeFolderName" : _folderSelect.stringValue,
             @"makeFolderPlace" : [_bSavePlace selectedItem].title,
             @"filePrefix" : _setPrefix.stringValue,
             @"fileSuffix" : _setSuffix.stringValue,
             @"saveType" : [NSNumber numberWithInt:(int)[_saveFormat selectedTag]],
             @"isSaveColor" : [NSNumber numberWithBool:[_saveColor selectedTag]],
             @"isSaveLayered" : [NSNumber numberWithBool:[_saveLayer selectedTag]],
             @"oldHotFolderPath" : _oHotFolderPath.stringValue,
             @"newHotFolderPath" : _nHotFolderPath.stringValue,
             @"hotFolderSavePath" : _hotFolderSavePath.stringValue,
             @"isTrashCompleteItem" : [NSNumber numberWithBool:_btnIsTrashCompleteItem.state],
             @"isStartFolderWakeOn" : [NSNumber numberWithBool:_btnIsStartFolderWakeOn.state],
             @"isForceResize" : [NSNumber numberWithBool:_btnIsForceResize.state],
             };
}


- (void)appendSettingFromUI
{
    KZSetting *s = KZSetting.sharedSetting;
    s.settingVal = [self gatherUIData];
}

- (void)appendUIFromSetting
{
    KZSetting *s = KZSetting.sharedSetting;

    _backConsentration = [s.settingVal[@"backConsentration"] doubleValue];
    _backAlphaColor = s.settingVal[@"backAlphaColor"];
    _addColor = s.settingVal[@"addColor"];
    _delColor = s.settingVal[@"delColor"];
    _diffColor = s.settingVal[@"diffColor"];
    _isAllAddColor = [s.settingVal[@"isAllAddColor"] boolValue];
    _isAllDelColor = [s.settingVal[@"isAllDelColor"] boolValue];
    _isAllDiffColor = [s.settingVal[@"isAllDiffColor"] boolValue];
    _aoAkaMode = s.settingVal[@"aoAkaMode"];
    _diffDispMode = s.settingVal[@"diffDispMode"];
    _colorSpace = (KZColorSpace)[s.settingVal[@"colorSpace"] intValue];
    _maxThread = [s.settingVal[@"maxThread"] doubleValue];
    _rasterDpi = [s.settingVal[@"rasterDpi"] doubleValue];
    _gapPix = [s.settingVal[@"gapPix"] doubleValue];
    _noizeReduction = [s.settingVal[@"noizeReduction"] doubleValue];
    _threthDiff = [s.settingVal[@"threthDiff"] doubleValue];
    _matchThresh = [s.settingVal[@"matchThresh"] doubleValue];
    _adjustMode = [s.settingVal[@"adjustMode"] intValue];
    _lineThickness = [s.settingVal[@"lineThickness"] unsignedIntegerValue];
    _isFillLine = [s.settingVal[@"isFillLine"] boolValue];
    _isSaveNoChange = [s.settingVal[@"isSaveNoChange"] boolValue];
    _folderNames = s.settingVal[@"folderNames"];
    _makeFolderName = s.settingVal[@"makeFolderName"];
    _makeFolderPlace = s.settingVal[@"makeFolderPlace"];
    _filePrefix = s.settingVal[@"filePrefix"];
    _fileSuffix = s.settingVal[@"fileSuffix"];
    _saveType = (KZFileFormat)[s.settingVal[@"saveType"] intValue];
    _isSaveColor = [s.settingVal[@"isSaveColor"] boolValue];
    _isSaveLayered = [s.settingVal[@"isSaveLayered"] boolValue];
    _oHotPath = (s.settingVal[@"oldHotFolderPath"])? s.settingVal[@"oldHotFolderPath"] : @"";
    _nHotPath = (s.settingVal[@"newHotFolderPath"])? s.settingVal[@"newHotFolderPath"] : @"";
    _hotSavePath = (s.settingVal[@"hotFolderSavePath"])? s.settingVal[@"hotFolderSavePath"] : @"";
    _isTrashCompleteItem = [s.settingVal[@"isTrashCompleteItem"] boolValue];
    _isStartFolderWakeOn = [s.settingVal[@"isStartFolderWakeOn"] boolValue];
    _isForceResize = [s.settingVal[@"isForceResize"] boolValue];
    [self appendUI];
}

- (NSDictionary*)getSettingChanged {
    KZSetting *s = KZSetting.sharedSetting;
    NSMutableDictionary *setVal = [s.settingVal mutableCopy];
    NSMutableDictionary *uiData = [[self gatherUIData] mutableCopy];
    NSMutableDictionary *result = NSMutableDictionary.dictionary;
    [setVal enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        id otherObj = uiData[key];
        
        if (![obj isEqual:otherObj]) {
            result[key] = obj;
        }
    }];
    return [result copy];
}

#pragma mark -
#pragma mark Action
- (IBAction)updatePreset:(id)sender
{
    NSString *curPreset = [[_bPreset selectedItem] title];
    [self appendSettingFromUI];
    KZSetting.sharedSetting.latestPreset = curPreset;

    [KZSetting saveToFile];
}

- (IBAction)selectPreset:(id)sender
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

- (IBAction)applySetting:(id)sender
{
    [self appendSettingFromUI];
}

- (IBAction)showAddPreset:(id)sender
{
    [_addPanel makeKeyAndOrderFront:nil];
}

- (IBAction)addPreset:(id)sender
{
    if([KZLibs isEqual:_addPresetName.stringValue compare:@""])
    {
        NSAlert *a = [[NSAlert alloc] init];
        [a setMessageText:NSLocalizedStringFromTable(@"PleaseEnterPreset", @"ErrorText", nil)];
        return;
    }
    
    if([KZLibs isEqual:_addPresetName.stringValue compare:@"Default"])
    {
        NSAlert *a = [[NSAlert alloc] init];
        [a setMessageText:NSLocalizedStringFromTable(@"PresetNameError", @"ErrorText", nil)];
        return;
    }
    [self appendSettingFromUI];
    NSString *addPresetName = [_addPresetName stringValue];
    KZSetting.sharedSetting.latestPreset = addPresetName;
    [KZSetting saveToFile];
    NSUInteger presetCount = _bPreset.itemArray.count;
    NSMenuItem *insertItem = [[NSMenuItem alloc] initWithTitle:addPresetName action:nil keyEquivalent:@""];
    insertItem.tag = presetCount + 1;
    [_addPanel close];
    KZSetting.sharedSetting.presetNames = [KZSetting getPresetNames];

}

- (IBAction)delPreset:(id)sender
{
    NSString *removeName = [_bPreset selectedItem].title;
    NSString *nextPreset = @"";
    NSUInteger removeIdx = _bPreset.selectedTag;
    NSUInteger presetCount = _bPreset.itemArray.count;
    [_bPreset removeItemWithTitle:removeName];
    if (presetCount - 1 == removeIdx) {
        [_bPreset selectItemWithTag:_bPreset.itemArray.count];
    }
    else {
        [_bPreset selectItemWithTag:removeIdx + 1];
    }
    nextPreset = _bPreset.selectedItem.title;
    [KZSetting removePreset:removeName nextPreset:nextPreset];
    
}

- (void)AddButton:(BOOL)isEnabled
{
    if(isEnabled)
    {
        _isAllAddColor = YES;
        _allDelColor.enabled = NO;
        _allDiffColor.enabled = NO;
        _delColorWell.enabled = NO;
        _diffColorWell.enabled = NO;
    }
    else
    {
        _isAllAddColor = NO;
        _allDelColor.enabled = YES;
        _allDiffColor.enabled = YES;
        _delColorWell.enabled = YES;
        _diffColorWell.enabled = YES;
    }
}

- (void)DelButton:(BOOL)isEnabled
{
    if(isEnabled)
    {
        _isAllDelColor = YES;
        _allAddColor.enabled = NO;
        _allDiffColor.enabled = NO;
        _addColorWell.enabled = NO;
        _diffColorWell.enabled = NO;
    }
    else
    {
        _isAllDelColor = NO;
        _allAddColor.enabled = YES;
        _allDiffColor.enabled = YES;
        _addColorWell.enabled = YES;
        _diffColorWell.enabled = YES;
    }
}

- (void)DiffButton:(BOOL)isEnabled
{
    if(isEnabled)
    {
        _isAllDiffColor = YES;
        _allAddColor.enabled = NO;
        _allDelColor.enabled = NO;
        _addColorWell.enabled = NO;
        _delColorWell.enabled = NO;
    }
    else
    {
        _isAllDiffColor = NO;
        _allAddColor.enabled = YES;
        _allDelColor.enabled = YES;
        _addColorWell.enabled = YES;
        _delColorWell.enabled = YES;
    }
}

- (void)AdjustPOCButton:(BOOL)isEnabled
{
    if(isEnabled)
    {
        _adjustMode = 0;
        _adjustModePOC.state = NSOnState;
        _adjustModeFeature.state = NSOffState;
    }
    else
    {
        _adjustMode = 1;
        _adjustModePOC.state = NSOffState;
        _adjustModeFeature.state = NSOnState;
    }
}

- (void)AdjustFeatureButton:(BOOL)isEnabled
{
    if(isEnabled)
    {
        _adjustMode = 1;
        _adjustModePOC.state = NSOffState;
        _adjustModeFeature.state = NSOnState;
    }
    else
    {
        _adjustMode = 0;
        _adjustModePOC.state = NSOnState;
        _adjustModeFeature.state = NSOffState;
    }
}

- (IBAction)allAddColor:(id)sender
{
    NSButton *btn = (NSButton*)sender;
    [self AddButton:(btn.state == NSOnState)];
}

- (IBAction)allDelColor:(id)sender
{
    NSButton *btn = (NSButton*)sender;
    [self DelButton:(btn.state == NSOnState)];
}

- (IBAction)allDiffColor:(id)sender
{
    NSButton *btn = (NSButton*)sender;
    [self DiffButton:(btn.state == NSOnState)];
}

- (IBAction)chgBackColorMode:(id)sender
{
    NSMatrix *mtx = (NSMatrix*)sender;
    if ([KZLibs isEqual:[mtx identifier] compare:@"rasterColor"])
    {
        NSInteger tag = [[mtx selectedCell] tag];
        if(tag == 0)
        {
            _colorSpace = KZColorSpace::SRGB;
        }
        else
        {
            _colorSpace = KZColorSpace::GRAY;
        }
    }
}

- (IBAction)selectSaveFolder:(id)sender
{
    NSPopUpButton *b = sender;

    if (EQ_STR(b.title, NSLocalizedStringFromTable(@"SaveFilePlaceSelect", @"Preference", nil))) {
        _folderSelect.stringValue = @"None";
        _makeFolderName = _folderSelect.stringValue;
        currentSelectFolderName = _makeFolderName;
    }
}

- (IBAction)selectSaveType:(id)sender
{
    NSPopUpButton *b = sender;
    if (EQ_STR(b.title, @"PNG")) {
        [_saveLayer selectItemWithTag:NO];
    }
}

- (IBAction)openNewHotFolder:(id)sender
{
    NSArray *paths = [KZLibs openFileDialog:NSLocalizedStringFromTable(@"OpenFolderDialogTitle", @"MainUI", nil) multiple:NO selectFile:NO selectDir:YES];
    NSString *path = nil;
    if(paths.count == 0) path = @"";
    else path = paths[0];
    _nHotFolderPath.stringValue = path;
}

- (IBAction)openOldHotFolder:(id)sender
{
    NSArray *paths = [KZLibs openFileDialog:NSLocalizedStringFromTable(@"OpenFolderDialogTitle", @"MainUI", nil) multiple:NO selectFile:NO selectDir:YES];
    NSString *path = nil;
    if(paths.count == 0) path = @"";
    else path = paths[0];
    _oHotFolderPath.stringValue = path;
}

- (IBAction)openSaveFolder:(id)sender
{
    NSArray *paths = [KZLibs openFileDialog:NSLocalizedStringFromTable(@"OpenFileDialogTitle", @"MainUI", nil) multiple:NO selectFile:NO selectDir:YES];
    NSString *path = nil;
    if(paths.count == 0) path = @"";
    else path = paths[0];
    _hotFolderSavePath.stringValue = path;
}

- (IBAction)startHotFolder:(id)sender
{
    KZHotFolderController *hot = KZHotFolderController.sharedHotFolder;
    if (hot.isRunning == [NSNumber numberWithBool:NO])
        [hot startHotFolder];
}
- (IBAction)stoptHotFolder:(id)sender
{
    KZHotFolderController *hot = KZHotFolderController.sharedHotFolder;
    if (hot.isRunning == [NSNumber numberWithBool:YES])
        [hot stopHotFolder];
}

- (IBAction)selectPOC:(id)sender
{
    NSButton *btn = (NSButton*)sender;
    [self AdjustPOCButton:(btn.state == NSOnState)];
}

- (IBAction)selectFeature:(id)sender
{
    NSButton *btn = (NSButton*)sender;
    [self AdjustFeatureButton:(btn.state == NSOnState)];
}

#pragma mark -
#pragma mark Delegates

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
    _makeFolderName = [notification.object stringValue];
}

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
{
    if (EQ_STR(control.identifier, @"makeFolderName")) {
        currentSelectFolderName = [control stringValue];
    }
    else {
        if (NEQ_STR(_oHotFolderPath.stringValue, @"") && NEQ_STR(_nHotFolderPath.stringValue, @"")) {
            _btnIsTrashCompleteItem.enabled = YES;
            _btnIsStartFolderWakeOn.enabled = YES;
        }
        else {
            _btnIsTrashCompleteItem.enabled = NO;
            _btnIsTrashCompleteItem.state = NO;
            _btnIsStartFolderWakeOn.enabled = NO;
            _btnIsStartFolderWakeOn.state = NO;
        }
    }
    return YES;
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    if (EQ_STR(control.identifier, @"makeFolderName")) {
        NSMutableArray *tmp = KZFolderNameSource.sharedFolderNameSource.values;
        if([KZLibs isEqual:[control stringValue] compare:@""])
        {
            // Delete Item
            [tmp removeObject:currentSelectFolderName];
            _folderNames = [tmp copy];
            KZFolderNameSource.sharedFolderNameSource.values = [_folderNames mutableCopy];
            if(tmp.count == 0)
            {
                _makeFolderName = @"";
            }
            else
            {
                _makeFolderName = KZFolderNameSource.sharedFolderNameSource.values[0];
            }
        }
        else
        {
            // Add Item
            [tmp addObject:[control stringValue]];
            _folderNames = [KZLibs distinctArray:[tmp copy]];
            KZFolderNameSource.sharedFolderNameSource.values = [_folderNames mutableCopy];
            _makeFolderName = [control stringValue];
            currentSelectFolderName = _makeFolderName;
        }
    }
    else {
        if (NEQ_STR(_oHotFolderPath.stringValue, @"") && NEQ_STR(_nHotFolderPath.stringValue, @"")) {
            _btnIsTrashCompleteItem.enabled = YES;
            _btnIsStartFolderWakeOn.enabled = YES;
        }
        else {
            _btnIsTrashCompleteItem.enabled = NO;
            _btnIsTrashCompleteItem.state = NO;
            _btnIsStartFolderWakeOn.enabled = NO;
            _btnIsStartFolderWakeOn.state = NO;
        }
    }
    return YES;
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
    
    [_bPreset.menu removeAllItems];
    for (int i = 0; i < list.count; i++) {
        NSMenuItem *insertItem = [[NSMenuItem alloc] initWithTitle:list[i] action:nil keyEquivalent:@""];
        insertItem.tag = i;
        [_bPreset.menu addItem:insertItem];
    }
    
    [_bPreset selectItemWithTitle:KZSetting.sharedSetting.latestPreset];
}

- (void)onChangeLatestPreset:(id)obj keyPath:(NSString*)keyPath change:(NSDictionary*)change
{
    NSString *latest = change[@"new"];
    [_bPreset selectItemWithTitle:latest];
    [self appendUIFromSetting];
    [self appendSettingFromUI];
}

@end
