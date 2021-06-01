//
//  PDFiumFuncs.h
//  KZImage
//
//  Created by 内山和也 on 2019/04/18.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#ifndef __KZImage__pdfium__
#define __KZImage__pdfium__

#include <memory>
#include <fpdfview.h>
#include <fpdf_doc.h>
#include <fpdf_ext.h>
#include <fpdf_progressive.h>
#import <Foundation/Foundation.h>

class PDFiumFuncs
{
public:
    PDFiumFuncs(double scale, void* delegate);
    ~PDFiumFuncs();
    
    const void* loadPDF(const char* path, uint page, size_t *out_size, double trim_size=0);
    void savePDF2PNG(const char* path, uint page, const char* save_path, double trim_size=0);
    std::pair<double, double> get_size(const char* path, uint page);
    
private:
    double _dpi;
    double _scale;
    double _width_mm;
    double _height_mm;
    void* _delegate;
};
#endif