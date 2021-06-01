//
//  BAOperationQueue.m
//  DigitalInspector
//
//  Created by uchiyama_Macmini on 2019/02/04.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

//  NSOperationQueue+SharedQueue.m

#import "NSOperationQueue+SharedQueue.h"

@implementation NSOperationQueue (SharedQueue)

+ (NSOperationQueue *) sharedOperationQueue {
    
    static dispatch_once_t pred;
    static NSOperationQueue* sharedQueue;
    
    dispatch_once(&pred, ^{
        sharedQueue = [[NSOperationQueue alloc] init];
        sharedQueue.maxConcurrentOperationCount = 4;
    });
    
    return sharedQueue;
}

- (void) performSelectorOnBackgroundQueue:(SEL)aSelector withObject:(id)anObject {
    
    NSOperation* operation = [[NSInvocationOperation alloc]
                              initWithTarget:self
                              selector:aSelector
                              object:anObject];
    [[NSOperationQueue sharedOperationQueue] addOperation:operation];
}

@end
