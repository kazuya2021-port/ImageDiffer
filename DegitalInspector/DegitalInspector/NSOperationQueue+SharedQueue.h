//
//  BAOperationQueue.h
//  DigitalInspector
//
//  Created by uchiyama_Macmini on 2019/02/04.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

//  NSOperationQueue+SharedQueue.h

#import <Foundation/Foundation.h>

@interface NSOperationQueue (SharedQueue)

+ (NSOperationQueue *) sharedOperationQueue;
- (void)performSelectorOnBackgroundQueue:(SEL)aSelector withObject:(id)anObject;

@end

#define SHARED_OPERATION_QUEUE [NSOperationQueue sharedOperationQueue]
