//
//  DVChangeSingle.m
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/08/02.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "DVChangeSingle.h"
#import "DVWholeImageView.h"

@interface DVChangeSingle()
{
    id diffViewResizeObserver;
}
@end

@implementation DVChangeSingle

- (void)awakeFromNib
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    diffViewResizeObserver = [center addObserverForName:NSViewFrameDidChangeNotification
                                                 object:_diffImageA
                                                  queue:[NSOperationQueue mainQueue]
                                             usingBlock:^(NSNotification *note) {
                                                 if ([_delegate respondsToSelector:@selector(changeImageViewSize:)]) {
                                                     [_delegate changeImageViewSize:_diffImageA.frame.size];
                                                 }
                                                 
                                             }];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)mouseEnteredAt:(NSPoint)realPos wholeImage:(DVWholeImageView*)wholeImage
{
    CALayer *layer = [[CALayer alloc] init];
    layer.contents = wholeImage.image;
    layer.contentsGravity = kCAGravityBottomLeft;
    layer.frame = NSMakeRect(0, 0, wholeImage.imgSizeReal.width, wholeImage.imgSizeReal.height);
    layer.name = @"Mag";
    
    if (self.diffImageA.layer.sublayers) {
        self.diffImageA.layer.sublayers = nil;
    }

    [self.diffImageA.layer addSublayer:layer];
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    layer.position = NSMakePoint(layer.position.x - realPos.x,
                                 layer.position.y - realPos.y);
    [CATransaction commit];
}

- (void)focusAt:(NSRect)focusRect wholeImage:(DVWholeImageView*)wholeImage
{
    CALayer *layer = [[CALayer alloc] init];
    layer.contents = wholeImage.image;
    layer.contentsGravity = kCAGravityBottomLeft;
    layer.frame = NSMakeRect(0, 0, wholeImage.imgSizeReal.width, wholeImage.imgSizeReal.height);
    layer.name = @"Mag";
    
    if (self.diffImageA.layer.sublayers) {
        self.diffImageA.layer.sublayers = nil;
    }
    [self.diffImageA.layer addSublayer:layer];
    
    
    NSPoint focusPoint = NSMakePoint(focusRect.origin.x + (focusRect.size.width / 2),
                                     focusRect.origin.y + (focusRect.size.height / 2));
    NSPoint realPos = NSMakePoint(focusPoint.x, abs(wholeImage.imgSizeReal.height - focusPoint.y));
    
    realPos.x -= (wholeImage.loupeSizeBase.width / 2);
    realPos.y -= (wholeImage.loupeSizeBase.height / 2);
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    layer.position = NSMakePoint(layer.position.x - realPos.x,
                                 layer.position.y - realPos.y);
    [CATransaction commit];
}

- (void)mouseMovedAt:(NSPoint)diffPos
{
    CALayer *layer;
    
    for (CALayer *lay in self.diffImageA.layer.sublayers) {
        if (EQ_STR(lay.name, @"Mag")) {
            layer = lay;
            break;
        }
    }
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    layer.position = NSMakePoint(layer.position.x - diffPos.x,
                                 layer.position.y - diffPos.y);
    [CATransaction commit];
}

- (void)mouseExitted
{
    self.diffImageA.layer.sublayers = nil;
}
@end
