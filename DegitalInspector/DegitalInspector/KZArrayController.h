//
//  KZArrayController.h
//  DigitalInspector
//
//  Created by uchiyama_Macmini on 2018/12/19.
//  Copyright © 2018年 uchiyama_Macmini. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface KZArrayController : NSArrayController
@property (nonatomic, assign) BOOL modified;
@property (nonatomic, copy) NSArray *keys;
@end
