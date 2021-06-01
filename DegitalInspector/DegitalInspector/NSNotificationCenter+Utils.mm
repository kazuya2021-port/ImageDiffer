//
//  NSNotificationCenter+Utils.m
//  DigitalInspector
//
//  Created by uchiyama_Macmini on 2018/12/21.
//  Copyright © 2018年 uchiyama_Macmini. All rights reserved.
//

#import "NSNotificationCenter+Utils.h"
#import "NSInvocation+Utils.h"

@interface NSNotificationCenter (Utils_Impl)
-(void)postNotificationOnMainThreadImpl:(NSNotification*)notification;
-(void)postNotificationNameOnMainThreadImpl:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo;
@end

@implementation NSNotificationCenter (Utils)
-(void)postNotificationOnMainThread:(NSNotification *)notification {
    CFRetain((__bridge CFTypeRef)notification);
    if(notification.object != nil){
        CFRetain((__bridge CFTypeRef)notification.object);
    }
    [self performSelectorOnMainThread:@selector(postNotificationOnMainThreadImpl:)
                           withObject:notification
                        waitUntilDone:NO];
}
-(void)postNotificationNameOnMainThread:(NSString *)aName object:(id)anObject {
    [self postNotificationNameOnMainThread:aName object:anObject userInfo:nil];
}

-(void)postNotificationNameOnMainThread:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo {
    CFRetain((__bridge CFTypeRef)aName);
    if(anObject != nil){
        CFRetain((__bridge CFTypeRef)anObject);
    }
    if(aUserInfo != nil){
        CFRetain((__bridge CFTypeRef)aUserInfo);
    }
    
    SEL sel = @selector(postNotificationNameOnMainThreadImpl:object:userInfo:);
    NSMethodSignature* sig = [self methodSignatureForSelector:sel];
    NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:sig];
    [invocation setTarget:self];
    [invocation setSelector:sel];
    [invocation setArgument:&aName atIndex:2];
    [invocation setArgument:&anObject atIndex:3];
    [invocation setArgument:&aUserInfo atIndex:4];
    [invocation invokeOnMainThreadWaitUntilDone:NO];
}
@end

@implementation NSNotificationCenter (Utils_Impl)

-(void)postNotificationOnMainThreadImpl:(NSNotification*)notification {
    [self postNotification:notification];
    if(notification.object != nil){
        CFRelease((__bridge CFTypeRef)notification.object);
    }
    CFRelease((__bridge CFTypeRef)notification);
}

-(void)postNotificationNameOnMainThreadImpl:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo {
    [self postNotificationName:aName object:anObject userInfo:aUserInfo];
    if(aUserInfo != nil){
        CFRelease((__bridge CFTypeRef)aUserInfo);
    }
    if(anObject != nil){
        CFRelease((__bridge CFTypeRef)anObject);
    }
    CFRelease((__bridge CFTypeRef)aName);
}

@end
