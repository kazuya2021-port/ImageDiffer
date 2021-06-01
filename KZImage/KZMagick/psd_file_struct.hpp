//
//  psd_file_struct.hpp
//  KZMagick
//
//  Created by uchiyama_Macmini on 2019/08/19.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef psd_file_struct_hpp
#define psd_file_struct_hpp
#include <iostream>
#include <vector>
#include <string>
#include <map>
#include "psd_def.h"

namespace Psd {
    namespace FileStruct {
        using namespace Type;


        struct PSDSignature
        {
            alignas(uint32_t) psd_uint32_t sig;
            
            PSDSignature() : sig(0) {}
            PSDSignature(psd_uint32_t sig) : sig(sig) {}
            PSDSignature(const std::string& str) {
                if(str.size() != 4) {
                    std::cerr << "PSDSignature : not get signature << " << str << " >>" << std::endl;
                    sig = 0;
                }
                else {
                    memcpy((void*)&sig, (const void*)str.data(), 4);
                    
//                    alignas(4) uint32_t tmp = *(uint32_t*)str.data();
//                    sig = tmp;
                }
            }
            operator std::string() const {
                return std::string((char*)&sig, (char*)&sig+4);
            }
            PSDSignature& operator = (PSDSignature s) {
                sig = s.sig;
                return *this;
            }
        }__attribute__((packed));
        
#pragma pack(push, 1)
        struct PSDHeader
        {
            PSDHeader() : reserve1(0), reserve2(0), bit_depth(0), c_mode(0), num_channels(0), height(0), width(0) {}
            PSDSignature signature;
            alignas(uint16_t) psd_uint16_B version;
            alignas(uint16_t) psd_uint16_t reserve1;
            alignas(uint32_t) psd_uint32_t reserve2;
            alignas(uint16_t) psd_uint16_B num_channels;
            alignas(uint32_t) psd_uint32_B height;
            alignas(uint32_t) psd_uint32_B width;
            alignas(uint16_t) psd_uint16_B bit_depth;
            alignas(uint16_t) psd_uint16_B c_mode;
            
            PSDHeader& operator = (int x) {
                signature = PSDSignature();
                version = 0;
                num_channels = 0;
                height = 0;
                width = 0;
                bit_depth = 0;
                c_mode = 0;
                return *this;
            }
            PSDHeader& operator = (PSDHeader h) {
                signature = h.signature;
                version = h.version;
                num_channels = h.num_channels;
                height = h.height;
                width = h.width;
                bit_depth = h.bit_depth;
                c_mode = h.c_mode;
                return *this;
            }
        }__attribute__((packed));
        
        struct PSDImageResource
        {
            PSDSignature signature;
            alignas(uint16_t) psd_uint16_B image_resource_id;
            std::string name; // encoded as pascal string; 1 byte length header
            std::vector<psd_uint8_t> buffer;
        }__attribute__((packed));
        
        struct PSDImageData
        {
            alignas(uint16_t) psd_int16_t channel_id;
            std::vector<std::vector<psd_uint8_t>> data;
            
            bool decode_image_with_method (std::vector<psd_uint8_t> buffer,
                                           psd_uint64_t read_idx,
                                           bool isPSB,
                                           psd_uint32_t width,
                                           psd_uint32_t height,
                                           psd_int16_t cmp_method) {
                switch (cmp_method) {
                    case 0: // RAW
                    {
                        data.resize(height);
                        for (psd_uint32_t y = 0; y < height; y++) {
                            data[y].resize(width);
                            Util::read_buf_byte(buffer, &data[y][0], &read_idx, width);
                        }
                    }
                        break;
                        
                    case 1: // RLE
                    {
                        data.resize(height);
                        
                        if (isPSB) {
                            std::vector<psd_uint32_B> byteCount_b(height);
                            Util::read_buf(buffer, &byteCount_b[0], &read_idx, height);
                            
                            if (!Util::decoe_RLE(buffer, &read_idx,
                                                 height, width,
                                                 &data, byteCount_b)) {
                                return false;
                            }
                        }
                        else {
                            std::vector<psd_uint16_B> byteCount(height);
                            Util::read_buf(buffer, &byteCount[0], &read_idx, height);
                            
                            if (!Util::decoe_RLE(buffer, &read_idx,
                                                     height, width,
                                                     &data, byteCount)) {
                                return false;
                            }
                        }
                    }
                        break;
                        
                    default:
                        break;
                }
                return true;
            }
        };
        
        struct PSDLayerRecord
        {
            PSDLayerRecord() : top(0), left(0), bottom(0), right(0), filler(0) {}
            psd_uint32_B top, left, bottom, right;
            psd_uint16_B num_channels;
            std::vector<std::pair<psd_int16_t, psd_uint64_t>> channel_infos;
            PSDSignature blend_sig;
            PSDSignature blend_key;
            psd_uint8_t opacity, clipping, bit_flags, filler;
            psd_uint32_B extra_len;
            
            struct LayerMask
            {
                psd_uint32_t size() const { return (psd_uint32_t)(data.size() + 4); }
                std::vector<psd_uint8_t> data;
            } mask;
            
            struct LayerBlendingRanges
            {
                psd_uint32_t size() const { return (psd_uint32_t)(data.size() + 4); }
                std::vector<psd_uint8_t> data;
            } blending_ranges;
            
            struct PSDLayerExtra
            {
                PSDSignature signature;
                PSDSignature key;
                psd_uint32_B length;
                std::vector<psd_uint8_t> data;
                
                psd_uint32_t size() const { return (psd_uint32_t)(12+data.size() + (data.size()%2)); }
            } additional_extra_data;
            
            std::string name;
            std::wstring wname;
            PSDImageData image;
            std::map<psd_int16_t, std::vector<psd_uint8_t>> ch_img_buf;
        };
        
        struct PSDImageResources
        {
            std::vector<PSDImageResource> resouces;
        };
        
#pragma pack(pop)
        
#pragma mark -
#pragma mark PSD Info
        
        
        
        
        struct PSDInfo
        {
            PSDInfo() : Depth(0)
                        ,Channels(0)
                        ,BytesPerPixel(0)
                        ,hRes(0)
                        ,hResUnit(0)
                        ,WidthUnit(0)
                        ,vRes(0)
                        ,vResUnit(0)
                        ,HeightUnit(0)
                        ,Width(0)
                        ,Height(0) {}
            psd_uint16_t Depth;
            psd_uint16_t Channels;
            psd_uint32_t BytesPerPixel;
            psd_uint32_t hRes;      /* Fixed-point number: pixels per inch */
            psd_uint32_t hResUnit;  /* 1=pixels per inch, 2=pixels per centimeter */
            psd_uint32_t WidthUnit; /* 1=in, 2=cm, 3=pt, 4=picas, 5=columns */
            psd_uint32_t vRes;      /* Fixed-point number: pixels per inch */
            psd_uint32_t vResUnit;  /* 1=pixels per inch, 2=pixels per centimeter */
            psd_uint32_t HeightUnit;/* 1=in, 2=cm, 3=pt, 4=picas, 5=columns */
            psd_uint32_t Width;
            psd_uint32_t Height;
            std::string  XmpSrc;
            std::string  fileName;
            std::vector<PSDLayer> Layers;
            bool has_merged_alpha_channel;
            std::vector<psd_uint8_t> merged_image_buf;
        };
        
    }
}

#endif /* psd_file_struct_hpp */
