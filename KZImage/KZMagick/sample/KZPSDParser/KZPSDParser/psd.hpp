//
//  psd.hpp
//  KZPSDParser
//
//  Created by uchiyama_Macmini on 2019/08/09.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef psd_hpp
#define psd_hpp

#include <stdio.h>

#define EQ_STR_C(x, y) (!memcmp(x, y, strlen(y)))

#define DUOTONE_DATA_SIZE (4*(10+64+28) + 2 + 11*10)

enum{RAWDATA,RLECOMP,ZIPNOPREDICT,ZIPPREDICT}; // ZIP types from CS doc
#define SCAVENGE_MODE -1
#define ModeBitmap         0
#define ModeGrayScale         1
#define ModeIndexedColor 2
#define ModeRGBColor         3
#define ModeCMYKColor         4
#define ModeHSLColor         5
#define ModeHSBColor         6
#define ModeMultichannel 7
#define ModeDuotone         8
#define ModeLabColor         9
#define ModeGray16        10
#define ModeRGB48            11
#define ModeLab48            12
#define ModeCMYK64        13
#define ModeDeepMultichannel 14
#define ModeDuotone16        15
#define TRANS_CHAN_ID (-1)
#define LMASK_CHAN_ID (-2)
#define UMASK_CHAN_ID (-3)

#define PAD2(x) (((x)+1) & -2) // same or next even
#define PAD4(x) (((x)+3) & -4) // same or next multiple of 4
#define PAD_BYTE 0

#define PNG_COLOR_MASK_PALETTE    1
#define PNG_COLOR_MASK_COLOR      2
#define PNG_COLOR_MASK_ALPHA      4

#define PNG_COLOR_TYPE_GRAY 0
#define PNG_COLOR_TYPE_PALETTE  (PNG_COLOR_MASK_COLOR | PNG_COLOR_MASK_PALETTE)
#define PNG_COLOR_TYPE_RGB        (PNG_COLOR_MASK_COLOR)
#define PNG_COLOR_TYPE_RGB_ALPHA  (PNG_COLOR_MASK_COLOR | PNG_COLOR_MASK_ALPHA)
#define PNG_COLOR_TYPE_GRAY_ALPHA (PNG_COLOR_MASK_ALPHA)

#define PNG_COLOR_TYPE_RGBA  PNG_COLOR_TYPE_RGB_ALPHA
#define PNG_COLOR_TYPE_GA  PNG_COLOR_TYPE_GRAY_ALPHA

const int mode_channel_count[] = {
    1, 1, 1, 3, 4, 3, 3, 0, 1, 3, 1, 3, 3, 4, 0, 1
};

const int mode_colour_space[] = {
    8, 8, 0, 0, 2, -1, -1, 8, 14, 7, 8, 0, 7, 2, 8, 14
};

typedef int int32;
typedef short int16;

typedef unsigned char unchar;
typedef unsigned short unint16;
typedef unsigned int unint32;
typedef unint32 psd_bytes_t;
typedef unint32 psd_pixels_t;

typedef struct _LayerInfo {
    const char *name;
    const void *data;
    size_t length;
    _LayerInfo(){
        this->data = nullptr;
        this->length = 0;
    }
    
    void setBuf(const void* buf, size_t len) {
        this->data = malloc(len);
        this->length = len;
        memmove((void*)this->data, buf, len);
    };
    
    void pushBuf(const void* item, size_t unit_size, int item_count) {
        void* adr = malloc(unit_size * (this->length + item_count));
        memcpy(adr, this->data, this->length);
        memcpy((char*)adr + (unit_size * this->length), item, unit_size);
        free((void*)this->data);
        this->data = nullptr;
        this->data = adr;
        this->length = unit_size * (this->length + item_count);
    }
    
    void freeBuf() {
        free((void *)this->data);
    }
} LayerInfo;

class psd {
public:
    psd();
    ~psd();
    psd(const char* path);
    LayerInfo *layer_data;
    void parselayers();
    
private:
    struct psd_header *header;
    FILE* psd_p;
};
#endif /* psd_hpp */
