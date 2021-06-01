//
//  NSInvocation+Utils.h
//  DigitalInspector
//
//  Created by uchiyama_Macmini on 2018/12/21.
//  Copyright © 2018年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSInvocation (Utils)
-(void)invokeOnMainThreadWaitUntilDone:(BOOL)wait;
@end
