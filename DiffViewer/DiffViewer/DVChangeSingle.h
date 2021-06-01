//
//  DVChangeSingle.h
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/08/02.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DVWholeImageView;

@protocol DVChangeSingleDelegate <NSObject>
- (void)changeImageViewSize:(NSSize)frameSize;
@end

@interface DVChangeSingle : NSView
@property (nonatomic, copy) NSString *imagePath;
@property (nonatomic, weak) IBOutlet NSImageView *diffImageA;
@property (nonatomic, strong) id <DVChangeSingleDelegate> delegate;

- (void)mouseEnteredAt:(NSPoint)realPos wholeImage:(DVWholeImageView*)wholeImage;
- (void)mouseMovedAt:(NSPoint)diffPos;
- (void)mouseExitted;
- (void)focusAt:(NSRect)focusRect wholeImage:(DVWholeImageView*)wholeImage;
@end
