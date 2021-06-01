//
//  DiffImgCV.m
//  DiffImgCV
//
//  Created by uchiyama_Macmini on 2018/12/20.
//  Copyright © 2018年 uchiyama_Macmini. All rights reserved.
//
#import <KZImage/ImageEnum.h>
#include "DiffImgCore.h"
#import "DiffImgCV.h"
#import <XMPTool/XMPTool.h>


@interface DiffImgCV()
{
    DiffImgCore *core;
    KZImage *imgUtil;
    ConvertSetting *imgSetting;
}
@end


@implementation DiffImgCV
- (id)init
{
    self = [super init];
    if (self) {
        core = new DiffImgCore();
        imgUtil = [[KZImage alloc] init];
        imgSetting = [[ConvertSetting alloc] init];
        [imgUtil startEngine];
    }
    return self;
}

#pragma mark -
#pragma mark Private Methods

- (NSArray*)getPages:(NSString*)pageStr
{
    NSMutableArray *retPages = [NSMutableArray array];
    NSArray *tmp = nil;
    if (!pageStr || EQ_STR(pageStr, @"")) return nil;
    
    if ([KZLibs isExistString:pageStr searchStr:@"-"]) { // contin
        tmp = [pageStr componentsSeparatedByString:@"-"];
        if (tmp.count == 2) {
            if ([KZLibs isOnlyDecimalNumber:tmp[0]] && [KZLibs isOnlyDecimalNumber:tmp[1]]) {
                int start = [tmp[0] intValue];
                int end = [tmp[1] intValue];
                for(int i = start - 1; i < end; i++) { // page is 0 start
                    [retPages addObject:[NSNumber numberWithInt:i]];
                }
            }
            else {
                LogF(@"Not Decimal Num : %@", pageStr);
                return nil;
            }
        }
        else {
            LogF(@"Invalid Page Range : %@", pageStr);
            return nil;
        }
    }
    else if ([KZLibs isExistString:pageStr searchStr:@"%"]) { // even
        tmp = [pageStr componentsSeparatedByString:@"%"];
        if (tmp.count == 2) {
            if ([KZLibs isOnlyDecimalNumber:tmp[0]] && [KZLibs isOnlyDecimalNumber:tmp[1]]) {
                int start = [tmp[0] intValue];
                int end = [tmp[1] intValue];
                for(int i = start - 1; i < end; i++) { // page is 0 start
                    if (i % 2 == 1) {
                        [retPages addObject:[NSNumber numberWithInt:i]];
                    }
                }
            }
            else {
                LogF(@"Not Decimal Num : %@", pageStr);
                return nil;
            }
        }
        else {
            LogF(@"Invalid Page Range : %@", pageStr);
            return nil;
        }
    }
    else if ([KZLibs isExistString:pageStr searchStr:@"/"]) { // odd
        tmp = [pageStr componentsSeparatedByString:@"/"];
        if (tmp.count == 2) {
            if ([KZLibs isOnlyDecimalNumber:tmp[0]] && [KZLibs isOnlyDecimalNumber:tmp[1]]) {
                int start = [tmp[0] intValue];
                int end = [tmp[1] intValue];
                for(int i = start - 1; i < end; i++) { // page is 0 start
                    if (i % 2 == 0) {
                        [retPages addObject:[NSNumber numberWithInt:i]];
                    }
                }
            }
            else {
                LogF(@"Not Decimal Num : %@", pageStr);
                return nil;
            }
        }
        else {
            LogF(@"Invalid Page Range : %@", pageStr);
            return nil;
        }
    }
    else if ([KZLibs isExistString:pageStr searchStr:@","]) { // multi
        tmp = [pageStr componentsSeparatedByString:@","];
        if (tmp.count != 0) {
            for(int i = 0; i < tmp.count; i++) {
                if ([KZLibs isOnlyDecimalNumber:tmp[i]]) {
                    [retPages addObject:[NSNumber numberWithInt:[tmp[i] intValue]]];
                }
                else {
                    LogF(@"Not Decimal Num : %@", pageStr);
                }
            }
        }else {
            LogF(@"Invalid Page Range : %@", pageStr);
            return nil;
        }
    }
    
    return [retPages copy];
}

- (NSString*)makeSaveName:(NSString*)fileName // not include extention
{
    std::string cur_file_name(fileName.UTF8String);
    
    if (core->setting.prefix == "") {
        if (core->setting.suffix == "") {
            cur_file_name = cur_file_name;
        }
        else {
            cur_file_name = cur_file_name + core->setting.suffix;
        }
    }
    else {
        cur_file_name = core->setting.prefix + cur_file_name;
        
        if (core->setting.suffix == "") {
            cur_file_name = cur_file_name;
        }
        else {
            cur_file_name = cur_file_name + core->setting.suffix;
        }
    }
    switch ((KZFileFormat)core->setting.saveType) {
        case KZFileFormat::PSD_FORMAT:
            cur_file_name = cur_file_name + ".psd";
            break;
            
        case KZFileFormat::GIF_FORMAT:
            cur_file_name = cur_file_name + ".gif";
            break;
            
        case KZFileFormat::PNG_FORMAT:
            cur_file_name = cur_file_name + ".png";
            break;
            
        default:
            break;
    }
    return [NSString stringWithCString:cur_file_name.c_str() encoding:NSUTF8StringEncoding];
}

- (NSString*)makeDiffFile:(NSString*)filename save:(NSString*)savePath infos:(NSDictionary*)infos
{
    NSData* oldImage = [infos objectForKey:@"oldImage"];
    NSData* newImage = [infos objectForKey:@"newImage"];
    NSData* diffImage = [infos objectForKey:@"diffImage"];
    NSData* blendImage = [infos objectForKey:@"blendImage"];

    NSString *saveFilePath = [savePath stringByAppendingPathComponent:[self makeSaveName:filename]];
    NSString *retPath = nil;
    NSString *fileType = nil;
    if ((KZFileFormat)core->setting.saveType == KZFileFormat::PSD_FORMAT) {
        if (![imgUtil makePSDfromBufferDiff:diffImage blend:blendImage low:oldImage mid:newImage savePath:saveFilePath setting:imgSetting]) {
            LogF(@"Make PSD Error : %@",saveFilePath);
        };
        retPath = saveFilePath;
        fileType = @"PSD";
    }
    else if ((KZFileFormat)core->setting.saveType == KZFileFormat::GIF_FORMAT) {
        NSArray *animeImg = @[oldImage, newImage];
        
        if (![imgUtil makeGIFimgs:animeImg savePath:saveFilePath]) {
            LogF(@"Make GIF Error : %@",saveFilePath);
        }
        NSString *fname = [[saveFilePath lastPathComponent] stringByDeletingPathExtension];
        
        [imgUtil ImageConvertfromBuffer:diffImage
                                     to:savePath
                                 format:KZFileFormat::PNG_FORMAT
                           saveFileName:fname
                                setting:imgSetting];
        
        retPath = saveFilePath;
        fileType = @"GIF";
        
    }
    else if ((KZFileFormat)core->setting.saveType == KZFileFormat::PNG_FORMAT) {
        // for Preview
        [imgUtil ImageConvertfromBuffer:diffImage
                                     to:savePath
                                 format:KZFileFormat::PNG_FORMAT
                           saveFileName:[KZLibs getFileName:saveFilePath]
                                setting:imgSetting];
        retPath = saveFilePath;
        fileType = @"PNG";
    }
    NSData *addC = [NSKeyedArchiver archivedDataWithRootObject:infos[@"addContours"]];
    NSData *delC = [NSKeyedArchiver archivedDataWithRootObject:infos[@"delContours"]];
    NSData *difC = [NSKeyedArchiver archivedDataWithRootObject:infos[@"diffContours"]];
    NSDictionary *xmp = @{@"addContours" : [addC base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength],
                          @"delContours" : [delC base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength],
                          @"diffContours" : [difC base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength],
                          };
    
    [XmpSDK writeXmpInfo:xmp imgPath:retPath fileType:fileType error:nil];
    NSArray* arIn = [XmpSDK getXmpInfo:retPath error:nil];
    
    NSString* pre_keyPath = @"xsdkEdit:";
    NSData *tmp;
    NSArray *ac, *dc, *dic;
    for (NSDictionary* d in arIn) {
        if (EQ_STR([pre_keyPath stringByAppendingString:@"addContours"], d[@"Path"])) {
            tmp = [[NSData alloc] initWithBase64EncodedString:d[@"Value"] options:NSDataBase64DecodingIgnoreUnknownCharacters];
            ac = [NSKeyedUnarchiver unarchiveObjectWithData:tmp];
        }
        else if (EQ_STR([pre_keyPath stringByAppendingString:@"delContours"], d[@"Path"])) {
            tmp = [[NSData alloc] initWithBase64EncodedString:d[@"Value"] options:NSDataBase64DecodingIgnoreUnknownCharacters];
            dc = [NSKeyedUnarchiver unarchiveObjectWithData:tmp];
        }
        else if (EQ_STR([pre_keyPath stringByAppendingString:@"diffContours"], d[@"Path"])) {
            tmp = [[NSData alloc] initWithBase64EncodedString:d[@"Value"] options:NSDataBase64DecodingIgnoreUnknownCharacters];
            dic = [NSKeyedUnarchiver unarchiveObjectWithData:tmp];
        }
    }

    core->test(dic);
    return retPath;
}


#pragma mark -
#pragma mark Private Methods

- (void)registerSetting:(NSString *)jsonObj
{
    core->registerSetting((char*)[jsonObj UTF8String]);
    
    imgSetting.toSpace = (KZColorSpace)core->setting.colorSpace;
    imgSetting.Resolution = (float)core->setting.rasterDpi;
    imgSetting.isSaveColor = core->setting.isSaveColor;
    imgSetting.isSaveLayer = core->setting.isSaveLayered;
    imgSetting.isResize = YES;
    imgSetting.Alpha = (core->setting.backConsentration / 100);
    
}

- (void)diffStart:(NSString*)src // OLD
           target:(NSString*)trg // NEW
             save:(NSString*)savePath // SAVEPATH not includes file
           object:(id)object // CallBack Object
     pageRangeOLD:(NSString*)pageRangeOLD // old page range
     pageRangeNEW:(NSString*)pageRangeNEW // new page range
{
    
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *error;
    NSString *saveCur = savePath;
    
    NSArray *arOldPages = [self getPages:pageRangeOLD];
    NSArray *arNewPages = [self getPages:pageRangeNEW];
    
    if (arNewPages.count != arOldPages.count) {
        LogF(@"Difference Page Count : old is %d new is %d", (int)arOldPages.count, (int)arNewPages.count);
        return;
    }
    
    if (![KZLibs isDirectory:savePath]) {
        //isSaveFile = YES;
        saveCur = [savePath stringByDeletingLastPathComponent];
    }
    
    if (![fm fileExistsAtPath:saveCur]) {
        [fm createDirectoryAtPath:saveCur withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    if (error) {
        Log(error.description);
        return;
    }
    
    for (int i = 0; i < arOldPages.count; i++) {
        if ([_delegate respondsToSelector:@selector(startConvert:imageFile:imagePage:)]) {
            [_delegate startConvert:object imageFile:src imagePage:arOldPages[i]];
        }
        NSMutableDictionary *retDic = nil;
        
        NSData *old_tmp = [imgUtil ImageConvertfrom:src
                                               page:[arOldPages[i] unsignedIntegerValue]
                                             format:KZFileFormat::TIFF_FORMAT
                                           trimSize:0 setting:imgSetting];
        
        if ([_delegate respondsToSelector:@selector(endConvert:imageFile:imagePage:)]) {
            [_delegate endConvert:object imageFile:src imagePage:arOldPages[i]];
        }
        
        if ([_delegate respondsToSelector:@selector(startConvert:imageFile:imagePage:)]) {
            [_delegate startConvert:object imageFile:trg imagePage:arNewPages[i]];
        }
        
        NSData *new_tmp = [imgUtil ImageConvertfrom:trg
                                               page:[arNewPages[i] unsignedIntegerValue]
                                             format:KZFileFormat::TIFF_FORMAT
                                           trimSize:0 setting:imgSetting];
        
        if ([_delegate respondsToSelector:@selector(endConvert:imageFile:imagePage:)]) {
            [_delegate endConvert:object imageFile:trg imagePage:arNewPages[i]];
        }
        
        if ([_delegate respondsToSelector:@selector(startInspect:imageFile:imagePage:)]) {
            [_delegate startInspect:object imageFile:trg imagePage:arNewPages[i]];
        }
        
        retDic = core->processBeforeAfter(old_tmp,
                                          new_tmp,
                                          nil,
                                          (__bridge void*)_delegate,
                                          (__bridge void*)object);
        
        if (!retDic) {
            return;
        }
        
        if ([_delegate respondsToSelector:@selector(endInspect:imageFile:imagePage:)]) {
            [_delegate endInspect:object imageFile:trg imagePage:arNewPages[i]];
        }
        
        BOOL isMakeDiffFile = NO;
        
        if (!core->setting.isSaveNoChange &&
            ([retDic[@"addContours"] count] != 0 || [retDic[@"delContours"] count] != 0 || [retDic[@"diffContours"] count] != 0)) {
            isMakeDiffFile = YES;
        }
        else if (core->setting.isSaveNoChange) {
            isMakeDiffFile = YES;
        }
        
        if(isMakeDiffFile)
        {
            NSString *savedFile = [self makeDiffFile:[KZLibs getFileName:trg] save:saveCur infos:retDic];
            
            // !!!!!ここでXMPメタデータ挿入!!!!!!
        }

    }
    
    if ([_delegate respondsToSelector:@selector(completeSaveFile:)]) {
        [_delegate completeSaveFile:object];
    }

    return;
}

+ (NSArray*)isSupported
{
    return [KZImage isSupportedFiles];
}

- (void)stopEngine
{
    [imgUtil stopEngine];
}
@end
