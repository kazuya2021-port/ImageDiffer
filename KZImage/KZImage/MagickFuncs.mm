//
//  MagickFuncs.m
//  KZImage
//
//  Created by 内山和也 on 2019/04/18.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#include <iostream>
#include <list>
#include <vector>
#include <string>
#include <sstream>
#include <stdio.h>
#include <Magick++.h>
#import "MagickFuncs.h"

void convertToMakePSD(Magick::Image &src_img, double_t dpi, bool is_color);

#pragma mark -
#pragma mark Initialize

MagickFuncs::MagickFuncs()
{
}

MagickFuncs::~MagickFuncs()
{
}

void MagickFuncs::initMagick(NSString* app_path, void* delegate)
{
    _delegate = delegate;
    NSString *path = [app_path stringByAppendingPathComponent:@"Resources"];
    NSString *configPath = [path stringByAppendingPathComponent:@"MagickConfig"];
    setenv("MAGICK_CONFIGURE_PATH", [configPath UTF8String], 1);
    setenv("MAGICK_TEMPORARY_PATH", "/tmp/", 1);
    /*setenv("MAGICK_MEMORY_LIMIT", "16GiB", 1);
    setenv("MAGICK_MAP_LIMIT", "32GiB", 1);
    setenv("MAGICK_DISK_LIMIT", "40GB", 1);
    setenv("MAGICK_THREAD_LIMIT", "1", 1);*/
//    setenv("MAGICK_SYNCHRONIZE", "true", 1);
    Magick::InitializeMagick([app_path UTF8String]);
    
}

void MagickFuncs::stopMagick()
{
    Magick::TerminateMagick();
}

#pragma mark -
#pragma mark Local Funcs
void convertToMakePSD(Magick::Image &src_img, double_t dpi, bool is_color)
{
    if (is_color) {
        src_img.type(Magick::TrueColorAlphaType);
    }else{
        src_img.type(Magick::GrayscaleAlphaType);
    }
    src_img.strip();
    src_img.compressType(Magick::RLECompression);
    src_img.endian(Magick::MSBEndian);
    src_img.resolutionUnits(Magick::PixelsPerInchResolution);
    src_img.density(dpi);
    src_img.backgroundColor(Magick::Color("white"));
}

#pragma mark -
#pragma mark Public Funcs

bool MagickFuncs::makePSD(const char* comp,
                          const char* diff,
                          const char* src,
                          const char* trg,
                          const char* save_path,
                          bool is_save_color,
                          bool is_save_layer,
                          double dpi,
                          double alpha)
{
    Magick::Image comp_img, diff_img, src_img, trg_img;
    bool ret = true;
    
    try
    {
        std::list<Magick::Image> images;
        
        std::string label_mrg = "Result";
        std::string label_old = "OLD";
        std::string label_new = "NEW";
        
        if(is_save_layer)
        {
            // 1st
            src_img.read(src);
            convertToMakePSD(src_img, dpi, is_save_color);
            src_img.classType(Magick::DirectClass);
            src_img.compose(Magick::OverCompositeOp);
            src_img.label(label_old);
            
            // 2nd
            trg_img.read(trg);
            convertToMakePSD(trg_img, dpi, is_save_color);
            trg_img.classType(Magick::DirectClass);
            trg_img.compose(Magick::NoCompositeOp);
            trg_img.label(label_new);
            
            // 3rd
            diff_img.read(diff);
            Magick::Color transColor;
            convertToMakePSD(diff_img, dpi, is_save_color);
            diff_img.evaluate(Magick::AlphaChannel, Magick::MultiplyEvaluateOperator, alpha);
            diff_img.classType(Magick::DirectClass);
            diff_img.compose(Magick::OverCompositeOp);
            diff_img.label(label_mrg);
            
            
            // top
            comp_img.read(comp);
            convertToMakePSD(comp_img, dpi, is_save_color);
            comp_img.classType(Magick::DirectClass);
            comp_img.compose(Magick::OverCompositeOp);
            
            images.push_back(src_img);
            images.push_back(trg_img);
            images.push_back(diff_img);
            images.push_front(comp_img);
            
            Magick::writeImages(images.begin(), images.end(), save_path);
        }
        else
        {
            comp_img.read(comp);
            convertToMakePSD(comp_img, dpi, is_save_color);
            comp_img.label(label_mrg);
            comp_img.write(save_path);
        }
    }
    catch( Magick::Exception &error)
    {
        std::cerr << "Caught exception : " << error.what() << std::endl;
        ret = false;
    }
    return ret;
}

bool MagickFuncs::makePSD(NSData* comp, NSData* diff, NSData* src, NSData* trg,
                          const char* save_path,
                          bool is_save_color,
                          bool is_save_layer,
                          double dpi,
                          double alpha)
{
    Magick::Image top_page, all_img, src_img, trg_img;
    bool ret = true;
    
    try
    {
        std::list<Magick::Image> images;
        
        std::string label_mrg = "Result";
        std::string label_old = "OLD";
        std::string label_new = "NEW";
        
        if(is_save_layer)
        {
            Magick::Blob src_b(src.bytes, src.length);
            Magick::Blob trg_b(trg.bytes, trg.length);
            Magick::Blob diff_b(diff.bytes, diff.length);
            Magick::Blob comp_b;
            if (comp) {
                comp_b = Magick::Blob(comp.bytes, comp.length);
            }
            else {
                comp_b = diff_b;
            }
            // 1st
            src_img.read(src_b);
            convertToMakePSD(src_img, dpi, is_save_color);
            src_img.classType(Magick::DirectClass);
            src_img.compose(Magick::OverCompositeOp);
            src_img.label(label_old);
            
            // 2nd
            trg_img.read(trg_b);
            convertToMakePSD(trg_img, dpi, is_save_color);
            trg_img.classType(Magick::DirectClass);
            trg_img.compose(Magick::OverCompositeOp);
            trg_img.label(label_new);
            
            // 3rd
            all_img.read(diff_b);
            Magick::Color transColor;
            convertToMakePSD(all_img, dpi, is_save_color);
            all_img.evaluate(Magick::AlphaChannel, Magick::MultiplyEvaluateOperator, alpha);
            all_img.classType(Magick::DirectClass);
            all_img.compose(Magick::OverCompositeOp);
            all_img.label(label_mrg);
            
            
            // top
            top_page.read(comp_b);
            convertToMakePSD(top_page, dpi, is_save_color);
            top_page.classType(Magick::DirectClass);
            top_page.compose(Magick::OverCompositeOp);
            
            images.push_back(src_img);
            images.push_back(trg_img);
            images.push_back(all_img);
            images.push_front(top_page);
            
            Magick::writeImages(images.begin(), images.end(), save_path);
        }
        else
        {
            Magick::Blob comp_b;
            if (comp) {
                comp_b = Magick::Blob(comp.bytes, comp.length);
            }
            else {
                comp_b = Magick::Blob(diff.bytes, diff.length);
            }

            all_img.read(comp_b);
            convertToMakePSD(all_img, dpi, is_save_color);
            all_img.label(label_mrg);
            all_img.write(save_path);
        }
    }
    catch( Magick::Exception &error)
    {
        std::cerr << "Caught exception : " << error.what() << std::endl;
        ret = false;
    }
    return ret;
}

bool MagickFuncs::makePSD(NSArray* imgs,
                          NSArray* labels,
                          const char* save_path,
                          bool is_save_color,
                          bool is_save_layer,
                          double dpi,
                          double alpha)
{
    
    bool ret = true;
    
    try {
        if (imgs.count != labels.count) return false;
        
        std::list<Magick::Image> images;
        
        if (imgs.count == 1) {
            NSData* data = imgs[0];
            Magick::Blob img_blob(data.bytes, data.length);
            Magick::Image img;
            img.read(img_blob);
            convertToMakePSD(img, dpi, is_save_color);
            img.label([labels[0] UTF8String]);
            img.write(save_path);
        }
        else {
            for (int i = 0; i < imgs.count; i++) {
                NSData *img_data = imgs[i];
                NSString *img_label = labels[i];
                Magick::Image img;
                
                if (is_save_layer) {
                    Magick::Blob img_blob(img_data.bytes, img_data.length);
                    img.read(img_blob);
                    convertToMakePSD(img, dpi, is_save_color);
                    
                    if ([img_label compare:@"Result"] == NSOrderedSame) {
                        Magick::Color transColor;
                        img.evaluate(Magick::AlphaChannel, Magick::MultiplyEvaluateOperator, alpha);
                        img.classType(Magick::DirectClass);
                        img.compose(Magick::OverCompositeOp);
                        img.label([img_label UTF8String]);
                        images.push_back(img);
                    }
                    else if ([img_label compare:@"THUMBNAIL"] == NSOrderedSame) {
                        img.classType(Magick::DirectClass);
                        img.compose(Magick::OverCompositeOp);
                        img.label([img_label UTF8String]);
                        images.push_front(img);
                    }
                    else if ([img_label compare:@"OrgDiff"] == NSOrderedSame) {
                        Magick::Color transColor;
                        img.evaluate(Magick::AlphaChannel, Magick::MultiplyEvaluateOperator, alpha / 2.0);
                        img.classType(Magick::DirectClass);
                        img.compose(Magick::OverCompositeOp);
                        img.label([img_label UTF8String]);
                        images.push_back(img);
                    }
                    else {
                        img.classType(Magick::DirectClass);
                        img.compose(Magick::OverCompositeOp);
                        img.label([img_label UTF8String]);
                        images.push_back(img);
                    }
                }
            }
            
            Magick::writeImages(images.begin(), images.end(), save_path);
        }
    }
    catch( Magick::Exception &error)
    {
        std::cerr << "Caught exception : " << error.what() << std::endl;
        ret = false;
    }
    return ret;
}

NSData* MagickFuncs::readPSD(const char* img_path)
{
    Magick::Image srcImg;
    NSData* ret = nil;
    try {
        srcImg.read(img_path);
        Magick::Blob buf;
        srcImg.magick("TIFF");
        srcImg.write(&buf);
        
        ret = [NSData dataWithBytes:buf.data() length:buf.length()];
        
    }catch( Magick::Exception &error_ ){
        std::cout << "Caught exception: " << error_.what() << std::endl;
    }
    return ret;
}

NSArray* MagickFuncs::getLayeredPSD(const char* img_path)
{
    NSMutableArray *arImages = [NSMutableArray array];
    try {
        std::list<Magick::Image> images;
        Magick::readImages( &images, img_path );
        for (auto it = images.begin(); it != images.end(); ++it) {
            Magick::Blob buf;
            it->magick("TIFF");
            it->write(&buf);
            
            NSData *lay = [NSData dataWithBytes:buf.data() length:buf.length()];
            [arImages addObject:lay];
        }
    }catch( Magick::Exception &error_ ){
        std::cout << "Caught exception: " << error_.what() << std::endl;
    }
    return [arImages copy];
}

bool MagickFuncs::makeGIF(NSArray* imgs, NSString* savePath, unsigned int delay)
{
    std::vector<Magick::Image> makeImages;
    if (!imgs) {
        return NO;
    }
    if (imgs.count == 0) {
        return NO;
    }
    
    BOOL ret = YES;
    BOOL isPathName = [imgs[0] isKindOfClass:[NSString class]];
    BOOL isImage = [imgs[0] isKindOfClass:[NSImage class]];
    BOOL isData = [imgs[0] isKindOfClass:[NSData class]];
    
    try {
        int isTop = 0;
        if (isPathName) {
            for (NSString* path in imgs) {
                Magick::Image im;
                im.read(path.UTF8String);
                if (isTop == 0)
                    im.animationDelay(delay * 2);
                else
                    im.animationDelay(delay);
                im.animationIterations(0);
                makeImages.push_back(im);
                isTop++;
            }
        }
        else if (isImage) {
            for (NSImage* nsimage in imgs) {
                NSData *imData = [nsimage TIFFRepresentation];
                Magick::Blob blob(imData.bytes, imData.length);
                Magick::Image im;
                im.read(blob);
                if (isTop == 0)
                    im.animationDelay(delay * 2);
                else
                    im.animationDelay(delay);
                im.animationIterations(0);
                makeImages.push_back(im);
                isTop++;
            }
            
        }
        else if (isData) {
            for (NSData* data in imgs) {
                Magick::Blob blob(data.bytes, data.length);
                Magick::Image im;
                im.read(blob);
                if (isTop == 0)
                    im.animationDelay(delay * 2);
                else
                    im.animationDelay(delay);
                im.animationIterations(0);
                makeImages.push_back(im);
                isTop++;
            }
        }
        else {
            Log(@"Invalod Images");
            return NO;
        }
        
        Magick::writeImages(makeImages.begin(), makeImages.end(), savePath.UTF8String);
    }
    catch( Magick::Exception &error)
    {
        std::cerr << "Caught exception : " << error.what() << std::endl;
        ret = false;
    }
    
    
    
    /*NSMutableData *gif89Data = [NSMutableData dataWithContentsOfFile:savePath];
    char gif89 = '9';
    [gif89Data replaceBytesInRange:NSMakeRange(4, 1) withBytes:&gif89];
    
    [gif89Data writeToFile:savePath atomically:YES];*/
    return YES;

}
