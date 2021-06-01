//
//  psd_util.hpp
//  KZMagick
//
//  Created by uchiyama_Macmini on 2019/08/19.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef psd_util_hpp
#define psd_util_hpp

#include "psd_def.h"
#include <string>
#include <vector>
#include <list>
#include <memory>

namespace Psd {
    namespace Util {
        
        template <class T>
        void write_buf(std::vector<psd_uint8_t> *buf, const T data)
        {
            std::vector<psd_uint8_t> tmp(sizeof(T));
            memcpy(&tmp[0], &data, sizeof(T));
            std::copy(tmp.begin(), tmp.end(), std::back_inserter(*buf));
        }
        
        template <class T>
        void write_list(std::list<psd_uint8_t> *buf, const T data)
        {
            std::vector<psd_uint8_t> tmp(sizeof(T));
            memcpy(&tmp[0], &data, sizeof(T));
            std::copy(tmp.begin(), tmp.end(), std::back_inserter(*buf));
        }
        
        
        template <class T>
        void insert_front(std::list<psd_uint8_t> *buf, const T data)
        {
            std::vector<psd_uint8_t> tmp(sizeof(T));
            memcpy(&tmp[0], &data, sizeof(T));
            std::reverse(tmp.begin(), tmp.end());
            std::copy(tmp.begin(), tmp.end(), std::front_inserter(*buf));
        }
        
        template <class T>
        void read_buf(const std::vector<psd_uint8_t> &buf, T *data, psd_uint64_t *read_pos)
        {
            std::string tmp(buf.begin()+(*read_pos), buf.begin()+(sizeof(T) + (*read_pos)));
            *read_pos += sizeof(T);
            const char* b = tmp.c_str();
            *data = 0;
            memcpy(data, b, sizeof(T));
        }
        
        template <class T>
        void read_buf(const std::vector<psd_uint8_t> &buf, T *data, psd_uint64_t *read_pos, size_t length)
        {
            std::string tmp(buf.begin()+(*read_pos), buf.begin()+((sizeof(T) * length) + (*read_pos)));
            *read_pos += (sizeof(T) * length);
            const char* b = tmp.c_str();
            *data = 0;
            memcpy(data, b, (sizeof(T) * length));
        }
        
        template <class T>
        void read_buf_byte(const std::vector<psd_uint8_t> &buf, T *data, psd_uint64_t *read_pos, size_t length)
        {
            std::string tmp(buf.begin()+(*read_pos), buf.begin()+((sizeof(char) * length) + (*read_pos)));
            *read_pos += (sizeof(char) * length);
            const char* b = tmp.c_str();
            *data = 0;
            memcpy(data, b, (sizeof(char) * length));
        }
        
        void read_string(const std::vector<psd_uint8_t> &buf, std::string *data, psd_uint64_t *read_pos)
        {
            std::string tmp(buf.begin()+(*read_pos), buf.begin()+(data->size() + (*read_pos)));
            *read_pos += data->size();
            const char* b = tmp.c_str();
            memcpy(data, b, data->size());
        }
        
        /*
        bool encode_RLE_img(const char * src_img,
                            const psd_uint32_t width,
                            const psd_uint32_t height,
                            const psd_uint8_t channels,
                            std::vector<std::vector<psd_uint8_t>> *ch_len,
                            std::vector<std::vector<psd_uint8_t>> *ch_img)
        {
            ch_len->resize(channels);
            ch_img->resize(channels);
            const int MaxLen = 127;
            std::vector<psd_uint32_t> count_bufs;
            std::vector<std::vector<std::vector<psd_uint8_t>>> splited;
            splited.resize(channels);
            for (int ch = 0; ch < channels; ch++) {
                splited[ch].resize(height);
                for (int y = 0; y < height; y++) {
                    splited[ch][y].resize(width);
                }
            }
            
            psd_uint64_t read_idx = 0;
            for (psd_uint32_t y = 0; y < height; y++)
            for (psd_uint32_t x = 0; x < width; x++)
            for (psd_uint8_t ch = 0; ch < channels; ch++) {
                splited[ch][y][x] = src_img[read_idx];
                read_idx++;
            }
            
            for (psd_uint8_t ch = 0; ch < channels; ch++)
            {
                std::vector<psd_uint8_t> img;
                img.reserve(height * width);
                ch_len->at(ch).resize(height*sizeof(psd_uint16_t));
                psd_uint32_t count_buf = 0;
                for (psd_uint32_t y = 0; y < height; y++)
                {
                    std::list<psd_int8_t> literals;
                    for (psd_uint32_t x = 0; x < width; x++)
                    {
                        char current = splited[ch][y][x];
                        if (x+1 != width)
                        {
                            char next = splited[ch][y][x+1];
                            if (next == current)
                            {
                                if (literals.size() > 0)
                                {
                                    img.push_back(literals.size() - 1);
                                    for (psd_int8_t li : literals) img.push_back(li);
                                }
                                literals.clear();
                                
                                int max = (x + MaxLen >= width )? width - x - 1 : MaxLen;
                                bool hitMax = true;
                                char runLength = 1;
                                for (int j = 2; j <= max; j++)
                                {
                                    char run = splited[ch][y][j + x];
                                    if (run != current)
                                    {
                                        hitMax = false;
                                        char count = (0-runLength);
                                        x += (j - 1);
                                        img.push_back(count);
                                        img.push_back(current);
                                        break;
                                    }
                                    runLength++;
                                }
                                
                                if (hitMax)
                                {
                                    img.push_back(0-max);
                                    img.push_back(current);
                                    x += max;
                                }
                            }
                            else
                            {
                                literals.push_back(current);
                                if (literals.size() == MaxLen) {
                                    if (literals.size() > 0)
                                    {
                                        img.push_back(literals.size() - 1);
                                        for (psd_int8_t li : literals) img.push_back(li);
                                    }
                                    literals.clear();
                                }
                            }
                        }
                        else
                        {
                            literals.push_back(current);
                            if (literals.size() > 0)
                            {
                                img.push_back(literals.size() - 1);
                                for (psd_int8_t li : literals) img.push_back(li);
                            }
                            literals.clear();
                        }
                    }
                    psd_uint16_t rc = img.size() - count_buf;
                    count_buf += rc;
                    
                    ch_len->at(ch).at(y*2) = (psd_uint8_t)(rc >> 8);
                    ch_len->at(ch).at(y*2+1) = (psd_uint8_t)rc;
                }
    
                ch_img->at(ch).reserve(count_buf);
                std::copy(img.begin(), img.begin() + count_buf, std::back_inserter(ch_img->at(ch)));
                count_bufs.push_back(img.size());
            }
            
            return true;
        }
        */
        
        bool encode_RLE_img(const char * src_img,
                            const psd_uint32_t width,
                            const psd_uint32_t height,
                            const psd_uint8_t channels,
                            std::vector<std::vector<psd_uint8_t>> *ch_len,
                            std::vector<std::vector<psd_uint8_t>> *ch_img)
        {
            ch_len->resize(channels);
            ch_img->resize(channels);
            const int MaxLen = 127;
            std::vector<psd_uint32_t> count_bufs;
            std::vector<std::vector<std::vector<psd_uint8_t>>> splited;
            splited.resize(channels);
            for (int ch = 0; ch < channels; ch++) {
                splited[ch].resize(height);
                for (int y = 0; y < height; y++) {
                    splited[ch][y].resize(width);
                }
            }
            
            psd_uint64_t read_idx = 0;
            for (psd_uint32_t y = 0; y < height; y++)
                for (psd_uint32_t x = 0; x < width; x++)
                    for (psd_uint8_t ch = 0; ch < channels; ch++) {
                        splited[ch][y][x] = src_img[read_idx];
                        read_idx++;
                    }
            
            for (psd_uint8_t ch = 0; ch < channels; ch++)
            {
                std::vector<psd_uint8_t> img;
                img.reserve(height * width);
                ch_len->at(ch).resize(height*sizeof(psd_uint16_t));
                psd_uint32_t count_buf = 0;
                for (psd_uint32_t y = 0; y < height; y++)
                {
                    std::list<psd_int8_t> literals;
                    for (psd_uint32_t x = 0; x < width; x++)
                    {
                        char current = splited[ch][y][x];
                        if (x+1 != width)
                        {
                            char next = splited[ch][y][x+1];
                            if (next == current)
                            {
                                if (literals.size() > 0)
                                {
                                    img.emplace_back(literals.size() - 1);
                                    for (psd_int8_t li : literals) img.emplace_back(li);
                                }
                                literals.clear();
                                
                                int max = (x + MaxLen >= width )? width - x - 1 : MaxLen;
                                bool hitMax = true;
                                char runLength = 1;
                                for (int j = 2; j <= max; j++)
                                {
                                    char run = splited[ch][y][j + x];
                                    if (run != current)
                                    {
                                        hitMax = false;
                                        char count = (0-runLength);
                                        x += (j - 1);
                                        img.emplace_back(count);
                                        img.emplace_back(current);
                                        break;
                                    }
                                    runLength++;
                                }
                                
                                if (hitMax)
                                {
                                    img.emplace_back(0-max);
                                    img.emplace_back(current);
                                    x += max;
                                }
                            }
                            else
                            {
                                literals.emplace_back(current);
                                if (literals.size() == MaxLen) {
                                    if (literals.size() > 0)
                                    {
                                        img.emplace_back(literals.size() - 1);
                                        for (psd_int8_t li : literals) img.emplace_back(li);
                                    }
                                    literals.clear();
                                }
                            }
                        }
                        else
                        {
                            literals.emplace_back(current);
                            if (literals.size() > 0)
                            {
                                img.emplace_back(literals.size() - 1);
                                for (psd_int8_t li : literals) img.emplace_back(li);
                            }
                            literals.clear();
                        }
                    }
                    psd_uint16_t rc = img.size() - count_buf;
                    count_buf += rc;
                    
                    ch_len->at(ch).at(y*2) = (psd_uint8_t)(rc >> 8);
                    ch_len->at(ch).at(y*2+1) = (psd_uint8_t)rc;
                }
                
                ch_img->at(ch).reserve(count_buf);
                std::copy(img.begin(), img.begin() + count_buf, std::back_inserter(ch_img->at(ch)));
                count_bufs.emplace_back(img.size());
            }
            
            return true;
        }
        
        template <typename T>
        bool decoe_RLE(std::vector<psd_uint8_t> buffer, psd_uint64_t *read_idx,
                       psd_uint32_t height, psd_uint32_t width,
                       std::vector<std::vector<psd_uint8_t>> *src,
                       std::vector<T> lengths)
        {
            for (psd_uint32_t y = 0; y < height; y++) {
                std::vector<psd_uint8_t> uncomp;
                src->at(y).resize(lengths[y]);
                
                read_buf(buffer, &(src->at(y).at(0)), read_idx, (size_t)lengths[y]);
                
                for (psd_uint32_t x = 0; x < src->at(y).size(); x++) {
                    psd_int8_t c = src->at(y).at(x);
                    if (c >= 128) c -= 256;
                    if (c == -128) continue;
                    else if (c < 0) {
                        x++;
                        for (int j = 0; j < 1-c; j++)
                            uncomp.emplace_back(src->at(y).at(x));
                    }
                    else {
                        if (x+1 + c+1 > src->at(y).size()) {
#ifdef DEBUG
                            std::cout << "PackBit source length invalid" << std::endl;
#endif
                            return false;
                        }
                        uncomp.insert(uncomp.end(), src->at(y).begin()+x+1, src->at(y).begin()+x+1+c+1);
                        x += c+1;
                    }
                }
                if (uncomp.size() * 8 % width != 0 || uncomp.size() == 0)
                {
#ifdef DEBUG
                    std::cout << "PackBit line " << y << " uncompressed length invalid " << uncomp.size() << ' ' << width << std::endl;
#endif
                    return false;
                }
                src->at(y).swap(uncomp);
            }
            return true;
        }
        
        
    }
}

#endif /* psd_util_hpp */
