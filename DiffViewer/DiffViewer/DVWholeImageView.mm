//
//  DVWholeImageView.m
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/08/01.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "DVWholeImageView.h"
#import "NSImageViewExt.h"
#import "DVShapeLayer.h"



@interface DVWholeImageView()
@property (nonatomic, assign) double scaleFactor;
@property (nonatomic, assign) NSPoint lastMovedLoupe;
@end

@implementation DVWholeImageView

#pragma mark -
#pragma mark Initialize
- (void)awakeFromNib
{
    _imgSizeReal = NSMakeSize(0, 0);
    _lastMovedLoupe = NSZeroPoint;
    self.wantsLayer = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)setImage:(NSImage *)image
{
    [super setImage:image];
    NSBitmapImageRep* rep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
    _imgSizeReal = NSMakeSize(rep.pixelsWide,rep.pixelsHigh);
}

#pragma mark -
#pragma mark Local Funcs



- (NSPoint)flipBl2Tl:(NSPoint)aPoint rect:(NSRect)rect
{
    return NSMakePoint(aPoint.x, abs(aPoint.y - rect.size.height));
}

- (NSPoint)flipTl2Bl:(NSPoint)aPoint rect:(NSRect)rect
{
    NSPoint fp = NSMakePoint(aPoint.x, abs(rect.size.height - aPoint.y));
    return fp;
}

- (NSArray*)makeContourRects:(NSArray*)arContours
{
    NSMutableArray *arContourRects = [NSMutableArray array];
    for(NSArray* cnts in arContours) {
        std::vector<cv::Point> vpts;
        for (NSArray* pts in cnts) {
            for (NSValue *val in pts) {
                NSPoint pt = [val pointValue];
                vpts.push_back(cv::Point(pt.x, pt.y));
            }
        }
        cv::Rect rc = cv::boundingRect(vpts);
        // Cocoa座標に合わせるため、BottomLeftの座標で取得
        cv::Point blPoint(rc.x, rc.y + rc.height);
        NSValue *rcVal = [NSValue valueWithRect:NSMakeRect(blPoint.x - TRACK_AROUND, blPoint.y + TRACK_AROUND, rc.width + (TRACK_AROUND * 2), rc.height + (TRACK_AROUND * 2))];
        [arContourRects addObject:rcVal];
    }
    return [arContourRects copy];
}

- (void)makeTrackArea:(NSArray*)areaRects trackAreas:(NSMutableArray**)arTracks trackNum:(NSUInteger*)num type:(NSString*)type
{
    NSUInteger curCount = *num;
    int opts = (NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingEnabledDuringMouseDrag);
    for (NSValue *v in areaRects) {
        NSRect rc = [v rectValue];
        rc.origin.x = rc.origin.x * _scaleFactor;
        rc.origin.y = rc.origin.y * _scaleFactor;
        rc.size.width = rc.size.width * _scaleFactor;
        rc.size.height = rc.size.height * _scaleFactor;
        rc.origin.x += self.imageFrame.origin.x;
        rc.origin.y += self.imageFrame.origin.y;
        NSPoint tlP = rc.origin;
        NSPoint blP = [self flipTl2Bl:tlP rect:self.frame];
        rc.origin = blP;
        NSTrackingArea *trackingArea = [ [NSTrackingArea alloc] initWithRect:rc
                                                                     options:opts
                                                                       owner:self
                                                                    userInfo:@{@"Count":[NSNumber numberWithUnsignedInteger:curCount],
                                                                               @"Area":[NSValue valueWithRect:rc]
                                                                               }];
        if ([_delegate respondsToSelector:@selector(addedTrackInfo:type:area:)]) {
            NSRect realRc = [v rectValue];
            realRc.origin.y -= realRc.size.height;
            [_delegate addedTrackInfo:curCount type:type area:realRc];
        }
        curCount += 1;
        [*arTracks addObject:trackingArea];
    }
    *num = curCount;
}

- (DVShapeLayer*)getNamedLayer:(NSString*)name
{
    DVShapeLayer *aLayer = nil;
    for (DVShapeLayer *lay in self.layer.sublayers) {
        if (EQ_STR(lay.identifier, name)) {
            aLayer = lay;
            break;
        }
    }
    return aLayer;
}

- (void)eraseNamedLayer:(NSString*)name
{
    NSMutableArray *arNewLayers = [NSMutableArray array];
    for (DVShapeLayer *lay in self.layer.sublayers) {
        if (NEQ_STR(lay.identifier, name)) {
            [arNewLayers addObject:lay];
        }
    }
    self.layer.sublayers = nil;
    self.layer.sublayers = [arNewLayers copy];
}


- (DVShapeLayer*)hitLayer:(NSPoint)point
{
    DVShapeLayer *aLayer = nil;
    for (DVShapeLayer *lay in self.layer.sublayers) {
        aLayer = (DVShapeLayer *)[lay hitTest:point];
        if (aLayer) {
            if (NEQ_STR(aLayer.identifier, @"loupeLayer")) {
                break;
            }
            aLayer = nil;
        }
    }
    return aLayer;
}

#pragma mark -
#pragma mark Mouse Event Funcs
- (void)mouseMoved:(NSEvent *)theEvent
{
    NSPoint curPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSPoint offsetPoint = NSMakePoint(curPoint.x - _lastMovedLoupe.x, curPoint.y - _lastMovedLoupe.y);
    _lastMovedLoupe = curPoint;
    
    if ([self.layer sublayers].count != 0) {
        DVShapeLayer *loupeLayer = [self getNamedLayer:@"loupeLayer"];
        if (loupeLayer) {
            CGFloat px = loupeLayer.position.x;
            CGFloat py = loupeLayer.position.y;
            
            [CATransaction begin];
            [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
            
            loupeLayer.position = CGPointMake(px + offsetPoint.x, py + offsetPoint.y);
            
            [CATransaction commit];
            
            if ([_delegate respondsToSelector:@selector(mouseMovedAt:)]) {
                
                curPoint = loupeLayer.position;
                curPoint.x -= self.imageFrame.origin.x;
                curPoint.y -= self.imageFrame.origin.y;
                curPoint.x -= (loupeLayer.frame.size.width / 2.0);
                curPoint.y -= (loupeLayer.frame.size.height / 2.0);
                
                [_delegate mouseMovedAt:NSMakePoint(curPoint.x / _scaleFactor,curPoint.y / _scaleFactor)];
            }
            
            /*if ([_delegate respondsToSelector:@selector(mouseMoved:)]) {
                NSPoint diffFrame = NSMakePoint(loupeLayer.frame.origin.x - self.imageFrame.origin.x, loupeLayer.frame.origin.y - self.imageFrame.origin.y);
                NSSize diffSize = loupeLayer.frame.size;
                if (diffFrame.x < 0) {
                    diffSize.width -= abs(diffFrame.x);
                    diffFrame.x = 0;
                }
                if (diffFrame.y < 0) {
                    diffSize.height -= abs(diffFrame.y);
                    diffFrame.y = 0;
                }
                // _scaleFactor
                //NSRect realRect = NSMakeRect(diffFrame.x / _scaleFactor, diffFrame.y / _scaleFactor, diffSize.width / _scaleFactor, diffSize.height / _scaleFactor);
                NSRect realRect = NSMakeRect(diffFrame.x / _scaleFactor, diffFrame.y / _scaleFactor, loupeLayer.frame.size.width / _scaleFactor, loupeLayer.frame.size.height / _scaleFactor);
                [_delegate mouseMoved:realRect];
            }*/
        }
        
    }
}

-(void)mouseEntered:(NSEvent *)theEvent
{
    [self eraseFocusedLayer];
    if (![theEvent userData]) {
        CGSize loupeSize = CGSizeMake(ceil(_loupeSizeBase.width *_scaleFactor),
                                      ceil(_loupeSizeBase.height *_scaleFactor));
        _lastMovedLoupe = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        DVShapeLayer *loupeLayer = [self getNamedLayer:@"loupeLayer"];
        if (!loupeLayer) {
            DVShapeLayer *loupe = [[DVShapeLayer alloc] init];
            loupe.identifier = @"loupeLayer";
            [self.layer addSublayer:loupe];
            loupeLayer = [self getNamedLayer:@"loupeLayer"];
        }
        
        loupeLayer.frame = CGRectMake(_lastMovedLoupe.x - (loupeSize.width / 2.0), _lastMovedLoupe.y - (loupeSize.height / 2.0), loupeSize.width, loupeSize.height);
        
        if ([_delegate respondsToSelector:@selector(mouseEnteredAt:)]) {
            NSPoint curPoint = loupeLayer.position;
            curPoint.x -= self.imageFrame.origin.x;
            curPoint.y -= self.imageFrame.origin.y;
            curPoint.x -= (loupeSize.width / 2.0);
            curPoint.y -= (loupeSize.height / 2.0);
            
            [_delegate mouseEnteredAt:NSMakePoint(curPoint.x / _scaleFactor,curPoint.y / _scaleFactor)];
        }
        
        [loupeLayer drawRect:1.5
                   rect:NSMakeRect(0, 0, loupeSize.width, loupeSize.height)
                  color:NSColor.orangeColor
                   name:@"Loupe"];
    }
    else {
        NSDictionary *info = (NSDictionary *)[theEvent userData];
        if ([_delegate respondsToSelector:@selector(mouseEnteredArea:)]) {
            [_delegate mouseEnteredArea:[info[@"Count"] unsignedIntegerValue]];
        }
        NSRect area = [info[@"Area"] rectValue];
        NSString *identifier = [NSString stringWithFormat:@"%d", [info[@"Count"] intValue]];
        
        DVShapeLayer *rectArea = [self getNamedLayer:identifier];
        if (!rectArea) {
            rectArea = [[DVShapeLayer alloc] init];
            rectArea.identifier = identifier;
            rectArea.frame = area;
            [rectArea drawRect:2
                          rect:NSMakeRect(0, 0, area.size.width, area.size.height)
                         color:NSColor.redColor
                          name:identifier];
            [self.layer addSublayer:rectArea];
        }
        else {
            [rectArea setColor:identifier color:NSColor.redColor];
        }
    }
    
}

-(void)mouseExited:(NSEvent *)theEvent
{
    if (![theEvent userData]) {
        [self eraseNamedLayer:@"loupeLayer"];
        if ([_delegate respondsToSelector:@selector(mouseExitted)]) {
            [_delegate mouseExitted];
        }
    }
    else {
        NSDictionary *info = (NSDictionary *)[theEvent userData];
        NSString *identifier = [NSString stringWithFormat:@"%d", [info[@"Count"] intValue]];
        [self eraseNamedLayer:identifier];
    }
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint curPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    DVShapeLayer *hitLayer = [self hitLayer:curPoint];
    if (hitLayer) {
        [hitLayer setColor:hitLayer.identifier color:NSColor.blueColor];
        if ([_delegate respondsToSelector:@selector(decideEnteredArea)]) {
            [_delegate decideEnteredArea];
        }
    }
    
}

- (void)mouseUp:(NSEvent *)theEvent
{
    NSPoint curPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    DVShapeLayer *hitLayer = [self hitLayer:curPoint];
    if (hitLayer) {
        NSRect area = hitLayer.frame;
        NSString *identifier = hitLayer.identifier;
        [self eraseNamedLayer:hitLayer.identifier];
        DVShapeLayer *rectArea = [[DVShapeLayer alloc] init];
        rectArea.identifier = identifier;
        rectArea.frame = area;
        [rectArea drawRect:2
                      rect:NSMakeRect(0, 0, area.size.width, area.size.height)
                     color:NSColor.redColor
                      name:identifier];
        [self.layer addSublayer:rectArea];
    }
    
}

-(void)updateTrackingAreas
{
    [super updateTrackingAreas];
    
    NSRect frame = self.imageFrame;
    double realScale = sqrt(pow(_imgSizeReal.width, 2) + pow(_imgSizeReal.height, 2));
    double viewScale = sqrt(pow(frame.size.width, 2) + pow(frame.size.height, 2));
    
    _scaleFactor = viewScale / realScale;
    
    NSArray *arDiffRects = [self makeContourRects:_file.diffContours];
    NSArray *arDelRects = [self makeContourRects:_file.delContours];
    NSArray *arAddRects = [self makeContourRects:_file.addContours];
    
    NSMutableArray *arTrackArea = [NSMutableArray array];

    NSUInteger diffCount = 0;
    [self makeTrackArea:arAddRects trackAreas:&arTrackArea trackNum:&diffCount type:@"Add"];
    [self makeTrackArea:arDelRects trackAreas:&arTrackArea trackNum:&diffCount type:@"Del"];
    [self makeTrackArea:arDiffRects trackAreas:&arTrackArea trackNum:&diffCount type:@"Diff"];
    int opts = (NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingEnabledDuringMouseDrag);
    NSTrackingArea *trackingAreaAll = [ [NSTrackingArea alloc] initWithRect:frame
                                                                    options:opts
                                                                   owner:self
                                                                userInfo:nil];
    [arTrackArea addObject:trackingAreaAll];
    if(self.trackingAreas != nil) {
        for (NSTrackingArea *area in self.trackingAreas)
            [self removeTrackingArea:area];
    }
    [self eraseNamedLayer:@"loupeLayer"];
    DVShapeLayer *loupe = [[DVShapeLayer alloc] init];
    loupe.identifier = @"loupeLayer";
    [self.layer addSublayer:loupe];
    if (arTrackArea.count != 0) {
        for (NSTrackingArea *area in arTrackArea) {
            [self addTrackingArea:area];
        }
    }
}

#pragma mark -
#pragma mark Public Funcs
- (void)focusArea:(NSRect)area no:(NSString*)identifier
{
    [self eraseFocusedLayer];
    // area は実際のサイズなので、拡大縮小して使用
    DVShapeLayer *trgArea = [[DVShapeLayer alloc] init];
    trgArea.identifier = identifier;
    NSRect resizedArea = NSMakeRect(area.origin.x * _scaleFactor,
                                    area.origin.y * _scaleFactor,
                                    area.size.width * _scaleFactor,
                                    area.size.height * _scaleFactor);
    NSPoint flipped = NSMakePoint(resizedArea.origin.x, abs(self.imageFrame.size.height - resizedArea.origin.y) - resizedArea.size.height);
    resizedArea.origin.x = flipped.x;
    resizedArea.origin.y = flipped.y;
    
    resizedArea.origin.x += self.imageFrame.origin.x;
    resizedArea.origin.y += self.imageFrame.origin.y;
    
    
    trgArea.frame = resizedArea;
    [trgArea drawRect:4
                 rect:NSMakeRect(0, 0, resizedArea.size.width, resizedArea.size.height)
                color:NSColor.magentaColor
                 name:identifier];
    [self.layer addSublayer:trgArea];
    [self setNeedsDisplay];
}

- (void)eraseFocusedLayer
{
    NSMutableArray *arNewLayers = [NSMutableArray array];
    for (DVShapeLayer *lay in self.layer.sublayers) {
        if (![KZLibs isExistString:lay.identifier searchStr:@"Focus"]) {
            [arNewLayers addObject:lay];
        }
    }
    self.layer.sublayers = nil;
    self.layer.sublayers = [arNewLayers copy];
}

@end
