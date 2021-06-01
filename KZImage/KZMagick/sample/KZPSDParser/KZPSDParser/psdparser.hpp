//
//  psdparser.hpp
//  KZPSDParser
//
//  Created by uchiyama_Macmini on 2019/08/13.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef psdparser_hpp
#define psdparser_hpp

#include <stdio.h>
#include <string>
#include <cstdint>

#include "psd_image_resources.hpp"
#include "psd_layer_and_mask.hpp"

namespace psd
{
    enum class ColorMode : uint16_t
    {
        Bitmap = 0,
        Grayscale = 1,
        Indexed = 2,
        RGB = 3,
        CMYK = 4,
        Multichannel = 7,
        Duotone = 8,
        Lab = 9,
    };
    
    
#pragma pack(push, 1)
    struct Header
    {
        Header() : reserve1(0), reserve2(0) {}
        Signature signature;
        be<uint16_t> version;
        uint16_t reserve1;
        uint32_t reserve2;
        be<uint16_t> num_channels;
        be<uint32_t> height;
        be<uint32_t> width;
        be<uint16_t> bit_depth;
        be<uint16_t> color_mode;
    };
    
    
#pragma pack(pop)
    
    class psd
    {
    public:
        psd();
        template <typename Stream> psd(Stream&& stream) {
            load(stream);
        }
        bool load(FILE* psd_file);
        bool load(std::string psd_file);
        bool save(FILE* psd_file);
        
        Header header;
        
        ImageResources image_resources;
        
        Layers layers;
        
        
        MultipleImageData merged_image;
        
        operator bool();
    private:
        bool read_header(FILE* psd_file);
        bool read_color_mode(FILE* psd_file);
        bool read_image_resources(FILE* psd_file);
        bool read_layers_and_masks(FILE* psd_file);
        
        bool read_layer_info(FILE* psd_file);
        
        bool write_header(FILE* psd_file);
        bool write_color_mode(FILE* psd_file);
        bool write_image_resources(FILE* psd_file);
        bool write_layers_and_masks(FILE* psd_file);
        
        bool valid_;
        
    };
}
#endif /* psdparser_hpp */
