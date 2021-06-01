//
//  MagickFuncs.h
//  KZImage
//
//  Created by 内山和也 on 2019/04/18.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#ifndef __KZImage__imageMagick__
#define __KZImage__imageMagick__

#import <Foundation/Foundation.h>
#import <KZLibs.h>

class MagickFuncs
{
public:
    MagickFuncs();
    ~MagickFuncs();
    void initMagick(NSString* app_path, void* delegate);
    void stopMagick();
    
    bool makePSD(const char* comp,
                 const char* diff,
                 const char* src,
                 const char* trg,
                 const char* save_path,
                 bool is_save_color,
                 bool is_save_layer,
                 double dpi,
                 double alpha);
    
    bool makePSD(NSData* comp, NSData* diff, NSData* src, NSData* trg,
                 const char* save_path,
                 bool is_save_color,
                 bool is_save_layer,
                 double dpi,
                 double alpha);
    
    bool makePSD(NSArray* imgs,
                 NSArray* labels,
                 const char* save_path,
                 bool is_save_color,
                 bool is_save_layer,
                 double dpi,
                 double alpha);
    
    bool makeGIF(NSArray* imgs, NSString* savePath, unsigned int delay);
    
    NSArray* getLayeredPSD(const char* img_path);

    NSData* readPSD(const char* img_path);
private:
    void* _delegate;
};
#endif
