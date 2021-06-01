//
//  NSInvocation+Utils.m
//  DigitalInspector
//
//  Created by uchiyama_Macmini on 2018/12/21.
//  Copyright © 2018年 uchiyama_Macmini. All rights reserved.
//

#import "NSInvocation+Utils.h"

@implementation NSInvocation (Utils)

-(void)invokeOnMainThreadWaitUntilDone:(BOOL)wait
{
    [self performSelectorOnMainThread:@selector(invoke)
                           withObject:nil
                        waitUntilDone:wait];
}

@end
