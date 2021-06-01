//
//  VipsFuncs.m
//  KZImage
//
//  Created by uchiyama_Macmini on 2019/03/22.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//
#include <libexif/exif-data.h>
#include <libexif/exif-loader.h>

#import "VipsFuncs.h"

using namespace vips;

#define NUM_IN_PARALLEL (1)

typedef struct WorkInfo {
    NSData *src_data;
    NSData *trg_data;
    const char *src_path;
    const char *trg_path;
    uint src_page;
    KZFileFormat src_format;
    KZFileFormat trg_format;
    KZColorSpace trg_color;
    double trg_dpi;
    bool is_resample;
    double trim_size;
    double pdf_scale;
    std::map<VipsInterpretation, std::string> profile_map;
    
    WorkInfo() {
        src_data = nil;
        trg_data = nil;
        src_path = "";
        trg_path = "";
        src_page = 0;
        trg_dpi = 0;
        is_resample = false;
        trim_size = 0;
        pdf_scale = 1;
    };
} WorkInfo;

GMutex allocation_lock;

/*typedef struct ReturnInfo {
    const void* data;
    size_t legth;
    void allocate(const void* buf, size_t size) {
        this->legth = size;
        this->data = (const void*)malloc(size);
        memmove((void*)this->data, buf, size);
    }
    ReturnInfo() {
        data = nullptr;
        legth = 0;
    };
    ~ReturnInfo() {
        if(data != nullptr) {
            free((void *)data);
        }
    };
} ReturnInfo;*/

bool checkImage(VImage img);
bool hasProfile(VImage img);
float getInchFormat(KZFileFormat format);

#pragma mark -
#pragma mark Initialize

VipsFuncs::VipsFuncs()
{
    _is_running = false;
    
    _profile_map.insert(
                      std::pair<VipsInterpretation, std::string>(
                                                            VIPS_INTERPRETATION_sRGB,
                                                            "/System/Library/ColorSync/Profiles/sRGB Profile.icc"));
    _profile_map.insert(
                      std::pair<VipsInterpretation, std::string>(
                                                            VIPS_INTERPRETATION_CMYK,
                                                            "/System/Library/ColorSync/Profiles/Generic CMYK Profile.icc"));
    _profile_map.insert(
                      std::pair<VipsInterpretation, std::string>(
                                                            VIPS_INTERPRETATION_LAB,
                                                            "/System/Library/ColorSync/Profiles/Generic Lab Profile.icc"));
    _profile_map.insert(
                      std::pair<VipsInterpretation, std::string>(
                                                            VIPS_INTERPRETATION_RGB,
                                                            "/System/Library/ColorSync/Profiles/Generic RGB Profile.icc"));
    _profile_map.insert(
                      std::pair<VipsInterpretation, std::string>(
                                                            VIPS_INTERPRETATION_XYZ,
                                                            "/System/Library/ColorSync/Profiles/Generic XYZ Profile.icc"));
    _profile_map.insert(
                      std::pair<VipsInterpretation, std::string>(
                                                            VIPS_INTERPRETATION_B_W,
                                                            "/System/Library/ColorSync/Profiles/Generic Gray Gamma 2.2 Profile.icc"));

}

VipsFuncs::~VipsFuncs()
{
}

#pragma mark -
#pragma mark Accesser

void VipsFuncs::setPdfScale(double val)
{
    _pdf_scale = val;
}


#pragma mark -
#pragma mark Local Funcs
bool deleteSameFiles(const char* fileName)
{
    std::remove(fileName);
    return true;
}

template <typename ... Args>
std::string format(const std::string& fmt, Args ... args)
{
    size_t len = std::snprintf(nullptr, 0, fmt.c_str(), args ...);
    std::vector<char> buf(len + 1);
    std::snprintf(&buf[0], len + 1, fmt.c_str(), args ...);
    return std::string(&buf[0], &buf[0] + len);
}

bool checkImage(VImage img)
{
    if (img.get_image() == NULL) return false;
    if (img.width() == 0) return false;
    if (img.height() == 0) return false;
    if (img.xres() == 0) return false;
    if (img.yres() == 0) return false;
    return true;
}

bool hasProfile(VImage img)
{
    if (!img.get_image()) return false;
    return vips_image_get_typeof(img.get_image(), VIPS_META_ICC_NAME);
}

float getInchFormat(KZFileFormat format)
{
    float ret = 0;
    switch (format) {
        case KZFileFormat::PNG_FORMAT:
        case KZFileFormat::JPG_FORMAT:
            ret = 25.4;
            break;
            
        case KZFileFormat::TIFF_FORMAT:
        case KZFileFormat::PSD_FORMAT:
            ret = 2.54;
            break;
            
        default:
            break;
    }
    return ret;
}

VipsInterpretation get_interpretation(KZColorSpace color)
{
    VipsInterpretation space;
    
    switch (color) {
        case KZColorSpace::GRAY:
            space = VIPS_INTERPRETATION_B_W;
            break;
        case KZColorSpace::SRGB:
            space = VIPS_INTERPRETATION_sRGB;
            break;
        case KZColorSpace::CMYK:
            space = VIPS_INTERPRETATION_CMYK;
            break;
        default:
            break;
    }
    return space;
}

static VImage openImage(WorkInfo *info)
{
    VImage ret_img;
    
    try {
        if (info->src_format != KZFileFormat::PDF_FORMAT && info->src_format != KZFileFormat::TIFF_FORMAT) {
            ret_img = VImage::new_from_file(info->src_path, VImage::option()->set ("access", VIPS_ACCESS_SEQUENTIAL));
        }
        else if (info->src_format == KZFileFormat::TIFF_FORMAT) {
            ret_img = VImage::tiffload((char*)info->src_path);
        }
        else if (info->src_format == KZFileFormat::PDF_FORMAT) {
            ret_img = VImage::pdfload(info->src_path,
                                      VImage::option()->
                                      set("page", (int)info->src_page)->
                                      set("n", 1)->
                                      set("dpi", 72)->
                                      set("scale", info->pdf_scale));
        }
        ret_img.remove(VIPS_META_IPTC_NAME);
    }
    catch (VError &er) {
        std::cerr << "open image error : " << er.what() << std::endl;
        [NSException raise:@"open error" format:@"%s",er.what()];
        return nil;
    }
    
    return ret_img;
}

static bool resize_process(VImage& img, WorkInfo *info)
{
    try {
        double resolution;
        if (info->src_format == KZFileFormat::GIF_FORMAT ||
            info->src_format == KZFileFormat::PDF_FORMAT) {
            resolution = 72;
        }
        else {
            resolution = vips_image_get_xres(img.get_image());
            resolution = round(resolution * getInchFormat(info->src_format));
        }
        
        double scaleFactor =  info->trg_dpi / resolution;
        resolution = info->trg_dpi / getInchFormat(info->trg_format);
        if (info->is_resample) {
            img = img.resize(scaleFactor);
            img = img.copy(VImage::option()->
                                       set("xres", resolution)->
                                       set("yres", resolution));
        }
        else {
            
            // xres/yres in pixels/mm
            // set_res(11.81, 11.81, "in") means 300 dpi
            img = img.copy(VImage::option()->
                                       set("xres", resolution)->
                                       set("yres", resolution));
        }
        
        if (img.get_image() == NULL) {
            std::cerr << "no image error : VipsFuncs::resize_process()" << std::endl;
            return false;
        }
    }
    catch (VError &er) {
        std::cerr << "resize error : " << er.what() << std::endl;
        return false;
    }
    
    return true;
}

static bool change_color_process(VImage& img, WorkInfo *info)
{
    VipsInterpretation space = get_interpretation(info->trg_color);
    
    if(hasProfile(img)) {
        try {
            img = img.icc_transform(
                                    const_cast<char*>(info->profile_map[space].data()), VImage::option()
                                    -> set("embedded", TRUE)
                                    -> set("intent", VIPS_INTENT_PERCEPTUAL));
        }
        catch (VError &er) {
            std::cerr << "change color error : " << er.what() << std::endl;
            return false;
        }
    }
    else {
        if (img.interpretation() == VIPS_INTERPRETATION_CMYK ||
            img.interpretation() == VIPS_INTERPRETATION_B_W ||
            img.interpretation() == VIPS_INTERPRETATION_RGB ||
            img.interpretation() == VIPS_INTERPRETATION_LAB ||
            img.interpretation() == VIPS_INTERPRETATION_sRGB) {
            
            try {
                img = img.icc_transform(
                                        const_cast<char*>(info->profile_map[space].data()), VImage::option()
                                        -> set("input_profile", info->profile_map[img.interpretation()].data())
                                        -> set("intent", VIPS_INTENT_PERCEPTUAL));
            }
            catch (VError &er) {
                std::cerr << "change color error : " << er.what() << std::endl;
                return false;
            }
        }
        else {
            try {
                img = img.colourspace(space);
            }
            catch (VError &er) {
                std::cerr << "change color error : " << er.what() << std::endl;
                return false;
            }
        }
    }
    
    if (img.get_image() == NULL) {
        std::cerr << "no image error : VipsFuncs::change_color_process()" << std::endl;
        return false;
    }
    
    return true;
}

static bool trim_image(VImage img, WorkInfo *info, const char* unit)
{
    if (!strcmp(unit, "mm")) {
        float one_point_mm = 25.4 / 72; // mm
        info->trim_size = round((info->trim_size * (1 / one_point_mm)) * info->pdf_scale);
    }
    if (info->trim_size > 0) {
        try {
            img = img.crop(info->trim_size,
                           info->trim_size,
                           img.width() - (info->trim_size * 2),
                           img.height() - (info->trim_size * 2));
        }
        catch (VError &er) {
            std::cerr << "trim error : " << er.what() << std::endl;
            return false;
        }
    }
    return true;
}

static void convertMainProcess(VImage& img, WorkInfo *info)
{
    if (!checkImage(img)) {
        [NSException raise:@"empty image error" format:@"image is empty size"];
        return;
    }
    
    if (!resize_process(img, info)) {
        [NSException raise:@"resize error" format:@"VipsFuncs::resize_process()"];
        return;
    }
    
    if (!change_color_process(img, info)) {
        [NSException raise:@"change clolor error" format:@"VipsFuncs::change_color_process()"];
        return;
    }
    if (info->trim_size != 0){
        std::string trim_unit("mm");
        if (info->src_format != KZFileFormat::PDF_FORMAT) {
            trim_unit = "pixel";
        }
        if (!trim_image(img, info, trim_unit.c_str())) {
            [NSException raise:@"trim image error" format:@"VipsFuncs::trim_image()"];
            return;
        }
    }
}

static bool saveFileProcess(VImage& img, WorkInfo *info)
{
    bool ret_state = true;
    
    VipsInterpretation space = get_interpretation(info->trg_color);
    
    deleteSameFiles(info->trg_path);
    
    try {
        switch (info->trg_format) {
            case KZFileFormat::TIFF_FORMAT:
                img.tiffsave((char*)info->trg_path,
                             VImage::option()->
                             set("compression", VIPS_FOREIGN_TIFF_COMPRESSION_LZW)->
                             set("predictor", VIPS_FOREIGN_TIFF_PREDICTOR_HORIZONTAL)->
                             set("resunit", VIPS_FOREIGN_TIFF_RESUNIT_INCH)->
                             set("xres", img.xres())->
                             set("yres", img.yres()));
                break;
                
            case KZFileFormat::PNG_FORMAT:
                img.pngsave((char*)info->trg_path);
                break;
                
            case KZFileFormat::JPG_FORMAT:
                vips_image_set_string(img.get_image(), "exif-ifd2-ColorSpace", "1"); // exif-srgb
                
                img.jpegsave((char*)info->trg_path,
                             VImage::option()->
                             set("interlace", false)->
                             set("Q", 90)->
                             set("profile", info->profile_map[space].data()));
                break;
            case KZFileFormat::GIF_FORMAT:
                break;
            case KZFileFormat::PSD_FORMAT:
                break;
            case KZFileFormat::PDF_FORMAT:
                break;
            case KZFileFormat::UNKNOWN_FORMAT:
                break;
        }
    }
    catch (VError &er) {
        std::cerr << "save file error : " << er.what() << std::endl;
        [NSException raise:@"save file error" format:@"%s",er.what()];
        return false;
    }
    return ret_state;
}

static VipsBlob* saveBufferProcess(VImage& img, WorkInfo *info)
{
    VipsBlob *buf_img = nullptr;
    VipsInterpretation space = get_interpretation(info->trg_color);
    
    try {
        switch (info->trg_format) {
            case KZFileFormat::TIFF_FORMAT:
                buf_img = img.tiffsave_buffer(VImage::option()->
                                              set("compression", VIPS_FOREIGN_TIFF_COMPRESSION_LZW)->
                                              set("predictor", VIPS_FOREIGN_TIFF_PREDICTOR_HORIZONTAL)->
                                              set("resunit", VIPS_FOREIGN_TIFF_RESUNIT_INCH)->
                                              set("xres", img.xres())->
                                              set("yres", img.yres()));
                break;
                
            case KZFileFormat::PNG_FORMAT:
                buf_img = img.pngsave_buffer();
                break;
                
            case KZFileFormat::JPG_FORMAT:
                vips_image_set_string(img.get_image(), "exif-ifd2-ColorSpace", "1"); // exif-srgb
                buf_img = img.jpegsave_buffer(VImage::option()->
                                              set("interlace", false)->
                                              set("Q", 90)->
                                              set("profile", info->profile_map[space].data()));
                break;
                
            default:
                buf_img = nullptr;
                break;
        }
    }
    catch (VError &er) {
        std::cerr << "save buffer error : " << er.what() << std::endl;
        [NSException raise:@"save buffer error" format:@"%s",er.what()];
        return nil;
    }
    return buf_img;
}


static int processImage (WorkInfo *info)
{
    VImage img;
    if (info->src_path == NULL) {
        img = VImage::new_from_buffer((void*)info->src_data.bytes, info->src_data.length, "");
    }
    else if (!strcmp(info->src_path, "")) {
        img = VImage::new_from_buffer((void*)info->src_data.bytes, info->src_data.length, "");
    }
    else {
        img = openImage(info);
    }
    
    convertMainProcess(img, info);
    
    if (info->trg_path == NULL) {
        VipsBlob* buf = saveBufferProcess(img,info);
        
        if (buf != nullptr) {
            info->trg_data = [[NSData alloc] initWithBytes:(const void *)buf->area.data length:buf->area.length];
            vips_area_unref( VIPS_AREA( buf ) );
        }
    }
    else if (!strcmp(info->trg_path, "")) {
        VipsBlob* buf = saveBufferProcess(img,info);
        
        if (buf != nullptr) {
            info->trg_data = [[NSData alloc] initWithBytes:(const void *)buf->area.data length:buf->area.length];
            vips_area_unref( VIPS_AREA( buf ) );
        }
    }
    else {
        saveFileProcess(img, info);
    }
    if (img.get_image() == NULL) {
        printf("no image");
    }
    return (0);
}

static void* worker(void *data)
{
    WorkInfo *info = (WorkInfo*)data;

    g_mutex_lock (&allocation_lock);

    if (processImage (info))
        vips_error_exit (NULL);
    g_mutex_unlock (&allocation_lock);
    
    

    
    return (NULL);
}

#pragma mark -
#pragma mark Public Funcs

bool VipsFuncs::startEngine(NSString* app_path, void* delegate)
{
    _delegate = delegate;
    if(!_is_running)
    {
        if (VIPS_INIT([app_path UTF8String]))
        {
            vips_error_exit (NULL);
            _is_running = false;
        }
        //vips_concurrency_set(0);
        //vips_cache_set_max(0);
        _is_running = true;
    }
    
    if(!_is_running)
    {
        std::cerr << "vips start error" << std::endl;
    }
    
    return _is_running;
}

void VipsFuncs::stopEngine(void)
{
    if(_is_running)
    {
        vips_shutdown();
        _is_running = false;
    }
}

NSData* VipsFuncs::imageConvert(NSData *src_data, const char *src_path, KZFileFormat src_format, uint page,
                             NSData *trg_data, const char *trg_path, KZFileFormat trg_format,
                             KZColorSpace trg_color, double trg_dpi, bool is_resample, double trim_size)
{
    WorkInfo *info = new WorkInfo();
    info->src_data = src_data;
    info->src_path = src_path;
    info->src_format = src_format;
    info->src_page = page;
    info->trg_path = trg_path;
    info->trg_format = trg_format;
    info->trg_color = trg_color;
    info->trg_dpi = trg_dpi;
    info->is_resample = is_resample;
    info->trim_size = trim_size;
    info->pdf_scale = _pdf_scale;
    info->profile_map = _profile_map;

    GThread *subfunc = g_thread_new(NULL, (GThreadFunc)worker, info);

    g_mutex_init(&allocation_lock);
    g_thread_join(subfunc);
    
    vips_thread_shutdown();
    if (info->src_path == NULL || !strcmp(info->src_path, "")) {
        NSString* path = [NSString stringWithUTF8String:info->trg_path];
        delete info;
        return [path dataUsingEncoding:NSUTF8StringEncoding];
    }
    else {
        NSData *retData = info->trg_data;
        delete info;
        return retData;
    }
    
}

std::pair<double, double> VipsFuncs::getPdfSize(const char *src_path, uint page)
{
    VImage pdf = VImage::pdfload(src_path,
                                 VImage::option()->
                                 set("page", (int)page)->
                                 set("n", 1)->
                                 set("dpi", 72));
    float w = pdf.width();
    float h = pdf.height();
    
    float one_point_mm = 25.4 / 72; // mm
    double width_mm = w * one_point_mm;
    double height_mm = h * one_point_mm;
    return std::pair<double, double>(width_mm,height_mm);
}

