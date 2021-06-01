//
//  NSNotificationCenter+Utils.h
//  DigitalInspector
//
//  Created by uchiyama_Macmini on 2018/12/21.
//  Copyright © 2018年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSNotificationCenter (Utils)
-(void)postNotificationOnMainThread:(NSNotification *)notification;
-(void)postNotificationNameOnMainThread:(NSString *)aName object:(id)anObject;
-(void)postNotificationNameOnMainThread:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo;
@end
