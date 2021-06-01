//
//  DiffImgCV.m
//  DiffImgCV
//
//  Created by uchiyama_Macmini on 2018/12/20.
//  Copyright © 2018年 uchiyama_Macmini. All rights reserved.
//
#include <time.h>
#include <opencv2/text.hpp>
//#include <opencv2/dnn.hpp>
#include <opencv2/features2d.hpp>

#include "parse_pdf.hpp"
#import <KZImage/ImageEnum.h>
#include "DiffImgCore.h"
#import "DiffImgCV.h"
#import <XMPTool/XMPTool.h>
#import "NSDataExt.h"



@interface DiffImgCV()
{
    DiffImgCore *core;
    PDFParser *parser;
    KZImage *imgUtil;
    ConvertSetting *imgSetting;
}
@property (nonatomic, assign) BOOL isManyDiff;
@end


@implementation DiffImgCV
- (id)init
{
    self = [super init];
    if (self) {
        core = new DiffImgCore();
        parser = new PDFParser();
        imgUtil = [[KZImage alloc] init];
        imgSetting = [[ConvertSetting alloc] init];
        [imgUtil startEngine];
//        setenv("OPENCV_IO_MAX_IMAGE_PIXELS", "18500000000", 1);
        _isManyDiff = NO;
    }
    return self;
}

#pragma mark -
#pragma mark Private Methods

/*- (std::vector<std::vector<std::vector<cv::Point>>>) clusterPoint:(std::vector<std::vector<std::vector<cv::Point>>>) areas
{
    std::vector<std::vector<std::vector<cv::Point>>> clust_areas;
    std::vector<cv::Rect> dbs_rects;
    std::vector<cv::Rect> rects;
    for(auto it = areas.begin(); it != areas.end(); ++it){
        for(auto jt = it->begin(); jt != it->end(); ++jt){
            dbs_rects.push_back(cv::boundingRect(*jt));
        }
    }
    util->rect_clustering(dbs_rects, rects, 10);
    
    for (int i = 0; i < rects.size(); i++) {
        cv::Rect focus = rects.at(i);
        std::vector<std::vector<cv::Point>> conts;
        for(auto it = areas.begin(); it != areas.end(); ++it){
            for(auto jt = it->begin(); jt != it->end(); ++jt){
                std::vector<cv::Point> cp;
                for(auto pt = jt->begin(); pt != jt->end(); ++pt){
                    if (focus.contains(*pt)) {
                        cp.push_back(*pt);
                    }
                }
                if (cp.size() != 0) conts.push_back(cp);
            }
        }
        if (conts.size() != 0) clust_areas.push_back(conts);
    }
    return clust_areas;
}
 */

- (BOOL)clusterDiffArea:(NSMutableDictionary**)info diffResult:(DiffImgCore::DiffResult&)res
{
    BOOL isNotWriteXMP = NO;
    NSMutableArray *arAddm = [NSMutableArray array];
    NSMutableArray *arDelm = [NSMutableArray array];
    NSMutableArray *arDiffm = [NSMutableArray array];
    
//    auto clust_add = [self clusterPoint:res.addAreas];
//    res.addAreas = clust_add;
//    auto clust_del = [self clusterPoint:res.delAreas];
//    res.delAreas = clust_del;
//    auto clust_diff = [self clusterPoint:res.diffAreas];
//    res.diffAreas = clust_diff;
    
    for(int i = 0; i < res.addAreas.size(); i++){
        isNotWriteXMP = NO;
        NSMutableArray *cnts = [NSMutableArray array];
        for (auto it = res.addAreas.at(i).begin(); it != res.addAreas.at(i).end(); ++it) {
            NSMutableArray *pts = [NSMutableArray array];
            for (auto ct = it->begin(); ct != it->end(); ++ct) {
                NSValue *value = [NSValue valueWithPoint:NSMakePoint(ct->x, ct->y)];
                [pts addObject:value];
            }
            [cnts addObject:pts];
        }
        [arAddm addObject:cnts];
    }
    for(int i = 0; i < res.delAreas.size(); i++){
        isNotWriteXMP = NO;
        NSMutableArray *cnts = [NSMutableArray array];
        for (auto it = res.delAreas.at(i).begin(); it != res.delAreas.at(i).end(); ++it) {
            NSMutableArray *pts = [NSMutableArray array];
            for (auto ct = it->begin(); ct != it->end(); ++ct) {
                NSValue *value = [NSValue valueWithPoint:NSMakePoint(ct->x, ct->y)];
                [pts addObject:value];
            }
            [cnts addObject:pts];
        }
        [arDelm addObject:cnts];
    }
    
    for(int i = 0; i < res.diffAreas.size(); i++){
        isNotWriteXMP = NO;
        NSMutableArray *cnts = [NSMutableArray array];
        for (auto it = res.diffAreas.at(i).begin(); it != res.diffAreas.at(i).end(); ++it) {
            NSMutableArray *pts = [NSMutableArray array];
            for (auto ct = it->begin(); ct != it->end(); ++ct) {
                NSValue *value = [NSValue valueWithPoint:NSMakePoint(ct->x, ct->y)];
                [pts addObject:value];
            }
            [cnts addObject:pts];
        }
        [arDiffm addObject:cnts];
    }
    
    [*info setObject:[arAddm copy] forKey:@"addContours"];
    [*info setObject:[arDelm copy] forKey:@"delContours"];
    [*info setObject:[arDiffm copy] forKey:@"diffContours"];
    return isNotWriteXMP;
}

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
                if (start == 0) {
                    LogF(@"start is zero : %d", start);
                    return nil;
                }
                
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
                if (start == 0) {
                    LogF(@"start is zero : %d", start);
                    return nil;
                }
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
                if (start == 0) {
                    LogF(@"start is zero : %d", start);
                    return nil;
                }
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
                    int registNum = [tmp[i] intValue] - 1;
                    if (registNum >= 0)
                        [retPages addObject:[NSNumber numberWithInt:registNum]];
                    else {
                        LogF(@"Minus Number : %@", pageStr);
                        return nil;
                    }
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
    else {
        if ([KZLibs isOnlyDecimalNumber:pageStr]) {
            int registNum = [pageStr intValue] - 1;
            if (registNum >= 0) {
                [retPages addObject:[NSNumber numberWithInt:registNum]];
            }
            else {
                LogF(@"Minus Number : %@", pageStr);
                return nil;
            }
        }
        else {
            LogF(@"Invalid Page Str : %@", pageStr);
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
    NSString *retPath = nil;
    
    NSData* oldImage = [infos objectForKey:@"oldImage"];
    NSData* newImage = [infos objectForKey:@"newImage"];
    NSData* diffImage = [infos objectForKey:@"diffImage"];
    NSData* blendImage = [infos objectForKey:@"blendImage"];
    NSData* mergeImage = [infos objectForKey:@"mergeImage"];
    
    NSString *saveFilePath = [savePath stringByAppendingPathComponent:[self makeSaveName:filename]];
    
    
    if ([NSFileManager.defaultManager fileExistsAtPath:saveFilePath])
        [NSFileManager.defaultManager removeItemAtPath:saveFilePath error:nil];
    
    bool isUseRedBlue = (strcmp(core->setting.aoAkaMode.c_str(), [NSLocalizedStringFromTable(@"AoAkaModeNone", @"Preference", nil) UTF8String]));
    bool isUseDiff = (strcmp(core->setting.diffDispMode.c_str(), [NSLocalizedStringFromTable(@"DiffModeNone", @"Preference", nil) UTF8String]));
    
    if ((KZFileFormat)core->setting.saveType == KZFileFormat::PSD_FORMAT) {
//        NSImage *ns_oldImage = [[NSImage alloc] initWithData:oldImage];
//        NSImage *ns_newImage = [[NSImage alloc] initWithData:newImage];
//        NSImage *ns_diffImage = [[NSImage alloc] initWithData:diffImage];
//
//        SFPSDWriter *psdWriter = [[SFPSDWriter alloc] initWithDocumentSize:NSSizeToCGSize(ns_oldImage.size)
//                                                             andResolution:imgSetting.Resolution
//                                                         andResolutionUnit:SFPSDResolutionUnitPPI];
//
//        [psdWriter addLayerWithCGImage:[ns_oldImage CGImageForProposedRect:NULL context:nil hints:nil]
//                               andName:@"比較元"
//                            andOpacity:1.0f
//                             andOffset:NSMakePoint(0, 0)];
//        [psdWriter addLayerWithCGImage:[ns_newImage CGImageForProposedRect:NULL context:nil hints:nil]
//                               andName:@"比較先"
//                            andOpacity:1.0f
//                             andOffset:NSMakePoint(0, 0)];
//        [psdWriter addLayerWithCGImage:[ns_diffImage CGImageForProposedRect:NULL context:nil hints:nil]
//                               andName:@"比較結果"
//                            andOpacity:(core->setting.backConsentration / 100)
//                             andOffset:NSMakePoint(0, 0)];
//
//        [psdWriter setColorProfile:SFPSDNoColorProfile];
//
//        NSError *error = nil;
//        NSData *psd = [psdWriter createPSDDataWithError:&error];
        
        
        // @"opaque"
        // @"data" @"isMerge" @"isHidden" @"label"
        
        // Checking for errors
        if (![imgUtil makePSDfromBufferDiff:@[
                                              @{@"opaque" : @1,
                                                @"data" : oldImage,
                                                @"isMerge" : @NO,
                                                @"isHidden" : @NO,
                                                @"label" : @"比較元"},
                                              @{@"opaque" : @1,
                                                @"data" : newImage,
                                                @"isMerge" : @YES,
                                                @"isHidden" : @NO,
                                                @"label" : @"比較先"},
                                              @{@"opaque" : [NSNumber numberWithFloat:(core->setting.backConsentration / 100)],
                                                @"data" : diffImage,
                                                @"isMerge" : @YES,
                                                @"isHidden" : @NO,
                                                @"label" : @"比較結果"},
                                              ] savePath:saveFilePath setting:imgSetting]) {
            NSLog(@"There was an error writing the PSD");
        }
//        [psd writeToFile:saveFilePath atomically:NO];
        retPath = saveFilePath;
        
    }
    else if ((KZFileFormat)core->setting.saveType == KZFileFormat::GIF_FORMAT) {
        NSArray *animeImg = nil;
        if (isUseDiff) {
            if (!isUseRedBlue) {
                animeImg = @[blendImage, oldImage, newImage];
            }
            else {
                animeImg = @[blendImage, oldImage, newImage, mergeImage];
            }
        }
        else {
            animeImg = @[mergeImage, oldImage, newImage];
        }
        
        if (![imgUtil makeGIFimgs:animeImg savePath:saveFilePath delay:50]) {
            LogF(@"Make GIF Error : %@",saveFilePath);
        }
        
        
        retPath = saveFilePath;
    }
    else if ((KZFileFormat)core->setting.saveType == KZFileFormat::PNG_FORMAT) {
        // for Preview
        ConvertSetting *p_setting = imgSetting;
        p_setting.isResize = NO;
        p_setting.isForceAdjustSize = NO;
        [imgUtil ImageConvertfromBufferData:blendImage
                                         to:savePath
                                     format:KZFileFormat::PNG_FORMAT
                                       size:NSMakeSize(0, 0)
                               saveFileName:[KZLibs getFileName:saveFilePath]
                                    setting:p_setting];
        
        retPath = saveFilePath;
    }
    
    return retPath;

}

enum class KZDiffError : int {
    NO_ERROR,
    NO_IMG,
    NOT_ADJUST,
    NOT_MATCH_SIZE,
};

- (KZDiffError)preProcessDiffSrc:(NSData*)src Trg:(NSData*)trg outSrc:(cv::Mat&)rS outTrg:(cv::Mat&)rT
{
    rS = core->openImg(src);
    rT = core->openImg(trg);
    
    if (!rS.data || !rT.data) {
        return KZDiffError::NO_IMG;
    }
    
    if (!core->adjustSize(rS, rT, core->setting.adjustMode)) return KZDiffError::NOT_ADJUST;
    
    if(rS.size != rT.size) return KZDiffError::NOT_MATCH_SIZE;
    
    return KZDiffError::NO_ERROR;
}

- (void)makeDiffImgProcess:(NSMutableDictionary**)info srcImg:(cv::Mat)srcImg trgImg:(cv::Mat)trgImg diffAdd:(cv::Mat)diffAdd
{
    //NSLog(@"%@",NSLocalizedStringFromTable(@"AoAkaModeNone", @"Preference", nil));
    //std::cout << core->setting.aoAkaMode << std::endl;
    
    const cv::String enc_format(".png");
    cv::Mat diff,blendImage;
    bool isUseRedBlue = (strcmp(core->setting.aoAkaMode.c_str(), [NSLocalizedStringFromTable(@"AoAkaModeNone", @"Preference", nil) UTF8String]));
    if (isUseRedBlue) {
        cv::Mat red,blue;
        blue = srcImg.clone();
        red = trgImg.clone();
        
        core->convertBlueRedImg(blue, red);
        cv::bitwise_and(blue, red, diff);
        blendImage = core->getAlphaBlendImg(diffAdd, diff);
        [*info setObject:core->encodeMatToData(blue, enc_format) forKey:@"oldImage"];
        [*info setObject:core->encodeMatToData(red, enc_format) forKey:@"newImage"];
        [*info setObject:core->encodeMatToData(diffAdd, enc_format) forKey:@"diffImage"];
        [*info setObject:core->encodeMatToData(diff, enc_format) forKey:@"mergeImage"];
    }
    else
    {
        blendImage = core->getAlphaBlendImg(diffAdd, trgImg);
        cv::bitwise_and(srcImg, trgImg, diff);
        
        [*info setObject:core->encodeMatToData(srcImg, enc_format) forKey:@"oldImage"];
        [*info setObject:core->encodeMatToData(trgImg, enc_format) forKey:@"newImage"];
        [*info setObject:core->encodeMatToData(diffAdd, enc_format) forKey:@"diffImage"];
        
        [*info setObject:core->encodeMatToData(diff, enc_format) forKey:@"mergeImage"];
    }
    [*info setObject:core->encodeMatToData(core->bitDiffImg, enc_format) forKey:@"orgDiffImage"];
    [*info setObject:core->encodeMatToData(blendImage, enc_format) forKey:@"blendImage"];
}

- (void)noMakeDiffImgProcess:(NSMutableDictionary**)info srcImg:(cv::Mat)srcImg trgImg:(cv::Mat)trgImg
{
    NSLog(@"%@",NSLocalizedStringFromTable(@"AoAkaModeNone", @"Preference", nil));
    std::cout << core->setting.aoAkaMode << std::endl;
    bool isUseRedBlue = (strcmp(core->setting.aoAkaMode.c_str(), [NSLocalizedStringFromTable(@"AoAkaModeNone", @"Preference", nil) UTF8String]));
    const cv::String enc_format(".png");
    cv::Mat diff, blend;
    cv::Mat diffAdd(srcImg.rows, srcImg.cols, CV_8UC3, core->setting.backAlphaColor);
    
//    if(core->setting.isSaveColor){
//        diffAdd = cv::Mat(srcImg.rows, srcImg.cols, CV_8UC3, core->setting.backAlphaColor);
//    }else{
//        diffAdd = cv::Mat(srcImg.rows, srcImg.cols, CV_8UC1, core->setting.backAlphaColor);
//    }
    
    if (isUseRedBlue) {
        core->convertBlueRedImg(srcImg, trgImg);
        cv::bitwise_and(srcImg, trgImg, diff);
        blend = core->getAlphaBlendImg(diffAdd, diff);
        [*info setObject:core->encodeMatToData(srcImg, enc_format) forKey:@"oldImage"];
        [*info setObject:core->encodeMatToData(trgImg, enc_format) forKey:@"newImage"];
    }
    else {
        cv::bitwise_and(srcImg, trgImg, diff);
        blend = core->getAlphaBlendImg(diffAdd, diff);
        [*info setObject:core->encodeMatToData(srcImg, enc_format) forKey:@"oldImage"];
        [*info setObject:core->encodeMatToData(trgImg, enc_format) forKey:@"newImage"];
        
    }
    
    [*info setObject:core->encodeMatToData(diff, enc_format) forKey:@"mergeImage"];
    [*info setObject:core->encodeMatToData(diffAdd, enc_format) forKey:@"diffImage"];
    [*info setObject:core->encodeMatToData(blend, enc_format) forKey:@"blendImage"];
    
    [*info setObject:@[] forKey:@"addPos"];
    [*info setObject:@[] forKey:@"delPos"];
    [*info setObject:@[] forKey:@"diffPos"];
}
//
//static Halide::Buffer<float> convertMat2Halide(cv::Mat& src)
//{
//    Halide::Buffer<float> dest;
//    dest = Halide::Buffer<float>(src.ptr<float>(0.0), src.cols, src.rows, src.channels());
//    return dest;
//}
//
//enum InterpolationType {
//    BOX, LINEAR, CUBIC, LANCZOS
//};
//
//Halide::Expr kernel_box(Halide::Expr x) {
//    Halide::Expr xx = abs(x);
//    return Halide::select(xx <= 0.5f, 1.0f, 0.0f);
//}
//
//Halide::Expr kernel_linear(Halide::Expr x) {
//    Halide::Expr xx = Halide::abs(x);
//    return Halide::select(xx < 1.0f, 1.0f - xx, 0.0f);
//}
//
//Halide::Expr kernel_cubic(Halide::Expr x) {
//    Halide::Expr xx = Halide::abs(x);
//    Halide::Expr xx2 = xx * xx;
//    Halide::Expr xx3 = xx2 * xx;
//    float a = -0.5f;
//
//    return Halide::select(xx < 1.0f, (a + 2.0f) * xx3 - (a + 3.0f) * xx2 + 1,
//                  Halide::select (xx < 2.0f, a * xx3 - 5 * a * xx2 + 8 * a * xx - 4.0f * a,
//                          0.0f));
//}
//
//Halide::Expr sinc(Halide::Expr x) {
//    return Halide::sin(float(M_PI) * x) / x;
//}
//
//Halide::Expr kernel_lanczos(Halide::Expr x) {
//    Halide::Expr value = sinc(x) * sinc(x/3);
//    value = Halide::select(x == 0.0f, 1.0f, value); // Take care of singularity at zero
//    value = Halide::select(x > 3 || x < -3, 0.0f, value); // Clamp to zero out of bounds
//    return value;
//}
//
//struct KernelInfo {
//    const char *name;
//    float size;
//    Halide::Expr (*kernel)(Halide::Expr);
//};
//
//static KernelInfo kernelInfo[] = {
//    { "box", 0.5f, kernel_box },
//    { "linear", 1.0f, kernel_linear },
//    { "cubic", 2.0f, kernel_cubic },
//    { "lanczos", 3.0f, kernel_lanczos }
//};
//
//- (NSData*)convertTIFImage:(NSString*)src
//{
//    cv::Mat tmpImg;
//    int colFlag = cv::IMREAD_UNCHANGED;
//    if (imgSetting.toSpace != KZColorSpace::SRC) {
//        if (imgSetting.toSpace == KZColorSpace::GRAY) {
//            colFlag = cv::IMREAD_GRAYSCALE;
//        }
//        else if ((imgSetting.toSpace == KZColorSpace::SRGB) || (imgSetting.toSpace == KZColorSpace::CMYK)) {
//            colFlag = cv::IMREAD_COLOR;
//        }
//    }
//    clock_t start = clock();
//
//    if (colFlag == cv::IMREAD_UNCHANGED) {
//        tmpImg = cv::imread(src.UTF8String);
//    }
//    else {
//        tmpImg = cv::imread(src.UTF8String, colFlag);
//    }
//    clock_t end = clock();
//
//    float resCur = [imgUtil getImageDPI:src];
//    float scaleFactor = (float)(imgSetting.Resolution) / resCur;
//
//    double time = static_cast<double>(end - start) / CLOCKS_PER_SEC * 1000.0;
//    printf("convert file->mat time %lf[s]\n", time / 1000.0);
//    bool isUse = cv::useOptimized();
//    cv::setUseOptimized(true) ;
//    cv::resize(tmpImg, tmpImg, cv::Size(0,0), scaleFactor, scaleFactor, cv::INTER_AREA);
//    cv::String enc_format(".tif");
//
//    return core->encodeMatToData(tmpImg, enc_format);
//}

- (NSData*)convertTIFImage:(NSString*)src
{
    cv::UMat tmpImg;
    int colFlag = cv::IMREAD_UNCHANGED;
    if (imgSetting.toSpace != KZColorSpace::SRC) {
        if (imgSetting.toSpace == KZColorSpace::GRAY) {
            colFlag = cv::IMREAD_GRAYSCALE;
        }
        else if ((imgSetting.toSpace == KZColorSpace::SRGB) || (imgSetting.toSpace == KZColorSpace::CMYK)) {
            colFlag = cv::IMREAD_COLOR;
        }
    }
    clock_t start = clock();
    if (colFlag == cv::IMREAD_UNCHANGED) {
        cv::imread(src.UTF8String).copyTo(tmpImg);
    }
    else {
        cv::imread(src.UTF8String, colFlag).copyTo(tmpImg);
    }
    clock_t end = clock();
    double time = static_cast<double>(end - start) / CLOCKS_PER_SEC * 1000.0;
    printf("convert file->mat time %lf[s]\n", time / 1000.0);
    
    start = clock();
    float resCur = [imgUtil getImageDPI:src];
    float scaleFactor = (float)(imgSetting.Resolution) / resCur;
    cv::resize(tmpImg, tmpImg, cv::Size(), scaleFactor, scaleFactor, cv::INTER_AREA);
    end = clock();
    time = static_cast<double>(end - start) / CLOCKS_PER_SEC * 1000.0;
    printf("resize mat time %lf[s]\n", time / 1000.0);
    
    cv::String enc_format(".tif");
    cv::Mat img;
    tmpImg.copyTo(img);
    return core->encodeMatToData(img, enc_format);
}

#pragma mark -
#pragma mark Public Methods

- (void)registerSetting:(NSString *)jsonObj
{
    core->registerSetting((char*)[jsonObj UTF8String]);
    
    if (!core->setting.isSaveColor) {
        imgSetting.toSpace = KZColorSpace::GRAY;
    }
    else {
        imgSetting.toSpace = KZColorSpace::SRC;
    }
    imgSetting.isSaveColor = core->setting.isSaveColor;
    imgSetting.Resolution = (float)core->setting.rasterDpi;
    imgSetting.isSaveLayer = core->setting.isSaveLayered;
    imgSetting.isResize = YES;
    imgSetting.isForceAdjustSize = (BOOL)core->setting.isForceResize;
    
}

- (NSOperation*)diffStart:(NSString*)src // OLD
           target:(NSString*)trg // NEW
             save:(NSString*)savePath // SAVEPATH not includes file
           object:(id)object // CallBack Object
     pageRangeOLD:(NSString*)pageRangeOLD // old page range
     pageRangeNEW:(NSString*)pageRangeNEW // new page range
{
    __block NSBlockOperation *diffop = [NSBlockOperation blockOperationWithBlock:^{
            __weak typeof(self) self_ = self;
            NSFileManager *fm = NSFileManager.defaultManager;
            NSError *error;
            NSString *saveCur = savePath;
            NSString *srcName = [KZLibs getFileName:src];
            NSString *trgName = [KZLibs getFileName:trg];
            NSArray *arOldPages = [self_ getPages:pageRangeOLD];
            NSArray *arNewPages = [self_ getPages:pageRangeNEW];
            
            if (arNewPages.count != arOldPages.count) {
                [_delegate skipProcess:object errMessage:[NSString stringWithFormat:@"Difference Page Count : old is %d new is %d", (int)arOldPages.count, (int)arNewPages.count]];
                return;
            }
            
            if (![KZLibs isDirectory:savePath]) {
                saveCur = [savePath stringByDeletingLastPathComponent];
            }
            
            if (![fm fileExistsAtPath:saveCur]) {
                [fm createDirectoryAtPath:saveCur withIntermediateDirectories:YES attributes:nil error:&error];
            }
            
            if (error) {
                [_delegate skipProcess:object errMessage:error.description];
                return;
            }
            
            for (int i = 0; i < arOldPages.count; i++) {
                if ([diffop isCancelled]) {
                    break;
                }
                if ([_delegate respondsToSelector:@selector(startConvert:imageFile:imagePage:)]) {
                    [_delegate startConvert:object imageFile:src imagePage:arOldPages[i]];
                }
                
RETRY:
                if (arOldPages.count != 1) {
                    NSString *processMessage = [NSString stringWithFormat:@"      - %d / %lu\n",i+1, (unsigned long)arOldPages.count];
                    [_delegate logProcess:processMessage];
                }
                NSMutableDictionary *retDic = [[NSMutableDictionary alloc] init];
                NSSize largeSize = NSMakeSize(0, 0);
                NSString *ext = [[KZLibs getFileExt:src] lowercaseString];
                if(core->setting.isForceResize) {
                    NSSize oldSize = NSMakeSize(0, 0);
                    NSSize newSize = NSMakeSize(0, 0);

                    if (NEQ_STR(ext, @"pdf")) {
                        oldSize = [KZLibs getImageSize:src];
                    }
                    else if (EQ_STR(ext, @"pdf")) {
                        NSSize mmSize = [KZLibs getPDFSizeMm:src];
                        oldSize = NSMakeSize([KZLibs mmToPixcel:mmSize.width dpi:imgSetting.Resolution],
                                             [KZLibs mmToPixcel:mmSize.height dpi:imgSetting.Resolution]);
                    }
                    
                    ext = [[KZLibs getFileExt:trg] lowercaseString];
                    if (NEQ_STR(ext, @"pdf")) {
                        newSize = [KZLibs getImageSize:trg];
                    }
                    else if (EQ_STR(ext, @"pdf")) {
                        NSSize mmSize = [KZLibs getPDFSizeMm:trg];
                        newSize = NSMakeSize([KZLibs mmToPixcel:mmSize.width dpi:imgSetting.Resolution],
                                             [KZLibs mmToPixcel:mmSize.height dpi:imgSetting.Resolution]);
                    }
                    largeSize.width = (oldSize.width < newSize.width)? oldSize.width : newSize.width;
                    largeSize.height = (oldSize.height < newSize.height)? oldSize.height : newSize.height;
                }
                NSData *old_tmp;
                clock_t start = clock();
                FILE *ofp = fopen(src.UTF8String, "rb");
                old_tmp = [imgUtil ImageConvertfromBuffer:ofp
                                                     page:[arOldPages[i] unsignedIntegerValue]
                                                   format:KZFileFormat::PNG_FORMAT
                                                     size:largeSize
                                                  setting:imgSetting];
                fclose(ofp);
                clock_t end = clock();
                double time = static_cast<double>(end - start) / CLOCKS_PER_SEC * 1000.0;
                printf("convert old time %lf[s]\n", time / 1000.0);
                
                if (!old_tmp) {
                    goto RETRY;
//                    NSString* noimg = [NSLocalizedStringFromTable(@"NoImg", @"ErrorText", nil) mutableCopy];
//                    noimg = [noimg stringByAppendingString:[NSString stringWithFormat:@"%@の変換に失敗しました。\n", [src lastPathComponent]]];
//                    [_delegate skipProcess:object errMessage:noimg];
//                    return;
                }
                
                if ([_delegate respondsToSelector:@selector(endConvert:imageFile:imagePage:)]) {
                    [_delegate endConvert:object imageFile:src imagePage:arOldPages[i]];
                }
                
                if ([_delegate respondsToSelector:@selector(startConvert:imageFile:imagePage:)]) {
                    [_delegate startConvert:object imageFile:trg imagePage:arNewPages[i]];
                }
                
                NSData *new_tmp;
                start = clock();
                FILE *nfp = fopen(trg.UTF8String, "rb");
                new_tmp = [imgUtil ImageConvertfromBuffer:nfp
                                                     page:[arNewPages[i] unsignedIntegerValue]
                                                   format:KZFileFormat::PNG_FORMAT
                                                     size:largeSize
                                                  setting:imgSetting];
                fclose(nfp);
                
                end = clock();
                time = static_cast<double>(end - start) / CLOCKS_PER_SEC * 1000.0;
                printf("convert new time %lf[s]\n", time / 1000.0);
                
                if (!new_tmp) {
                    goto RETRY;
//                    NSString* noimg = [NSLocalizedStringFromTable(@"NoImg", @"ErrorText", nil) mutableCopy];
//                    noimg = [noimg stringByAppendingString:[NSString stringWithFormat:@"%@の変換に失敗しました。\n", [trg lastPathComponent]]];
//                    [_delegate skipProcess:object errMessage:noimg];
//                    return;
                }
                
                
                if ([_delegate respondsToSelector:@selector(endConvert:imageFile:imagePage:)]) {
                    [_delegate endConvert:object imageFile:trg imagePage:arNewPages[i]];
                }
                
                if ([_delegate respondsToSelector:@selector(startInspect:imageFile:imagePage:)]) {
                    [_delegate startInspect:object imageFile:trg imagePage:arNewPages[i]];
                }
                
                NSString *startMessage = [NSString stringWithFormat:@" START - %@ <=> %@\n",srcName,trgName];
                [_delegate logProcess:startMessage];
                
                cv::Mat rS,rT;
                KZDiffError state = [self_ preProcessDiffSrc:old_tmp Trg:new_tmp outSrc:rS outTrg:rT];
                
                if (state != KZDiffError::NO_ERROR) {
                    NSMutableString *ermsg;
                    switch (state) {
                        case KZDiffError::NO_ERROR:
                            break;
                            
                        case KZDiffError::NO_IMG:
                            ermsg = [NSLocalizedStringFromTable(@"NoImg", @"ErrorText", nil) mutableCopy];
                            if (!rS.data)
                                [ermsg appendFormat:@" -- %@\n",srcName];
                            if (!rT.data)
                                [ermsg appendFormat:@" -- %@\n",trgName];
                            [_delegate skipProcess:object errMessage:[ermsg copy]];
                            break;
                            
                        case KZDiffError::NOT_ADJUST:
                            ermsg = [NSLocalizedStringFromTable(@"NotAdjustImg", @"ErrorText", nil) mutableCopy];
                            [ermsg appendFormat:@" -- %@\n",srcName];
                            [ermsg appendFormat:@" -- %@\n",trgName];
                            [_delegate skipProcess:object errMessage:[ermsg copy]];
                            break;
                            
                        case KZDiffError::NOT_MATCH_SIZE:
                            ermsg = [NSLocalizedStringFromTable(@"NotMatchSize", @"ErrorText", nil) mutableCopy];
                            [ermsg appendFormat:@" -- %@ (%d x %d)\n",srcName,rS.cols,rS.rows];
                            [ermsg appendFormat:@" -- %@ (%d x %d)\n",trgName,rT.cols,rT.rows];
                            [_delegate skipProcess:object errMessage:[ermsg copy]];
                            break;
                    }
                    
                    return;
                }
                std::vector<cv::Rect> iLLustArea;
                std::vector<cv::Rect> textArea;
                std::vector<cv::Rect> textAreaAll;
                cv::Mat diffAdd(rS.rows, rS.cols, rS.type(), core->setting.backAlphaColor);
                BOOL isNotWriteXMP = YES;
                
                if(!strcmp(core->setting.diffDispMode.c_str(), [NSLocalizedStringFromTable(@"DiffModeNone", @"Preference", nil) UTF8String])){
                    [self_ noMakeDiffImgProcess:&retDic srcImg:rS trgImg:rT];
                }
                else {
                    
                    // イラストエリアの判別(PDFの場合)
                    if (EQ_STR(@"pdf", [src pathExtension])) {
                        cv::Mat testImg;
                        rS.copyTo(testImg);
                        
                        if (testImg.channels() == 1)
                            cv::cvtColor(testImg, testImg, cv::COLOR_GRAY2BGR);
                        
                        std::vector<PDFParser::RectImageF> imgRects;
                        std::vector<PDFParser::RectImageF> textRects;
                        parser->scale = (float)core->setting.rasterDpi / 72.0;
                        parser->parsePDF(src.UTF8String, imgRects, textRects);
                        
                        cv::Mat cntImg(rS.size(), CV_8UC1, cv::Scalar(0));
                        for (auto it = textRects.begin(); it != textRects.end(); ++it) {
                            cv::Rect theR((int)it->origin.x, (int)it->origin.y, (int)it->width, (int)it->height);
                            textAreaAll.push_back(theR);
                        }
                        
                        for (auto it = imgRects.begin(); it != imgRects.end(); ++it) {
                            cv::Rect theR((int)it->origin.x, (int)it->origin.y, (int)it->width, (int)it->height);
                            iLLustArea.push_back(theR);
                        }
                        
                        for (auto it = iLLustArea.begin(); it != iLLustArea.end(); ++it) {
                            cv::Rect chk = *it;
                            for (auto jt = textAreaAll.begin(); jt != textAreaAll.end(); ++jt) {
                                if ((chk & *jt) != cv::Rect()) {
                                    textArea.push_back(*jt);
                                }
                            }
                        }
                        if (textArea.size() != 0) {
                            for (size_t j = 0; j < textArea.size(); ++j) {
                                cv::rectangle(testImg, textArea.at(j).tl(), textArea.at(j).br(), cv::Scalar(255,0,0), 1);
                            }
                        }
                        
                        if (iLLustArea.size() != 0) {
                            for (size_t j = 0; j < iLLustArea.size(); ++j) {
                                cv::rectangle(testImg, iLLustArea.at(j).tl(), iLLustArea.at(j).br(), cv::Scalar(0,0,255), 2);
                            }

                            std::string imar([KZLibs getFileName:src].UTF8String);
                            imar.append("Area.tif");
                            std::stringstream ss;
                            ss << "/tmp/" << imar;
                            cv::imwrite(ss.str(), testImg);
                            std::cout << "iLLustArea count : " << iLLustArea.size() << std::endl;
                        }
                    }
                    
                    
                    std::vector<cv::Rect> diff_rects = core->getDiffRects(rS, rT, &retDic, iLLustArea, textArea);
                    
                    if (diff_rects.size() == 0 && core->setting.isSaveNoChange && iLLustArea.size() == 0) {
                        [self_ noMakeDiffImgProcess:&retDic srcImg:rS trgImg:rT];
                    }
                    else if (diff_rects.size() == 0 && !core->setting.isSaveNoChange && iLLustArea.size() == 0) {
                        // nop
                    }
                    else {
                        int diffArea = (int)diff_rects.size() + (int)iLLustArea.size();
                        [_delegate maxDiffAreas:diffArea object:object];

                        if (diff_rects.size() >= 30000) {
                            _isManyDiff = YES;
                            [_delegate endInspect:object imageFile:trg imagePage:arNewPages[i]];
                            
                            if (core->bitDiffImg.channels() != 1)
                                cv::cvtColor(core->bitDiffImg, core->bitDiffImg, cv::COLOR_BGR2GRAY);
                            
                            cv::Mat dilateBit(core->bitDiffImg);
                            cv::dilate(dilateBit, dilateBit, cv::Mat());
                            cv::dilate(dilateBit, dilateBit, cv::Mat());
                            core->cvtGrayIfColor(dilateBit, dilateBit);
                            if (core->setting.isSaveColor) {
                                cv::cvtColor(dilateBit, dilateBit, cv::COLOR_GRAY2BGR);
                                cv::Mat dst(dilateBit.size(), CV_8UC3, cv::Scalar::all(0));
                                for (int y = 0; y < dilateBit.rows; y++) {
                                    cv::Vec3b *pix = dilateBit.ptr<cv::Vec3b>(y);
                                    cv::Vec3b *dstP = dst.ptr<cv::Vec3b>(y);
                                    for (int x = 0; x < dilateBit.cols; x++) {
                                        if ((pix[x][0] == 255) && (pix[x][1] == 255) && (pix[x][2] == 255)) {
                                            dstP[x][0] = core->setting.addColor.val[0];
                                            dstP[x][1] = core->setting.addColor.val[1];
                                            dstP[x][2] = core->setting.addColor.val[2];
                                        }
                                    }
                                }
                                dst.copyTo(dilateBit);
                            }

                            [self_ makeDiffImgProcess:&retDic srcImg:rS trgImg:rT diffAdd:dilateBit];

                        }
                        else {
                            cv::Mat bigS, bigT;
                            cv::Mat imS,imT;
                            DiffImgCore::DiffResult res;
                            
                            if (core->setting.colorSpace == (int)KZColorSpace::GRAY) {
                                core->cvtGrayIfColor(rS, imS);
                                core->cvtGrayIfColor(rT, imT);
                            }
                            else {
                                rS.copyTo(imS);
                                rT.copyTo(imT);
                            }

                            core->resizeImage(imS, bigS, VIEW_SCALE);
                            core->resizeImage(imT, bigT, VIEW_SCALE);
                            
//                            std::vector<cv::Rect> checkedRects;
                            int extCropSize = 30;
                            float ratioExt = 30.0 / 168.0;
                            if (core->setting.rasterDpi != 168) {
                                extCropSize = round(ratioExt * (float)core->setting.rasterDpi);
                            }
                            for(int i = 0; i < diff_rects.size(); i++) {
                                std::cout << i << "---------------------" << std::endl;
                               
                                if ([diffop isCancelled]) {
                                    break;
                                }
                                cv::Rect theDiffRect = diff_rects.at(i);
                                if (theDiffRect.width == 0 || theDiffRect.height == 0) {
                                    [_delegate notifyProcess:object];
                                    continue;
                                }
                                std::cout << "x = " << theDiffRect.x << ", y = " << theDiffRect.y << ", w = " << theDiffRect.width << ", h = " << theDiffRect.height << std::endl;
                                // ff
                                if ((theDiffRect.x == 1061) && (theDiffRect.y == 2596) && (theDiffRect.width == 4) && (theDiffRect.height == 2)) {
                                    std::cout << i << std::endl;
                                }
                                
                                // e th
                                if ((theDiffRect.x == 1553) && (theDiffRect.y == 2565) && (theDiffRect.width == 8) && (theDiffRect.height == 7)) {
                                    std::cout << i << std::endl;
                                }
                                
                                // xty
                                if ((theDiffRect.x == 4642) && (theDiffRect.y == 2585) && (theDiffRect.width == 7) && (theDiffRect.height == 9)) {
                                    std::cout << i << std::endl;
                                }
                                
                                /*bool isAlreadyCheck = false;
                                for (auto it = checkedRects.begin(); it != checkedRects.end(); ++it) {
                                    cv::Point chkTL = it->tl();
                                    cv::Point chkBR = it->br();
                                    cv::Point trgTL = theDiffRect.tl();
                                    cv::Point trgBR = theDiffRect.br();
                                    if (trgTL.inside(*it) || ((trgTL.x == chkTL.x) || (trgTL.y == chkTL.y))) {
                                        if (trgBR.inside(*it) || ((trgBR.x == chkBR.x) || (trgBR.y == chkBR.y))) {
                                            isAlreadyCheck = true;
                                            break;
                                        }
                                    }
                                   
                                }
                                
                                if (isAlreadyCheck) {
                                    [_delegate notifyProcess:object];
                                    continue;
                                }*/
                                
                                
                                
                                cv::Rect extCrop(theDiffRect.x - extCropSize,
                                                 theDiffRect.y - extCropSize,
                                                 theDiffRect.width + (extCropSize * 2),
                                                 theDiffRect.height + (extCropSize * 2));
                                
                                if (extCrop.x < 0) extCrop.x = 0;
                                if (extCrop.y < 0) extCrop.y = 0;
                                if((extCrop.y + extCrop.height) > imS.rows){
                                    extCrop.height = (imS.rows - extCrop.y);
                                }
                                if((extCrop.x + extCrop.width) > imS.cols){
                                    extCrop.width = (imS.cols - extCrop.x);
                                }
                                
                                cv::Rect bigCropExt(extCrop.x * VIEW_SCALE,
                                                    extCrop.y * VIEW_SCALE,
                                                    extCrop.width * VIEW_SCALE,
                                                    extCrop.height * VIEW_SCALE);
                                
                                cv::Mat crpS(imS, extCrop);
                                cv::Mat crpT(imT, extCrop);
                                cv::Mat crpSE(bigS, bigCropExt);
                                cv::Mat crpTE(bigT, bigCropExt);
                                
                                //std::vector<cv::Rect> checked =
                                core->diff(crpS, crpT, crpSE, crpTE, theDiffRect, res, core->setting.matchThresh / 100, false, textArea, extCropSize);
                                /*for (auto it = checked.begin(); it != checked.end(); ++it) {
                                    checkedRects.push_back(*it);
                                }*/
                                
                                [_delegate notifyProcess:object];
                            }
                            for (auto it = iLLustArea.begin(); it != iLLustArea.end(); ++it) {
                                cv::Mat crpS(imS, *it);
                                cv::Mat crpT(imT, *it);
                                core->diff(crpS, crpT, cv::Mat(), cv::Mat(), *it, res, core->setting.matchThresh / 100, true, textArea, extCropSize);
                                [_delegate notifyProcess:object];
                            }

                            isNotWriteXMP = [self_ clusterDiffArea:&retDic diffResult:res];

                            if ([retDic[@"addContours"] count] == 0 && [retDic[@"delContours"] count] == 0 && [retDic[@"diffContours"] count] == 0) {
                                
                            }
                            else {
                                core->drawDiffContours(diffAdd, res);
                                [self_ makeDiffImgProcess:&retDic srcImg:rS trgImg:rT diffAdd:diffAdd];
                            }
                            
                        }
                    }
                }
                
                if ([diffop isCancelled]) {
                    break;
                }
                
                if (retDic.count == 0) {
                    [_delegate skipProcess:object errMessage:[NSString stringWithFormat:@"比較に失敗しました %@ <=> %@",[KZLibs getFileName:src],[KZLibs getFileName:trg]]];
                    return;
                }
                
                if ([_delegate respondsToSelector:@selector(endInspect:imageFile:imagePage:)]) {
                    [_delegate endInspect:object imageFile:trg imagePage:arNewPages[i]];
                    
                    NSString *endMessage = [NSString stringWithFormat:@"   END - %@ <=> %@\n",[KZLibs getFileName:src], [KZLibs getFileName:trg]];
                    [_delegate logProcess:endMessage];
                }
                
                BOOL isMakeDiffFile = NO;
                if (!core->setting.isSaveNoChange &&
                    ([retDic[@"addContours"] count] != 0 || [retDic[@"delContours"] count] != 0 || [retDic[@"diffContours"] count] != 0)) {
                    isMakeDiffFile = YES;
                }
                else if ([retDic[@"addContours"] count] == 0 && [retDic[@"delContours"] count] == 0 && [retDic[@"diffContours"] count] == 0) {
                    isMakeDiffFile = NO;
                }
                else if (core->setting.isSaveNoChange) {
                    isMakeDiffFile = YES;
                }
                else if (_isManyDiff) {
                    isMakeDiffFile = YES;
                }
                
                
                if (isMakeDiffFile) {
                    NSString *savedFile = nil;
                    if (EQ_STR(pageRangeOLD, @"1-1")) {
                        savedFile = [self_ makeDiffFile:[KZLibs getFileName:trg] save:saveCur infos:retDic];
                        if (savedFile == nil) {
                            [_delegate skipProcess:object errMessage:[NSString stringWithFormat:@"保存に失敗しました %@ <=> %@",[KZLibs getFileName:src],[KZLibs getFileName:trg]]];
                            return;
                        }
                    }
                    else {
                        NSString *makeFileName = [NSString stringWithFormat:@"%@_%@", [KZLibs getFileName:trg], [KZLibs paddNumber:3 num:i+1]];
                        savedFile = [self_ makeDiffFile:makeFileName save:saveCur infos:retDic];
                    }
                    
                    // XMP書き込み
                    if (!isNotWriteXMP) {
                        NSString *fileType = nil;
                        if ((KZFileFormat)core->setting.saveType == KZFileFormat::PSD_FORMAT) {
                            fileType = @"PSD";
                        }
                        else if ((KZFileFormat)core->setting.saveType == KZFileFormat::GIF_FORMAT) {
                            fileType = @"GIF";
                        }
                        else if ((KZFileFormat)core->setting.saveType == KZFileFormat::PNG_FORMAT) {
                            fileType = @"PNG";
                        }
                        
                        NSData *addC = [NSKeyedArchiver archivedDataWithRootObject:retDic[@"addContours"]];
                        addC = [addC deflate:9];
                        NSData *delC = [NSKeyedArchiver archivedDataWithRootObject:retDic[@"delContours"]];
                        delC = [delC deflate:9];
                        NSData *difC = [NSKeyedArchiver archivedDataWithRootObject:retDic[@"diffContours"]];
                        difC = [difC deflate:9];
                        NSDictionary *xmp = @{@"addContours" : [addC base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength],
                                              @"delContours" : [delC base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength],
                                              @"diffContours" : [difC base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength],
                                              };
                        NSError *er;
                        [XmpSDK writeXmpInfo:xmp imgPath:savedFile fileType:fileType error:&er];
                    }
                    
                }
                
            }
            
            if ([diffop isCancelled]) {
                [_delegate cancelProcess:object message:[NSString stringWithFormat:@"CANCEL - %@ <=> %@\n",srcName, trgName]];
            }
            else if ([_delegate respondsToSelector:@selector(completeSaveFile:)]) {
                [_delegate completeSaveFile:object];
            }
//        }
        return;
    }];
    
    return diffop;
}

+ (NSArray*)isSupported
{
    return [KZImage isSupportedFiles];
}

- (void)stopEngine
{
    [imgUtil stopEngine];
    delete core;
    delete parser;
}
@end
