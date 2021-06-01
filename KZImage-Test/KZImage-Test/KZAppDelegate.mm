//
//  KZAppDelegate.m
//  KZImage-Test
//
//  Created by 内山和也 on 2019/03/26.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZAppDelegate.h"
#import <KZImage/KZImage.h>
#import <KZImage/ImageEnum.h>
#import <KZLibs.h>
@implementation KZAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    freopen([@"/tmp/KZImageLog.txt" fileSystemRepresentation], "w+", stderr);
    freopen([@"/tmp/KZImageOut.txt" fileSystemRepresentation], "w+", stdout);
    
    KZImage *imgutil = [[KZImage alloc] init];
    ConvertSetting *setting = [[ConvertSetting alloc] init];
    
    setting.Resolution = 36;
    setting.toSpace = KZColorSpace::SRGB;
    setting.isResize = YES;
    
    
    [imgutil startEngine];
    

    
    NSString *openPath;
    NSOpenPanel *openP = [[NSOpenPanel alloc] init];
    openP.title = @"変換もと開く";
    NSInteger ret = [openP runModal];

    if(ret == NSFileHandlingPanelOKButton)
    {
        openPath = openP.URL.path;
        NSData *imgdata = [NSData dataWithContentsOfFile:openPath];
        NSArray *ar = [imgutil makeAllThumbnails:imgdata atPage:0 toPage:335 format:KZFileFormat::JPG_FORMAT size:NSMakeSize(114, 160) setting:setting];
        NSLog(@"%@" , ar);
    }
    
    [imgutil stopEngine];
}

@end
