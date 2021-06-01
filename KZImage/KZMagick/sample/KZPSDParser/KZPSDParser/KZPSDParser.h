//
//  KZPSDParser.h
//  KZPSDParser
//
//  Created by uchiyama_Macmini on 2019/08/08.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KZPSDParser : NSObject
@property (nonatomic, assign) NSUInteger layerCount;
@property (nonatomic, copy) NSArray *layers;
+ (id)initWithPath:(NSString*)path;
@end
