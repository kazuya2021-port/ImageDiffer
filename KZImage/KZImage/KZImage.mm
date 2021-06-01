//
//  KZImage.m
//  KZImage
//
//  Created by 内山和也 on 2019/03/26.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

//#import "XmpSDK.h"

//#import "Exiv2Funcs.h"

#include "psd.hpp"
#import "VipsFuncs.h"
//#import "MagickFuncs.h"
#import "KZImage.h"
#import <KZLibs.h>

GMutex kzimg_lock;
 
#define RESPATH [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources"]

@interface ConvertSetting()
@property UInt16 magic;
@property KZFileFormat SourceFormat;
@property KZFileFormat TargetFormat;
@end

@implementation ConvertSetting
@end

@interface KZImage()
{
//    MagickFuncs *magick;
    VipsFuncs *vips;
    //Exiv2Funcs *exiv;
}
@end

@implementation KZImage

#define SUPPORT_SRC_EXT @[@"pdf", @"png", @"psd", @"gif", @"jpg", @"jpeg", @"tif", @"tiff", @"eps"]
#define SUPPORT_TRG_EXT @[@"png", @"psd", @"gif", @"jpg", @"jpeg", @"tif", @"tiff", @"pdf"]

#pragma mark -
#pragma mark Initialize

- (id)init
{
    self = [super init];
    if (self) {
        _isDeleteLastFiles = YES;
        _isModifyExtention = YES;
    }
    return self;
}

- (void)startEngine
{
//    magick = new MagickFuncs();
    vips = new VipsFuncs();
    
    NSBundle *mb = [NSBundle bundleForClass:NSClassFromString(@"KZImage")];
    NSString *path = [mb pathForResource:@"Info" ofType:@"plist"];
    vips->startEngine([[path stringByDeletingLastPathComponent] stringByDeletingLastPathComponent],
                      (__bridge void*)_delegate);
}

- (void)stopEngine
{
    NSLog(@"dealloc");
    vips->stopEngine();
    delete vips;
}

#pragma mark -
#pragma mark Internal Funcs

- (NSData*) imageConvert:(FILE*)srcData nsDataImg:(NSData*)srcDataD srcPath:(NSString*)srcPath page:(NSUInteger)page
                 trgPath:(NSString*)trgPath saveFileName:(NSString*)saveFileName format:(KZFileFormat)targetFormat size:(NSSize)trgSize trimSize:(double)trimSize setting:(ConvertSetting*)setting
{
    BOOL isOpenFile = NO;
    BOOL isSaveFile = NO;
    if (EQ_STR(srcPath, @"") || !srcPath) {
        if (srcData != nil) {
            if (![self beforeConvertCheckDataF:srcData format:targetFormat setting:setting]) {
                return nil;
            }
        }
        else {
            if (![self beforeConvertCheckData:srcDataD format:targetFormat setting:setting]) {
                return nil;
            }
        }
    }
    else {
        isOpenFile = YES;
        if (![self beforeConvertChecks:srcPath format:targetFormat setting:setting]) {
            return nil;
        }
    }
    
    if (NEQ_STR(trgPath, @"") || trgPath) {
        isSaveFile = YES;
    }
    
    NSData* retData = nil;
    BOOL isResize = setting.isResize;
    
    NSString *savePath = nil;
    
    if (isSaveFile) {
        if (![NSFileManager.defaultManager fileExistsAtPath:trgPath]) {
            NSError *error = nil;
            [NSFileManager.defaultManager createDirectoryAtPath:trgPath withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) {
                LogF(@"Create Save Folder Error : %@", error.description);
                return nil;
            }
        }
        
        NSString *saveExt = [self getExtFromFormat:targetFormat];
        
        if (isOpenFile) {
            if (setting.SourceFormat == KZFileFormat::PDF_FORMAT) {
                saveFileName = [NSString stringWithFormat:@"%@ %lu.%@",saveFileName, page, saveExt];
            }
            else {
                saveFileName = [NSString stringWithFormat:@"%@.%@",saveFileName, saveExt];
            }
        }
        else {
            saveFileName = [NSString stringWithFormat:@"%@.%@",saveFileName, saveExt];
        }
        
        
        savePath = [trgPath stringByAppendingPathComponent:saveFileName];
        
        BOOL isMainThread = [NSThread.currentThread isMainThread];
        
        if ([NSFileManager.defaultManager fileExistsAtPath:savePath]) {
            if (isMainThread) {
                NSAlert *al = [[NSAlert alloc] init];
                al.messageText = @"既にファイルが存在しています。削除しますか？";
                __block BOOL ok;
                [al beginSheetModalForWindow:[KZLibs getMainWindow] completionHandler:^(NSModalResponse returnCode) {
                    if (returnCode == NSModalResponseCancel) {
                        ok = NO;
                    }
                    else {
                        ok = YES;
                    }
                }];
                
                if (ok) {
                    [NSFileManager.defaultManager trashItemAtURL:[NSURL fileURLWithPath:savePath] resultingItemURL:nil error:nil];
                }
                else {
                    return nil;
                }
            }
            else {
                [NSFileManager.defaultManager trashItemAtURL:[NSURL fileURLWithPath:savePath] resultingItemURL:nil error:nil];
            }
        }
    }
    
    if (setting.SourceFormat == KZFileFormat::PDF_FORMAT || setting.SourceFormat == KZFileFormat::EPS_FORMAT) {
        vips->setPdfScale(setting.Resolution / 72.0);
        isResize = NO;
    }
    
    try {

        if (isSaveFile) {
            if (isOpenFile) {
                retData = vips->imageConvert(NULL, srcPath.UTF8String, setting.SourceFormat, (uint)page,
                                             savePath.UTF8String, setting.TargetFormat, setting.toSpace, setting.Resolution, trgSize.width, trgSize.height, -1, setting.isForceAdjustSize, isResize, trimSize);
            }
            else {
                if (!srcDataD) {
                    retData = vips->imageConvert(srcData, NULL, setting.SourceFormat, (uint)page,
                                                 savePath.UTF8String, setting.TargetFormat, setting.toSpace, setting.Resolution, trgSize.width, trgSize.height, -1, setting.isForceAdjustSize, isResize);
                }
                else {
                    retData = vips->imageConvertD(srcDataD, NULL, setting.SourceFormat, (uint)page,
                                                 savePath.UTF8String, setting.TargetFormat, setting.toSpace, setting.Resolution, trgSize.width, trgSize.height, -1, setting.isForceAdjustSize, isResize);
                }
            }
            
            if (setting.TargetFormat == KZFileFormat::JPG_FORMAT) {
                [self editJFIF:savePath resolution:setting.Resolution];
            }
        }
        else {
            if (isOpenFile) {
                retData = vips->imageConvert(NULL, srcPath.UTF8String, setting.SourceFormat, (uint)page,
                                             NULL, setting.TargetFormat, setting.toSpace, setting.Resolution, trgSize.width, trgSize.height, -1,setting.isForceAdjustSize, isResize, trimSize);
            }
            else {
                if (!srcDataD) {
                    retData = vips->imageConvert(srcData, NULL, setting.SourceFormat, (uint)page,
                                                 NULL, setting.TargetFormat, setting.toSpace, setting.Resolution, trgSize.width, trgSize.height, -1,setting.isForceAdjustSize, isResize);
                }
                else {
                    retData = vips->imageConvertD(srcDataD, NULL, setting.SourceFormat, (uint)page,
                                                 NULL, setting.TargetFormat, setting.toSpace, setting.Resolution, trgSize.width, trgSize.height, -1,setting.isForceAdjustSize, isResize);
                }
            }
            
            if (setting.TargetFormat == KZFileFormat::JPG_FORMAT) {
                [self editJFIFData:&retData resolution:setting.Resolution];
            }
        }
        
    }
    catch (NSException *ex) {
        LogF(@"Image Edit Error! : %@", ex.description);
        return nil;
    }

    return retData;
}

// Use Only vips made JPEG
- (BOOL)editJFIF:(NSString*)imgPath resolution:(int)reso
{
    FILE* fp = fopen(imgPath.UTF8String, "rb+");
    
    if (fp == NULL) {
        return NO;
    }
    long unit_pos = 13;
    fseek(fp, unit_pos, SEEK_SET);
    char unit[1];
    unit[0] = 0x01; // inch
    
    fwrite(unit, sizeof(unit[0]), sizeof(unit), fp);
    
    char res[2];
    
    if (reso <= 0xFFFF) {
        CFByteOrder order = CFByteOrderGetCurrent();
        if (order == CFByteOrderLittleEndian) {
            res[0] = reso >> 8;
            res[1] = reso & 0xff;
        }
        else {
            res[1] = reso >> 8;
            res[0] = reso & 0xff;
        }
    }
    
    fwrite(res, sizeof(res[0]), sizeof(res), fp);
    fwrite(res, sizeof(res[0]), sizeof(res), fp);
    fclose(fp);
    return YES;
}

- (BOOL)editJFIFData:(NSData**)img resolution:(int)reso
{
    NSMutableData *tmp = [*img mutableCopy];
    char unit[1];
    unit[0] = 1; // inch

    [tmp replaceBytesInRange:NSMakeRange(13, 1) withBytes:unit length:1];
    
    char res[2];
    
    if (reso <= 0xFFFF) {
        CFByteOrder order = CFByteOrderGetCurrent();
        if (order == CFByteOrderLittleEndian) {
            res[0] = reso >> 8;
            res[1] = reso & 0xff;
        }
        else {
            res[1] = reso >> 8;
            res[0] = reso & 0xff;
        }
    }
    
    [tmp replaceBytesInRange:NSMakeRange(14, 2) withBytes:res length:2];
    [tmp replaceBytesInRange:NSMakeRange(16, 2) withBytes:res length:2];
    *img = [tmp copy];
    return YES;
}

+ (BOOL)checkFormat:(NSString*)imgPath magick:(UInt16*)magicNum format:(KZFileFormat*)format
{
    BOOL ret = NO;
    
    NSFileHandle* filehandle = [NSFileHandle fileHandleForReadingAtPath:imgPath];
    
    if (!filehandle) {
        return ret;
    }
    
    NSData* header = [filehandle readDataOfLength:8];
    
    if (!header || header.length == 0) {
        return ret;
    }
    NSString* headStr = nil;
    
    const NSStringEncoding * enc = [NSString availableStringEncodings];
    
    while (*enc) {
        headStr = [[NSString alloc] initWithData:header encoding:*enc];
        
        if (headStr) {
            break;
        }
        enc++;
    }
    
    if ([KZLibs isExistString:headStr searchStr:@"âPNG"]) {
        *format = KZFileFormat::PNG_FORMAT;
    }
    else if ([KZLibs isExistString:headStr searchStr:@"%PDF-"]) {
        *format = KZFileFormat::PDF_FORMAT;
    }
    else if ([KZLibs isExistString:headStr searchStr:@"GIF89"] ||
             [KZLibs isExistString:headStr searchStr:@"GIF87"]) {
        *format = KZFileFormat::GIF_FORMAT;
    }
    else if ([KZLibs isExistString:headStr searchStr:@"8BPS"] ||
             [KZLibs isExistString:headStr searchStr:@".PSD"]) {
        *format = KZFileFormat::PSD_FORMAT;
    }
    else if ([KZLibs isExistString:headStr searchStr:@"MM.*"] ||
             [KZLibs isExistString:headStr searchStr:@"II*\0"]) {
        *format = KZFileFormat::TIFF_FORMAT;
    }
    else if ([KZLibs isExistString:headStr searchStr:@"%!PS"]) {
        *format = KZFileFormat::EPS_FORMAT;
    }
    
    CFByteOrder order = CFByteOrderGetCurrent();
    [header getBytes:magicNum length:2];
    *magicNum = (order == CFByteOrderLittleEndian)? _OSSwapInt16(*magicNum) : *magicNum;

    if (*format == KZFileFormat::UNKNOWN_FORMAT) {
        // JPEG MagicNumber is 0xFFD8
        *format = (*magicNum == 65496)? KZFileFormat::JPG_FORMAT : KZFileFormat::UNKNOWN_FORMAT;
    }
    
    ret = (*format != KZFileFormat::UNKNOWN_FORMAT)? YES : NO;
    
    return ret;
}

+ (BOOL)checkFormatData:(NSData*)img magick:(UInt16*)magicNum format:(KZFileFormat*)format
{
    BOOL ret = NO;
    if (img == NULL) {
        return ret;
    }
    
    void *tmp = malloc(10);
    [img getBytes:tmp length:10];
    if (!tmp) {
        return ret;
    }
    
    NSData *header = [NSData dataWithBytes:tmp length:10];
    free(tmp);
    NSString* headStr = nil;
    const NSStringEncoding * enc = [NSString availableStringEncodings];
    
    while (*enc) {
        headStr = [[NSString alloc] initWithData:header encoding:*enc];
        
        if (headStr) {
            break;
        }
        enc++;
    }
    
    if ([KZLibs isExistString:headStr searchStr:@"âPNG"]) {
        *format = KZFileFormat::PNG_FORMAT;
    }
    else if ([KZLibs isExistString:headStr searchStr:@"%PDF-"]) {
        *format = KZFileFormat::PDF_FORMAT;
    }
    else if ([KZLibs isExistString:headStr searchStr:@"GIF89"] ||
             [KZLibs isExistString:headStr searchStr:@"GIF87"]) {
        *format = KZFileFormat::GIF_FORMAT;
    }
    else if ([KZLibs isExistString:headStr searchStr:@"8BPS"] ||
             [KZLibs isExistString:headStr searchStr:@".PSD"]) {
        *format = KZFileFormat::PSD_FORMAT;
    }
    else if ([KZLibs isExistString:headStr searchStr:@"MM.*"] ||
             [KZLibs isExistString:headStr searchStr:@"II*"]) {
        *format = KZFileFormat::TIFF_FORMAT;
    }
    else if ([KZLibs isExistString:headStr searchStr:@"%!PS"]) {
        *format = KZFileFormat::EPS_FORMAT;
    }
    
    CFByteOrder order = CFByteOrderGetCurrent();
    [header getBytes:magicNum length:2];
    *magicNum = (order == CFByteOrderLittleEndian)? _OSSwapInt16(*magicNum) : *magicNum;

    if (*format == KZFileFormat::UNKNOWN_FORMAT) {
        // JPEG MagicNumber is 0xFFD8
        *format = (*magicNum == 65496)? KZFileFormat::JPG_FORMAT : KZFileFormat::UNKNOWN_FORMAT;
    }
    
    ret = (*format != KZFileFormat::UNKNOWN_FORMAT)? YES : NO;
    
    return ret;
}

- (NSString*)getExtFromFormat:(KZFileFormat)format
{
    NSString *ext = nil;
    
    switch (format) {
        case KZFileFormat::PNG_FORMAT:
            ext = @"png";
            break;
        case KZFileFormat::PDF_FORMAT:
            ext = @"pdf";
            break;
        case KZFileFormat::GIF_FORMAT:
            ext = @"gif";
            break;
        case KZFileFormat::PSD_FORMAT:
            ext = @"psd";
            break;
        case KZFileFormat::TIFF_FORMAT:
            ext = @"tif";
            break;
        case KZFileFormat::JPG_FORMAT:
            ext = @"jpg";
            break;
        default:
            break;
    }
    return ext;
}

- (BOOL)modifyExtention:(NSString*)srcPath realExt:(KZFileFormat)format
{
    NSString *extention = [srcPath pathExtension];
    NSString *targetExt = [self getExtFromFormat:format];
    
    if (!targetExt) {
        return NO;
    }
    
    if (![KZLibs isEqual:extention compare:targetExt]) {
        if (_isModifyExtention) {
            NSString *makePath = [srcPath stringByReplacingOccurrencesOfString:extention withString:targetExt];
            NSError *er = nil;
            
            [[NSFileManager defaultManager] moveItemAtPath:srcPath toPath:makePath error:&er];
            
            if (er) {
                LogF(@"%@", er.description);
                return NO;
            }
        }
    }
    
    return YES;
}

- (BOOL)checkFileFormat:(NSString*)imgPath setting:(ConvertSetting*)setting
{
    KZFileFormat format = KZFileFormat::UNKNOWN_FORMAT;
    UInt16 mgk = 0;
    BOOL ret = [KZImage checkFormat:imgPath magick:&mgk format:&format];
    setting.magic = mgk;
    
    if (ret) {
        
        NSString *extention = [[imgPath pathExtension] lowercaseString];
        NSString *realExt = [self getExtFromFormat:format];
        
        if (NEQ_STR(extention, realExt)) {
            
            if (![self modifyExtention:imgPath realExt:format]) {
                ret = NO;
            }
        }
        else {
            setting.SourceFormat = format;
        }
    }
    
    return ret;
}

- (BOOL)checkDataFormat:(NSData*)img setting:(ConvertSetting*)setting
{
    KZFileFormat format = KZFileFormat::UNKNOWN_FORMAT;
    UInt16 mgk = 0;
    BOOL ret = [KZImage checkFormatData:img magick:&mgk format:&format];
    setting.magic = mgk;
    
    if (ret) {
        setting.SourceFormat = format;
    }
    
    return ret;
}


- (BOOL)checkSetting:(NSString*)imgPath setting:(ConvertSetting*)setting
{
    if (![self checkFileFormat:imgPath setting:setting]) {
        LogF(@"Unsupported Format!! MagicNumber=0x%lx",(unsigned long)setting.magic);
        return NO;
    }
    
    if (setting.Resolution <= 0) {
        LogF(@"Invalid Resolution %f dpi", setting.Resolution);
        return NO;
    }
    
    return YES;
}

- (BOOL)checkSettingData:(NSData*)img setting:(ConvertSetting*)setting
{
    if (![self checkDataFormat:img setting:setting]) {
        LogF(@"Unsupported Format!! MagicNumber=0x%lx",(unsigned long)setting.magic);
        return NO;
    }
    
    if (setting.Resolution <= 0) {
        LogF(@"Invalid Resolution %f dpi", setting.Resolution);
        return NO;
    }
    
    return YES;
}


- (BOOL)beforeConvertChecks:(NSString*)imgPath format:(KZFileFormat)targetFormat setting:(ConvertSetting*)setting
{
    BOOL retState = YES;
    retState = [self checkSetting:imgPath setting:setting];
    
    if (!retState) {
        return retState;
    }
    
    if (targetFormat == KZFileFormat::JPG_FORMAT ||
        targetFormat == KZFileFormat::PNG_FORMAT ||
        targetFormat == KZFileFormat::TIFF_FORMAT ||
        targetFormat == KZFileFormat::RAW_FORMAT ||
        targetFormat == KZFileFormat::PDF_FORMAT) {
        setting.TargetFormat = targetFormat;
    }
    else {
        retState = NO;
        LogF(@"Unsupported Convert To %@",[self getExtFromFormat:targetFormat]);
    }
    
    if (!retState) {
        return retState;
    }
    
    return retState;
}

- (BOOL)beforeConvertCheckData:(NSData*)img format:(KZFileFormat)targetFormat setting:(ConvertSetting*)setting
{
    BOOL retState = YES;
    retState = [self checkSettingData:img setting:setting];
    
    if (!retState) {
        return retState;
    }
    
    if (targetFormat == KZFileFormat::JPG_FORMAT ||
        targetFormat == KZFileFormat::PNG_FORMAT ||
        targetFormat == KZFileFormat::TIFF_FORMAT ||
        targetFormat == KZFileFormat::RAW_FORMAT ||
        targetFormat == KZFileFormat::PDF_FORMAT) {
        setting.TargetFormat = targetFormat;
    }
    else {
        retState = NO;
        LogF(@"Unsupported Convert To %@",[self getExtFromFormat:targetFormat]);
    }
    
    if (!retState) {
        return retState;
    }
    
    return retState;
}

- (BOOL)beforeConvertCheckDataF:(FILE*)img format:(KZFileFormat)targetFormat setting:(ConvertSetting*)setting
{
    
    char tmp[10];
    fread(tmp, 1, 10, img);
    NSData *d = [NSData dataWithBytes:tmp length:sizeof(tmp)];
    return [self beforeConvertCheckData:d format:targetFormat setting:setting];
}


#pragma mark -
#pragma mark Public Funcs
+ (NSArray*)isSupportedFiles
{
    return @[@"png", @"pdf", @"gif", @"psd", @"tif", @"tiff", @"jpg", @"jpeg"];
}

+ (BOOL)isSupported:(NSString*)imgPath
{
    UInt16 m;
    KZFileFormat f;
    return [self checkFormat:imgPath magick:&m format:&f];
}

- (NSData*)ImageConvertfromBuffer:(FILE*)img page:(NSUInteger)page format:(KZFileFormat)targetFormat size:(NSSize)trgSize setting:(ConvertSetting*)setting
{
    return [self imageConvert:img nsDataImg:nil srcPath:nil page:page trgPath:nil saveFileName:nil format:targetFormat size:trgSize trimSize:0 setting:setting];
}

- (NSData*)ImageConvertfromBufferData:(NSData*)img page:(NSUInteger)page format:(KZFileFormat)targetFormat size:(NSSize)trgSize setting:(ConvertSetting*)setting
{
    return [self imageConvert:nil nsDataImg:img srcPath:nil page:page trgPath:nil saveFileName:nil format:targetFormat size:trgSize trimSize:0 setting:setting];
}

- (NSData*)ImageConvertfrom:(NSString*)imgPath page:(NSUInteger)page format:(KZFileFormat)targetFormat size:(NSSize)trgSize trimSize:(double)trimSize setting:(ConvertSetting*)setting
{
    return [self imageConvert:nil nsDataImg:nil srcPath:imgPath page:page trgPath:nil saveFileName:nil format:targetFormat size:trgSize trimSize:0 setting:setting];
}

- (NSString*)ImageConvertfromBuffer:(FILE*)img to:(NSString*)toFolder format:(KZFileFormat)targetFormat size:(NSSize)trgSize saveFileName:(NSString*)saveFileName setting:(ConvertSetting*)setting
{
    NSData* retPath = [self imageConvert:img nsDataImg:nil srcPath:nil page:0 trgPath:toFolder saveFileName:saveFileName format:targetFormat size:trgSize trimSize:0 setting:setting];
    return [[NSString alloc] initWithData:retPath encoding:NSUTF8StringEncoding];
}

- (NSString*)ImageConvertfromBufferData:(NSData*)img to:(NSString*)toFolder format:(KZFileFormat)targetFormat size:(NSSize)trgSize saveFileName:(NSString*)saveFileName setting:(ConvertSetting*)setting
{
    NSData* retPath = [self imageConvert:nil nsDataImg:img srcPath:nil page:0 trgPath:toFolder saveFileName:saveFileName format:targetFormat size:trgSize trimSize:0 setting:setting];
    return [[NSString alloc] initWithData:retPath encoding:NSUTF8StringEncoding];
}

- (NSString*)ImageConvertfrom:(NSString*)imgPath page:(NSUInteger)page to:(NSString*)toFolder format:(KZFileFormat)targetFormat size:(NSSize)trgSize saveFileName:(NSString*)saveFileName trimSize:(double)trimSize setting:(ConvertSetting*)setting
{
    NSData* retPath = [self imageConvert:nil nsDataImg:nil srcPath:imgPath page:page trgPath:toFolder saveFileName:saveFileName format:targetFormat size:trgSize trimSize:trimSize setting:setting];
    return [[NSString alloc] initWithData:retPath encoding:NSUTF8StringEncoding];
}

- (NSSize)getPdfSize:(NSString*)imgPath
{
    std::pair<double, double> s = vips->getPdfSize([imgPath UTF8String], 0);
    NSSize retSize = NSMakeSize(s.first, s.second);
    return retSize;
}

- (NSSize)getImageSize:(NSString*)imgPath dpi:(int)dpi
{
    std::pair<double, double> s = vips->getImageSize([imgPath UTF8String], dpi);
    NSSize retSize = NSMakeSize(s.first, s.second);
    return retSize;
}

- (int)getImageDPI:(NSString*)imgPath
{
    return vips->getDPI(imgPath.UTF8String);
}


- (void)cropMentuke:(NSString*)imgPath menInfo:(NSArray*)info isSiagari:(BOOL)isSiagari savePath:(NSString*)savePath saveNames:(NSArray*)arNames
{
    FILE *fp = fopen(imgPath.UTF8String, "rb");
    vips->cropMentuke(fp, info, isSiagari, savePath.UTF8String, arNames, (__bridge void*)self);
}

- (NSData*)cropRect:(NSString*)imgPath rect:(NSRect)rect ratio:(float)ratio
{
    FILE *fp = fopen(imgPath.UTF8String, "rb");
    return vips->cropRect(fp, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height, ratio);
}

/*


- (BOOL)makePSDfromBufferDiff:(NSArray*)infos savePath:(NSString*)savePath setting:(ConvertSetting*)setting
{
    NSMutableArray *arImges = [@[] mutableCopy];
    NSMutableArray *arLabels = [@[] mutableCopy];
    
    for (NSDictionary *info in infos) {
        [arImges addObject:info[@"data"]];
        [arLabels addObject:info[@"label"]];
    }
    
    return magick->makePSD([arImges copy], [arLabels copy], savePath.UTF8String, setting.isSaveColor, setting.isSaveLayer, setting.Resolution, setting.Alpha);
}

- (BOOL)makePSDDiff:(NSArray*)infos savePath:(NSString*)savePath setting:(ConvertSetting*)setting
{
    NSMutableArray *arImges = [@[] mutableCopy];
    NSMutableArray *arLabels = [@[] mutableCopy];
    for (NSDictionary *info in infos) {
        [arImges addObject:info[@"data"]];
        [arLabels addObject:info[@"label"]];
    }
    
    return magick->makePSD([arImges copy], [arLabels copy], savePath.UTF8String, setting.isSaveColor, setting.isSaveLayer, setting.Resolution, setting.Alpha);
}
- (NSArray*)getLayerImageFrom:(NSString*)imgPath setting:(ConvertSetting*)setting
{
    return nil;
}*/


/*

 
 BOOL ret = YES;
 BOOL isPathName = [imgs[0] isKindOfClass:[NSString class]];
 BOOL isImage = [imgs[0] isKindOfClass:[NSImage class]];
 BOOL isData = [imgs[0] isKindOfClass:[NSData class]];
 
 NSMutableArray *tmpImgs = [NSMutableArray array];
 
 if (isPathName) {
 
 for (int i = 0; i < imgs.count; i++) {
 
 if ([[NSFileManager defaultManager] fileExistsAtPath:imgs[i]]) {
 NSImage *img;
 
 try {
 img = [[NSImage alloc] initWithContentsOfFile:imgs[i]];
 }
 catch (NSException *ex) {
 Log(ex.description);
 ret = NO;
 break;
 }
 [tmpImgs addObject:img];
 }
 else {
 ret = NO;
 LogF(@"Not exist file at : %@", imgs[i]);
 }
 }
 
 if(!ret) {
 return ret;
 }
 
 imgs = [tmpImgs copy];
 }
 else if (isImage) {
 //tmpImgs = [imgs mutableCopy];
 }
 else if (isData) {
 for (int i = 0; i < imgs.count; i++) {
 [tmpImgs addObject:[[NSImage alloc] initWithData:imgs[i]]];
 }
 imgs = [tmpImgs copy];
 }
 else {
 Log(@"Invalod Images");
 return NO;
 }
 
 NSUInteger kFrameCount = imgs.count;
 
 NSDictionary *fileProperties = @{(__bridge id)kCGImagePropertyGIFDictionary :
 @{(__bridge id)kCGImagePropertyGIFLoopCount : @0,
 }
 };
 NSURL *fileURL = [NSURL fileURLWithPath:savePath];
 
 CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)fileURL, kUTTypeGIF, kFrameCount, NULL);
 CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)fileProperties);
 NSDictionary *frameProperties = @{(__bridge id)kCGImagePropertyGIFDictionary :
 @{(__bridge id)kCGImagePropertyGIFDelayTime : @0.2f,}
 };
 
 for(NSUInteger i = 0; i < kFrameCount; i++) {
 
 @autoreleasepool {
 NSImage *image = [imgs objectAtIndex:i];
 CGImageRef ref = [image CGImageForProposedRect:NULL context:nil hints:nil];
 CGImageDestinationAddImage(destination, ref, (__bridge CFDictionaryRef)frameProperties);
 }
 }
 
 if(!CGImageDestinationFinalize(destination)) {
 Log(@"failed to finalize image destination");
 CFRelease(destination);
 return NO;
 }
 
 CFRelease(destination);
 
 NSMutableData *gif89Data = [NSMutableData dataWithContentsOfFile:savePath];
 char gif89 = '9';
 [gif89Data replaceBytesInRange:NSMakeRange(4, 1) withBytes:&gif89];
 
 [gif89Data writeToFile:savePath atomically:YES];*/

#pragma mark -
#pragma mark KZMagick

- (BOOL)makeGIFimgs:(NSArray*)imgs savePath:(NSString*)savePath delay:(NSUInteger)delay
{
    if (!imgs) return NO;
    if (imgs.count == 0) return NO;
    
    BOOL ret = YES;
    BOOL isPathName = [imgs[0] isKindOfClass:[NSString class]];
    BOOL isImage = [imgs[0] isKindOfClass:[NSImage class]];
    BOOL isData = [imgs[0] isKindOfClass:[NSData class]];
    
    NSMutableArray *tmpImgs = [NSMutableArray array];
    
    if (isPathName) {
        for (int i = 0; i < imgs.count; i++) {
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:imgs[i]]) {
                NSImage *img;
                
                try {
                    img = [[NSImage alloc] initWithContentsOfFile:imgs[i]];
                }
                catch (NSException *ex) {
                    Log(ex.description);
                    ret = NO;
                    break;
                }
                [tmpImgs addObject:img];
            }
            else {
                ret = NO;
                LogF(@"Not exist file at : %@", imgs[i]);
            }
        }
        
        if(!ret) {
            return ret;
        }
        
        imgs = [tmpImgs copy];
    }
    else if (isImage) {
        //tmpImgs = [imgs mutableCopy];
    }
    else if (isData) {
        for (int i = 0; i < imgs.count; i++) {
            [tmpImgs addObject:[[NSImage alloc] initWithData:imgs[i]]];
        }
        imgs = [tmpImgs copy];
    }
    else {
        Log(@"Invalod Images");
        return NO;
    }
    NSUInteger kFrameCount = imgs.count;
    
    NSDictionary *fileProperties = @{(__bridge id)kCGImagePropertyGIFDictionary :
                                         @{(__bridge id)kCGImagePropertyGIFLoopCount : @0,
                                           }
                                     };
    NSURL *fileURL = [NSURL fileURLWithPath:savePath];
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)fileURL, kUTTypeGIF, kFrameCount, NULL);
    CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)fileProperties);
    NSDictionary *frameProperties = @{(__bridge id)kCGImagePropertyGIFDictionary :
                                          @{(__bridge id)kCGImagePropertyGIFDelayTime : [NSNumber numberWithFloat:(float)delay / 10],}
                                      };
    
    for(NSUInteger i = 0; i < kFrameCount; i++) {
        
        @autoreleasepool {
            NSImage *image = [imgs objectAtIndex:i];
            CGImageRef ref = [image CGImageForProposedRect:NULL context:nil hints:nil];
            CGImageDestinationAddImage(destination, ref, (__bridge CFDictionaryRef)frameProperties);
        }
    }
    
    if(!CGImageDestinationFinalize(destination)) {
        Log(@"failed to finalize image destination");
        CFRelease(destination);
        return NO;
    }
    
    CFRelease(destination);
    
    NSMutableData *gif89Data = [NSMutableData dataWithContentsOfFile:savePath];
    char gif89 = '9';
    [gif89Data replaceBytesInRange:NSMakeRange(4, 1) withBytes:&gif89];
    
    [gif89Data writeToFile:savePath atomically:YES];

    return YES;
}

- (NSArray*)getLayerImageFrom:(NSString*)imgPath setting:(ConvertSetting*)setting
{
    if ([imgPath hasSuffix:@"psd"] || [imgPath hasSuffix:@"PSD"] ||
        [imgPath hasSuffix:@"psb"] || [imgPath hasSuffix:@"PSB"]) {
        
        NSMutableArray *arLays = [NSMutableArray array];
        
        Psd::PSD psd;
        psd.open([imgPath UTF8String]);
        long parseFlag = SKIP_COLOR_MODE_DATA | SKIP_LAYER_EXTRA_INFO;
        psd.parse(parseFlag);
        psd.get_layer_datas();
        
        setting.TargetFormat = KZFileFormat::PNG_FORMAT;
        setting.SourceFormat = KZFileFormat::RAW_FORMAT;
        
        for (PSDLayer l : psd.info.Layers) {
            NSData *raw = [[NSData alloc] initWithBytes:l.img.image_data length:l.img.image_size];
            NSString *layName = [NSString stringWithUTF8String:l.name.c_str()];
            NSData *png = vips->imageConvertD(raw, NULL, setting.SourceFormat, 0, NULL, setting.TargetFormat, setting.toSpace, setting.Resolution, psd.info.Width, psd.info.Height, l.img.channels, setting.isForceAdjustSize, false);
            NSDictionary *d = @{@"data":png,
                                @"name":layName};
            [arLays addObject:d];
        }
        return [arLays copy];
    }
    return nil;
}


static void make_alpha_blend(NSImage* src_img, NSImage *alpha_img, CGFloat alpha, NSData **outPng)
{
    NSData* tmp_rep = src_img.TIFFRepresentation;
    NSBitmapImageRep *tmp_imgrep = [NSBitmapImageRep imageRepWithData:tmp_rep];
    
    size_t width = tmp_imgrep.pixelsWide;
    size_t height = tmp_imgrep.pixelsHigh;
    size_t bpc = 8;
    size_t bpr = align16(4*width);
    size_t bufsize = bpr * height;
    if (bufsize == 0) {
        *outPng = nil;
        return;
    }
    uint8_t *bytes = (uint8_t *)malloc(bufsize);
    
    CGBitmapInfo binfo = kCGBitmapAlphaInfoMask & kCGImageAlphaPremultipliedFirst;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef sourceImage = [src_img CGImageForProposedRect:NULL context:nil hints:nil];
    CGImageRef destImage = [alpha_img CGImageForProposedRect:NULL context:nil hints:nil];
    
    CGContextRef context = CGBitmapContextCreate(bytes, width, height, bpc, bpr, colorSpace, binfo);
    CGContextClearRect(context, CGRectMake(0, 0, width, height));
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), sourceImage);
    CGContextSetAlpha(context, alpha);
    CGContextSetBlendMode(context, kCGBlendModeMultiply);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), destImage);
    CGContextRelease(context);
    context = NULL;
    
    CGDataProviderRef dataP = CGDataProviderCreateWithData(NULL, bytes, bufsize, bufferFree);
    size_t bpp = 32;
    CGImageRef image = CGImageCreate(width, height, bpc, bpp, bpr, colorSpace, binfo, dataP, NULL, NO, kCGRenderingIntentDefault);
    
    CGDataProviderRelease(dataP);
    dataP = NULL;
    CGColorSpaceRelease(colorSpace);
    colorSpace = NULL;
    NSImage *outImage = [[NSImage alloc] initWithCGImage:image size:NSMakeSize(width, height)];
    CGImageRelease(image);
    
    NSData* tifr =  outImage.TIFFRepresentation;
    NSBitmapImageRep *imgrep = [NSBitmapImageRep imageRepWithData:tifr];
    *outPng = [imgrep representationUsingType:NSPNGFileType properties:@{}];
//    mtx_kz.unlock();
}

static void bufferFree(void *info, const void *data, size_t size)
{
    free((void *)data);
}
static size_t align16(size_t size)
{
    if(size == 0)
        return 0;
    
    return (((size - 1) >> 4) << 4) + 16;
}

- (BOOL)makePSDDiff:(NSArray*)infos savePath:(NSString*)savePath topImg:(NSData*)topImg setting:(ConvertSetting*)setting
{
    std::vector<std::pair<const char*,PSDRawImage>> lays;
    setting.SourceFormat = KZFileFormat::PNG_FORMAT;
    setting.TargetFormat = KZFileFormat::RAW_FORMAT;
    
    NSImage *src_img;
    NSImage *alpha_img;
    float opaque = 0.0;
    for (NSDictionary *info_lay in infos) {
        float im_opaque = [info_lay[@"opaque"] floatValue];
        
        if (EQ_STR(info_lay[@"path"], @"") || !info_lay[@"path"]) {
            return NO;
        }
        else {
            if (![self beforeConvertChecks:info_lay[@"path"] format:KZFileFormat::RAW_FORMAT setting:setting]) {
                return NO;
            }
        }
        
        NSData *raw = vips->imageConvertD(NULL, [info_lay[@"path"] UTF8String], setting.SourceFormat, 0, NULL, KZFileFormat::RAW_FORMAT, setting.toSpace, setting.Resolution, 0, 0, 4, NO, false);
        
        if ([info_lay[@"isMerge"] compare:@YES] == NSOrderedSame) {
            //merged
            if (im_opaque == 1.0) {
                src_img = [[NSImage alloc] initWithContentsOfFile:info_lay[@"path"]];
            }
            else {
                opaque = [info_lay[@"opaque"] floatValue];
                alpha_img = [[NSImage alloc] initWithContentsOfFile:info_lay[@"path"]];
            }
        }
        
        PSDRawImage im;
        im.image_data = raw.bytes;
        im.image_size = raw.length;
        im.channels = vips->bands;
        im.width = vips->width;
        im.height = vips->height;
        im.resolution = vips->res;
        im.hasAlpha = true;
        im.opaque = (unsigned char)(im_opaque * 255.0);
        im.is_hidden = ([info_lay[@"isHidden"] boolValue])? true : false;
        
        switch (vips->space) {
            case KZColorSpace::GRAY:
                im.c_mode = 1;
                break;
                
            case KZColorSpace::SRGB:
                im.c_mode = 3;
                break;
                
            case KZColorSpace::CMYK:
                im.c_mode = 4;
                break;
                
            default:
                break;
        }
        
        im.depth = vips->depth;
        lays.push_back(std::pair<const char*,PSDRawImage>([info_lay[@"label"] UTF8String], im));
    }
    
    NSData *merged_data;
    make_alpha_blend(src_img, alpha_img, opaque, &merged_data);
    
    NSData *merged_raw = vips->imageConvertD(merged_data, NULL, KZFileFormat::PNG_FORMAT, 0, NULL, KZFileFormat::RAW_FORMAT, setting.toSpace, setting.Resolution, 0, 0, 4, NO, false);
    PSDRawImage merged;
    
    merged.image_data = merged_raw.bytes;
    merged.image_size = merged_raw.length;
    merged.channels = vips->bands;
    merged.width = vips->width;
    merged.height = vips->height;
    merged.resolution = vips->res;
    Psd::PSD psd;
    psd.save([savePath UTF8String], lays, merged);

    return YES;
}

- (BOOL)makePSDfromBufferDiff:(NSArray*)infos savePath:(NSString*)savePath setting:(ConvertSetting*)setting
{
    @synchronized(self) {
        std::vector<std::pair<const char*,PSDRawImage>> lays;
        
        NSImage *src_img;
        NSImage *alpha_img;
        float opaque = 0.0;
        for (NSDictionary *info_lay in infos) {
            float im_opaque = [info_lay[@"opaque"] floatValue];
            if (!info_lay[@"data"]) {
                return NO;
            }
            else {
                if (![self beforeConvertCheckData:info_lay[@"data"] format:KZFileFormat::RAW_FORMAT setting:setting]) {
                    return NO;
                }
            }
//            NSData *d = info_lay[@"data"];
//            [d writeToFile:@"/tmp/d.png" atomically:YES];
            NSData *raw = vips->imageConvertD(info_lay[@"data"], NULL, setting.SourceFormat, 0, NULL, KZFileFormat::RAW_FORMAT, setting.toSpace, setting.Resolution, 0, 0, 4, NO, false);
            if ([info_lay[@"isMerge"] compare:@YES] == NSOrderedSame) {
                //merged
                if (im_opaque == 1.0) {
                    src_img = [[NSImage alloc] initWithData:info_lay[@"data"]];
                }
                else {
                    opaque = [info_lay[@"opaque"] floatValue];
                    alpha_img = [[NSImage alloc] initWithData:info_lay[@"data"]];
                }
            }
            
            PSDRawImage im;
            im.image_data = raw.bytes;
            im.image_size = raw.length;
            im.channels = vips->bands;
            im.width = vips->width;
            im.height = vips->height;
            im.resolution = vips->res;
            im.hasAlpha = true;
            im.opaque = (unsigned char)(im_opaque * 255.0);
            im.is_hidden = ([info_lay[@"isHidden"] boolValue])? true : false;
            
            switch (vips->space) {
                case KZColorSpace::GRAY:
                    im.c_mode = 1;
                    break;
                    
                case KZColorSpace::SRGB:
                    im.c_mode = 3;
                    break;
                    
                case KZColorSpace::CMYK:
                    im.c_mode = 4;
                    break;
                    
                default:
                    break;
            }
            
            im.depth = vips->depth;
            lays.push_back(std::pair<const char*,PSDRawImage>([info_lay[@"label"] UTF8String], im));
        }
        
        NSData *merged_data;
        make_alpha_blend(src_img, alpha_img, opaque, &merged_data);
        //[merged_data writeToFile:@"/tmp/res.png" atomically:YES];
        NSData *merged_raw = vips->imageConvertD(merged_data, NULL, KZFileFormat::PNG_FORMAT, 0, NULL, KZFileFormat::RAW_FORMAT, setting.toSpace, setting.Resolution, 0, 0, 4, NO, false);
        
        PSDRawImage merged;
        merged.image_data = merged_raw.bytes;
        merged.image_size = merged_raw.length;
        merged.width = vips->width;
        merged.height = vips->height;
        merged.resolution = vips->res;
        switch (setting.toSpace) {
            case KZColorSpace::GRAY:
                merged.c_mode = 1;
                merged.channels = 2;
                break;
                
            case KZColorSpace::SRGB:
            case KZColorSpace::SRC:
                merged.c_mode = 3;
                merged.channels = vips->bands;
                break;
                
            case KZColorSpace::CMYK:
                merged.c_mode = 4;
                break;
                
            default:
                break;
        }
        Psd::PSD psd;
        psd.save([savePath UTF8String], lays, merged);
        
    }
    
    return YES;
}

#pragma mark -
#pragma mark Delegate From CropMentuke
- (void)cropApageStart:(const char*)savePath
{
    NSString* crop = [NSString stringWithUTF8String:savePath];
    [_delegate cropPageStart:crop];
}

- (void)cropApageDone:(const char*)croppedPath
{
    NSString* crop = [NSString stringWithUTF8String:croppedPath];
    [_delegate cropPageDone:crop];
}

@end
