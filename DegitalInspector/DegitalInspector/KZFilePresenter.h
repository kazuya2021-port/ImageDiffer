//
//  KZFilePresenter.h
//  DegitalInspector
//
//  Created by uchiyama_Macmini on 2019/07/16.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KZFilePresenter : NSObject<NSFilePresenter>
@property (assign) BOOL isPresenting;
@property (nonatomic, copy) NSURL *presentedItemURL;
@property (nonatomic, strong) NSOperationQueue *presentedItemOperationQueue;
- (id)initWithURL:(NSURL*)path;
@end
