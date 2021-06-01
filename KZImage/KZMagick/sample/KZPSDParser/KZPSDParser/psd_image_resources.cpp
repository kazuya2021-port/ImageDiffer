//
//  psd_image_resources.cpp
//  KZPSDParser
//
//  Created by uchiyama_Macmini on 2019/08/13.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//
#include <sstream>
#include "psd_image_resources.hpp"

bool psd::ImageResources::load(FILE *psd_file)
{
    be<uint32_t> length;
    std::vector<ImageResourceBlock> blocks;
    
    if (!read_file<be<uint32_t>>(psd_file, &length)) {
        std::cerr << "image resource length read error" << std::endl;
    }
    
#ifdef DEBUG
    std::cout << "Image Resource Block length: " << length << std::endl;
#endif
    auto start_pos = ftell(psd_file);
    
    while(ftell(psd_file) - start_pos < length) {
        ImageResourceBlock b;
        if (!b.read(psd_file)) {
            std::cerr << "Cannot read ImageResourceBlock" << std::endl;
            return false;
        }
        blocks.push_back(std::move(b));
    }
    return true;
}

#pragma mark -
#pragma mark ImageResourceBlock

psd::ImageResourceBlock::~ImageResourceBlock()
{
    //if (resource) delete resource;
}

bool psd::ImageResourceBlock::read(FILE* psd_file)
{
    if (feof(psd_file)) {
        std::cerr << "ImageResourceBlock : end of file!!" << std::endl;
        return false;
    }
    
    if (!read_file<Signature>(psd_file, &signature)) {
        std::cerr << "ImageResourceBlock : signature read error: " << std::endl;
    }
    if (signature != "8BIM") {
        std::cout << "Invalid image resource block signature: " << std::string((char*)&signature, (char*)&signature+4) << std::endl;
        return false;
    }
    
    if (!read_file<be<uint16_t>>(psd_file, &image_resource_id)) {
        std::cerr << "ImageResourceBlock : resource id read error: " << std::endl;
        return false;
    }
    
    // データ名:先頭1バイトが長さ、以降ASCII文字
    uint8_t length;
    if (!read_file<uint8_t>(psd_file, &length)) {
        std::cerr << "ImageResourceBlock : name length read error: " << std::endl;
        return false;
    }
    
    if (length == 0x00) {
        fseek(psd_file, 1, SEEK_CUR);
    }
    else {
        name.resize(length);
        
        if (!read_file<std::string>(psd_file, &name)) {
            std::cerr << "ImageResourceBlock : name read error: " << std::endl;
            return false;
        }
    }
    
    be<uint32_t> buffer_length;
    if (!read_file<be<uint32_t>>(psd_file, &buffer_length)) {
        std::cerr << "ImageResourceBlock : data size read error: " << std::endl;
        return false;
    }
    
    buffer.resize(buffer_length);
    
    size_t ret = fread(&buffer[0], 1, buffer.size(), psd_file);
    if (ret==0) {
        std::cerr << "ImageResourceBlock : data read error: " << std::endl;
        return false;
    }
    if (buffer_length % 2 == 1)
        fseek(psd_file, 1, SEEK_CUR);
    
    switch (image_resource_id) {
/*
        case PS2_INFO:
            std::cout << "(PS2.0)Contains five 2-byte values: number of channels, rows, columns, depth, and mode" << std::endl;
            break;
            
        case MAC_PRINT_INFO:
            std::cout << "Macintosh print manager print info record" << std::endl;
            break;
            
        case MAC_PAGE_INFO:
            std::cout << "Macintosh page format information" << std::endl;
            break;
            
        case PS2_COLOR_TABLE:
            std::cout << "(PS2.0)Indexed color table" << std::endl;
            break;
*/
        case RESN_INFO:
            resource = new ResolutionInfo();
            resource->interpretBlock(buffer);
            std::cout << resource->description() << std::endl;
            break;
/*
        case ALPHA_NAMES:
            std::cout << "Names of the alpha channels" << std::endl;
            break;
            
        case PRINT_FLAGS:
            std::cout << "Print flags. A series of one-byte boolean values" << std::endl;
            break;
            
        case COLOR_HALFTONE:
            std::cout << "Color halftoning information" << std::endl;
            break;
            
        case COLOR_XFER:
            std::cout << "Color transfer functions" << std::endl;
            break;
            
        case LAYER_STATE:
            std::cout << "Layer state info. 2 bytes containing the index of target layer (0 = bottom layer)." << std::endl;
            break;
            
        case LAYER_GROUP:
            std::cout << "Layers group information. 2 bytes per layer containing a group ID for the dragging groups. Layers in a group have the same group ID." << std::endl;
            break;
            
        case GRID_GUIDE:
            std::cout << "Grid and guides information" << std::endl;
            break;
            
        case THUMB_RES2:
            std::cout << "Thumbnail resource (supersedes resource 1033)" << std::endl;
            break;
            
        case GLOBAL_ANGLE:
            std::cout << "Global angle" << std::endl;
            break;
            
        case ICC_UNTAGGED:
            std::cout << "ICC Untagged Profile. 1 byte that disables any assumed profile handling when opening the file. 1 = intentionally untagged." << std::endl;
            break;
            
        case DOC_IDS:
            std::cout << "Document-specific IDs seed number. 4 bytes: Base value, starting at which layer IDs will be generated (or a greater value if existing IDs already exceed it). Its purpose is to avoid the case where we add layers, flatten, save, open, and then add more layers that end up with the same IDs as the first set." << std::endl;
            break;
            
        case GLOBAL_ALT:
            std::cout << "Global altitude" << std::endl;
            break;
            
        case SLICES:
            std::cout << "Slices" << std::endl;
            break;
            
        case URL_LIST_UNI:
            std::cout << "URL List. 4 byte count of URLs, followed by 4 byte long, 4 byte ID, and Unicode string for each count." << std::endl;
            break;
            
        case VERSION_INFO:
            std::cout << "Version Info. 4 bytes version, 1 byte hasRealMergedData , Unicode string: writer name, Unicode string: reader name, 4 bytes file version." << std::endl;
            break;
            
        case EXIF_DATA:
            std::cout << "EXIF data 1" << std::endl;
            break;
*/
        case XMP_DATA:
            resource = new XMPInfo();
            resource->interpretBlock(buffer);
            //std::cout << resource->description() << std::endl;
            break;
/*
        case CAPTION_DIGEST:
            std::cout << "Caption digest" << std::endl;
            break;
            
        case PRINT_SCALE:
            std::cout << "Print scale. 2 bytes style (0 = centered, 1 = size to fit, 2 = user defined). 4 bytes x location (floating point). 4 bytes y location (floating point). 4 bytes scale (floating point)" << std::endl;
            break;
            
        case PIXEL_ASPECT_RATION:
            std::cout << "Pixel Aspect Ratio. 4 bytes (version = 1 or 2), 8 bytes double, x / y of a pixel. Version 2, attempting to correct values for NTSC and PAL, previously off by a factor of approx. 5%." << std::endl;
            break;
            
        case LAYER_SELECTION_ID:
            std::cout << "Layer Selection ID(s). 2 bytes count, following is repeated for each count: 4 bytes layer ID" << std::endl;
            break;
            
        case LAYER_GROUP_ENABLED_ID:
            std::cout << "Layer Group(s) Enabled ID. 1 byte for each layer in the document, repeated by length of the resource. NOTE: Layer groups have start and end markers" << std::endl;
            break;
            
        case CS5_PRINT_INFO:
            std::cout << "Print Information. 4 bytes (descriptor version = 16), Descriptor (see See Descriptor structure) Information about the current print settings in the document. The color management options." << std::endl;
            break;
            
        case CS5_PRINT_STYLE:
            std::cout << "Print Style. 4 bytes (descriptor version = 16), Descriptor (see See Descriptor structure) Information about the current print style in the document. The printing marks, labels, ornaments, etc." << std::endl;
            break;
            
        case PRINT_FLAGS_2:
            std::cout << "Print flags information. 2 bytes version ( = 1), 1 byte center crop marks, 1 byte ( = 0), 4 bytes bleed width value, 2 bytes bleed width scale." << std::endl;
            break;
*/
        default:
            break;
    }
    
    return true;
}

std::string psd::ResolutionInfo::description()
{
    std::stringstream ss;
    ss <<
    "hRes: " << this->hRes << ((this->hResUnit == 1)? " pixel/inchi" : " pixel/cm") << std::endl <<
    "WidthUnit: " << ((this->WidthUnit == PSD_UNIT_INCH)? "inchi" :
                      (this->WidthUnit == PSD_UNIT_CM)? "cm" :
                      (this->WidthUnit == PSD_UNIT_POINT)? "point" :
                      (this->WidthUnit == PSD_UNIT_PICA)? "pica" : "column") << std::endl <<
    "vRes: " << this->vRes << ((this->vResUnit == 1)? " pixel/inchi" : " pixel/cm") << std::endl <<
    "HeightUnit: " << ((this->HeightUnit == PSD_UNIT_INCH)? "inchi" :
                      (this->HeightUnit == PSD_UNIT_CM)? "cm" :
                      (this->HeightUnit == PSD_UNIT_POINT)? "point" :
                       (this->HeightUnit == PSD_UNIT_PICA)? "pica" : "column") << std::endl;

    return ss.str();
}
