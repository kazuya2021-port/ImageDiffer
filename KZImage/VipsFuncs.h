//
//  VipsFuncs.h
//  KZImage
//
//  Created by uchiyama_Macmini on 2019/03/22.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//
#ifndef vips_core_hpp
#define vips_core_hpp


#include <ImageEnum.h>
#include <map>
#include <iostream>
#include <iomanip>
#include <cassert>
#include <cmath>
#include <string>
#include <vips/vips8>
#include <vector>
#import <Foundation/Foundation.h>
#import <KZLibs.h>

using namespace vips;

class VipsFuncs
{
public:
    VipsFuncs();
    ~VipsFuncs();

    // funcs
    bool startEngine(NSString* app_path, void* delegate);
    void stopEngine(void);
    
    // -------
    NSData* imageConvert(NSData *src_data, const char *src_path, KZFileFormat src_format, uint page,
                      NSData *trg_data, const char *trg_path, KZFileFormat trg_format,
                      KZColorSpace trg_color, double trg_dpi, bool is_resample = true, double trim_size = 0);
    
    // accesser
    void setPdfScale(double val);
    
    std::pair<double, double> getPdfSize(const char *src_path, uint page);
    
private:
    bool _is_running;
    double _pdf_scale = 1.0;
    std::map<VipsInterpretation, std::string> _profile_map;
    void* _delegate;
    const void* _buf;
    
    VImage openImage(const char* img_path, KZFileFormat format, uint page);
    bool resize_process(VImage &src, double trg_dpi, bool is_resize, KZFileFormat src_format, KZFileFormat trg_format);
    bool change_color_process(VImage &src, KZColorSpace trg_color);
    bool trim_image(VImage &src, double trim_size, const char* unit);
    bool saveFileProcess(VImage &img, KZFileFormat trg_format, const char *trg_path, KZColorSpace color);
    VipsBlob* saveBufferProcess(VImage &img, KZFileFormat trg_format, KZColorSpace color);
    void convertMainProcess(VImage &img,
                            double trg_dpi,
                            bool is_resample,
                            KZFileFormat src_format,
                            KZFileFormat trg_format,
                            KZColorSpace trg_color,
                            double trim_size);
};

#endif
