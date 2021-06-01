//
//  KZSetting.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/01.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZSetting.h"
#import "KZSettingLoader.h"

@interface KZSetting()
+ (NSDictionary*)getColorDict:(NSColor*)color;
+ (NSColor*)getColor:(NSDictionary*)dic;
@end

@implementation KZSetting

#pragma mark -
#pragma mark Initialize

- (instancetype)init
{
    self = [super init];
    if(!self) return nil;
    _presetNames = @[];
    return self;
}

#pragma mark -
#pragma mark Local Func

+ (NSDictionary*)getColorDict:(NSColor*)color
{
    NSColor *tmpColor;
    NSDictionary *retDic;
    
    tmpColor = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    int rVal = (int)round(tmpColor.redComponent * 255);
    int gVal = (int)round(tmpColor.greenComponent * 255);
    int bVal = (int)round(tmpColor.blueComponent * 255);
    retDic = @{@"R": [NSNumber numberWithInt:rVal],
               @"G": [NSNumber numberWithInt:gVal],
               @"B": [NSNumber numberWithInt:bVal]};
    
    return retDic;
}

+ (NSColor*)getColor:(NSDictionary*)dic
{
    NSColor *tmpColor;

    tmpColor = [NSColor colorWithDeviceRed:[[dic objectForKey:@"R"] floatValue] / 255.0
                                     green:[[dic objectForKey:@"G"] floatValue] / 255.0
                                      blue:[[dic objectForKey:@"B"] floatValue] / 255.0
                                     alpha:1.0f];
    
    return tmpColor;
}

+ (void)convertColorDictToColor:(NSDictionary**)dict
{
    NSMutableDictionary *tmpDic = [*dict mutableCopy];
    NSColor *addColor = [KZSetting getColor:[*dict objectForKey:@"addColor"]];
    NSColor *delColor = [KZSetting getColor:[*dict objectForKey:@"delColor"]];
    NSColor *diffColor = [KZSetting getColor:[*dict objectForKey:@"diffColor"]];
    NSColor *backAlphaColor = [KZSetting getColor:[*dict objectForKey:@"backAlphaColor"]];
    [tmpDic removeObjectForKey:@"addColor"];
    [tmpDic removeObjectForKey:@"delColor"];
    [tmpDic removeObjectForKey:@"diffColor"];
    [tmpDic removeObjectForKey:@"backAlphaColor"];
    [tmpDic setObject:addColor forKey:@"addColor"];
    [tmpDic setObject:delColor forKey:@"delColor"];
    [tmpDic setObject:diffColor forKey:@"diffColor"];
    [tmpDic setObject:backAlphaColor forKey:@"backAlphaColor"];
    *dict = [tmpDic copy];
}

+ (void)convertColorToColorDict:(NSDictionary**)dict
{
    NSMutableDictionary *tmpDic = [*dict mutableCopy];
    NSDictionary *addColor = [KZSetting getColorDict:tmpDic[@"addColor"]];
    NSDictionary *delColor = [KZSetting getColorDict:tmpDic[@"delColor"]];
    NSDictionary *diffColor = [KZSetting getColorDict:tmpDic[@"diffColor"]];
    NSDictionary *backAlphaColor = [KZSetting getColorDict:tmpDic[@"backAlphaColor"]];
    [tmpDic setValue:addColor forKey:@"addColor"];
    [tmpDic setValue:delColor forKey:@"delColor"];
    [tmpDic setValue:diffColor forKey:@"diffColor"];
    [tmpDic setValue:backAlphaColor forKey:@"backAlphaColor"];
    *dict = [tmpDic copy];
}

#pragma mark -
#pragma mark Public Func
+ (instancetype)sharedSetting
{
    static KZSetting *_sharedSetting;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedSetting = [[KZSetting alloc] init];
    });
    return _sharedSetting;
}

+ (BOOL)loadFromPresetName:(NSString*)preset
{
    NSDictionary *settings = [KZSettingLoader loadSetting];
    if(settings)
    {
        BOOL isFoundPreset = NO;
        NSArray *arPresets = [settings allKeys];
        for(NSString *preset in arPresets)
        {
            if([KZLibs isEqual:preset compare:preset])
            {
                isFoundPreset = YES;
                break;
            }
            else if ([KZLibs isEqual:preset compare:@"latestPresetName"])
            {
                continue;
            }
        }
        
        if(isFoundPreset)
        {
            NSDictionary *tmp = [settings objectForKey:preset];
            [KZSetting convertColorDictToColor:&tmp];
            KZSetting.sharedSetting.settingVal = tmp;
        }
        else
        {
            Log(@"Nothing Preset!");
        }
        return isFoundPreset;
    }
    else
    {
        Log(@"Nothing Setting File!");
    }
    return NO;
}

+ (void)loadFromFile
{
    NSDictionary *settings = [KZSettingLoader loadSetting];
    BOOL isMakeDefault = YES;
    if(settings){
        NSString *latestPreset = [settings objectForKey:@"latestPresetName"];
        if(latestPreset)
        {
            KZSetting.sharedSetting.latestPreset = latestPreset;
            NSDictionary *setDict = [settings objectForKey:latestPreset];
            [KZSetting convertColorDictToColor:&setDict];
            KZSetting.sharedSetting.settingVal = setDict;
            isMakeDefault = NO;
        }
        else
        {
            Log(@"No Latest Preset!");
        }
        KZSetting.sharedSetting.presetNames = [self getPresetNames];
    }

    
    if(isMakeDefault)
    {
        NSDictionary *data = @{@"backConsentration": @80.0,
                               @"gapPix": @2.0,
                               @"noizeReduction": @1.0,
                               @"threthDiff": @69.0,
                               @"matchThresh": @97.0,
                               @"adjustMode" : @0,
                               @"lineThickness": @40U,
                               @"isFillLine": @NO,
                               @"isAllDiffColor": @YES,
                               @"isAllDelColor": @NO,
                               @"isAllAddColor": @NO,
                               @"addColor": [KZSetting getColorDict:[NSColor colorWithCalibratedRed:255.0 green:0.0 blue:0.0 alpha:0.0]],
                               @"delColor": [KZSetting getColorDict:[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:255.0 alpha:0.0]],
                               @"diffColor": [KZSetting getColorDict:[NSColor colorWithCalibratedRed:0 green:255.0 blue:0.0 alpha:0.0]],
                               @"backAlphaColor": [KZSetting getColorDict:NSColor.blackColor],
                               @"diffDispMode": NSLocalizedStringFromTable(@"DiffModeArround", @"Preference", nil),
                               @"aoAkaMode": NSLocalizedStringFromTable(@"AoAkaModeNone", @"Preference", nil),
                               @"rasterDpi": @168.0,
                               @"colorSpace": [NSNumber numberWithInt:(int)KZColorSpace::GRAY],
                               @"maxThread": @4.0,
                               @"isSaveNoChange": @YES,
                               @"folderNames": @[@"RIP後_比較", @"COMPARE", @"None"],
                               @"makeFolderName": @"RIP後_比較",
                               @"makeFolderPlace": NSLocalizedStringFromTable(@"SaveFilePlaceOLD", @"Preference", nil),
                               @"filePrefix": @"比較_",
                               @"fileSuffix": @"",
                               @"saveType": [NSNumber numberWithInt:(int)KZFileFormat::PSD_FORMAT],
                               @"isSaveLayered": @YES,
                               @"isSaveColor": @YES,
                               @"oldHotFolderPath": @"",
                               @"newHotFolderPath": @"",
                               @"hotFolderSavePath": @"",
                               @"isStartFolderWakeOn": @NO,
                               @"isTrashCompleteItem": @NO,
                               @"isForceResize": @NO,
                               };
        NSDictionary *saveDict = @{@"Default" : data};
        [KZSettingLoader saveSetting:@"Default" data:saveDict];
        [self convertColorDictToColor:&data];
        KZSetting.sharedSetting.settingVal = data;
        KZSetting.sharedSetting.latestPreset = @"Default";
        KZSetting.sharedSetting.presetNames = @[@"Default"];
    }
}

+ (void)saveToFile
{

    if([KZLibs isEqual:KZSetting.sharedSetting.latestPreset compare:@"Default"])
    {
        [self replaceLatestPresetNameOnly:KZSetting.sharedSetting.latestPreset];
        NSAlert *a = [[NSAlert alloc] init];
        [a setMessageText:NSLocalizedStringFromTable(@"PresetNameError", @"ErrorText", nil)];
        [a runModal];
        return;
    }
    NSDictionary *writeDic = [KZSetting.sharedSetting.settingVal copy];
    [self convertColorToColorDict:&writeDic];
    [KZSettingLoader saveSetting:KZSetting.sharedSetting.latestPreset
                            data:writeDic];
}

+ (void)removePreset:(NSString*)preset nextPreset:(NSString*)newPreset
{
    if([KZLibs isEqual:preset compare:@"Default"])
    {
        NSAlert *a = [[NSAlert alloc] init];
        [a setMessageText:NSLocalizedStringFromTable(@"PresetDeleteError", @"ErrorText", nil)];
        [a runModal];
        return;
    }
    [KZSettingLoader removeSetting:preset next:newPreset];
    KZSetting.sharedSetting.presetNames = [self getPresetNames];
    KZSetting.sharedSetting.latestPreset = newPreset;
}



+ (NSString*)convertToJSON
{
    NSError *error = nil;
    NSDictionary *writeDic = [KZSetting.sharedSetting.settingVal copy];
    [self convertColorToColorDict:&writeDic];
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:writeDic
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];
    if(error)
    {
        Log(error.description);
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (void)replaceLatestPresetNameOnly:(NSString*)name
{
    [KZSettingLoader replaceLatestPreset:name];
}

+ (NSString*)getLatestPreset
{
    NSDictionary *settings = [KZSettingLoader loadSetting];
    return settings[@"latestPresetName"];
}

+ (NSArray*)getPresetNames
{
    NSDictionary *settings = [KZSettingLoader loadSetting];
    NSMutableArray *arKeys = [settings.allKeys mutableCopy];
    for(NSString *preName in arKeys)
    {
        if([KZLibs isEqual:preName compare:@"latestPresetName"])
        {
            [arKeys removeObject:preName];
            break;
        }
    }
    return [arKeys copy];
}
@end
