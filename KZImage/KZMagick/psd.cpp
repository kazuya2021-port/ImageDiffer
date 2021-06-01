//
//  psd.cpp
//  KZMagick
//
//  Created by uchiyama_Macmini on 2019/08/19.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#include <math.h>
#include <codecvt>
#include <mutex>
#include "psd.hpp"

using namespace Psd;
using namespace Psd::Type;
using namespace Psd::Util;
using namespace Psd::FileStruct;

std::mutex mtx;

bool charTowchar(wchar_t* buf, size_t capacity, const char *ch)
{
    size_t result = mbstowcs(buf, ch, capacity);
    if (result <= 0) {
        std::cerr << "failed mbstowcs wchar" << std::endl;
        return false;
    }
    return true;
}

#pragma mark -
#pragma mark write PSD

bool PSD::save(const char *path, const std::vector<std::pair<const char*,PSDRawImage>> &layer_imgs, PSDRawImage &merged)
{
    FILE* f = fopen(path, "wb");
    
    const char* file_name_all  = strrchr(path, '/') + 1;
    const char* ext_name  = strrchr(file_name_all, '.');
    char file_name[1024];
    strncpy(file_name, file_name_all, strlen(file_name_all) - strlen(ext_name));
    
    this->info.fileName = std::string(file_name);
    
    if (f)  return save(f, layer_imgs, merged);
    else {
        log_err("read file error!", path);
        return false;
    }
    return true;
}

bool PSD::save(FILE *f, const std::vector<std::pair<const char*,PSDRawImage>> &layer_imgs, PSDRawImage &merged)
{
    psd_uint32_B zero_32 = 0;
    psd_uint16_B zero_16 = 0;
    PSDHeader header_;
    
    // Image Decode
    PSDInfo info_ = info;
    float resolution = 0.0;
    
    for (std::pair<const char*,PSDRawImage> lay:layer_imgs) {
        PSDLayer l;
        l.name = std::string(lay.first);
        l.img = lay.second;
        
        if (resolution == 0.0) resolution = lay.second.resolution;
        if (header_.bit_depth == 0) header_.bit_depth = lay.second.depth;
        if (header_.c_mode == 0) header_.c_mode = lay.second.c_mode;
        if (header_.num_channels == 0) header_.num_channels = lay.second.channels;
        if (header_.width == 0) header_.width = lay.second.width;
        if (header_.height == 0) header_.height = lay.second.height;
        if (lay.second.hasAlpha) info_.has_merged_alpha_channel = true;
        info_.Layers.emplace_back(l);
    }
    
    
    
    info_.Height = header_.height;
    info_.Width = header_.width;
    info_.Depth = header_.bit_depth;
    info_.Channels = header_.num_channels;
    info_.BytesPerPixel = header_.bit_depth/8;
    info_.hRes = ceil(resolution);
    info_.hResUnit = 1;
    info_.WidthUnit = 1;
    info_.vRes = ceil(resolution);
    info_.vResUnit = 1;
    info_.HeightUnit = 1;
    
    std::vector<psd_uint8_t> out_buffer;
    out_buffer.clear();
    
    // header
    header_.signature = PSDSignature("8BPS");
    header_.version = 1;
    
    write_buf(&out_buffer, header_);
    
    // color mode
    write_buf(&out_buffer, zero_32);
    
    // image resource
    psd_uint32_B im_resource_len = (4+2+2+4+(4*4));
    write_buf(&out_buffer, im_resource_len);
    
    PSDImageResource res;
    res.signature = PSDSignature("8BIM");
    res.image_resource_id = RESN_INFO;
    write_buf(&out_buffer, res.signature);
    write_buf(&out_buffer, res.image_resource_id);
    write_buf(&out_buffer, zero_16); // name
    psd_uint32_B reso_len = 4*4;
    write_buf(&out_buffer, reso_len); // length
    
    psd_uint32_B hRes = (psd_uint32_t)(info_.hRes * 65536.0) | 0x01;
    psd_uint16_B hResUnit = info_.hResUnit;
    psd_uint16_B WidthUnit = info_.WidthUnit;
    psd_uint32_B vRes = (psd_uint32_t)(info_.vRes * 65536.0) | 0x01;
    psd_uint16_B vResUnit = info_.vResUnit;
    psd_uint16_B HeightUnit = info_.HeightUnit;
    
    write_buf(&out_buffer, hRes);
    write_buf(&out_buffer, hResUnit);
    write_buf(&out_buffer, WidthUnit);
    write_buf(&out_buffer, vRes);
    write_buf(&out_buffer, vResUnit);
    write_buf(&out_buffer, HeightUnit);

    // layer and mask
    // Image RLE Encode
    std::vector<std::vector<std::vector<psd_uint8_t>>> lay_ch_img(info_.Layers.size());
    std::vector<std::vector<std::vector<psd_uint8_t>>> lay_ch_pack(info_.Layers.size());
    
    int lay_count = 0;
    for (PSDLayer l:info_.Layers) {
        std::vector<std::vector<psd_uint8_t>> ch_img;
        std::vector<std::vector<psd_uint8_t>> ch_pack;
        mtx.lock();
        encode_RLE_img((const char*)l.img.image_data,
                       header_.width, header_.height, l.img.channels, &ch_pack, &ch_img);
        mtx.unlock();
        lay_ch_img[lay_count] = ch_img;
        lay_ch_pack[lay_count] = ch_pack;
        lay_count++;
    }
    std::vector<std::vector<psd_uint8_t>> mrg_ch_img;
    std::vector<std::vector<psd_uint8_t>> mrg_ch_pack;
    mtx.lock();
    encode_RLE_img((const char*)merged.image_data,
                   header_.width, header_.height, merged.channels, &mrg_ch_pack, &mrg_ch_img);
    mtx.unlock();
    
    if (!write_layer_and_mask(&out_buffer, &info_, lay_ch_img, lay_ch_pack)) return false;
    
    write_image(&out_buffer, &info_, mrg_ch_img, mrg_ch_pack);
    
    fwrite(&out_buffer[0], sizeof(psd_uint8_t), out_buffer.size(), f);
    fclose(f);
    
    return true;
}

bool PSD::write_image(std::vector<psd_uint8_t> *out_buf,
                      PSDInfo *info,
                      const std::vector<std::vector<psd_uint8_t>> &lay_ch_img,
                      const std::vector<std::vector<psd_uint8_t>> &lay_ch_pack)
{
    std::vector<psd_uint8_t> merged;
    psd_int16_B compress = 1;
    write_buf(out_buf, compress);
    
    merged.reserve(merged.size()+(lay_ch_pack[0].size() * lay_ch_img.size()));
    
    for (int ch = 0; ch < lay_ch_pack.size(); ch++) {
        std::copy(lay_ch_pack[ch].begin(),
                  lay_ch_pack[ch].end(),
                  std::back_inserter(merged));
    }
    
    for (int ch = 0; ch < lay_ch_pack.size(); ch++) {
        merged.reserve(merged.size() + lay_ch_pack[ch].size());
        std::copy(lay_ch_img[ch].begin(),
                  lay_ch_img[ch].end(),
                  std::back_inserter(merged));
    }
    
    out_buf->reserve(out_buf->size() + merged.size());
    std::copy(merged.begin(),
              merged.end(),
              std::back_inserter(*out_buf));
    
    return true;
}

bool utf8CharToUcs2Char(const char* utf8Tok, wchar_t* ucs2Char, uint32_t* utf8TokLen)
{
    //We do math, that relies on unsigned data types
    const unsigned char* utf8TokUs = reinterpret_cast<const unsigned char*>(utf8Tok);
    
    //Initialize return values for 'return false' cases.
    *ucs2Char = L'?';
    *utf8TokLen = 1;
    
    //Decode
    if (0x80 > utf8TokUs[0])
    {
        //Tokensize: 1 byte
        *ucs2Char = static_cast<const wchar_t>(utf8TokUs[0]);
    }
    else if (0xC0 == (utf8TokUs[0] & 0xE0))
    {
        //Tokensize: 2 bytes
        if ( 0x80 != (utf8TokUs[1] & 0xC0) )
        {
            return false;
        }
        *utf8TokLen = 2;
        *ucs2Char = static_cast<const wchar_t>(
                                               (utf8TokUs[0] & 0x1F) << 6
                                               | (utf8TokUs[1] & 0x3F)
                                               );
    }
    else if (0xE0 == (utf8TokUs[0] & 0xF0))
    {
        //Tokensize: 3 bytes
        if (   ( 0x80 != (utf8TokUs[1] & 0xC0) )
            || ( 0x80 != (utf8TokUs[2] & 0xC0) )
            )
        {
            return false;
        }
        *utf8TokLen = 3;
        *ucs2Char = static_cast<const wchar_t>(
                                               (utf8TokUs[0] & 0x0F) << 12
                                               | (utf8TokUs[1] & 0x3F) << 6
                                               | (utf8TokUs[2] & 0x3F)
                                               );
    }
    else if (0xF0 == (utf8TokUs[0] & 0xF8))
    {
        //Tokensize: 4 bytes
        *utf8TokLen = 4;
        return false;                        //Character exceeds the UCS-2 range (UCS-4 would be necessary)
    }
    else if ((0xF8 == utf8TokUs[0] & 0xFC))
    {
        //Tokensize: 5 bytes
        *utf8TokLen = 5;
        return false;                        //Character exceeds the UCS-2 range (UCS-4 would be necessary)
    }
    else if (0xFC == (utf8TokUs[0] & 0xFE))
    {
        //Tokensize: 6 bytes
        *utf8TokLen = 6;
        return false;                        //Character exceeds the UCS-2 range (UCS-4 would be necessary)
    }
    else
    {
        return false;
    }
    
    return true;
}


std::wstring utf8Toucs2(const std::string& utf8Str)
{
    std::wstring ucs2res;
    wchar_t ucs2CharToStrBuf[] = { 0, 0 };
    const char* cursor = utf8Str.c_str();
    const char* const end = utf8Str.c_str() + utf8Str.length();
    
    while (end > cursor)
    {
        uint32_t utf8TokLen = 1;
        utf8CharToUcs2Char(cursor, &ucs2CharToStrBuf[0], &utf8TokLen);
        ucs2res.append(ucs2CharToStrBuf);
        cursor += utf8TokLen;
    }
    return ucs2res;
}

std::string wide_to_utf8_cppapi(std::wstring const& src)
{
    std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
    return converter.to_bytes(src);
}

bool PSD::write_layer_and_mask(std::vector<psd_uint8_t> *out_buf,
                               PSDInfo *info,
                               const std::vector<std::vector<std::vector<psd_uint8_t>>> &lay_ch_img,
                               const std::vector<std::vector<std::vector<psd_uint8_t>>> &lay_ch_pack)
{
    psd_uint32_B section_len = 0;
    std::list<psd_uint8_t> layinfo;
    
    // layer info
    psd_int16_B layer_count = info->Layers.size();
    
    if (info->has_merged_alpha_channel) {
        layer_count = -layer_count;
    }

    write_list(&layinfo, layer_count);

    if (layer_count < 0) layer_count = layer_count * -1;
    
    for (int i = 0; i < layer_count; i++) {

        // layer record
        psd_uint32_B tmp32 = 0;
        psd_uint16_B tmp16 = 0;
        psd_uint8_t tmp8 = 0;
        
        // rectangle
        write_list(&layinfo, tmp32);
        write_list(&layinfo, tmp32);
        tmp32 = info->Height;
        write_list(&layinfo, tmp32);
        tmp32 = info->Width;
        write_list(&layinfo, tmp32);
        
        // channel
        tmp16 = lay_ch_img[i].size();
        write_list(&layinfo, tmp16);
        
        // channel info
        psd_int16_B ids[] = {0, 1, 2, -1};
        for (int j = 0; j < lay_ch_img[i].size(); j++) {
            write_list(&layinfo, ids[j]);
            tmp32 = lay_ch_img[i][j].size()+2;
            tmp32 += lay_ch_pack[i][j].size();
            write_list(&layinfo, tmp32);
        }
        
        write_list(&layinfo, PSDSignature("8BIM"));
        write_list(&layinfo, PSDSignature("norm"));
        tmp8 = info->Layers[i].img.opaque;
        write_list(&layinfo, tmp8); // opacity
        tmp8 = 0;
        write_list(&layinfo, tmp8); // clipping
        
        // bit_flags
        // 0x0010 = unlock
        tmp8 = 0x0010;
        write_list(&layinfo, tmp8);
        tmp8 = 0;
        write_list(&layinfo, tmp8); // filler
        
        size_t extlen = 0;
        
        const char *n = info->Layers[i].name.c_str();
        psd_uint8_t nlen = (psd_uint8_t)strlen(n);
        if (nlen > 251) nlen = 251;
        std::vector<psd_uint8_t> layn;
        layn.emplace_back(nlen);
        for (int i = 0; i < nlen; i++) {
            layn.emplace_back(n[i]);
        }
        
        if (layn.size() % 4 != 0) {
            int remain = 4 - (layn.size() % 4);
            for (int i = 0; i < remain; i++)
                layn.emplace_back(0);
        }
        extlen += layn.size();
        
        
        // Unicode レイヤ名
        PSDSignature lunisig("8BIM");
        PSDSignature lunikey("luni");
        size_t unicount = 0;
        std::vector<psd_uint16_B> buf_uniname;
        psd_uint32_B lunilen = 0;
        
        auto const wide = utf8Toucs2(info->Layers[i].name);

        extlen += sizeof(PSDSignature) * 2;
    
        unicount = wide.size();
        buf_uniname = std::vector<psd_uint16_B>(wide.size());
        for (psd_uint32_t i = 0; i < buf_uniname.size(); i++) {
            buf_uniname[i] = wide[i];
        }
        extlen += sizeof(psd_uint32_B);
        extlen += sizeof(psd_uint32_B);
        extlen += sizeof(psd_uint16_B)*buf_uniname.size();
        
        lunilen += sizeof(psd_uint32_B);
        lunilen += sizeof(psd_uint16_B)*buf_uniname.size();

        tmp32 = (psd_uint32_B)(extlen + 8);
        
        write_list(&layinfo, tmp32); // extlen
        
        tmp32 = 0;
        write_list(&layinfo, tmp32); // Layer mask data
        write_list(&layinfo, tmp32); // Layer blending ranges
        
        for (psd_uint8_t d:layn) {
            write_list(&layinfo, d); // layer name
        }
        
        write_list(&layinfo, lunisig); // layer name unicode
        write_list(&layinfo, lunikey);
        tmp32 = lunilen;
        write_list(&layinfo, tmp32);
        tmp32 = unicount;
        write_list(&layinfo, tmp32);
        
        for (int i = 0; i < buf_uniname.size(); i++) {
            write_list(&layinfo, buf_uniname[i]);
        }
        
    }
    
    // Channel image data
    psd_int16_B compress = 1;
    
    for (int lay = 0; lay < layer_count; lay++) {
        for (int ch = 0; ch < lay_ch_img[lay].size(); ch++) {
            write_list(&layinfo, compress);
            // 高さ * 2byte + イメージデータ
//            size_t img_size = lay_ch_pack[lay][ch].size() + lay_ch_img[lay][ch].size();
            std::copy(lay_ch_pack[lay][ch].begin(), lay_ch_pack[lay][ch].end(), std::back_inserter(layinfo));
            std::copy(lay_ch_img[lay][ch].begin(), lay_ch_img[lay][ch].end(), std::back_inserter(layinfo));
        }
    }
    
    section_len = (psd_uint32_B)layinfo.size();
    insert_front(&layinfo, section_len);
    
    psd_uint32_B g_len = 0;
    write_list(&layinfo, g_len); // Global layer masks
    section_len += sizeof(psd_uint32_B);
    section_len += sizeof(psd_uint32_B);
    write_buf(out_buf, section_len);
    out_buf->reserve(out_buf->size() + layinfo.size());
    std::copy(layinfo.begin(), layinfo.end(), std::back_inserter(*out_buf));
    
    return true;
}

#pragma mark -
#pragma mark read PSD
bool PSD::open(const char *path)
{
    FILE* f = fopen(path, "rb");
    
    const char* file_name_all  = strrchr(path, '/') + 1;
    const char* ext_name  = strrchr(file_name_all, '.');
    char file_name[1024];
    strncpy(file_name, file_name_all, strlen(file_name_all) - strlen(ext_name));
    
    std::cout << file_name << std::endl;
    this->info.fileName = std::string(file_name);
    
    if (f)  return open(f);
    else {
        log_err("read file error!", path);
        return false;
    }
    return true;
}

bool PSD::open(FILE *f)
{
    fseek(f, 0, SEEK_END);
    long psd_len = ftell(f);
    fseek(f, 0, SEEK_SET);
    std::vector<psd_uint8_t> buffer(psd_len);
    size_t readed = fread(&buffer[0], sizeof(buffer[0]), psd_len, f);
    if (!readed) {
        log_err("read buffer error!", readed);
        fclose(f);
        return false;
    }
    this->psd_buffer = buffer;
    fclose(f);
    return true;
}

bool PSD::parse(long flags)
{
    PSDInfo info_ = info;
    PSDHeader header_;
    PSDImageResources imageresouces_;
    psd_uint64_t read_idx = 0;
    bool isPSB_ = false;
    
    // header
    read_buf(this->psd_buffer, &header_.signature, &read_idx);
    read_buf(this->psd_buffer, &header_.version, &read_idx);
    read_buf(this->psd_buffer, &header_.reserve1, &read_idx);
    read_buf(this->psd_buffer, &header_.reserve2, &read_idx);
    read_buf(this->psd_buffer, &header_.num_channels, &read_idx);
    read_buf(this->psd_buffer, &header_.height, &read_idx);
    read_buf(this->psd_buffer, &header_.width, &read_idx);
    read_buf(this->psd_buffer, &header_.bit_depth, &read_idx);
    read_buf(this->psd_buffer, &header_.c_mode, &read_idx);
    if (!check_head(header_, &isPSB_)) return false;
    
    isPSB = isPSB_;
    
    info_.Depth = header_.bit_depth;
    info_.BytesPerPixel = header_.bit_depth/8;
    info_.Channels = header_.num_channels;
    info_.Width = header_.width;
    info_.Height = header_.height;
    
    // colormode
    if (SKIP_COLOR_MODE_DATA & flags) {
        skip_block(this->psd_buffer, &read_idx);
    }
    else {
        // not implemented get color mode!
        skip_block(this->psd_buffer, &read_idx);
    }
    
    // image resource
    if (SKIP_IMAGE_RESOURCE_DATA & flags) {
        if (!skip_block(this->psd_buffer, &read_idx)) return false;
    }
    else {
        if (!read_imageresource(&read_idx, &imageresouces_, &info_)) return false;
    }
    
    // layer and masks
    if (!read_layer_and_mask(&read_idx, &info_, flags)) return false;
    
    dump(read_idx);
    if (!read_merged_image(&read_idx, &info_)) return false;
    
    /*dump(
         (std::string)header_.signature,
         header_.version,
         header_.num_channels,
         header_.height,
         header_.width,
         header_.bit_depth,
         header_.c_mode)*/
    
    this->info = info_;
    return true;
}

bool PSD::get_layer_datas()
{
    for (PSDLayerRecord& rec : layers) {
        std::vector<PSDImageData> all_ch(rec.ch_img_buf.size());
        
        for (auto it = rec.ch_img_buf.begin(); it != rec.ch_img_buf.end(); ++it) {
            PSDImageData im;
            
            psd_uint16_B compression_method;
            psd_uint64_t read_idx = 0;
            read_buf(it->second, &compression_method, &read_idx);
            im.channel_id = it->first;
            if (!im.decode_image_with_method(it->second, read_idx, isPSB, info.Width, info.Height, compression_method)) {
                return err_operation("get_layer_datas()", "decode image error", rec.name);
            }
            switch (it->first) {
                case 0:
                    all_ch[0] = im;
                    break;
                    
                case 1:
                    all_ch[1] = im;
                    break;
                    
                case 2:
                    all_ch[2] = im;
                    break;
                    
                case -1:
                    all_ch[3] = im;
                    break;
                    
                default:
                    break;
            }
        }
        PSDLayer l;
        
        l.ImageData.reserve(all_ch.size() * info.Height * info.Width);
        for (int y = 0; y < info.Height; y++)
            for (int x = 0; x < info.Width; x++)
                for (int c = 0; c < all_ch.size(); c++)
                    l.ImageData.emplace_back(all_ch[c].data[y][x*info.BytesPerPixel+info.BytesPerPixel-1]);
        
        l.name = rec.name;
        l.img.height = info.Height;
        l.img.width = info.Width;
        l.img.depth = 8;
        l.img.hasAlpha = true;
        l.img.resolution = 72;
        l.img.image_data = (const void*)l.ImageData.data();
        l.img.image_size = l.ImageData.size();
        l.img.channels = all_ch.size();
        info.Layers.emplace_back(l);
    }
    return true;
}


bool PSD::check_head(const PSDHeader& h, bool* is_psb)
{
    if (((std::string)h.signature != "8BPS") && ((std::string)h.signature != "8BPB"))
        return err_operation("PSDHead", "invalid signature!", (std::string)h.signature);
    if ((h.version != 1) && (h.version != 2))
        return err_operation("PSDHead", "invalid version!", h.version);
    if (h.version == 2 || (std::string)h.signature == "8BPB")
        *is_psb = true;
    if (h.num_channels == 0 || h.num_channels > 56)
        return err_operation("PSDHead", "invalid channel range!", h.num_channels);
    if (h.height == 0 || (*is_psb && h.width > 300000) || (!*is_psb && h.width > 30000) )
        return err_operation("PSDHead", "invalid image height!", h.height);
    if (h.width == 0 || (*is_psb && h.width > 300000) || (!*is_psb && h.width > 30000) )
        return err_operation("PSDHead", "invalid image width!", h.width);
    if (h.bit_depth != 1 && h.bit_depth != 8 && h.bit_depth != 16 && h.bit_depth != 32)
        return err_operation("PSDHead", "invalid image bitdepth!", h.bit_depth);
    if (h.c_mode != Bitmap && h.c_mode != Grayscale && h.c_mode != Indexed && h.c_mode != RGB &&
        h.c_mode != CMYK && h.c_mode != Multichannel && h.c_mode != Duotone && h.c_mode != Lab)
        return err_operation("PSDHead", "invalid image color mode!", h.c_mode);
    
    // supported check
    if (h.c_mode == Indexed || h.c_mode == Duotone)
        return err_operation("PSDHead", "not support color mode!", h.c_mode);
    
    return true;
}

bool PSD::read_imageresource(psd_uint64_t *read_idx, PSDImageResources *resouces, PSDInfo *info)
{
    psd_uint32_B res_len;
    psd_uint64_t start = *read_idx;
    
    read_buf(this->psd_buffer, &res_len, read_idx);
    if (res_len == 0)
        return true; // no image resource
    
    resouces->resouces.clear();
    while (*read_idx - start < res_len) {
        PSDImageResource res;
        
        read_buf(this->psd_buffer, &res.signature, read_idx);
        if ((std::string)res.signature != "8BIM")
            return err_operation("PSDImageResource", "invalid signature!", (std::string)res.signature);
        
        read_buf(this->psd_buffer, &res.image_resource_id, read_idx);
        
        psd_uint8_t name_len;
        read_buf(this->psd_buffer, &name_len, read_idx);
        if (name_len == 0x00)
            *read_idx+= 1; // padding
        else {
            res.name.resize(name_len);
            read_string(this->psd_buffer, &res.name, read_idx);
        }
        
        psd_uint32_B buf_len;
        read_buf(this->psd_buffer, &buf_len, read_idx);
        res.buffer.resize(buf_len);
        
        read_buf_byte(this->psd_buffer, &res.buffer[0], read_idx, buf_len);
        if (buf_len % 2 == 1)
            *read_idx+= 1; // padding
        
        switch (res.image_resource_id) {
            case RESN_INFO:
            {
                psd_uint64_t buf_idx = 0;
                psd_uint32_B tmp_32;
                psd_uint16_B tmp_16;
                read_buf(res.buffer, &tmp_32, &buf_idx);
                info->hRes = tmp_32 / 65536.0;
                read_buf(res.buffer, &tmp_16, &buf_idx);
                info->hResUnit = tmp_16;
                read_buf(res.buffer, &tmp_16, &buf_idx);
                info->WidthUnit = tmp_16;
                read_buf(res.buffer, &tmp_32, &buf_idx);
                info->vRes = tmp_32 / 65536.0;
                read_buf(res.buffer, &tmp_16, &buf_idx);
                info->vResUnit = tmp_16;
                read_buf(res.buffer, &tmp_16, &buf_idx);
                info->HeightUnit = tmp_16;
                break;
            }
            case XMP_DATA:
                info->XmpSrc = std::string(res.buffer.begin(), res.buffer.end());
                break;
            default:
                break;
        }
        resouces->resouces.emplace_back(res);
    }
    return true;
}

bool PSD::read_layer_and_mask(psd_uint64_t *read_idx, PSDInfo *info, long flags)
{
    psd_uint64_t section_len;
    if (isPSB) {
        psd_uint64_B section_len_;
        read_buf(this->psd_buffer, &section_len_, read_idx);
        section_len = section_len_;
    }
    else {
        psd_uint32_B section_len_;
        read_buf(this->psd_buffer, &section_len_, read_idx);
        section_len = section_len_;
    }
    psd_uint64_t section_start = *read_idx;
    if (section_len == 0) return true;
    
    if (!read_layer_info(read_idx, info, flags)) return false;
    
    // Global Layer Mask
    skip_block(this->psd_buffer, read_idx);
    
    // Additional
    if (*read_idx - section_start < section_len) {
        auto remaining = section_len - (*read_idx - section_start);
        *read_idx += remaining;
    }

    return true;
}

bool PSD::read_layer_info(psd_uint64_t *read_idx, PSDInfo *info, long flags)
{
//    psd_uint64_t info_len;
    if (isPSB) {
        psd_uint64_B info_len_;
        read_buf(this->psd_buffer, &info_len_, read_idx);
//        info_len = info_len_;
    }
    else {
        psd_uint32_B info_len_;
        read_buf(this->psd_buffer, &info_len_, read_idx);
//        info_len = info_len_;
    }
    
    psd_int16_B num_layers;
    info->has_merged_alpha_channel = false;
    
    read_buf(this->psd_buffer, &num_layers, read_idx);
    
    if (num_layers < 0) {
        num_layers = -num_layers;
        info->has_merged_alpha_channel = true;
    }
    
    //std::vector<PSDLayerRecord> lays;
    for (psd_uint32_t i = 0; i < num_layers; i++) {
        PSDLayerRecord layer;
        layer.channel_infos.clear();
        
        read_buf(this->psd_buffer, &layer.top, read_idx);
        read_buf(this->psd_buffer, &layer.left, read_idx);
        read_buf(this->psd_buffer, &layer.bottom, read_idx);
        read_buf(this->psd_buffer, &layer.right, read_idx);
        read_buf(this->psd_buffer, &layer.num_channels, read_idx);
        
        for (psd_uint32_t c = 0; c < layer.num_channels; c++) {
            psd_int16_B chan_id;
            psd_uint64_t chan_data_len;
            read_buf(this->psd_buffer, &chan_id, read_idx);
            if (isPSB) {
                psd_uint64_B chan_data_len_;
                read_buf(this->psd_buffer, &chan_data_len_, read_idx);
                chan_data_len = chan_data_len_;
            }
            else {
                psd_uint32_B chan_data_len_;
                read_buf(this->psd_buffer, &chan_data_len_, read_idx);
                chan_data_len = chan_data_len_;
            }
            layer.channel_infos.emplace_back(std::pair<psd_int16_t, psd_uint64_t>((psd_int16_t)chan_id, chan_data_len));
        }
        read_buf(this->psd_buffer, &layer.blend_sig, read_idx);
        
        if ((std::string)layer.blend_sig != "8BIM")
            return err_operation("PSDLayerRecord", "invalid signature!", (std::string)layer.blend_sig);
        
        read_buf(this->psd_buffer, &layer.blend_key, read_idx);
        read_buf(this->psd_buffer, &layer.opacity, read_idx);
        read_buf(this->psd_buffer, &layer.clipping, read_idx);
        read_buf(this->psd_buffer, &layer.bit_flags, read_idx);
        read_buf(this->psd_buffer, &layer.filler, read_idx);
        read_buf(this->psd_buffer, &layer.extra_len, read_idx);

        psd_int64_t extra_start = *read_idx;
        
        if (SKIP_LAYER_EXTRA_INFO & flags) {
            skip_block(this->psd_buffer, read_idx);
            skip_block(this->psd_buffer, read_idx);
        }
        else {
            // Layer Mask
            psd_uint32_B mask_len = 0;
            read_buf(this->psd_buffer, &mask_len, read_idx);
            if (mask_len != 0) {
                layer.mask.data.resize(mask_len);
                read_buf_byte(this->psd_buffer, &layer.mask.data[0], read_idx, mask_len);
            }
            
            // Layer Blend Mode
            psd_uint32_B blend_len = 0;
            read_buf(this->psd_buffer, &blend_len, read_idx);
            if (blend_len != 0) {
                layer.blending_ranges.data.resize(blend_len);
                read_buf_byte(this->psd_buffer, &layer.blending_ranges.data[0], read_idx, blend_len);
            }
        }
        psd_uint8_t name_size;
        read_buf(this->psd_buffer, &name_size, read_idx);
        
        std::vector<char> nm;
        nm.resize(name_size);
        read_buf(this->psd_buffer, &nm[0], read_idx, name_size);
        layer.name = std::string(nm.begin(), nm.end());
        
        switch(name_size%4)
        {
            case 0:
                *read_idx += 3;
                break;
            case 1:
                *read_idx += 2;
                break;
            case 2:
                *read_idx += 1;
                break;
            case 3:
                break;
        }

        while (*read_idx - extra_start < layer.extra_len) {
            PSDLayerRecord::PSDLayerExtra ed;
            read_buf(this->psd_buffer, &ed.signature, read_idx);
            if ((std::string)ed.signature != "8BIM" && (std::string)ed.signature != "8B64") {
                return err_operation("PSDLayerRecord::PSDLayerExtra", "invalid signature!", (std::string)ed.signature);
            }
            read_buf(this->psd_buffer, &ed.key, read_idx);
            
            psd_uint64_t ed_len;
            if (isPSB && (
                (std::string)ed.key == "LMsk" || (std::string)ed.key == "Lr16" || (std::string)ed.key == "Lr32" ||
                (std::string)ed.key == "Layr" || (std::string)ed.key == "Mt16" || (std::string)ed.key == "Mt32" ||
                (std::string)ed.key == "Mtrn" || (std::string)ed.key == "Alph" || (std::string)ed.key == "FMsk" ||
                (std::string)ed.key == "lnk2" || (std::string)ed.key == "FEid" || (std::string)ed.key == "FXid" || (std::string)ed.key == "PxSD") ) {
                psd_uint64_B ed_len_;
                read_buf(this->psd_buffer, &ed_len_, read_idx);
                ed_len = ed_len_;
            }
            else {
                psd_uint32_B ed_len_;
                read_buf(this->psd_buffer, &ed_len_, read_idx);
                ed_len = ed_len_;
                dump(ed_len)
            }
            if ((std::string)ed.key == "luni") { // レイヤー名取得(Unicode)
                ed.data.resize(ed_len);
                read_buf_byte(this->psd_buffer, &ed.data[0], read_idx, ed_len);
                char* p = (char*)&ed.data[0];
                psd_uint32_B uni_length = *(psd_uint32_B*)p;
                layer.wname.clear();
                for (psd_uint32_t i = 0; i < uni_length; i ++) {
                    layer.wname += (wchar_t)(psd_uint16_t)*(psd_uint16_B*)(p+4+i*2);
                }
                std::string utf8name;
                for (auto wc : layer.wname) {
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
                layer.name = utf8name;
            }
            else {
                *read_idx += ed_len;
            }
        }
        
        if (*read_idx - extra_start < layer.extra_len) {
            *read_idx += layer.extra_len - (*read_idx - extra_start);
        }
        
        
        layers.emplace_back(layer);
    }
    
    for (PSDLayerRecord& rec : layers) {
        
        for (std::pair<psd_int16_t, psd_uint64_t> ci : rec.channel_infos) {
            std::vector<psd_uint8_t> buf;
            rec.ch_img_buf[ci.first].resize(ci.second);
            read_buf_byte(this->psd_buffer, &rec.ch_img_buf[ci.first][0], read_idx, ci.second);
        }
    }

    return true;
}

bool PSD::read_merged_image(psd_uint64_t *read_idx, PSDInfo *info)
{
    PSDImageData im;
    
    psd_uint16_B compression_method;
    read_buf(this->psd_buffer, &compression_method, read_idx);
    if (!im.decode_image_with_method(this->psd_buffer, *read_idx, isPSB, info->Width, info->Height * info->Channels, compression_method)) {
        return err_operation("read_merged_image()", "decode image error", this->info.fileName);
    }
  
    
    std::vector<std::vector<std::vector<psd_uint8_t>>> data;
    data.resize(info->Channels);
    psd_uint32_t row = 0;
    for (psd_uint32_t ch = 0; ch < info->Channels; ch++) {
        data[ch].resize(info->Height);
        for (int y = 0; y < info->Height; y++) {
            data[ch][y].swap(im.data[row++]);
            if (data[ch][y].size() != info->Width*info->BytesPerPixel) {
                return err_operation("read_merged_image()", "not support depth", info->BytesPerPixel);
            }
        }
    }
    std::vector<psd_uint8_t> merged_buf;
    merged_buf.reserve(info->Channels*info->Height*info->Width);
    for (int y = 0; y < info->Height; y++)
        for (int x = 0; x < info->Width; x++)
            for (int ch = 0; ch < info->Channels; ch++)
                merged_buf.emplace_back(data[ch][y][x*info->BytesPerPixel+info->BytesPerPixel-1]);
    
    merged.image_data = (const void*)merged_buf.data();
    merged.image_size = merged_buf.size();
    merged.channels = info->Channels;
    return true;
}
