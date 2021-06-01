//
//  PDFiumFuncs.m
//  KZImage
//
//  Created by 内山和也 on 2019/04/18.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#include <iostream>
#include <string>
#include <vector>
#include "image_diff_png.h"
#import "PDFiumFuncs.h"

#define FOPEN_READ "r"

void PrintLastError();
void Unsupported_Handler(UNSUPPORT_INFO*, int type);
bool CheckDimensions(int stride, int width, int height);
std::vector<unsigned char> WritePng(const char* path,
                                    uint page,
                                    const void* buffer_void,
                                    int stride,
                                    int width,
                                    int height,
                                    size_t *outsize);

std::string WritePngFile(const char* path,
                         const char* save_path,
                         uint page,
                         const void* buffer_void,
                         int stride,
                         int width,
                         int height);
#pragma mark -
#pragma mark Initialize

PDFiumFuncs::PDFiumFuncs(double scale, void* delegate){
    _delegate = delegate;
    setlocale(LC_ALL, "");
    FPDF_LIBRARY_CONFIG config;
    config.version = 2;
    config.m_pUserFontPaths = NULL;
    config.m_pIsolate = NULL;
    config.m_v8EmbedderSlot = 0;
    
    FPDF_InitLibraryWithConfig(&config);
    
    UNSUPPORT_INFO unsuppored_info;
    memset(&unsuppored_info, '\0', sizeof(unsuppored_info));
    unsuppored_info.version = 1;
    unsuppored_info.FSDK_UnSupport_Handler = Unsupported_Handler;
    
    FSDK_SetUnSpObjProcessHandler(&unsuppored_info);
    
    _scale = scale;
    _dpi = 72.0;
}

PDFiumFuncs::~PDFiumFuncs(){
    std::cout <<  "Destroy PDFIUM" << std::endl;
    FPDF_DestroyLibrary();
}

#pragma mark -
#pragma mark Local Funcs

void PrintLastError() {
    unsigned long err = FPDF_GetLastError();
    const char *description = nullptr;

    switch (err) {
        case FPDF_ERR_SUCCESS:
            description = "Success.";
            break;
        case FPDF_ERR_UNKNOWN:
            description = "Unknown error.";
            break;
        case FPDF_ERR_FILE:
            description = "File not found or could not be opened.";
            break;
        case FPDF_ERR_FORMAT:
            description = "File not in PDF format or corrupted.";
            break;
        case FPDF_ERR_PASSWORD:
            description = "Password required or incorrect password.";
            break;
        case FPDF_ERR_SECURITY:
            description = "Unsupported security scheme.";
            break;
        case FPDF_ERR_PAGE:
            description = "Page not found or content error.";
            break;
        default:
            sprintf((char*)description, "Unknown error %ld.", err);
    }
    
    std::cerr << "Load pdf docs unsuccessful: " << description << std::endl;
    
    return;
}

void Unsupported_Handler(UNSUPPORT_INFO*, int type) {
    std::string feature = "Unknown";
    switch (type) {
        case FPDF_UNSP_DOC_XFAFORM:
            feature = "XFA";
            break;
        case FPDF_UNSP_DOC_PORTABLECOLLECTION:
            feature = "Portfolios_Packages";
            break;
        case FPDF_UNSP_DOC_ATTACHMENT:
        case FPDF_UNSP_ANNOT_ATTACHMENT:
            feature = "Attachment";
            break;
        case FPDF_UNSP_DOC_SECURITY:
            feature = "Rights_Management";
            break;
        case FPDF_UNSP_DOC_SHAREDREVIEW:
            feature = "Shared_Review";
            break;
        case FPDF_UNSP_DOC_SHAREDFORM_ACROBAT:
        case FPDF_UNSP_DOC_SHAREDFORM_FILESYSTEM:
        case FPDF_UNSP_DOC_SHAREDFORM_EMAIL:
            feature = "Shared_Form";
            break;
        case FPDF_UNSP_ANNOT_3DANNOT:
            feature = "3D";
            break;
        case FPDF_UNSP_ANNOT_MOVIE:
            feature = "Movie";
            break;
        case FPDF_UNSP_ANNOT_SOUND:
            feature = "Sound";
            break;
        case FPDF_UNSP_ANNOT_SCREEN_MEDIA:
        case FPDF_UNSP_ANNOT_SCREEN_RICHMEDIA:
            feature = "Screen";
            break;
        case FPDF_UNSP_ANNOT_SIG:
            feature = "Digital_Signature";
            break;
    }
    std::cerr << "Unsupported feature: " << feature << "." << std::endl;
}

bool CheckDimensions(int stride, int width, int height)
{
    if (stride < 0 || width < 0 || height < 0) {
        return false;
    }
    if (height > 0 && width > INT_MAX / height) {
        return false;
    }
    
    return true;
}

std::vector<unsigned char> WritePng(const char* path,
                                    uint page,
                                    const void* buffer_void,
                                    int stride,
                                    int width,
                                    int height,
                                    size_t *outsize)
{
    std::vector<unsigned char> png_encoding;
    
    if (!CheckDimensions(stride, width, height)) {
        std::cerr << "Check Dimention Error!" <<  std::endl;
        return std::vector<unsigned char>();
    }
    const auto* buffer = static_cast<const unsigned char*>(buffer_void);
    
    if (!image_diff_png::EncodeBGRAPNG(buffer, width, height, stride, false, &png_encoding)) {
        std::cerr << "Failed to convert bitmap to PNG" <<  std::endl;
        return std::vector<unsigned char>();
    }
    *outsize = png_encoding.size();
    
    return png_encoding;
/*
    std::auto_ptr<const char> encoded_data((const char*)malloc(*outsize));
    memset((void*)encoded_data.get(), 0, *outsize);
    memcpy((void*)encoded_data.get(), static_cast<void*>(png_encoding.data()), *outsize);
    return encoded_data.get();*/
}

std::string WritePngFile(const char* path,
                         const char* save_path,
                         uint page,
                         const void* buffer_void,
                         int stride,
                         int width,
                         int height)
{
    std::vector<unsigned char> png_encoding;
    
    if (!CheckDimensions(stride, width, height)) {
        std::cerr << "Check Dimention Error!" <<  std::endl;
        return "";
    }
    const auto* buffer = static_cast<const unsigned char*>(buffer_void);
    
    if (!image_diff_png::EncodeBGRAPNG(buffer, width, height, stride, false, &png_encoding)) {
        std::cerr << "Failed to convert bitmap to PNG" <<  std::endl;
        return "";
    }
    
    FILE* fp = fopen(save_path, "wb");
    if (!fp) {
        std::cerr << "Failed to open save_path : " << save_path << std::endl;
        return "";
    }
    size_t bytes_written =
    fwrite(&png_encoding.front(), 1, png_encoding.size(), fp);
    if (bytes_written != png_encoding.size()) {
        std::cerr << "Failed to write to " << save_path << std::endl;
        return "";
    }
    
    (void)fclose(fp);

    return save_path;
}

#pragma mark -
#pragma mark Public Funcs
void PDFiumFuncs::savePDF2PNG(const char* path, uint page, const char* save_path, double trim_size)
{
    FILE *pdf_file = fopen(path, FOPEN_READ);
    if(!pdf_file){
        std::cerr << "Failed to open: " << path <<  std::endl;
        return;
    }
    
    (void) fseek(pdf_file, 0, SEEK_END);
    size_t len = ftell(pdf_file);
    (void) fseek(pdf_file, 0, SEEK_SET);
    
    std::auto_ptr<char> docBuf((char*)malloc(len));
    
    size_t ret = fread(docBuf.get(), 1, len, pdf_file);
    (void) fclose(pdf_file);
    
    if (ret != len) {
        std::cerr << "Failed to read: " << path <<  std::endl;
        return;
    }
    
    FPDF_DOCUMENT current_doc = FPDF_LoadMemDocument(docBuf.get(), (int)ret, "");
    if (!current_doc) {
        PrintLastError();
        return;
    }
    
    FPDF_PAGE current_page = FPDF_LoadPage(current_doc, (int)page);
    if (!current_page) {
        FPDF_CloseDocument(current_doc);
        PrintLastError();
        return;
    }
    
    int width = static_cast<int>(round(FPDF_GetPageWidth(current_page) * _scale));
    int height = static_cast<int>(round(FPDF_GetPageHeight(current_page) * _scale));
    int orgWidth = width;
    int orgHeight = height;
    int alpha = 0;
    
    float one_point_mm = 25.4 / 72; // mm
    _width_mm = (orgWidth / _scale) * one_point_mm;
    _height_mm = (orgHeight / _scale) * one_point_mm;
    
    int trimPt = static_cast<int>(round((trim_size * (1 / one_point_mm)) * _scale));
    
    if (trim_size > 0) {
        width -= (trimPt * 2);
        height -= (trimPt * 2);
    }
    
    FPDF_BITMAP bmp(FPDFBitmap_Create(width, height, alpha));
    
    if (!bmp) {
        std::cerr << "Page was too large to be rendered." <<  std::endl;
        FPDF_ClosePage(current_page);
        FPDF_CloseDocument(current_doc);
        return;
    }
    
    FPDF_DWORD fill_color = alpha ? 0x00000000 : 0xFFFFFFFF;
    FPDFBitmap_FillRect(bmp, 0, 0, width, height, fill_color);
    
    if (trim_size > 0) {
        FPDF_RenderPageBitmap(bmp, current_page, -1 * trimPt, -1 * trimPt, orgWidth, orgHeight, 0, 0);
    }
    else {
        FPDF_RenderPageBitmap(bmp, current_page, 0, 0, width, height, 0, 0);
    }
    
    int stride = FPDFBitmap_GetStride(bmp);
    
    const void* buf = static_cast<const void*>(FPDFBitmap_GetBuffer(bmp));
    
    std::string saved = WritePngFile(path, save_path, page, buf, stride, width, height);

    FPDFBitmap_Destroy(bmp);
    FPDF_ClosePage(current_page);
    FPDF_CloseDocument(current_doc);
    
    return;
}

const void* PDFiumFuncs::loadPDF(const char* path, uint page, size_t *out_size, double trim_size)
{
    FILE *pdf_file = fopen(path, FOPEN_READ);
    if(!pdf_file){
        std::cerr << "Failed to open: " << path <<  std::endl;
        return nullptr;
    }
    
    (void) fseek(pdf_file, 0, SEEK_END);
    size_t len = ftell(pdf_file);
    (void) fseek(pdf_file, 0, SEEK_SET);
    
    std::auto_ptr<char> docBuf((char*)malloc(len));
    
    size_t ret = fread(docBuf.get(), 1, len, pdf_file);
    (void) fclose(pdf_file);
    
    if (ret != len) {
        std::cerr << "Failed to read: " << path <<  std::endl;
        return nullptr;
    }
    
    FPDF_DOCUMENT current_doc = FPDF_LoadMemDocument(docBuf.get(), (int)ret, "");
    if (!current_doc) {
        PrintLastError();
        return nullptr;
    }
    
    FPDF_PAGE current_page = FPDF_LoadPage(current_doc, (int)page);
    if (!current_page) {
        FPDF_CloseDocument(current_doc);
        PrintLastError();
        return nullptr;
    }
    
    int width = static_cast<int>(round(FPDF_GetPageWidth(current_page) * _scale));
    int height = static_cast<int>(round(FPDF_GetPageHeight(current_page) * _scale));
    int orgWidth = width;
    int orgHeight = height;
    int alpha = 0;
    
    float one_point_mm = 25.4 / 72; // mm
    _width_mm = (orgWidth / _scale) * one_point_mm;
    _height_mm = (orgHeight / _scale) * one_point_mm;
    
    int trimPt = static_cast<int>(round((trim_size * (1 / one_point_mm)) * _scale));
    
    if (trim_size > 0) {
        width -= (trimPt * 2);
        height -= (trimPt * 2);
    }
    
    FPDF_BITMAP bmp(FPDFBitmap_Create(width, height, alpha));
    
    if (!bmp) {
        std::cerr << "Page was too large to be rendered." <<  std::endl;
        FPDF_ClosePage(current_page);
        FPDF_CloseDocument(current_doc);
        return nullptr;
    }
    
    FPDF_DWORD fill_color = alpha ? 0x00000000 : 0xFFFFFFFF;
    FPDFBitmap_FillRect(bmp, 0, 0, width, height, fill_color);
    
    if (trim_size > 0) {
        FPDF_RenderPageBitmap(bmp, current_page, -1 * trimPt, -1 * trimPt, orgWidth, orgHeight, 0, 0);
    }
    else {
        FPDF_RenderPageBitmap(bmp, current_page, 0, 0, width, height, 0, 0);
    }
    
    int stride = FPDFBitmap_GetStride(bmp);
    
    const char* buf = reinterpret_cast<const char*>(FPDFBitmap_GetBuffer(bmp));
    std::vector<unsigned char> png_d = WritePng(path, page, buf, stride, width, height, out_size);
    FPDFBitmap_Destroy(bmp);
    FPDF_ClosePage(current_page);
    FPDF_CloseDocument(current_doc);

    return (const void*)png_d.data();
    /*
     std::auto_ptr<const char> encoded_data((const char*)malloc(*outsize));
     memset((void*)encoded_data.get(), 0, *outsize);
     memcpy((void*)encoded_data.get(), static_cast<void*>(png_encoding.data()), *outsize);
     return encoded_data.get();*/
}

std::pair<double, double> PDFiumFuncs::get_size(const char* path, uint page)
{
    std::pair<double, double> ret_size;
    
    FILE *pdf_file = fopen(path, FOPEN_READ);
    if(!pdf_file){
        std::cerr << "Failed to open: " << path <<  std::endl;
        return ret_size;
    }
    
    (void) fseek(pdf_file, 0, SEEK_END);
    size_t len = ftell(pdf_file);
    (void) fseek(pdf_file, 0, SEEK_SET);
    
    std::auto_ptr<char> docBuf((char*)malloc(len));
    
    size_t ret = fread(docBuf.get(), 1, len, pdf_file);
    (void) fclose(pdf_file);
    
    if (ret != len) {
        std::cerr << "Failed to read: " << path <<  std::endl;
        return ret_size;
    }
    
    FPDF_DOCUMENT current_doc = FPDF_LoadMemDocument(docBuf.get(), (int)ret, "");
    if (!current_doc) {
        PrintLastError();
        return ret_size;
    }
    
    FPDF_PAGE current_page = FPDF_LoadPage(current_doc, (int)page);
    if (!current_page) {
        FPDF_CloseDocument(current_doc);
        PrintLastError();
        return ret_size;
    }
    
    int width = static_cast<int>(round(FPDF_GetPageWidth(current_page) * _scale));
    int height = static_cast<int>(round(FPDF_GetPageHeight(current_page) * _scale));
    int orgWidth = width;
    int orgHeight = height;
    int alpha = 0;
    
    float one_point_mm = 25.4 / 72; // mm
    double width_mm = (orgWidth / _scale) * one_point_mm;
    double height_mm = (orgHeight / _scale) * one_point_mm;

    FPDF_ClosePage(current_page);
    FPDF_CloseDocument(current_doc);
    
    ret_size = std::pair<double, double>(width_mm, height_mm);
    
    return ret_size;
}

