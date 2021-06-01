//
//  DVChangeDouble.m
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/08/02.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "DVChangeDouble.h"
#import "DVWholeImageView.h"

@interface DVChangeDouble()
{
    id diffViewResizeObserver;
    std::vector<cv::Mat> imageArray;
}
@property (nonatomic, retain) KZImage *imgUtil;
@property (nonatomic, assign) NSPoint defPos;
@end

@implementation DVChangeDouble

NSImage* encodeMatToImage(cv::Mat img, const cv::String type)
{
    std::vector<uchar> buf;
    cv::imencode(type, img, buf);
    NSData *retData = [[NSData alloc] initWithBytes:buf.data() length:buf.size()];
    NSImage *retImage = [[NSImage alloc] initWithData:retData];
    return retImage;
}

- (CALayer*)getLayer:(NSString*)name
{
    CALayer *ret = nil;
    NSArray *searchLayers = nil;
    if ([KZLibs isExistString:name searchStr:@"A"]) {
        searchLayers = self.diffImageA.layer.sublayers;
    }
    else if ([KZLibs isExistString:name searchStr:@"B"]) {
        searchLayers = self.diffImageB.layer.sublayers;
    }
    for (CALayer *lay in searchLayers) {
        if (EQ_STR(lay.name, name)) {
            ret = lay;
            break;
        }
    }
    return ret;
}

- (void)setImageLayer
{
    const cv::String enc_format(".tif");
    CALayer *layerA = [[CALayer alloc] init];
    CALayer *layerB = [[CALayer alloc] init];
    CGFloat width = imageArray[0].cols;
    CGFloat height = imageArray[0].rows;
    layerA.contents = encodeMatToImage(imageArray[0], enc_format);
    layerB.contents = encodeMatToImage(imageArray[1], enc_format);
    layerA.contentsGravity = kCAGravityBottomLeft;
    layerB.contentsGravity = kCAGravityBottomLeft;
    layerA.frame = NSMakeRect(0, 0, width, height);
    layerB.frame = NSMakeRect(0, 0, width, height);
    layerA.name = @"MagA";
    layerB.name = @"MagB";
    layerA.hidden = YES;
    layerB.hidden = YES;
    
    if (self.diffImageA.layer.sublayers) {
        self.diffImageA.layer.sublayers = nil;
    }
    if (self.diffImageB.layer.sublayers) {
        self.diffImageB.layer.sublayers = nil;
    }
    
    [self.diffImageA.layer addSublayer:layerA];
    [self.diffImageB.layer addSublayer:layerB];
}

- (void)setPath:(NSString *)path
{
    _imagePath = path;
    
    NSArray *arLays = [_imgUtil getLayerImageFrom:_imagePath];
    
    NSData *bImage;
    NSData *aImage;
    bImage = arLays[1];
    aImage = arLays[2];
    imageArray.push_back(cv::imdecode(cv::Mat(1, (int)bImage.length, CV_8UC3, (void*)bImage.bytes), cv::IMREAD_COLOR));
    imageArray.push_back(cv::imdecode(cv::Mat(1, (int)aImage.length, CV_8UC3, (void*)aImage.bytes), cv::IMREAD_COLOR));
    [self setImageLayer];
    CALayer *layerA = [self getLayer:@"MagA"];
    _defPos = layerA.position;
}

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
    _imgUtil = [[KZImage alloc] init];
    [_imgUtil startEngine];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)mouseEnteredAt:(NSPoint)realPos wholeImage:(DVWholeImageView*)wholeImage
{
    CALayer *layerA = [self getLayer:@"MagA"];
    CALayer *layerB = [self getLayer:@"MagB"];
    
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
    layerA.hidden = NO;
    layerB.hidden = NO;
    
    layerA.position = NSMakePoint(_defPos.x - realPos.x,
                                  _defPos.y - realPos.y);
    layerB.position = NSMakePoint(_defPos.x - realPos.x,
                                  _defPos.y - realPos.y);
    [CATransaction commit];
}

- (void)focusAt:(NSRect)focusRect wholeImage:(DVWholeImageView*)wholeImage
{
    CALayer *layerA = [self getLayer:@"MagA"];
    CALayer *layerB = [self getLayer:@"MagB"];
    
    NSPoint focusPoint = NSMakePoint(focusRect.origin.x + (focusRect.size.width / 2),
                                     focusRect.origin.y + (focusRect.size.height / 2));
    NSPoint realPos = NSMakePoint(focusPoint.x, abs(wholeImage.imgSizeReal.height - focusPoint.y));
    
    realPos.x -= (wholeImage.loupeSizeBase.width / 2);
    realPos.y -= (wholeImage.loupeSizeBase.height / 2);
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    layerA.hidden = NO;
    layerB.hidden = NO;
    layerA.position = NSMakePoint(_defPos.x - realPos.x,
                                  _defPos.y - realPos.y);
    layerB.position = NSMakePoint(_defPos.x - realPos.x,
                                  _defPos.y - realPos.y);
    [CATransaction commit];
}

- (void)mouseMovedAt:(NSPoint)diffPos
{
    CALayer *layerA = [self getLayer:@"MagA"];
    CALayer *layerB = [self getLayer:@"MagB"];
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
    layerA.hidden = NO;
    layerB.hidden = NO;
    layerA.position = NSMakePoint(layerA.position.x - diffPos.x,
                                  layerA.position.y - diffPos.y);
    layerB.position = NSMakePoint(layerB.position.x - diffPos.x,
                                  layerB.position.y - diffPos.y);
    
    [CATransaction commit];
}

- (void)mouseExitted
{
    for (CALayer *lay in self.diffImageA.layer.sublayers) {
        lay.hidden = YES;
    }
    for (CALayer *lay in self.diffImageB.layer.sublayers) {
        lay.hidden = YES;
    }
    
}
@end
