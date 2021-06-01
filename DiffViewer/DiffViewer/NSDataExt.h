//
//  NSDataExt.h
//  DiffImgCV
//
//  Created by uchiyama_Macmini on 2019/07/31.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (NSDataZlibExtension)
- (id)deflate:(int)compressionLevel;
- (id)inflate;
@end
