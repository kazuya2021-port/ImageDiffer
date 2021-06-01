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
    NSData* imageConvert(FILE *src_data, const char *src_path, KZFileFormat src_format, uint page,
                      const char *trg_path, KZFileFormat trg_format,
                      KZColorSpace trg_color, double trg_dpi, int width, int height, int num_channels, bool is_adjust = false, bool is_resample = true, double trim_size = 0);
    
    NSData* imageConvertD(NSData *src_data, const char *src_path, KZFileFormat src_format, uint page,
                         const char *trg_path, KZFileFormat trg_format,
                         KZColorSpace trg_color, double trg_dpi, int width, int height, int num_channels, bool is_adjust = false, bool is_resample = true, double trim_size = 0);
    
    NSData* mergeImg(NSArray *src_datas);
    //savePath:(NSString*)savePath saveNames:(NSArray*)arNames
    void cropMentuke(FILE *src_data, NSArray* info, bool isSiagari, const char* savePath, NSArray* arNames, void* sender);
    NSData* cropRect(FILE *src_data, float x, float y, float w, float h, float ratio);
    // accesser
    void setPdfScale(double val);

    std::pair<double, double> getPdfSize(const char *src_path, uint page);
    std::pair<double, double> getImageSize(const char *src_path, int dpi);
    int getDPI(const char *src_path);
    
    // for decode
    int bands;
    int width, height,depth;
    float res;
    bool is_alpha;
    KZColorSpace space;
    void* _delegate;
    
private:
    bool _is_running;
    double _pdf_scale = 1.0;
    
};

#endif
