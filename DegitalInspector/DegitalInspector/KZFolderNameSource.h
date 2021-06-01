//
//  KZFolderNameSource.h
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/05.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KZFolderNameSource : NSObject <NSComboBoxDataSource>
+ (instancetype)sharedFolderNameSource;
@property (nonatomic, strong) NSMutableArray *values;
@end
