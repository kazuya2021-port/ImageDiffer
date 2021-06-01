//
//  DVArrayController.h
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/08/02.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DVArrayController : NSArrayController
@property (nonatomic, assign) BOOL modified;
@property (nonatomic, copy) NSArray *keys;
@end
