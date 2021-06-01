//
//  KZDisplaySetting.h
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/01.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//
#import <Foundation/Foundation.h>

@interface KZDisplaySetting : NSObject

- (void)appendUIFromSetting;
- (void)appendSettingFromUI;

- (NSDictionary*)getSettingChanged;

// DiffSetting
@property (nonatomic, assign) double gapPix;
@property (nonatomic, assign) double noizeReduction;
@property (nonatomic, assign) double threthDiff;
@property (nonatomic, assign) double matchThresh;
@property (nonatomic, assign) int adjustMode;

// DisplaySetting
@property (nonatomic, assign) NSUInteger lineThickness;
@property (nonatomic, assign) BOOL isFillLine;
@property (nonatomic, assign) double backConsentration;
@property (nonatomic, assign) BOOL isAllDiffColor;
@property (nonatomic, assign) BOOL isAllDelColor;
@property (nonatomic, assign) BOOL isAllAddColor;
@property (nonatomic, retain) NSColor *addColor;
@property (nonatomic, retain) NSColor *delColor;
@property (nonatomic, retain) NSColor *diffColor;
@property (nonatomic, retain) NSColor *backAlphaColor;
@property (nonatomic, retain) NSString *diffDispMode;
@property (nonatomic, retain) NSString *aoAkaMode;

// AppSetting
@property (nonatomic, assign) double rasterDpi;
@property (nonatomic, assign) BOOL isForceResize;
@property (nonatomic, assign) KZColorSpace colorSpace;
@property (nonatomic, assign) double maxThread;
@property (nonatomic, assign) BOOL isSaveNoChange;
@property (nonatomic, retain) NSString *oHotPath;
@property (nonatomic, retain) NSString *nHotPath;
@property (nonatomic, retain) NSString *hotSavePath;
@property (nonatomic, assign) BOOL isTrashCompleteItem;
@property (nonatomic, assign) BOOL isStartFolderWakeOn;

@property (nonatomic, retain) NSArray *folderNames;
@property (nonatomic, retain) NSString *makeFolderName;
@property (nonatomic, retain) NSString *makeFolderPlace;
@property (nonatomic, retain) NSString *filePrefix;
@property (nonatomic, retain) NSString *fileSuffix;
@property (nonatomic, assign) KZFileFormat saveType;
@property (nonatomic, assign) BOOL isSaveLayered;
@property (nonatomic, assign) BOOL isSaveColor;

@end
