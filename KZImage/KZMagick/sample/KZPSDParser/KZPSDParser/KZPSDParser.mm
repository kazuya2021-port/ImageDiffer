//
//  KZPSDParser.m
//  KZPSDParser
//
//  Created by uchiyama_Macmini on 2019/08/08.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#include <stdio.h>
#include <iostream>
#include "miniz.h"
#include "psdparser.hpp"
#import "KZPSDParser.h"





@interface KZPSDParser()
{
    psd::psd *_psd;
}
@end

@implementation KZPSDParser
+ (id)initWithPath:(NSString*)path
{
    KZPSDParser* psd = [[KZPSDParser alloc] init];
    if (psd) {
        psd->_psd = new psd::psd([path UTF8String]);
        
        if (!psd->_psd) {
            std::cerr << "fail to open" << std::endl;
            delete psd->_psd;
            return nil;
        }
        
        psd.layerCount = psd->_psd->layers.layers().size();
        NSMutableArray *arLayImgs = [NSMutableArray arrayWithCapacity:psd.layerCount];
        
        if (psd->_psd->header.bit_depth == 1) {
            std::cerr << "unsupported bit depth: " << psd->_psd->header.bit_depth << std::endl;
            return nil;
        }
        uint32_t bytes_per_pixel = psd->_psd->header.bit_depth/8;
        
        for (auto it = psd->_psd->layers.layers().begin(); it != psd->_psd->layers.layers().end(); ++it) {
            std::vector<char> theLayData;
            uint16_t channels = it->num_channels;
            uint32_t w = it->right - it->left;
            uint32_t h = it->bottom - it->top;
            
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    for (int ch = 0; ch < channels; ch++) {
                        theLayData.push_back(it->channel_info_data[ch].data[y][x*bytes_per_pixel + bytes_per_pixel-1]);
                    }
                }
            }
            size_t png_size;
            NSData *png_data = [[NSData alloc] initWithBytes:tdefl_write_image_to_png_file_in_memory(theLayData.data(), w, h, channels, &png_size)
                                                      length:png_size];
            NSDictionary *layInfo = @{@"name" : [NSString stringWithUTF8String:it->name.c_str()],
                                      @"data" : png_data
                                      };
            [arLayImgs addObject:layInfo];
        }
        psd.layers = [arLayImgs copy];
        return psd;
    }
    return nil;
}
@end
