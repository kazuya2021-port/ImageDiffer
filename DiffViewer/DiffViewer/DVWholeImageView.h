//
//  DVWholeImageView.h
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/08/01.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@protocol DVWholeImageViewDelegate <NSObject>
- (void)mouseExitted;
- (void)mouseEnteredArea:(NSUInteger)areaNo;
- (void)mouseEnteredAt:(NSPoint)realPos;
- (void)mouseMovedAt:(NSPoint)realPos;
- (void)decideEnteredArea;
- (void)addedTrackInfo:(NSUInteger)areaNo type:(NSString*)type area:(NSRect)rect;

@end

@interface DVWholeImageView : NSImageView
@property (nonatomic, strong) id <DVWholeImageViewDelegate> delegate;
@property (nonatomic, weak) OpenedFile *file;
@property (nonatomic, assign) NSSize loupeSizeBase; // diffImageViewのサイズ
@property (nonatomic, assign) NSSize imgSizeReal; // 画像のサイズ
- (void)focusArea:(NSRect)area no:(NSString*)identifier; // 指定エリアの枠書き込み
- (void)eraseFocusedLayer;
@end
