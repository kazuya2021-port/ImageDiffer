//
//  psd_layer_and_mask.cpp
//  KZPSDParser
//
//  Created by uchiyama_Macmini on 2019/08/13.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#include "psd_layer_and_mask.hpp"

bool psd::ExtraData::read(FILE *psd_file)
{
    if (!read_file(psd_file, &signature)) {
        std::cerr << "ExtraData : signature read error" << std::endl;
        return false;
    }
    
    if (signature != "8BIM" && signature != "8B64") {
#ifdef DEBUG
        std::cout << "Extra data signature error at: " << ftell(psd_file) << ' ' << (std::string)signature <<std::endl;
#endif
        return false;
    }
    
    if (!read_file(psd_file, &key)) {
        std::cerr << "ExtraData : key read error" << std::endl;
        return false;
    }
    
    if (is_psb) {
        if (((std::string)key == "LMsk") || ((std::string)key == "Lr16") ||
            ((std::string)key == "Lr32") || ((std::string)key == "Layr") ||
            ((std::string)key == "Mt16") || ((std::string)key == "Mt32") ||
            ((std::string)key == "Mtrn") || ((std::string)key == "Alph") ||
            ((std::string)key == "FMsk") || ((std::string)key == "lnk2") ||
            ((std::string)key == "FEid") || ((std::string)key == "FXid") ||
            ((std::string)key == "PxSD")) {
            if (!read_file(psd_file, &length_b)) {
                std::cerr << "ExtraData : length read error" << std::endl;
                return false;
            }
            data.resize(length_b);
            fread(&data[0], sizeof(data[0]), length_b, psd_file);
        }
        else {
            if (!read_file(psd_file, &length)) {
                std::cerr << "ExtraData : length read error" << std::endl;
                return false;
            }
            data.resize(length);
            fread(&data[0], sizeof(data[0]), length, psd_file);
        }
    }
    else {
        if (!read_file(psd_file, &length)) {
            std::cerr << "ExtraData : length read error" << std::endl;
            return false;
        }
        data.resize(length);
        fread(&data[0], sizeof(data[0]), length, psd_file);
    }

    return true;
}

void psd::ExtraData::luni_read_name(std::wstring& wname, std::string& utf8name)
{
    char* p = &data[0];
    be<uint32_t> uni_length = *(be<uint32_t>*)p;
    wname.clear();
    for (uint32_t i = 0; i < uni_length; i ++) {
        wname += (wchar_t)(uint16_t)*(be<uint16_t>*)(p+4+i*2);
    }
    utf8name.clear();
    for (auto wc : wname) {
        if (wc < 0x80)
            utf8name += (char)wc;
        else if (wc < 0x800) { //110xxxxx 10xxxxxx
            utf8name += (char)(0xC0 + ((wc>>6)&0x1F));
            utf8name += (char)(0x80 + (wc & 0x3F));
        }
        else {  // 1110xxxx 10xxxxxx 10xxxxxx 6+6+4
            utf8name += (char)(0xE0 + ((wc>>12)&0x0F));
            utf8name += (char)(0x80 + ((wc>>6) & 0x3F));
            utf8name += (char)(0x80 + (wc & 0x3F));
        }
    }
}


bool psd::Layer::LayerMask::read(FILE *psd_file)
{
    if (!read_file(psd_file, &length)) {
        std::cerr << "LayerMask : length read error" << std::endl;
        return false;
    }
#ifdef DEBUG
    std::cout << "Reading mask (size: " << length << ")" << std::endl;
#endif
    
    size_t ret = 1;
    
    if (length) {
        if (!read_file(psd_file, &top)) {
            std::cerr << "LayerMask : top read error" << std::endl;
            return false;
        }
        if (!read_file(psd_file, &left)) {
            std::cerr << "LayerMask : left read error" << std::endl;
            return false;
        }
        if (!read_file(psd_file, &bottom)) {
            std::cerr << "LayerMask : bottom read error" << std::endl;
            return false;
        }
        if (!read_file(psd_file, &right)) {
            std::cerr << "LayerMask : right read error" << std::endl;
            return false;
        }
        if (!read_file(psd_file, &default_color)) {
            std::cerr << "LayerMask : default_color read error" << std::endl;
            return false;
        }
        if (!read_file(psd_file, &flags)) {
            std::cerr << "LayerMask : flags read error" << std::endl;
            return false;
        }
        
        uint32_t remaining = length - (4*4+2);
        additional_data.resize(remaining);
        ret = fread(&additional_data[0], sizeof(additional_data[0]), remaining, psd_file);
    }
    return (ret == 0)? false : true;
}

bool psd::Layer::LayerBlendingRanges::read(FILE *psd_file)
{
    be<uint32_t> size;
    size_t ret = 1;
    
    if (!read_file(psd_file, &size)) {
        std::cerr << "LayerBlendingRanges : size read error" << std::endl;
    }
    
    if (size != 0) {
        data.resize(size);
        ret = fread(&data[0], sizeof(data[0]), size, psd_file);
    }
    
    return (ret == 0)? false : true;
}

bool psd::Layer::read(FILE *psd_file)
{
    if (!read_file(psd_file, &top)) {
        std::cerr << "Layer : top read error" << std::endl;
        return false;
    }
    if (!read_file(psd_file, &left)) {
        std::cerr << "Layer : left read error" << std::endl;
        return false;
    }
    if (!read_file(psd_file, &bottom)) {
        std::cerr << "Layer : bottom read error" << std::endl;
        return false;
    }
    if (!read_file(psd_file, &right)) {
        std::cerr << "Layer : right read error" << std::endl;
        return false;
    }
    if (!read_file(psd_file, &num_channels)) {
        std::cerr << "Layer : num_channels read error" << std::endl;
        return false;
    }
    
#ifdef DEBUG
    std::cout << '\t' << top << ' ' << left <<' ' <<bottom << ' ' << right << std::endl;
    std::cout << "Number of channels: " << num_channels << std::endl;
#endif
    
    for(uint16_t i = 0; i < num_channels; i ++) {
        unsigned char buffer[6];
        unsigned char buffer_b[10];
        if (is_psb) {
            if (!read_file(psd_file, &buffer_b)) {
                std::cerr << "Layer : buffer read error" << std::endl;
                return false;
            }
            channel_infos_big.emplace_back(
                                       (int16_t)((uint16_t)buffer_b[0]*256+(uint16_t)buffer_b[1]),
                                       (uint64_t)(
                                                  ((uint64_t)buffer_b[2]<<56)+
                                                  ((uint64_t)buffer_b[3]<<48)+
                                                  ((uint64_t)buffer_b[4]<<40)+
                                                  ((uint64_t)buffer_b[5]<<32)+
                                                  ((uint64_t)buffer_b[6]<<24)+
                                                  ((uint64_t)buffer_b[7]<<16)+
                                                  ((uint64_t)buffer_b[8]<<8)+
                                                  ((uint64_t)buffer_b[9]<<0))
                                       );
        }
        else {
            if (!read_file(psd_file, &buffer)) {
                std::cerr << "Layer : buffer read error" << std::endl;
                return false;
            }
            
            channel_infos.emplace_back(
                                       (int16_t)((uint16_t)buffer[0]*256+(uint16_t)buffer[1]),
                                       (uint32_t)(
                                                  ((uint32_t)buffer[2]<<24)+
                                                  ((uint32_t)buffer[3]<<16)+
                                                  ((uint32_t)buffer[4]<<8)+
                                                  ((uint32_t)buffer[5]<<0))
                                       );
        }
        
    }
    if (!read_file(psd_file, &blend_signature)) {
        std::cerr << "Layer : blend_signature read error" << std::endl;
        return false;
    }
    if (!read_file(psd_file, &blend_key)) {
        std::cerr << "Layer : blend_key read error" << std::endl;
        return false;
    }
    if (!read_file(psd_file, &opacity)) {
        std::cerr << "Layer : opacity read error" << std::endl;
        return false;
    }
    if (!read_file(psd_file, &clipping)) {
        std::cerr << "Layer : opacity read error" << std::endl;
        return false;
    }
    if (!read_file(psd_file, &bit_flags)) {
        std::cerr << "Layer : bit_flags read error" << std::endl;
        return false;
    }
    if (!read_file(psd_file, &dummy1)) {
        std::cerr << "Layer : dummy1 read error" << std::endl;
        return false;
    }
    if (!read_file(psd_file, &extra_data_length)) {
        std::cerr << "Layer : extra_data_length read error" << std::endl;
        return false;
    }
    
#ifdef DEBUG
    std::cout << "Blend Signature: " << std::string((char*)&blend_signature, (char*)&blend_signature+4) << std::endl;
    std::cout << "Blend Key: " << std::string((char*)&blend_key, (char*)&blend_key+4) << std::endl;
    std::cout << "Visible: " << (((bit_flags & 0x2) == 1) ? "NO" : "YES") << std::endl;
    std::cout << "Extra Data Size: " << extra_data_length << std::endl;
#endif
    if ((*(uint32_t*)"8BIM") != blend_signature)
        return false;
    
    auto extra_start_pos = ftell(psd_file);
    
    if (!mask.read(psd_file)) {
        std::cerr << "Layer : mask read fail" << std::endl;
        return false;
    }
    
    if (!blending_ranges.read(psd_file)) {
        std::cerr << "Layer : blending ranges read fail" << std::endl;
        return false;
    }
    
    uint8_t name_size;
    if (!read_file(psd_file, &name_size)) {
        std::cerr << "Layer : name_size read error" << std::endl;
        return false;
    }
    name.resize(name_size);
    
    size_t ret = fread(&name[0], sizeof(name[0]), name_size, psd_file);
    if (!ret) {
        std::cerr << "Layer : name read error" << std::endl;
        return false;
    }
    switch(name_size%4)
    {
        case 0:
            fseek(psd_file ,3, SEEK_CUR);
            break;
        case 1:
            fseek(psd_file ,2, SEEK_CUR);
            break;
        case 2:
            fseek(psd_file ,1, SEEK_CUR);
            break;
        case 3:
            break;
    }
    
    for(char c:name)
        wname += (wchar_t)c;
    
    utf8name = name;
#ifdef DEBUG
    std::cout << "ExtraData size" << mask.size() << " + " << blending_ranges.size();
#endif
    
    while(ftell(psd_file) - extra_start_pos < extra_data_length) {
        ExtraData ed;
        ed.is_psb = is_psb;
        if (!ed.read(psd_file)) {
            std::cerr << "fail to read ExtraData" << std::endl;
            return false;
        }
#ifdef DEBUG
        std::cout << " + " << ed.size();
#endif
        additional_extra_data.push_back(std::move(ed));
    }
    
#ifdef DEBUG
    std::cout << std::endl;
#endif
    
    for(auto& ed:additional_extra_data) {
#ifdef DEBUG
        std::cout << '\t' << (std::string)ed.key;
#endif
        if (ed.key == "luni") {
            ed.luni_read_name(wname, utf8name);
        }
        else if (ed.key == "TySh") {
            has_text = true;
        }
    }
    
#ifdef DEBUG
    std::cout << std::endl;
    std::cout << "Layer " << utf8name << std::endl;
#endif
    return true;
}

bool psd::Layer::read_images(FILE* psd_file)
{
    if (is_psb) {
        for (auto& ci:channel_infos_big) {
            ImageData id;
            id.is_psb = is_psb;
            
            auto pos = ftell(psd_file);
            id.read(psd_file, right-left, bottom-top);
            auto read_size = ftell(psd_file) - pos;
            
            if (read_size != ci.second) {
                std::cerr << "Layer read image fail" << ' ' << read_size << ' ' << ci.second << std::endl;
                return false;
            }
            channel_info_data.push_back(std::move(id));
        }
    }
    else {
        for (auto& ci:channel_infos) {
            ImageData id;
            id.is_psb = is_psb;
            
            auto pos = ftell(psd_file);
            id.read(psd_file, right-left, bottom-top);
            auto read_size = ftell(psd_file) - pos;
            
            if (read_size != ci.second) {
                std::cerr << "Layer read image fail" << ' ' << read_size << ' ' << ci.second << std::endl;
                return false;
            }
            channel_info_data.push_back(std::move(id));
        }
    }
    
    
    return true;
}

bool psd::GlobalLayerMaskInfo::read(FILE* psd_file)
{
    if (!read_file(psd_file, &length)) {
        std::cerr << "GlobalLayerMaskInfo : length read error" << std::endl;
        return false;
    }
    
    if (length >= 2+2*4+2+1) {
        if (!read_file(psd_file, &overlay_colorspace)) {
            std::cerr << "GlobalLayerMaskInfo : overlay_colorspace read error" << std::endl;
            return false;
        }
        if (!fread(&color_component[0], sizeof(color_component[0]), 4, psd_file)) {
            std::cerr << "GlobalLayerMaskInfo : color_component read error" << std::endl;
            return false;
        }
        if (!read_file(psd_file, &opacity)) {
            std::cerr << "GlobalLayerMaskInfo : opacity read error" << std::endl;
            return false;
        }
        if (!read_file(psd_file, &kind)) {
            std::cerr << "GlobalLayerMaskInfo : kind read error" << std::endl;
            return false;
        }
        uint32_t remaining = length - (2+2*4+2+1);
        data.resize(remaining);
        if (!fread(&data[0], sizeof(data[0]), remaining, psd_file)) {
            std::cerr << "GlobalLayerMaskInfo : data read error" << std::endl;
            return false;
        }
    }
    else if (length != 0)
    {
#ifdef DEBUG
        std::cout << "Invalid GlobalLayerMaskInfo size: " << length << std::endl;
#endif
        return false;
    }
    return true;
}

bool psd::LayerInfo::read(FILE *psd_file)
{
    be<uint32_t> length;
    be<uint64_t> length_b;
    if (is_psb) {
        if (!read_file(psd_file, &length_b)) {
            std::cerr << "LayerInfo : length read error" << std::endl;
            return false;
        }
    }
    else {
        if (!read_file(psd_file, &length)) {
            std::cerr << "LayerInfo : length read error" << std::endl;
            return false;
        }
    }
    
    
    auto start_pos = ftell(psd_file);
    
    if (!read_file(psd_file, &num_layers)) {
        std::cerr << "LayerInfo : layer count read error" << std::endl;
        return false;
    }
    
    if (num_layers < 0) {
        num_layers = -num_layers;
        has_merged_alpha_channel = true;
    }
    
#ifdef DEBUG
    std::cout  << "Number of layers: " << num_layers << std::endl;
#endif
    
    for (int32_t i = 0; i < num_layers; i ++) {
#ifdef DEBUG
        std::cout << "Layer " << i << ": (at " << ftell(psd_file) << ")" << std::endl;
#endif
        Layer l;
        l.is_psb = is_psb;
        if (!l.read(psd_file)) {
            std::cerr << "Layer read fail" << std::endl;
            return false;
        }
        layers.push_back(std::move(l));
    }
    
    for (auto& l:layers) {
        if (!l.read_images(psd_file)) {
            std::cerr << "Layer read images fail" << std::endl;
            return false;
        }
    }
    
    auto diff = ftell(psd_file) - start_pos;
    if (diff != length && diff + 1 != length) {
        std::cerr << "Layer diff fail" << diff << ' ' << length << std::endl;
        return false;
    }
    
    return true;
}

bool psd::Layers::load(FILE *psd_file)
{
    be<uint64_t> length_b = 0;
    be<uint32_t> length = 0;
    if (is_psb) {
        layer_info.is_psb = true;
        if (!read_file(psd_file, &length_b)) {
            std::cerr << "layers length read error" << std::endl;
            return false;
        }
    }
    else {
        layer_info.is_psb = false;
        if (!read_file(psd_file, &length)) {
            std::cerr << "layers length read error" << std::endl;
            return false;
        }
    }
    
    auto start_pos = ftell(psd_file);
    
    if (length == 0 && length_b == 0)
        return true;
    
    if (!layer_info.read(psd_file))
        return false;
    
    if (!global_layer_mask_info.read(psd_file))
        return false;
    
    if (ftell(psd_file)-start_pos < length) {
        auto remaining = length - (ftell(psd_file)-start_pos);
#ifdef DEBUG
        std::cout << "Layer remaining: " << remaining << " at " << ftell(psd_file) << std::endl;
#endif
        additional_layer_data.resize(remaining);
        fread(&additional_layer_data[0], sizeof(additional_layer_data[0]), remaining, psd_file);
    }
    
    return true;
}
