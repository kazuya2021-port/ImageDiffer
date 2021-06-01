//
//  ImageEnum.h
//  KZImage
//
//  Created by 内山和也 on 2019/04/16.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#ifndef KZImage_ImageEnum_h
#define KZImage_ImageEnum_h

enum class KZFileFormat : int {
    TIFF_FORMAT,
    PNG_FORMAT,
    JPG_FORMAT,
    GIF_FORMAT,
    PSD_FORMAT,
    PDF_FORMAT,
    EPS_FORMAT,
    RAW_FORMAT,
    UNKNOWN_FORMAT,
};

enum class KZColorSpace : int {
    GRAY,
    SRGB,
    CMYK,
    SRC,
};

#endif
