//
//  DVShapeLayer.m
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/08/02.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "DVShapeLayer.h"
#import "NSBezierPathExt.h"

@implementation DVShapeLayer
- (void)drawRect:(CGFloat)line rect:(NSRect)rect color:(NSColor*)color name:(NSString*)name
{
    NSBezierPath *drawPath = [NSBezierPath bezierPathWithRect:rect];
    CAShapeLayer *rectLayer = [[CAShapeLayer alloc] init];
    rectLayer.strokeColor = [color CGColor];
    rectLayer.fillColor = [[NSColor clearColor] CGColor];
    rectLayer.lineWidth = line;
    rectLayer.path = [drawPath quartzPath];
    rectLayer.name = name;
    [self addSublayer:rectLayer];
}

- (void)eraseRect:(NSString*)name
{
    if (self.sublayers.count != 0) {
        NSMutableArray *arErased = [NSMutableArray array];
        for (CAShapeLayer *lay in self.sublayers) {
            if (NEQ_STR(lay.name, name)) {
                [arErased addObject:lay];
            }
        }
        self.sublayers = [arErased copy];
    }
}

- (void)setColor:(NSString*)name color:(NSColor*)color
{
    if (self.sublayers.count != 0) {
        for (CAShapeLayer *lay in self.sublayers) {
            if (EQ_STR(lay.name, name)) {
                lay.strokeColor = color.CGColor;
                break;
            }
        }
    }
}
@end
