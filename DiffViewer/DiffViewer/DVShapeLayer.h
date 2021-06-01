//
//  DVShapeLayer.h
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/08/02.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface DVShapeLayer : CALayer
@property (nonatomic, retain) id identifier;
- (void)drawRect:(CGFloat)line rect:(NSRect)rect color:(NSColor*)color name:(NSString*)name;
- (void)eraseRect:(NSString*)name;
- (void)setColor:(NSString*)name color:(NSColor*)color;
@end
