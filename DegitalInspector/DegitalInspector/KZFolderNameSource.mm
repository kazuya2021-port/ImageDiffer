//
//  KZFolderNameSource.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/05.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZFolderNameSource.h"

@interface KZFolderNameSource ()
@end

@implementation KZFolderNameSource

- (id)init
{
    self = [super init];
    if(self)
    {
        _values = [[NSMutableArray alloc] init];
    }
    return self;
}

+ (instancetype)sharedFolderNameSource
{
    static KZFolderNameSource *_sharedNameSource;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedNameSource = [[KZFolderNameSource alloc] init];
    });
    return _sharedNameSource;
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
    return _values.count;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
    return [_values objectAtIndex:index];
}
@end
