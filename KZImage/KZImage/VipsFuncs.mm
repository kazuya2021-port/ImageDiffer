//
//  VipsFuncs.m
//  KZImage
//
//  Created by uchiyama_Macmini on 2019/03/22.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "VipsFuncs.h"
#import "MagickFuncs.h"
#import "KZImage.h"

using namespace vips;

#define NUM_IN_PARALLEL (1)
#define PRINT_MEMORY(prefix) printf(#prefix ":%u, %u, %i, %i\n", static_cast<unsigned int>(vips_tracked_get_mem_highwater()), static_cast<unsigned int>(vips_tracked_get_mem()), vips_tracked_get_allocs(), vips_tracked_get_files());


typedef struct _WorkInfo {
    FILE *src_data;
    NSData *src_data_D;
    const char *src_path;
    NSData *trg_data;
    const char *trg_path;
    uint at_page;
    uint to_page;
    KZFileFormat src_format;
    KZFileFormat trg_format;
    KZColorSpace trg_color;
    double trg_dpi;
    bool is_resample;
    double trim_size;
    
    bool is_adjust;
    int trg_width;
    int trg_height;
    
    double pdf_scale;
    
    int num_channels;
    //std::map<VipsInterpretation, std::string> profile_map;
} WorkInfo;

typedef struct _CropInfo {
    void *delegateObj;
    FILE *src_data;
    const char *trg_path;
    NSArray *arNames;
    bool isTrim;
    
    NSArray *crops;
    float x;
    float y;
    float width;
    float height;
    float ratio;
} CropInfo;

typedef struct _RetBuf {
    const void *data;
    size_t length;
    _RetBuf(){
        this->data = nullptr;
        this->length = 0;
    }
    
    void setBuf(const void* buf, size_t len) {
        this->data = malloc(len);
        this->length = len;
        memmove((void*)this->data, buf, len);
    };
    
    void freeBuf() {
        free((void *)this->data);
    }
    
    int w,h,ch;
    VipsInterpretation space;
    VipsBandFormat depth;
    float res;
    bool is_alpha;
} RetBuf;

typedef struct _RetBufArray {
    NSMutableArray *data_array;
    
    _RetBufArray(){
        this->data_array = [NSMutableArray array];
    }
    
    void addBuf(const void* buf, size_t len) {
        const void *data = malloc(len);
        size_t length = len;
        memmove((void*)data, buf, len);
        NSData *d = [[NSData alloc] initWithBytes:data length:length];
        [this->data_array addObject:d];
        free((void *)data);
    };
    
    int w,h,ch;
    VipsInterpretation space;
    VipsBandFormat depth;
    float res;
    bool is_alpha;
} RetBufArray;

GMutex allocation_lock;
GCond cond;
std::vector<GThread*> workers;
int n_calls = 0;

bool checkImage(VImage img);
bool hasProfile(VImage img);
float getInchFormat(KZFileFormat format);

#pragma mark -
#pragma mark Initialize

VipsFuncs::VipsFuncs()
{
    _is_running = false;
//    magick = new MagickFuncs();
}

VipsFuncs::~VipsFuncs()
{
}

#pragma mark -
#pragma mark Accesser

void VipsFuncs::setPdfScale(double val)
{
    g_mutex_lock(&allocation_lock);
        _pdf_scale = val;
    g_mutex_unlock(&allocation_lock);
}


#pragma mark -
#pragma mark Local Funcs



#pragma mark -
#pragma mark Convert Work
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
//    std::cout << "width = " << img.width() << std::endl;
//    std::cout << "height = " << img.height() << std::endl;
//    std::cout << "xres = " << img.xres() << std::endl;
    
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

std::string get_profilepath(VipsInterpretation space)
{
    std::string ret;
    
    switch (space) {
        case VIPS_INTERPRETATION_sRGB:
            ret = "/System/Library/ColorSync/Profiles/sRGB Profile.icc";
            break;
        case VIPS_INTERPRETATION_CMYK:
            ret = "/System/Library/ColorSync/Profiles/Generic CMYK Profile.icc";
            break;
        case VIPS_INTERPRETATION_LAB:
            ret = "/System/Library/ColorSync/Profiles/Generic Lab Profile.icc";
            break;
        case VIPS_INTERPRETATION_RGB:
            ret = "/System/Library/ColorSync/Profiles/Generic RGB Profile.icc";
            break;
        case VIPS_INTERPRETATION_XYZ:
            ret = "/System/Library/ColorSync/Profiles/Generic XYZ Profile.icc";
            break;
        case VIPS_INTERPRETATION_B_W:
            ret = "/System/Library/ColorSync/Profiles/Generic Gray Gamma 2.2 Profile.icc";
            break;
        default:
            break;
    }
    
    return ret;
}

VipsInterpretation get_interpretation(KZColorSpace color)
{
    VipsInterpretation space = VIPS_INTERPRETATION_ERROR;
    
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

KZColorSpace get_color_from_interpretation(VipsInterpretation color)
{
    KZColorSpace space = KZColorSpace::SRC;
    
    switch (color) {
        case VIPS_INTERPRETATION_B_W:
            space = KZColorSpace::GRAY;
            break;
            
        case VIPS_INTERPRETATION_RGB:
        case VIPS_INTERPRETATION_sRGB:
            space = KZColorSpace::SRGB;
            break;
            
        case VIPS_INTERPRETATION_CMYK:
            space = KZColorSpace::CMYK;
            break;
            
        default:
            break;
    }
    return space;
}

static VImage openImage(WorkInfo *info)
{
    VImage out;
    try {
        PRINT_MEMORY("open start")
        
        if ((info->src_path == NULL) || !strcmp(info->src_path, "")) {
            // read from buffer
            size_t length;
            if (info->src_data != NULL) {
                char *buffer;
                if (fseek(info->src_data, 0, SEEK_END) != 0) {
                    throw "error file seek";
                }
                length = ftell(info->src_data);
                if (fseek(info->src_data, 0L, SEEK_SET) != 0) {
                    throw "error file seek";
                }
                buffer = (char*)malloc(length);
                
                if (buffer == NULL) {
                    throw "error malloc memory";
                }
                if (fread(buffer, sizeof(char), length, info->src_data) < length) {
                    throw "error read file";
                }
                NSData *d = [NSData dataWithBytes:buffer length:length];
                info->src_data_D = d;
                free(buffer);
            }
            if (info->src_data_D != NULL) {
                length = info->src_data_D.length;
            }
            
            
            if (info->src_format == KZFileFormat::PSD_FORMAT) {
                // KZMagick
            }
            else if (info->src_format == KZFileFormat::RAW_FORMAT) {
                out = VImage::new_from_memory((void*)info->src_data_D.bytes, length, info->trg_width, info->trg_height, info->num_channels, VIPS_FORMAT_UCHAR);
            }
            else if (info->src_format == KZFileFormat::PDF_FORMAT || info->src_format == KZFileFormat::EPS_FORMAT) {
                out = VImage::new_from_buffer((void*)info->src_data_D.bytes, length, "",
                                              VImage::option()->
                                              set("page", (int)info->at_page)->
                                              set("n", 1)->
                                              set("dpi", 72.0)->
                                              set("scale", info->pdf_scale)->
                                              set("memory", true));
            }
            else {
                out = VImage::new_from_buffer((void*)info->src_data_D.bytes, length, "");
            }
            
        }
        else {
            if (info->src_format == KZFileFormat::PSD_FORMAT) {
                // KZMagickのreadを実装？
            }
            else if (info->src_format != KZFileFormat::PDF_FORMAT && info->src_format != KZFileFormat::TIFF_FORMAT) {
                out = VImage::new_from_file(info->src_path, VImage::option()->set ("access", VIPS_ACCESS_SEQUENTIAL));
            }
            else if (info->src_format == KZFileFormat::TIFF_FORMAT) {
                out = VImage::new_from_file(info->src_path, VImage::option()->set ("access", VIPS_ACCESS_SEQUENTIAL));
            }
            else if (info->src_format == KZFileFormat::PDF_FORMAT || info->src_format == KZFileFormat::EPS_FORMAT) {
                
                out = VImage::pdfload(info->src_path,
                                      VImage::option()->
                                      set("page", (int)info->at_page)->
                                      set("n", 1)->
                                      set("dpi", 72.0)->
                                      set("scale", info->pdf_scale)->
                                      set("memory", true));
            }
        }

    }
    catch (VError &er) {
        std::cerr << "open image error : " << er.what() << std::endl;
        [NSException raise:@"open error" format:@"%s",er.what()];
        return out;
    }
    
    return out;
}

static VImage resize_process(VImage img, WorkInfo *info)
{
    VImage out;
    VImage tmp_img;
    try {
        
        if (info->is_adjust) {
            int org_w = img.width();
            int org_h = img.height();
            int w = info->trg_width;
            int h = info->trg_height;
            double xfac = 0;
            double yfac = 0;
            if (w == 0 && h != 0) {
                yfac = (double)org_h / (double)h;
                tmp_img = img.reduce(yfac, yfac);
            }
            else if (w != 0 && h == 0) {
                xfac = (double)org_w / (double)w;
                tmp_img = img.reduce(xfac, xfac);
            }
            else {
                xfac = (double)org_w / (double)w;
                yfac = (double)org_h / (double)h;
                tmp_img = img.reduce(xfac, yfac);
            }
        }
        else {
            tmp_img = img;
        }
        
        double resolution = 0;
        double trg_dpi = info->trg_dpi;
        if (info->src_format == KZFileFormat::GIF_FORMAT ||
            info->src_format == KZFileFormat::PDF_FORMAT) {
            resolution = 72;
        }
        else {
            resolution = vips_image_get_xres(tmp_img.get_image());
            resolution = round(resolution * 25.4);
        }
        
        double scaleFactor =  trg_dpi / resolution;
        resolution = vips_image_get_xres(tmp_img.get_image()) * scaleFactor;//trg_dpi / getInchFormat(info->trg_format);
        if (info->is_resample) {
            VImage tmp;
            tmp = tmp_img.resize(scaleFactor);
            out = tmp.copy(VImage::option()->
                           set("xres", resolution)->
                           set("yres", resolution));
        }
        else {
            
            // xres/yres in pixels/mm
            // set_res(11.81, 11.81, "in") means 300 dpi
            out = tmp_img.copy(VImage::option()->
                           set("xres", resolution)->
                           set("yres", resolution));
        }
        
        if (out.get_image() == NULL) {
            std::cerr << "no image error : VipsFuncs::resize_process()" << std::endl;
            return out;
        }
    }
    catch (VError &er) {
        std::cerr << "resize error : " << er.what() << std::endl;
        return out;
    }
    
    return out;
}

static VImage change_color_process(VImage img, WorkInfo *info)
{
    VImage out;
    VipsInterpretation space = get_interpretation(info->trg_color);
    
    if (info->trg_color == KZColorSpace::SRC) {
        return img;
    }
    else {
        if (hasProfile(img)) {
            try {
                out = img.icc_transform(get_profilepath(space).c_str(), VImage::option()->
                                        set("embedded", TRUE)->
                                        set("intent", VIPS_INTENT_PERCEPTUAL));
                
            }
            catch (VError &er) {
                std::cerr << "change color error : " << er.what() << std::endl;
                return out;
            }
        }
        else {
            try {
                out = img.colourspace(space);
            }
            catch (VError &er) {
                std::cerr << "change color error : " << er.what() << std::endl;
                return out;
            }
        }
    }
    
    
    if (out.get_image() == NULL) {
        std::cerr << "no image error : VipsFuncs::change_color_process()" << std::endl;
        return out;
    }
    
    return out;
}

static VImage trim_image(VImage img, WorkInfo *info, const char* unit)
{
    VImage out;
    
    if (!strcmp(unit, "mm")) {
        float one_point_mm = 25.4 / 72; // mm
        info->trim_size = round((info->trim_size * (1 / one_point_mm)) * info->pdf_scale);
    }
    if (info->trim_size > 0) {
        try {
            out = img.crop(info->trim_size,
                           info->trim_size,
                           img.width() - (info->trim_size * 2),
                           img.height() - (info->trim_size * 2));
        }
        catch (VError &er) {
            std::cerr << "trim error : " << er.what() << std::endl;
            return out;
        }
    }
    return out;
}

static VImage convertMainProcess(VImage img, WorkInfo *info)
{
    VImage out;
    VImage resized, colored;
    if (!checkImage(img)) {
        [NSException raise:@"empty image error" format:@"image is empty size"];
        return out;
    }
    
    resized = resize_process(img, info);
    if (!checkImage(resized)) {
        [NSException raise:@"empty image error" format:@"resized is empty size"];
        return resized;
    }
    
    colored = change_color_process(resized, info);
    if (!checkImage(colored)) {
        [NSException raise:@"empty image error" format:@"colored is empty size"];
        return colored;
    }

//    PRINT_MEMORY("colored")
    
    if (info->trim_size != 0){
        std::string trim_unit("mm");
        if (info->src_format != KZFileFormat::PDF_FORMAT) {
            trim_unit = "pixel";
        }
        out = trim_image(colored, info, trim_unit.c_str());
        if (out.get_image() == NULL) {
            [NSException raise:@"trim image error" format:@"VipsFuncs::trim_image()"];
            return out;
        }
    }
    else {
        out = colored.copy();
    }
    
    return out;
}

static bool saveFileProcess(VImage img, WorkInfo *info)
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
                
                img.jpegsave((char*)info->trg_path, VImage::option()->
                             set("interlace", false)->
                             set("Q", 90)->
                             set("profile", get_profilepath(space).c_str()));
                break;
            case KZFileFormat::GIF_FORMAT:
                break;
            case KZFileFormat::PSD_FORMAT:
                break;
            case KZFileFormat::PDF_FORMAT:
                break;
            case KZFileFormat::RAW_FORMAT:
                return false;
                break;
            case KZFileFormat::EPS_FORMAT:
                return false;
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

static VipsBlob* saveBufferProcess(VImage img, WorkInfo *info)
{
    PRINT_MEMORY("save start")
    VipsBlob *buf_img = nullptr;
    VipsInterpretation space = get_interpretation(info->trg_color);
    
    try {
        switch (info->trg_format) {
            case KZFileFormat::TIFF_FORMAT:
                PRINT_MEMORY("tiff save start")
                buf_img = img.tiffsave_buffer(VImage::option()->
                                              set("compression", VIPS_FOREIGN_TIFF_COMPRESSION_PACKBITS)->
                                              set("predictor", VIPS_FOREIGN_TIFF_PREDICTOR_HORIZONTAL)->
                                              set("resunit", VIPS_FOREIGN_TIFF_RESUNIT_INCH)->
                                              set("xres", img.xres())->
                                              set("yres", img.yres()));
                PRINT_MEMORY("tiff save end")
                break;
                
            case KZFileFormat::PNG_FORMAT:
                buf_img = img.pngsave_buffer();
                break;
                
            case KZFileFormat::JPG_FORMAT:
                vips_image_set_string(img.get_image(), "exif-ifd2-ColorSpace", "1"); // exif-srgb
                buf_img = img.jpegsave_buffer(VImage::option()->
                                              set("interlace", false)->
                                              set("Q", 90)->
                                              set("profile", get_profilepath(space).c_str()));
                break;
                
            case KZFileFormat::RAW_FORMAT:
                buf_img = vips_blob_copy(img.data(), img.width() * img.height() * img.bands());
                break;
                
            default:
                std::cout << "no save format! from vips" << std::endl;
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

void hex_dmp(const void *buf, int size)
{
    int i,j;
    unsigned char *p = (unsigned char *)buf, tmp[20];
    
    printf("+0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F|  -- ASCII --\r\n");
    printf("--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+----------------\r\n");
    for (i=0; p-(unsigned char *)buf<size; i++) {
        for (j=0; j<16; j++) {
            tmp[j] = (unsigned char)((*p<0x20||*p>=0x7f)? '.': *p);
            printf("%02X ", (int)*p);
            if (++p-(unsigned char *)buf>=size) {
                tmp[++j] = '\0';
                for (;j<16;j++) {
                    printf("   ");
                }
                break;
            }
        }
        tmp[16] = '\0';
        printf("%s\r\n", tmp);
        if (p-(unsigned char *)buf>=size) {
            break;
        }
    }
}


static RetBuf* processImage (WorkInfo *info)
{
    //PRINT_MEMORY("start")
    RetBuf* retData = new RetBuf();
    VImage img;
    img = openImage(info);
    checkImage(img);
    retData->w = img.width();
    retData->h = img.height();
    retData->ch = img.bands();
    retData->space = img.interpretation();
    retData->depth = img.format();
    retData->res = (float)img.xres() * 25.4;
    retData->is_alpha = img.has_alpha();
    if (!retData->is_alpha) {
        VipsImage *added;
        vips_addalpha(img.get_image(), &added, (void *) NULL);
        VImage al(added);
        retData->is_alpha = al.has_alpha();
        retData->ch = al.bands();
        img = al;
    }
    
    VImage edited;
    edited = convertMainProcess(img, info);
    
    
    
    if ((info->trg_path == NULL) || !strcmp(info->trg_path, "")) {
        VipsBlob* buf = saveBufferProcess(edited, info);

        retData->setBuf((const void *)buf->area.data, buf->area.length);

        vips_area_unref( VIPS_AREA( buf ) );
        return retData;
    }
    else {
        saveFileProcess(edited, info);
        return retData;
    }
    
    return nullptr;
}

static void* worker(void *data)
{
    WorkInfo *info = (WorkInfo*)data;
    
    g_mutex_lock (&allocation_lock);
    
    //PRINT_MEMORY("start process")
    void *ret = processImage(info);
    
    if (ret == nullptr) {
        std::cout << "convert error! from vips" << std::endl;
        vips_error_exit (NULL);
    }
    
    //PRINT_MEMORY("end process")
    g_mutex_unlock (&allocation_lock);
    
    return (ret);
}


#pragma mark -
#pragma mark Crop Work

static RetBuf* processCrop(CropInfo *info)
{
    RetBuf* retData = new RetBuf();
    VImage img;
    char *buffer;
    if (fseek(info->src_data, 0, SEEK_END) != 0) {
        throw "error file seek";
    }
    size_t length = ftell(info->src_data);
    if (fseek(info->src_data, 0L, SEEK_SET) != 0) {
        throw "error file seek";
    }
    buffer = (char*)malloc(length);
    
    if (buffer == NULL) {
        throw "error malloc memory";
    }
    if (fread(buffer, sizeof(char), length, info->src_data) < length) {
        throw "error read file";
    }
    NSData *d = [NSData dataWithBytes:buffer length:length];
    img = VImage::new_from_buffer((void*)d.bytes, length, "");
    free(buffer);
    
    if (!checkImage(img)) {
        [NSException raise:@"empty image error" format:@"image is empty size"];
        return retData;
    }
    
    if (info->x == 0 && info->y == 0 && info->width == 0 && info->height == 0) {
        
        for (int i = 0; i < info->crops.count; i++) {
            std::string savePath(info->trg_path);
            std::string fileName([[info->arNames objectAtIndex:i] UTF8String]);
            savePath.append("/");
            savePath.append(fileName);
            [(__bridge KZImage*)info->delegateObj cropApageStart:savePath.c_str()];
            
            NSDictionary *infoMen = info->crops[i];
            NSRect theRc = [infoMen[@"rect"] rectValue];
            BOOL isRot = infoMen[@"isRot"] == @YES;
            VImage p;
            p = img.extract_area(theRc.origin.x, theRc.origin.y, theRc.size.width, theRc.size.height);
            VImage out;
            if (isRot) out = p.rot180();
            else out = p;
            PRINT_MEMORY("tiff save start")
            
            
            
            
            out.tiffsave((char*)savePath.c_str(),
                         VImage::option()->
                         set("compression", VIPS_FOREIGN_TIFF_COMPRESSION_LZW)->
                         set("predictor", VIPS_FOREIGN_TIFF_PREDICTOR_NONE)->
                         set("resunit", VIPS_FOREIGN_TIFF_RESUNIT_INCH)->
                         set("xres", img.xres())->
                         set("yres", img.yres())->
                         set("miniswhite", true)->
                         set("squash", true));
            [(__bridge KZImage*)info->delegateObj cropApageDone:savePath.c_str()];
        }
        
        return retData;
    }
    else {
        VImage shrinc = img.resize(info->ratio);
        VImage crpImg = shrinc.extract_area(info->x, info->y, info->width, info->height);
        VipsBlob *buf_img = nullptr;
        PRINT_MEMORY("tiff save start")
        buf_img = crpImg.tiffsave_buffer(VImage::option()->
                                      set("compression", VIPS_FOREIGN_TIFF_COMPRESSION_PACKBITS)->
                                      set("predictor", VIPS_FOREIGN_TIFF_PREDICTOR_HORIZONTAL)->
                                      set("resunit", VIPS_FOREIGN_TIFF_RESUNIT_INCH)->
                                      set("xres", crpImg.xres())->
                                      set("yres", crpImg.yres()));
        PRINT_MEMORY("tiff save end")
        retData->setBuf((const void *)buf_img->area.data, buf_img->area.length);
        
        vips_area_unref( VIPS_AREA( buf_img ) );
        return retData;
    }
    
    
}

static void* cropWorker(void *data)
{
    CropInfo *info = (CropInfo*)data;
    
    g_mutex_lock (&allocation_lock);
    
    //PRINT_MEMORY("start process")
    void *ret = processCrop(info);
    
    //PRINT_MEMORY("end process")
    g_mutex_unlock (&allocation_lock);
    
    return ret;
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
        vips_leak_set(true);
        vips_concurrency_set(vips_concurrency_get());
        vips_cache_set_max(0);
        
        _is_running = true;
    }
    
    if(!_is_running)
    {
        std::cerr << "vips start error" << std::endl;
    }
    
    if (!g_thread_supported()) {
        g_mutex_init(&allocation_lock);
        g_cond_init(&cond);
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

NSData* VipsFuncs::imageConvert(FILE *src_data, const char *src_path, KZFileFormat src_format, uint page,
                             const char *trg_path, KZFileFormat trg_format,
                             KZColorSpace trg_color, double trg_dpi, int width, int height, int num_channels, bool is_adjust, bool is_resample, double trim_size)
{
    WorkInfo *info = new WorkInfo();
    info->src_data = src_data;
    info->src_data_D = NULL;
    info->src_path = src_path;
    info->src_format = src_format;
    info->at_page = page;
    info->trg_data = nil;
    info->trg_path = trg_path;
    info->trg_format = trg_format;
    info->trg_color = trg_color;
    info->trg_dpi = trg_dpi;
    info->is_resample = is_resample;
    info->trim_size = trim_size;
    info->pdf_scale = _pdf_scale;
    info->is_adjust = is_adjust;
    info->trg_width = width;
    info->trg_height = height;
    info->num_channels = num_channels;

//    RetBuf *retbuf = processImage(info);
    GThread *subfunc = vips_g_thread_new("cnv", (GThreadFunc)worker, info);

    RetBuf *retbuf = (RetBuf *)vips_g_thread_join(subfunc);
    
    this->width = retbuf->w;
    this->height = retbuf->h;
    this->bands = retbuf->ch;
    this->space = get_color_from_interpretation(retbuf->space);
    this->depth = (retbuf->depth == 0 || retbuf->depth == 1)? 8 : -1;
    this->res = retbuf->res;
    this->is_alpha = retbuf->is_alpha;
    
    const char *tPath = info->trg_path;
    const char *sPath = info->trg_path;
    delete info;
    
    if (sPath == NULL || !strcmp(sPath, "")) {
        if (tPath == NULL || !strcmp(tPath, "")) {
            NSData *retData = [NSData dataWithBytes:retbuf->data length:retbuf->length];
            retbuf->freeBuf();
            delete retbuf;
            return retData;
        }
        else {
            NSString* path = [NSString stringWithUTF8String:tPath];
            retbuf->freeBuf();
            delete retbuf;
            return [path dataUsingEncoding:NSUTF8StringEncoding];
        }
    }
    else {
        NSData *retData = [NSData dataWithBytes:retbuf->data length:retbuf->length];
        retbuf->freeBuf();
        delete retbuf;
        return retData;
    }
}

NSData* VipsFuncs::imageConvertD(NSData *src_data, const char *src_path, KZFileFormat src_format, uint page,
                                const char *trg_path, KZFileFormat trg_format,
                                KZColorSpace trg_color, double trg_dpi, int width, int height, int num_channels, bool is_adjust, bool is_resample, double trim_size)
{
    WorkInfo *info = new WorkInfo();
    info->src_data = NULL;
    info->src_data_D = src_data;
    info->src_path = src_path;
    info->src_format = src_format;
    info->at_page = page;
    info->trg_data = nil;
    info->trg_path = trg_path;
    info->trg_format = trg_format;
    info->trg_color = trg_color;
    info->trg_dpi = trg_dpi;
    info->is_resample = is_resample;
    info->trim_size = trim_size;
    info->pdf_scale = _pdf_scale;
    info->is_adjust = is_adjust;
    info->trg_width = width;
    info->trg_height = height;
    info->num_channels = num_channels;
    
    //    RetBuf *retbuf = processImage(info);
    GThread *subfunc = vips_g_thread_new("cnv", (GThreadFunc)worker, info);
    
    RetBuf *retbuf = (RetBuf *)vips_g_thread_join(subfunc);
    
    this->width = retbuf->w;
    this->height = retbuf->h;
    this->bands = retbuf->ch;
    this->space = get_color_from_interpretation(retbuf->space);
    this->depth = (retbuf->depth == 0 || retbuf->depth == 1)? 8 : -1;
    this->res = retbuf->res;
    this->is_alpha = retbuf->is_alpha;
    
    const char *tPath = info->trg_path;
    const char *sPath = info->trg_path;
    delete info;
    
    if (sPath == NULL || !strcmp(sPath, "")) {
        if (tPath == NULL || !strcmp(tPath, "")) {
            NSData *retData = [NSData dataWithBytes:retbuf->data length:retbuf->length];
            retbuf->freeBuf();
            delete retbuf;
            return retData;
        }
        else {
            NSString* path = [NSString stringWithUTF8String:tPath];
            retbuf->freeBuf();
            delete retbuf;
            return [path dataUsingEncoding:NSUTF8StringEncoding];
        }
    }
    else {
        NSData *retData = [NSData dataWithBytes:retbuf->data length:retbuf->length];
        retbuf->freeBuf();
        delete retbuf;
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

std::pair<double, double> VipsFuncs::getImageSize(const char *src_path, int dpi)
{
    VImage img = VImage::new_from_file(src_path);
    float w = img.width();
    float h = img.height();
    
    float one_point_mm = 25.4 / dpi; // mm
    double width_mm = w * one_point_mm;
    double height_mm = h * one_point_mm;
    return std::pair<double, double>(width_mm,height_mm);
}

int VipsFuncs::getDPI(const char *src_path)
{
    VImage img = VImage::new_from_file(src_path);
    double resolution = vips_image_get_xres(img.get_image());
    resolution = round(resolution * 25.4);
    return (int)resolution;
}

NSData* VipsFuncs::cropRect(FILE *src_data, float x, float y, float w, float h, float ratio)
{
    CropInfo *c_info = new CropInfo();
    c_info->src_data = src_data;
    c_info->x = x;
    c_info->y = y;
    c_info->width = w;
    c_info->height = h;
    c_info->ratio = ratio;
    GThread *subfunc = vips_g_thread_new("crp", (GThreadFunc)cropWorker, c_info);
    RetBuf *retbuf = (RetBuf *)vips_g_thread_join(subfunc);
    NSData *retData = [NSData dataWithBytes:retbuf->data length:retbuf->length];
    retbuf->freeBuf();
    delete retbuf;
    return retData;
}

void VipsFuncs::cropMentuke(FILE *src_data, NSArray* info, bool isSiagari, const char* savePath, NSArray* arNames, void* sender)
{
    CropInfo *c_info = new CropInfo();
    c_info->src_data = src_data;
    c_info->crops = info;
    c_info->isTrim = isSiagari;
    c_info->arNames = arNames;
    c_info->trg_path = savePath;
    c_info->x = 0;
    c_info->y = 0;
    c_info->width = 0;
    c_info->height = 0;
    c_info->delegateObj = sender;
    GThread *subfunc = vips_g_thread_new("crp", (GThreadFunc)cropWorker, c_info);
    vips_g_thread_join(subfunc);

    return;
}
