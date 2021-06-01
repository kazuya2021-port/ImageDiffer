//
//  psd_image.cpp
//  KZPSDParser
//
//  Created by uchiyama_Macmini on 2019/08/13.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#include "psd_image.hpp"

bool psd::ImageData::read(FILE* psd_file, uint32_t w, uint32_t h)
{
    this->w = w;
    this->h = h;
    
    if(!read_file(psd_file, &compression_method)) {
        std::cerr << "ImageData : read compression_method fail" << std::endl;
        return false;
    }
    return read_with_method(psd_file);
}

template <typename T>
bool psd::ImageData::decoe_RLE(FILE* psd_file,
                               std::vector<std::vector<char>> &src,
                               std::vector<T> lengths)
{
    for (uint32_t y = 0; y < h; y++) {
        std::vector<char> uncomp;
        src[y].resize(lengths[y]);
        fread(&src[y][0], sizeof(src[y][0]), lengths[y], psd_file);
        
        for (uint32_t x = 0; x < src[y].size(); x++) {
            int c = src[y][x];
            if (c >= 128) c -= 256;
            if (c == -128) continue;
            else if (c < 0) {
                x++;
                for (int j = 0; j < 1-c; j++)
                    uncomp.push_back(src[y][x]);
            }
            else {
                if (x+1 + c+1 > data[y].size()) {
#ifdef DEBUG
                    std::cout << "PackBit source length invalid" << std::endl;
#endif
                    return false;
                }
                uncomp.insert(uncomp.end(), src[y].begin()+x+1, src[y].begin()+x+1+c+1);
                x += c+1;
            }
        }
        if (uncomp.size()*8%w != 0 || uncomp.size() == 0)
        {
#ifdef DEBUG
            std::cout << "PackBit line " << y << " uncompressed length invalid " << uncomp.size() << ' ' << w << std::endl;
#endif
            return false;
        }
        src[y].swap(uncomp);
    }
    return true;
}

bool psd::ImageData::read_with_method(FILE* psd_file)
{
    switch(compression_method) {
        case 0: // RAW
        {
            data.resize(h);
            for (uint32_t y = 0; y < h; y ++) {
                data[y].resize(w);
                fread(&data[y][0], sizeof(data[y][0]), w, psd_file);
            }
        }
            break;
            
        case 1: // PackBits by line
        {
            std::vector<be<uint16_t>> byteCount;
            std::vector<be<uint32_t>> byteCount_b;
            data.resize(h);
            
            if (is_psb) {
                byteCount_b.resize(h);
                fread(&byteCount_b[0], sizeof(byteCount_b[0]), h, psd_file);
            }
            else {
                byteCount.resize(h);
                fread(&byteCount[0], sizeof(byteCount[0]), h, psd_file);
            }
            
            
            if (is_psb) {
                if (!decoe_RLE<be<uint32_t>>(psd_file, data, byteCount_b)) {
                    return false;
                }
            }
            else {
                if (!decoe_RLE<be<uint16_t>>(psd_file, data, byteCount)) {
                    return false;
                }
            }
        }
            break;
        default:
            if (compression_method >= 2) {
#ifdef DEBUG
                std::cout << "Not supported compression method (ImageData): " << compression_method << std::endl;
#endif
                return false;
            }
    }
    
    return true;
}

bool psd::MultipleImageData::read(FILE* psd_file, uint32_t w, uint32_t h, uint32_t count, uint16_t bit_depth)
{
    this->w = w;
    this->h = h;
    this->count = count;
    if (!read_file(psd_file, &compression_method)) {
        std::cerr << "MultipleImageData : read compression_method fail" << std::endl;
        return false;
    }
    
    ImageData imageData;
    imageData.w = w;
    imageData.h = h*count;
    imageData.compression_method = compression_method;
    
    if (!imageData.read_with_method(psd_file)) {
        std::cerr << "MultipleImageData::read error" << std::endl;
        return false;
    }
    datas.resize(count);
    uint32_t row = 0;
    for (uint32_t ch = 0; ch < count; ch ++) {
        datas[ch].resize(h);
        for (uint32_t y = 0; y < h; y ++) {
            datas[ch][y].swap(imageData.data[row++]);
            if (datas[ch][y].size() != w*bit_depth/8) {
#ifdef DEBUG
                std::cout << datas[ch][y].size() << ' ' << w << ' ' <<bit_depth << std::endl;
#endif
                return false;
            }
        }
    }
    return true;
}
