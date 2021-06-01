//
//  psd_image_resources.hpp
//  KZPSDParser
//
//  Created by uchiyama_Macmini on 2019/08/13.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef psd_image_resources_hpp
#define psd_image_resources_hpp

#include <stdio.h>
#include "psd_utils.hpp"

class PSDImageResoucrce
{
public:
    virtual ~PSDImageResoucrce() {}
    virtual bool interpretBlock(std::vector<char> buffer) { return true; }
    virtual bool createBlock(std::vector<char> &buffer) { return true; }
    virtual std::string description() { return ""; }
    virtual bool valid() { return true; }
};

namespace psd
{
    enum PSDResourceID {
        UNKNOWN                = 0,
        PS2_INFO               = 1000,
        MAC_PRINT_INFO         = 1001,
        MAC_PAGE_INFO          = 1002,
        PS2_COLOR_TABLE        = 1003,
        RESN_INFO              = 1005,
        ALPHA_NAMES            = 1006,
        PRINT_FLAGS            = 1011,
        COLOR_HALFTONE         = 1013,
        COLOR_XFER             = 1016,
        LAYER_STATE            = 1024,
        LAYER_GROUP            = 1026,
        GRID_GUIDE             = 1032,
        THUMB_RES2             = 1036,
        GLOBAL_ANGLE           = 1037,
        ICC_UNTAGGED           = 1041,
        DOC_IDS                = 1044,
        GLOBAL_ALT             = 1049,
        SLICES                 = 1050,
        URL_LIST_UNI           = 1054,
        VERSION_INFO           = 1057,
        EXIF_DATA              = 1058,
        XMP_DATA               = 1060,
        CAPTION_DIGEST         = 1061,
        PRINT_SCALE            = 1062,
        PIXEL_ASPECT_RATION    = 1064,
        LAYER_SELECTION_ID     = 1069,
        LAYER_GROUP_ENABLED_ID = 1072,
        CS5_PRINT_INFO         = 1082,
        CS5_PRINT_STYLE        = 1083,
        PRINT_FLAGS_2          = 10000
    };
    
    struct ResolutionInfo : public PSDImageResoucrce
    {
        enum Unit {
            PSD_UNIT_INCH         = 1,
            PSD_UNIT_CM           = 2,
            PSD_UNIT_POINT        = 3,
            PSD_UNIT_PICA         = 4,
            PSD_UNIT_COLUMN       = 5
        };

        ResolutionInfo() {}
        
        be<uint32_t> hRes;      /* Fixed-point number: pixels per inch */
        be<uint16_t> hResUnit;  /* 1=pixels per inch, 2=pixels per centimeter */
        be<uint16_t> WidthUnit; /* 1=in, 2=cm, 3=pt, 4=picas, 5=columns */
        be<uint32_t> vRes;      /* Fixed-point number: pixels per inch */
        be<uint16_t> vResUnit;  /* 1=pixels per inch, 2=pixels per centimeter */
        be<uint16_t> HeightUnit;/* 1=in, 2=cm, 3=pt, 4=picas, 5=columns */
        
        bool interpretBlock(std::vector<char> buffer) override {
            this->hRes = read_vector<be<uint32_t>>(buffer, 0, 4);
            this->hRes = (this->hRes / 65536.0);
            this->hResUnit = read_vector<be<uint16_t>>(buffer, 4, 6);
            this->WidthUnit = read_vector<be<uint16_t>>(buffer, 6, 8);
            this->vRes = read_vector<be<uint32_t>>(buffer, 8, 12);
            this->vRes = this->vRes / 65536.0;
            this->vResUnit = read_vector<be<uint16_t>>(buffer, 12, 14);
            this->HeightUnit = read_vector<be<uint16_t>>(buffer, 14, 16);
            return true;
        }
        bool createBlock(std::vector<char> &buffer) override { return true; }
        bool valid() override { return true; }
        std::string description() override;
    };
    
    struct XMPInfo : public PSDImageResoucrce
    {
        XMPInfo() {}
        
        std::string xmp_rawdata;
        
        bool interpretBlock(std::vector<char> buffer) override {
            xmp_rawdata = std::string(buffer.begin(), buffer.end());
            return true;
        }
        
        bool createBlock(std::vector<char> &buffer) override { return true; }
        bool valid() override { return true; }
        std::string description() override {
            return xmp_rawdata;
        };
    };
    
    struct ImageResourceBlock
    {
        ~ImageResourceBlock();
        Signature signature;
        be<uint16_t> image_resource_id;
        std::string name; // encoded as pascal string; 1 byte length header
        
        std::vector<char> buffer;
        PSDImageResoucrce *resource;
        bool read(FILE* psd_file);
        bool write(FILE* psd_file);
    };
    
    struct ImageResources
    {
        std::map<PSDResourceID, ImageResourceBlock> resouces;
        bool load(FILE* psd_file);
        bool save(FILE* psd_file);
    };
    
    
}


#endif /* psd_image_resources_hpp */
