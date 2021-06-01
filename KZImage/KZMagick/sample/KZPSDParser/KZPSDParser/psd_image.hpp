//
//  psd_image.hpp
//  KZPSDParser
//
//  Created by uchiyama_Macmini on 2019/08/13.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef psd_image_hpp
#define psd_image_hpp

#include <stdio.h>
#include "psd_utils.hpp"

namespace psd {
    struct ImageData
    {
        uint32_t w;
        uint32_t h;
        be<uint16_t> compression_method;
        std::vector<std::vector<char>> data;
        bool is_psb;
        bool read(FILE* psd_file, uint32_t w, uint32_t h);
        bool write(FILE* psd_file);
        bool read_with_method(FILE* psd_file);
        
        template <typename T>
        bool decoe_RLE(FILE* psd_file,
                       std::vector<std::vector<char>> &src,
                       std::vector<T> lengths);
    };
    
    struct MultipleImageData
    {
        uint32_t w;
        uint32_t h;
        uint32_t count;
        be<uint16_t> compression_method;
        std::vector<std::vector<std::vector<char>>> datas;
        bool read(FILE* psd_file, uint32_t w, uint32_t h, uint32_t count, uint16_t bit_depth);
        bool write(FILE* psd_file);
    };
}
#endif /* psd_image_hpp */
