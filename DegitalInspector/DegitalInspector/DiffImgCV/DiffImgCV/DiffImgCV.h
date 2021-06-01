//
//  DiffImgCV.h
//  DiffImgCV
//
//  Created by uchiyama_Macmini on 2018/12/20.
//  Copyright © 2018年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <KZLibs.h>
#import <KZImage/KZImage.h>




@protocol DiffImgCVDelegate <NSObject>
@required
- (void)maxDiffAreas:(int)count object:(id)object;
- (void)skipProcess:(id)object errMessage:(NSString*)msg;
- (void)notifyProcess:(id)object;
- (void)logProcess:(NSString*)msg;
- (void)cancelProcess:(id)object message:(NSString*)msg;
@optional
- (void)tooManyDiff:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage;
- (void)startConvert:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage;
- (void)endConvert:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage;
- (void)startInspect:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage;
- (void)endInspect:(id)object imageFile:(NSString*)imageFile imagePage:(NSNumber*)imagePage;
- (void)completeSaveFile:(id)object;
@end

//! Project version number for DiffImgCV.
FOUNDATION_EXPORT double DiffImgCVVersionNumber;

//! Project version string for DiffImgCV.
FOUNDATION_EXPORT const unsigned char DiffImgCVVersionString[];

@interface DiffImgCV : NSObject
@property(nonatomic, strong) id <DiffImgCVDelegate> delegate;

- (void)registerSetting:(NSString*)jsonObj;
- (NSOperation*)diffStart:(NSString*)src        // OLD
           target:(NSString*)trg        // NEW
             save:(NSString*)outPath    // SAVEPATH not includes file
           object:(id)object            // CallBack Object
     pageRangeOLD:(NSString*)pageRangeOLD
     pageRangeNEW:(NSString*)pageRangeNEW;

+ (NSArray*)isSupported;

- (void)stopEngine;
@end
