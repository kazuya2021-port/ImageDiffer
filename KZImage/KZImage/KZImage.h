//
//  KZImage.h
//  KZImage
//
//  Created by 内山和也 on 2019/03/26.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "ImageEnum.h"

@protocol KZImageDelegate <NSObject>
@optional
- (void)cropPageStart:(NSString*)savePath;
- (void)cropPageDone:(NSString*)croppedPath;
@end


@interface ConvertSetting : NSObject
@property KZColorSpace toSpace;
@property float Resolution;
@property float Alpha;
@property BOOL isSaveLayer; // only use PSD writing
@property BOOL isResize;    // true: resample image     false : change dpi
@property BOOL isSaveColor; // true: save RGB image     false : save Gray image
@property BOOL isForceAdjustSize; // true: adjust size
@end

@interface KZImage : NSObject
- (void)startEngine;
- (void)stopEngine;

+ (NSArray*)isSupportedFiles;
+ (BOOL)isSupported:(NSString*)imgPath;


- (NSData*)ImageConvertfromBuffer:(FILE*)img page:(NSUInteger)page format:(KZFileFormat)targetFormat size:(NSSize)trgSize setting:(ConvertSetting*)setting;
- (NSData*)ImageConvertfromBufferData:(NSData*)img page:(NSUInteger)page format:(KZFileFormat)targetFormat size:(NSSize)trgSize setting:(ConvertSetting*)setting;
- (NSData*)ImageConvertfrom:(NSString*)imgPath page:(NSUInteger)page format:(KZFileFormat)targetFormat size:(NSSize)trgSize trimSize:(double)trimSize setting:(ConvertSetting*)setting;

// saveFileName is pure file name without extention
- (NSString*)ImageConvertfromBuffer:(FILE*)img to:(NSString*)toFolder format:(KZFileFormat)targetFormat size:(NSSize)trgSize saveFileName:(NSString*)saveFileName setting:(ConvertSetting*)setting;
- (NSString*)ImageConvertfromBufferData:(NSData*)img to:(NSString*)toFolder format:(KZFileFormat)targetFormat size:(NSSize)trgSize saveFileName:(NSString*)saveFileName setting:(ConvertSetting*)setting;
- (NSString*)ImageConvertfrom:(NSString*)imgPath page:(NSUInteger)page to:(NSString*)toFolder format:(KZFileFormat)targetFormat size:(NSSize)trgSize saveFileName:(NSString*)saveFileName trimSize:(double)trimSize setting:(ConvertSetting*)setting;



- (BOOL)makeGIFimgs:(NSArray*)imgs savePath:(NSString*)savePath delay:(NSUInteger)delay;
- (NSArray*)getLayerImageFrom:(NSString*)imgPath setting:(ConvertSetting*)setting;

- (BOOL)makePSDfromBufferDiff:(NSArray*)infos savePath:(NSString*)savePath setting:(ConvertSetting*)setting;
- (BOOL)makePSDDiff:(NSArray*)infos savePath:(NSString*)savePath topImg:(NSData*)topImg setting:(ConvertSetting*)setting;

- (NSSize)getPdfSize:(NSString*)imgPath;
- (NSSize)getImageSize:(NSString*)imgPath dpi:(int)dpi;
- (int)getImageDPI:(NSString*)imgPath;

- (void)cropMentuke:(NSString*)imgPath menInfo:(NSArray*)info isSiagari:(BOOL)isSiagari savePath:(NSString*)savePath saveNames:(NSArray*)arNames;
- (void)cropApageStart:(const char*)savePath;
- (void)cropApageDone:(const char*)croppedPath;
- (NSData*)cropRect:(NSString*)imgPath rect:(NSRect)rect ratio:(float)ratio;
@property (nonatomic) BOOL isModifyExtention; // Modify Extention Whwn Source Extention Difference RealFileFormat
@property (nonatomic) BOOL isDeleteLastFiles; // If Same File in Converted Path, Delete this file
@property (nonatomic, strong) id <KZImageDelegate> delegate;
@end
