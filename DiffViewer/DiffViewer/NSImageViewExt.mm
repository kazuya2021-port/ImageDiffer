//
//  NSImageExt.m
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/08/01.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "NSImageViewExt.h"

@implementation NSImageView (ImageFrame)

// -------------------------------------------------------------------------
// -imageFrame
// -------------------------------------------------------------------------
- (NSRect)imageFrame
{
    // Find the content frame of the image without any borders first
    NSRect contentFrame = self.bounds;
    NSSize imageSize = self.image.size;
    NSImageFrameStyle imageFrameStyle = self.imageFrameStyle;
    
    if (imageFrameStyle == NSImageFrameButton ||
        imageFrameStyle == NSImageFrameGroove)
    {
        contentFrame = NSInsetRect(self.bounds, 2, 2);
    }
    
    else if (imageFrameStyle == NSImageFramePhoto)
    {
        contentFrame = NSMakeRect(contentFrame.origin.x + 1,
                                  contentFrame.origin.y + 2,
                                  contentFrame.size.width - 3,
                                  contentFrame.size.height - 3);
    }
    
    else if (imageFrameStyle == NSImageFrameGrayBezel)
    {
        contentFrame = NSInsetRect(self.bounds, 8, 8);
    }
    
    
    // Now find the right image size for the current imageScaling
    NSImageScaling imageScaling = self.imageScaling;
    NSSize drawingSize = imageSize;
    
    // Proportionally scaling
    if (imageScaling == NSImageScaleProportionallyDown ||
        imageScaling == NSImageScaleProportionallyUpOrDown)
    {
        NSSize targetScaleSize = contentFrame.size;
        if (imageScaling == NSImageScaleProportionallyDown)
        {
            if (targetScaleSize.width > imageSize.width) targetScaleSize.width = imageSize.width;
            if (targetScaleSize.height > imageSize.height) targetScaleSize.height = imageSize.height;
        }
        
        NSSize scaledSize = [self sizeByScalingProportionallyToSize:targetScaleSize fromSize:imageSize];
        drawingSize = NSMakeSize(scaledSize.width, scaledSize.height);
    }
    
    // Axes independent scaling
    else if (imageScaling == NSImageScaleAxesIndependently)
        drawingSize = contentFrame.size;
    
    
    // Now get the image position inside the content frame (center is default) from the current imageAlignment
    NSImageAlignment imageAlignment = self.imageAlignment;
    NSPoint drawingPosition = NSMakePoint(contentFrame.origin.x + contentFrame.size.width / 2.0 - drawingSize.width / 2.0,
                                          contentFrame.origin.y + contentFrame.size.height / 2.0 - drawingSize.height / 2.0);
    
    // NSImageAlignTop / NSImageAlignTopLeft / NSImageAlignTopRight
    if (imageAlignment == NSImageAlignTop ||
        imageAlignment == NSImageAlignTopLeft ||
        imageAlignment == NSImageAlignTopRight)
    {
        drawingPosition.y = contentFrame.origin.y+contentFrame.size.height - drawingSize.height;
        
        if (imageAlignment == NSImageAlignTopLeft)
            drawingPosition.x = contentFrame.origin.x;
        else if (imageAlignment == NSImageAlignTopRight)
            drawingPosition.x = contentFrame.origin.x + contentFrame.size.width - drawingSize.width;
    }
    
    // NSImageAlignBottom / NSImageAlignBottomLeft / NSImageAlignBottomRight
    else if (imageAlignment == NSImageAlignBottom ||
             imageAlignment == NSImageAlignBottomLeft ||
             imageAlignment == NSImageAlignBottomRight)
    {
        drawingPosition.y = contentFrame.origin.y;
        
        if (imageAlignment == NSImageAlignBottomLeft)
            drawingPosition.x = contentFrame.origin.x;
        else if (imageAlignment == NSImageAlignBottomRight)
            drawingPosition.x = contentFrame.origin.x + contentFrame.size.width - drawingSize.width;
    }
    
    // NSImageAlignLeft / NSImageAlignRight
    else if (imageAlignment == NSImageAlignLeft)
        drawingPosition.x = contentFrame.origin.x;
    
    // NSImageAlignRight
    else if (imageAlignment == NSImageAlignRight)
        drawingPosition.x = contentFrame.origin.x + contentFrame.size.width - drawingSize.width;
    
    NSRect retRC = NSMakeRect(round(drawingPosition.x),
                              round(drawingPosition.y),
                              ceil(drawingSize.width),
                              ceil(drawingSize.height));
    
    return retRC;
}


// -------------------------------------------------------------------------
// -sizeByScalingProportionallyToSize:fromSize:
// -------------------------------------------------------------------------
- (NSSize)sizeByScalingProportionallyToSize:(NSSize)newSize fromSize:(NSSize)oldSize
{
    CGFloat widthHeightDivision = oldSize.width / oldSize.height;
    CGFloat heightWidthDivision = oldSize.height / oldSize.width;
    
    NSSize scaledSize = NSZeroSize;
    if (oldSize.width > oldSize.height)
    {
        if ((widthHeightDivision * newSize.height) >= newSize.width)
        {
            scaledSize = NSMakeSize(newSize.width, heightWidthDivision * newSize.width);
        }  else {
            scaledSize = NSMakeSize(widthHeightDivision * newSize.height, newSize.height);
        }
        
    } else {
        
        if ((heightWidthDivision * newSize.width) >= newSize.height)
        {
            scaledSize = NSMakeSize(widthHeightDivision * newSize.height, newSize.height);
        } else {
            scaledSize = NSMakeSize(newSize.width, heightWidthDivision * newSize.width);
        }
    }
    
    return scaledSize;
}

@end
