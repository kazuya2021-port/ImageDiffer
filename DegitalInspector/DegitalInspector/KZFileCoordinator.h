//
//  KZFileCoordinator.h
//  DegitalInspector
//
//  Created by uchiyama_Macmini on 2019/07/16.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol KZFileCoordinatorDelegate <NSObject>
- (void)onDirectoryChanged:(id)sender file:(NSURL*)file isRemoved:(BOOL)isRemoved;
@end

@interface KZFileCoordinator : NSObject <NSFilePresenter>
@property (assign) BOOL isPresenting;
@property (assign) BOOL isDirEntered;
@property (nonatomic, strong) NSFileCoordinator *corrd;
@property (nonatomic, copy) NSURL *presentedItemURL;
@property (nonatomic, strong) NSOperationQueue *presentedItemOperationQueue;
@property (weak, nonatomic) id<KZFileCoordinatorDelegate> delegate;
- (id)initWithPath:(NSString*)path;
@end
