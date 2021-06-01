//
//  psd_layer_and_mask.hpp
//  KZPSDParser
//
//  Created by uchiyama_Macmini on 2019/08/13.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef psd_layer_and_mask_hpp
#define psd_layer_and_mask_hpp

#include <stdio.h>
#include "psd_image.hpp"
#include "psd_utils.hpp"

namespace psd {
    
    struct ExtraData
    {
        Signature signature;
        Signature key;
        be<uint32_t> length;
        be<uint64_t> length_b;
        std::vector<char> data;
        bool is_psb;
        
        uint32_t size() const { return (uint32_t)(12+data.size() + (data.size()%2)); }
        bool read(FILE* psd_file);
        bool write(FILE* psd_file);
        
        void luni_read_name(std::wstring& wname, std::string& utf8name);
    };
    
    struct Layer
    {
        Layer() : has_text(false) {}
        be<uint32_t> top, left, bottom, right;
        be<uint16_t> num_channels;
        std::vector<std::pair<be<int16_t>, be<uint32_t>>> channel_infos; // ID, length
        std::vector<std::pair<be<int16_t>, be<uint64_t>>> channel_infos_big; // ID, length
        std::vector<ImageData> channel_info_data;
        ImageData* get_channel_info_by_id(int16_t id) {
            if (is_psb) {
                for(uint16_t i = 0; i < channel_infos_big.size(); i ++)
                    if (channel_infos_big[i].first == id)
                        return &channel_info_data[i];
            }
            else {
                for(uint16_t i = 0; i < channel_infos.size(); i ++)
                    if (channel_infos[i].first == id)
                        return &channel_info_data[i];
            }
            return nullptr;
        }
        
        Signature blend_signature;
        be<uint32_t> blend_key;
        uint8_t opacity; // 0 for transparent
        uint8_t clipping; // 0 base, 1 non-base
        uint8_t bit_flags;
        uint8_t dummy1;
        be<uint32_t> extra_data_length;
        std::vector<ExtraData> additional_extra_data;
        
        uint16_t name_size();
        
        struct LayerMask
        {
            uint32_t size() const { return 4 + (uint32_t)length; }
            be<uint32_t> length;
            be<uint32_t> top, left, bottom, right;
            uint8_t default_color;
            uint8_t flags;
            std::vector<char> additional_data;
            
            bool read(FILE* psd_file);
            bool write(FILE* psd_file);
            
        } mask;
        
        struct LayerBlendingRanges
        {
            uint32_t size() const { return (uint32_t)(data.size() + 4); }
            std::vector<char> data;
            bool read(FILE* psd_file);
            bool write(FILE* psd_file);
        } blending_ranges;
        std::string name;
        std::wstring wname;
        std::string utf8name;
        bool has_text;
        bool is_psb;
        
        bool read(FILE* psd_file);
        bool write(FILE* psd_file);
        bool read_images(FILE* psd_file);
        bool write_images(FILE* psd_file);
    };
    
    struct LayerInfo
    {
        LayerInfo() : num_layers(0), has_merged_alpha_channel(false) {
        }
        be<int16_t> num_layers;
        bool has_merged_alpha_channel;
        std::vector<Layer> layers;
        bool is_psb;
        bool read(FILE* psd_file);
        bool write(FILE* psd_file);
    };
    
    struct GlobalLayerMaskInfo
    {
        be<uint32_t> length;
        be<uint16_t> overlay_colorspace;
        be<uint16_t> color_component[4];
        be<uint16_t> opacity; // 0 = transparent 100 = opaque
        uint8_t kind;
        std::vector<char> data;
        
        bool read(FILE* psd_file);
        bool write(FILE* psd_file);
    };
    
    struct Layers
    {
        bool is_psb;
        LayerInfo layer_info;
        GlobalLayerMaskInfo global_layer_mask_info;
        std::vector<char> additional_layer_data;
        std::vector<Layer>& layers() { return layer_info.layers; }
        
        bool load(FILE* psd_file);
        bool save(FILE* psd_file);
    };
}
#endif /* psd_layer_and_mask_hpp */
