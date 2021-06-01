//
//  psdparser.cpp
//  KZPSDParser
//
//  Created by uchiyama_Macmini on 2019/08/13.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#include "psdparser.hpp"


namespace psd
{    
#pragma mark -
#pragma mark Public Funcs
    bool psd::load(std::string psd_file) {
        FILE *psd = fopen(psd_file.c_str(), "rb");
        return load(psd);
    }
    
    bool psd::load(FILE* psd_file) {
        valid_ = false;
        if (!read_header(psd_file))
            return false;
        if (!read_color_mode(psd_file))
            return false;
        if (!image_resources.load(psd_file))
            return false;
        if (!layers.load(psd_file))
            return false;
        /*if (!merged_image.read(psd_file, header.width, header.height, header.num_channels, header.bit_depth))
            return false;*/
        valid_ = true;
        return true;
    }
    
    bool psd::read_header(FILE* psd_file) {
        fseek(psd_file, 0, SEEK_SET);
        
        if (!read_file<Header>(psd_file, &header)) {
            std::cerr << "signature read error" << std::endl;
        }
        
        if (header.signature != *(uint32_t*)"8BPS" && header.signature != *(uint32_t*)"8BPB") {
            std::cerr << "signature error" << std::endl;
            return false;
        }
        
        if ((header.version != 1) && header.version != 2) {
            std::cerr << "header version error" << std::endl;
            return false;
        }
        
        if ((header.signature == *(uint32_t*)"8BPB") ||  header.version == 2) {
            layers.is_psb = true;
        }
        else {
            layers.is_psb = false;
        }
        
        if (header.bit_depth != 8) {
            std::cerr << "Not supported bit depth: " << header.bit_depth << std::endl;
            return false;
        }
        
#ifdef DEBUG
        std::cout << "Header:" << std::endl;
        std::cout << "\tsignature: " << std::string((char*)&header.signature, (char*)&header.signature + 4) << std::endl;
        std::cout << "\tversion: " << header.version << std::endl;
        std::cout << "\tnum_channels: " << header.num_channels << std::endl;
        std::cout << "\twidth: " << header.width << std::endl;
        std::cout << "\theight: " << header.height << std::endl;
        std::cout << "\tbit_depth: " << header.bit_depth << std::endl;
        std::cout << "\tcolor_mode: " << header.color_mode << std::endl;
#endif
        
        return true;
    }
    
    bool psd::read_color_mode(FILE* psd_file) {
        be<uint32_t> length;
        
        if (!read_file<be<uint32_t>>(psd_file, &length)) {
            std::cerr << "color mode length read error" << std::endl;
        }
        
        if (length != 0) {
            // 未対応のカラーモード(DuoTone or Indexed Color)
            std::cerr << "Not implemented color mode: " << header.color_mode;
            return false;
        }
        return true;
    }
   
}
