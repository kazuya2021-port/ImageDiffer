//
//  psd_def.h
//  KZMagick
//
//  Created by uchiyama_Macmini on 2019/08/19.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef psd_def_h
#define psd_def_h
#include <stdio.h>
#include <queue>
#include <string>
#include <sstream>
#include <iostream>

std::queue<std::string> argment_contents;
void set_args_con() {}

template<class First, class... Rest>
void set_args_con(const First& first, const Rest&... rest){
    std::stringstream ss;
    ss<<first;
    argment_contents.push(ss.str());
    set_args_con(rest...);
}

std::string gen_string(std::string s){
    s+=',';
    std::string ret="";
    int par=0;
    for(int i=0; i<(int)s.size(); i++) {
        if(s[i]=='(' || s[i]=='<' || s[i]=='{') par++;
        else if(s[i]==')' || s[i]=='>' || s[i]=='}') par--;
        if(par==0 && s[i]==',') {
            ret+=" = "+argment_contents.front();
            argment_contents.pop();
            if(i!=(int)s.size()-1) {
                ret+=",";
            }
        }
        else ret+=s[i];
    }
    return ret;
}

#ifdef DEBUG
#define dump(...) {set_args_con(__VA_ARGS__);std::cerr<<gen_string(#__VA_ARGS__)<<std::endl;}
#define log_err(message, ...) {std::cerr<<message<<std::endl;set_args_con(__VA_ARGS__);std::cerr<<gen_string(#__VA_ARGS__)<<std::endl;}
#else
#define dump(...)
#define log_err(message, ...) std::cerr<<message<<std::endl;
#endif

typedef uint8_t psd_uint8_t;
typedef uint16_t psd_uint16_t;
typedef uint32_t psd_uint32_t;
typedef uint64_t psd_uint64_t;
typedef int8_t psd_int8_t;
typedef int16_t psd_int16_t;
typedef int32_t psd_int32_t;
typedef int64_t psd_int64_t;

enum PSDColorMode {
    Bitmap = 0,
    Grayscale = 1,
    Indexed = 2,
    RGB = 3,
    CMYK = 4,
    Multichannel = 7,
    Duotone = 8,
    Lab = 9
};

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

// ***** Parse Flags Info *****
enum PsdParseFlags {
    SKIP_COLOR_MODE_DATA        = 0x0000000000000001,   // skip ColorModeData
    SKIP_IMAGE_RESOURCE_DATA    = 0x0000000000000010,   // skip ImageResources ==> not read Dpi/XmpSrc
    SKIP_LAYER_EXTRA_INFO       = 0x0000000000000100,   // skip Extra Layer Info
    //SKIP_LAYER_ADDITIONAL_INFO  = 0x0000000000001000    // skip Additional Layer Info
};

struct PSDRawImage
{
    PSDRawImage() : opaque(255) {}
    const void* image_data;
    size_t image_size;
    int channels;
    int width, height;
    int c_mode;
    int depth;
    bool hasAlpha;
    bool is_hidden;
    float resolution;
    psd_uint8_t opaque;
};

struct PSDLayer
{
    PSDRawImage img;
    std::vector<psd_uint8_t> ImageData;
    std::string name;
};
#endif /* psd_def_h */
