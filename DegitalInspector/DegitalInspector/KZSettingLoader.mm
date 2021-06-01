//
//  KZSettingLoader.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/01.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZSettingLoader.h"

@implementation KZSettingLoader

#pragma mark -
#pragma mark Local Func

+ (BOOL)isContainPresetName:(NSString*)name data:(NSDictionary*)savedSetting
{
    NSArray *keys = [savedSetting allKeys];
    BOOL isContainName = NO;

    for(NSString *preset in keys)
    {
        if([KZLibs isEqual:preset compare:name])
        {
            isContainName = YES;
            break;
        }
        else if ([KZLibs isEqual:preset compare:@"latestPresetName"])
        {
            continue;
        }
    }
    return isContainName;
}

#pragma mark -
#pragma mark Public Func

+ (NSDictionary*)loadSetting
{
    BOOL isValid = YES;
    NSDictionary *setting = nil;
    if([NSFileManager.defaultManager fileExistsAtPath:SETTING_PATH])
    {
        NSData *settingFile = [NSData dataWithContentsOfFile:SETTING_PATH];
        NSError *error = nil;
        setting = (NSDictionary*)[[NSJSONSerialization JSONObjectWithData:settingFile options:NSJSONReadingMutableContainers error:&error] copy];
        if(error)
        {
            Log(error.description);
            isValid = NO;
            
        }
        else if(![NSJSONSerialization isValidJSONObject:setting])
        {
            Log(@"Invalid JSON");
            isValid = NO;
        }
    }
    if(isValid)
    {
        return setting;
    }

    return nil;
}

+ (BOOL)saveSetting:(NSString*)name data:(NSDictionary*)data
{
    NSMutableDictionary *savedSetting = [[KZSettingLoader loadSetting] mutableCopy];
    if(savedSetting)
    {
        BOOL isContainName = [self isContainPresetName:name data:savedSetting];
        BOOL retVal = NO;
        
        @try {
            if(isContainName)
            {
                [savedSetting removeObjectForKey:name];
                [savedSetting setObject:data forKey:name];
            }
            else
            {
                [savedSetting setObject:data forKey:name];
            }
            [savedSetting setObject:name forKey:@"latestPresetName"];
            retVal = YES;
        }
        @catch (NSException *exception) {
            Log(exception.description);
            retVal = NO;
        }
        @finally
        {
            NSError *error = nil;
            if(retVal)
            {
                
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:savedSetting options:2 error:&error];
                if(error)
                {
                    Log(error.description);
                    return NO;
                }else
                {
                    [jsonData writeToFile:SETTING_PATH atomically:NO];
                }
            }

            return retVal;
        }
    }
    else
    {
        // No Setting
        NSError *error = nil;
        NSDictionary *writeDic = @{@"latestPresetName" : name,
                                   name : [data objectForKey:name]};
        
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:writeDic options:2 error:&error];
        if(error)
        {
            Log(error.description);
            return NO;
        }else
        {
            [jsonData writeToFile:SETTING_PATH atomically:NO];
        }
        return YES;
    }
}

+ (BOOL)removeSetting:(NSString*)name next:(NSString*)nextPreset
{
    NSMutableDictionary *savedSetting = [[KZSettingLoader loadSetting] mutableCopy];
    if(savedSetting)
    {
        BOOL isContainName = [self isContainPresetName:name data:savedSetting];
        BOOL retVal = NO;

        @try {
            if(isContainName)
            {
                [savedSetting removeObjectForKey:name];
            }
            [savedSetting setObject:nextPreset forKey:@"latestPresetName"];
            retVal = YES;
        }
        @catch (NSException *exception) {
            Log(exception.description);
            retVal = NO;
        }
        @finally
        {
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:savedSetting options:2 error:&error];
            if(error)
            {
                Log(error.description);
                return NO;
            }else
            {
                [jsonData writeToFile:SETTING_PATH atomically:NO];
            }
        }
        return retVal;
    }
    else
    {
        return NO;
    }
}

+ (BOOL)replaceLatestPreset:(NSString*)name
{
    NSMutableDictionary *savedSetting = [[KZSettingLoader loadSetting] mutableCopy];
    if(savedSetting)
    {
        BOOL isContainName = [self isContainPresetName:name data:savedSetting];
        BOOL retVal = NO;
        
        @try {
            if(isContainName)
            {
                savedSetting[@"latestPresetName"] = name;
            }
            retVal = YES;
        }
        @catch (NSException *exception) {
            Log(exception.description);
            retVal = NO;
        }
        @finally
        {
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:savedSetting options:2 error:&error];
            if(error)
            {
                Log(error.description);
                return NO;
            }else
            {
                [jsonData writeToFile:SETTING_PATH atomically:NO];
            }
        }
        return retVal;
    }
    else
    {
        return NO;
    }
}
@end
