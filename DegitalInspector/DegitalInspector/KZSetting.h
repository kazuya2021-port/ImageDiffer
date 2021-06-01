//
//  KZSetting.h
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/01.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface KZSetting : NSObject

+ (instancetype)sharedSetting;
+ (void)loadFromFile;
+ (BOOL)loadFromPresetName:(NSString*)preset;
+ (void)saveToFile;
+ (void)removePreset:(NSString*)preset nextPreset:(NSString*)newPreset;
+ (NSString*)convertToJSON;
+ (NSString*)getLatestPreset;
+ (NSArray*)getPresetNames;
+ (void)replaceLatestPresetNameOnly:(NSString*)name;
@property (nonatomic, copy) NSString *latestPreset;
@property (nonatomic, copy) NSArray *presetNames;
@property (nonatomic, copy) NSDictionary *settingVal;

@end
