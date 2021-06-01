//
//  XMPTool.h
//  XMPTool
//
//  Created by 内山和也 on 2019/06/14.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

//! Project version number for XMPTool.
FOUNDATION_EXPORT double XMPToolVersionNumber;

//! Project version string for XMPTool.
FOUNDATION_EXPORT const unsigned char XMPToolVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <XMPTool/PublicHeader.h>

@interface XmpSDK : NSObject

+ (NSArray*)getXmpInfoBuffer:(NSData*)imgData error:(NSError **) error;
+ (NSArray*)getXmpInfo:(NSString*)imgPath error:(NSError **) error;
+ (BOOL)writeXmpInfo:(NSDictionary*)writeInfo imgPath:(NSString*)imgPath fileType:(NSString*)type error:(NSError **) error;

@end


