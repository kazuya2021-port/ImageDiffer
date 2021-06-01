//
//  KZSettingLoader.h
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/01.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import <Foundation/Foundation.h>

#define SETTING_PATH [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/setting.json"]

@interface KZSettingLoader : NSObject

+ (NSDictionary*)loadSetting;
+ (BOOL)replaceLatestPreset:(NSString*)name;
+ (BOOL)saveSetting:(NSString*)name data:(NSDictionary*)data;
+ (BOOL)removeSetting:(NSString*)name next:(NSString*)nextPreset;

@end
