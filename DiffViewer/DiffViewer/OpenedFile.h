//
//  OpenFile.h
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/07/31.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OpenedFile : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *fileType;
@property (nonatomic, copy) NSArray *diffContours;
@property (nonatomic, copy) NSArray *addContours;
@property (nonatomic, copy) NSArray *delContours;
+ (id)initWithPath:(NSString*)path error:(NSError**)error;
@end
