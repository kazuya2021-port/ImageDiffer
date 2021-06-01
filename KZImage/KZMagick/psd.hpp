//
//  psd.hpp
//  KZMagick
//
//  Created by uchiyama_Macmini on 2019/08/19.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef psd_hpp
#define psd_hpp
#include <sstream>
//#include <mutex>
#include "psd_def.h"
#include "psd_util.hpp"
#include "psd_types.hpp"
#include "psd_file_struct.hpp"



namespace Psd {
//    std::mutex mtx;
    using namespace Psd::Util;
    using namespace Psd::FileStruct;
    class Layer {
        std::string name;
        PSDImageData imageData;
        
    };
    class PSD {
    public:
        PSD() {}
        ~PSD() {}
        
        // PSD Infos
        PSDInfo info;
        PSDRawImage merged;
        
        bool open(const char *path);
        bool open(FILE *f);
        bool parse(long flags);
        bool get_layer_datas();
        bool get_merged_image();
        
        bool save(const char *path, const std::vector<std::pair<const char*,PSDRawImage>> &layer_imgs, PSDRawImage &merged);
        bool save(FILE *f, const std::vector<std::pair<const char*,PSDRawImage>> &layer_imgs, PSDRawImage &merged);
        bool write_layer_and_mask(std::vector<psd_uint8_t> *out_buf,
                                  PSDInfo *info,
                                  const std::vector<std::vector<std::vector<psd_uint8_t>>> &lay_ch_img,
                                  const std::vector<std::vector<std::vector<psd_uint8_t>>> &lay_ch_pack);
        
        bool write_image(std::vector<psd_uint8_t> *out_buf,
                         PSDInfo *info,
                         const std::vector<std::vector<psd_uint8_t>> &lay_ch_img,
                         const std::vector<std::vector<psd_uint8_t>> &lay_ch_pack);
    private:
        
        bool decode_PNG(const std::vector<std::pair<const char*,PSDRawImage>>&layer_imgs, std::vector<std::pair<const char*,std::vector<unsigned char>>>*imgs);
        
        std::vector<PSDLayerRecord> layers;
        std::vector<psd_uint8_t> psd_buffer;
        PSDHeader header;
        bool isPSB;
        
        template <class T>
        bool err_operation(std::string cate, std::string msg, const T& data)
        {
            std::stringstream ss;
            ss << cate << " : " << msg;
            std::cerr<<ss.str()<< ":" << data <<std::endl;
            return false;
        }
        
        bool check_head(const PSDHeader& h, bool* is_psb);
        bool read_imageresource(psd_uint64_t *read_idx, PSDImageResources *resouces, PSDInfo *info);
        bool read_layer_and_mask(psd_uint64_t *read_idx, PSDInfo *info, long flags);
        bool read_layer_info(psd_uint64_t *read_idx, PSDInfo *info, long flags);
        bool read_merged_image(psd_uint64_t *read_idx, PSDInfo *info);
        bool skip_block(const std::vector<psd_uint8_t> &buf, psd_uint64_t *read_pos)
        {
            psd_uint32_B count;
            read_buf(buf, &count, read_pos);
            if (count != 0) {
                *read_pos += count;
                return true;
            }
            else {
                return false;
            }
        }
    };
}
#endif /* psd_hpp */
