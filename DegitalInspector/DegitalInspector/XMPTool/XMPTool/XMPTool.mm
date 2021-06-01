//
//  XMPTool.m
//  XMPTool
//
//  Created by 内山和也 on 2019/06/14.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "XMPTool.h"
#import <Foundation/Foundation.h>

#include <stdio.h>
#include <iostream>
#include <fstream>
#include <iterator>
#include <memory>
#include <string>

//#define ENABLE_XMP_CPP_INTERFACE 1

// Must be defined to instantiate template classes
#define TXMP_STRING_TYPE std::string

// Must be defined to give access to XMPFiles
#define XMP_INCLUDE_XMPFILES 1

#define XMPUtilsDomain @"org.kaz.xmptoolkit.mac.XMPToolKitSDK-Sample"

// Ensure XMP templates are instantiated
#include "XMP.incl_cpp"

// Provide access to the API
#include "XMP.hpp"

#include <sstream>
#include <iostream>
#include <fstream>

@implementation XmpSDK

const XMP_StringPtr  kXMP_NS_SDK_EDIT = "http://ns.asahi.com/ctp/Edit/";

+ (bool)initialize:(NSError **)error options:(XMP_OptionBits)options
{
    if (!SXMPMeta::Initialize()) {
        std::cout << "Could not initialize toolkit!";
        *error = [NSError errorWithDomain:XMPUtilsDomain code:-1 userInfo:@{@"message": @"Could not initialize toolkit!"}];
        return false;
    }
    
    if (!SXMPFiles::Initialize(options)) {
        std::cout << "Could not initialize SXMPFiles.";
        *error = [NSError errorWithDomain:XMPUtilsDomain code:-4 userInfo:@{@"message": @"Could not initialize SXMPFiles."}];
        return false;
    }
    return true;
}

+ (NSArray*)getXmp:(SXMPFiles)myFile
{
    NSMutableArray *retAr = [NSMutableArray array];
    SXMPMeta meta;
    myFile.GetXMP(&meta);
    
    std::string schemaNS, propPath, propVal;
    
    SXMPIterator allIter (meta);
    while(allIter.Next(&schemaNS, &propPath, &propVal))
    {
        if (strcmp(propPath.c_str(), "") && strcmp(propVal.c_str(), "")) {
            NSDictionary *dict = @{@"NameSpace" : [NSString stringWithUTF8String:schemaNS.c_str()],
                                   @"Path" : [NSString stringWithUTF8String:propPath.c_str()],
                                   @"Value" : [NSString stringWithUTF8String:propVal.c_str()]};
            
            [retAr addObject:dict];
        }
    }
    
    return [retAr copy];
}

+ (const char *)getDCFormat:(const char*)format
{
    const char* ret;
    if (!strcmp(format, "PDF")) {
        ret = "application/pdf";
    }
    else if (!strcmp(format, "TIFF") || !strcmp(format, "TIF")) {
        ret = "image/tiff";
    }
    else if (!strcmp(format, "JPEG") || !strcmp(format, "JPG")) {
        ret = "image/jpeg";
    }
    else if (!strcmp(format, "GIF")) {
        ret = "image/gif";
    }
    else if (!strcmp(format, "PNG")) {
        ret = "image/png";
    }
    else if (!strcmp(format, "PSD")) {
        ret = "application/vnd.adobe.photoshop";
    }
    else{
        ret = "";
    }
    return ret;
}

+ (NSArray*)getXmpInfo:(NSString*)imgPath error:(NSError **) error
{
    NSArray *retAr = nil;
    
    if (!imgPath || [imgPath compare:@""] == NSOrderedSame) return nil;
    
    if (![self initialize:error options:0]) {
        return nil;
    }
    
    std::string filename(imgPath.UTF8String);
    
    try {
        // Options to open the file with - read only and use a file handler
        XMP_OptionBits opts = kXMPFiles_OpenForRead | kXMPFiles_OpenUseSmartHandler;
        
        bool ok;
        SXMPFiles myFile;
        
        // First we try and open the file
        ok = myFile.OpenFile(filename, kXMP_UnknownFile, opts);
        if( ! ok )
        {
            // Now try using packet scanning
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning;
            ok = myFile.OpenFile(filename, kXMP_UnknownFile, opts);
        }
        
        if (ok) {
            
            retAr = [self getXmp:myFile];
            
        }
        myFile.CloseFile();
    }
    catch(XMP_Error & e) {
        std::cout << "ERROR: " << e.GetErrMsg() << std::endl;
        *error = [NSError errorWithDomain:XMPUtilsDomain code:-3 userInfo:@{@"message": @"read other error"}];
    }
    
    SXMPFiles::Terminate();
    SXMPMeta::Terminate();
    
    return retAr;
}

+ (NSArray*)getXmpInfoBuffer:(NSData*)imgData error:(NSError **) error
{
    if (!imgData) {
        return nil;
    }
    
    if (![self initialize:error options:0]) {
        return nil;
    }
    
    // out temporary
    std::string filename = "/tmp/KZImageTemp";
    [imgData writeToFile:[NSString stringWithUTF8String:filename.c_str()] atomically:YES];
    
    return [self getXmpInfo:[[NSString alloc] initWithUTF8String:filename.c_str()] error:&(*error)];
}

template<typename T>
T read_binary_as(std::ifstream& is)
{
    T val;
    is.read(reinterpret_cast<char*>(&val),sizeof(T));
    return val;
}

template<typename T>
void write_binary_as(std::ofstream& os, const T& v, size_t size)
{
    for (size_t i = 0; i < size; i++) {
        os.write(reinterpret_cast<const char*>(v)[i],sizeof(T));
    }
}

static bool write_gif_xmp ( std::string xmp_src, const char* img_path )
{
    std::ifstream ifs(img_path, std::ios::in | std::ios::binary);
    
    ifs.seekg(0, std::ios::beg);
    long insert_xmp_pos = 0;
    
    while(!ifs.eof()) {
        char c = read_binary_as<char>(ifs);
        long cur_pos = ifs.tellg();
        if (c == 33) {
            c = read_binary_as<char>(ifs);
            
            if (insert_xmp_pos == 0 && c == -1) { // 0x21ff
                // Application Extension
                insert_xmp_pos = ifs.tellg();
                c = read_binary_as<char>(ifs);
                if (c == 11) {
                    insert_xmp_pos = ifs.tellg();
                    break;
                }
                else {
                    insert_xmp_pos = 0;
                }
            }
            else if (insert_xmp_pos == 0 && c == -7) { // 0x21f9
                // Graphic Control Extens
                c = read_binary_as<char>(ifs);
                insert_xmp_pos = ifs.tellg();
                break;
            }
            else {
                ifs.seekg(cur_pos, std::ios::beg);
            }
        }
    }
    if (insert_xmp_pos == 0) return false;
    size_t header_size = insert_xmp_pos - 3;
    
    ifs.seekg(0, std::ios::beg);
    // XMP挿入位置で分割
    std::istreambuf_iterator<char> infile(ifs);
    std::istreambuf_iterator<char> last;
    std::vector<char> all_data(infile,last);
    std::vector<char> header_data(all_data.begin(), all_data.begin() + header_size);
    std::vector<char> footer_data(all_data.begin() + header_size, all_data.end());
    
    char xmp_head[] = {0x21, -1, 0x0b, 0x58, 0x4d, 0x50, 0x20, 0x44,
        0x61, 0x74, 0x61, 0x58, 0x4d, 0x50};
    std::vector<char> xmp_header(xmp_head, xmp_head + 14);
    std::vector<char> xmp_trailer;
    xmp_trailer.push_back(0x01);
    for (int i = -1; i > -129; i--) {
        xmp_trailer.push_back(static_cast<char>(i));
    }
    for (int i = 127; i >= 0; i--) {
        xmp_trailer.push_back(static_cast<char>(i));
    }
    xmp_trailer.push_back(0x00);
    
    std::vector<char> xmp_packet(xmp_src.begin(), xmp_src.end());
    
    header_data.reserve(header_data.size() + xmp_header.size() + xmp_packet.size() + xmp_trailer.size() + footer_data.size());
    std::copy(xmp_header.begin(), xmp_header.end(), std::back_inserter(header_data));
    std::copy(xmp_packet.begin(), xmp_packet.end(), std::back_inserter(header_data));
    std::copy(xmp_trailer.begin(), xmp_trailer.end(), std::back_inserter(header_data));
    std::copy(footer_data.begin(), footer_data.end(), std::back_inserter(header_data));
    
    std::ofstream ofs_gif(img_path, std::ios::out | std::ios::binary | std::ios::trunc);
    std::copy(header_data.begin(), header_data.end(), std::ostreambuf_iterator<char>(ofs_gif));
    
    ifs.close();
    ofs_gif.close();
    return true;
}	// DumpCallback

+ (BOOL)writeXmpInfo:(NSDictionary*)writeInfo imgPath:(NSString*)imgPath fileType:(NSString*)type error:(NSError **) error
{
    std::string filename = [imgPath UTF8String];
    
    if (![self initialize:error options:0]) {
        return false;
    }
    
    try
    {
        // Options to open the file with - open for editing and use a smart handler
        XMP_OptionBits opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUseSmartHandler;
        //XMP_FileFormat fmt = SXMPFiles::CheckFileFormat((XMP_StringPtr)filename.c_str());

        bool ok;
        SXMPFiles myFile;
        std::string status = "";
        
        // First we try and open the file
        ok = myFile.OpenFile(filename, kXMP_UnknownFile, opts);
        if( ! ok )
        {
            status += "No smart handler available for " + filename + "\n";
            status += "Trying packet scanning.\n";
            
            opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning;
            ok = myFile.OpenFile(filename, kXMP_UnknownFile, opts);
        }
        
        if(ok)
        {
            // Create the XMP object and get the XMP data
            std::string actualPrefix;
            SXMPMeta::RegisterNamespace(kXMP_NS_SDK_EDIT, "xsdkEdit", &actualPrefix);
            SXMPMeta meta;
            myFile.GetXMP(&meta);
            
            for (NSString* key in writeInfo.allKeys) {
                NSString *val = writeInfo[key];
                meta.SetProperty(kXMP_NS_SDK_EDIT, key.UTF8String, val.UTF8String);
            }
            
            meta.SetProperty(kXMP_NS_DC, "format", [self getDCFormat:type.UTF8String]);
            meta.SetProperty(kXMP_NS_XMP, "CreatorTool", "DiffImgCV");
            
            if (myFile.CanPutXMP(meta)) {
                myFile.PutXMP(meta);
            } else {
                if ([type compare:@"GIF"] == NSOrderedSame) {
                    std::string metaBuffer;
                    meta.SerializeToBuffer(&metaBuffer);
                    if (!write_gif_xmp(metaBuffer, imgPath.UTF8String)) {
                        *error = [NSError errorWithDomain:XMPUtilsDomain code:-2 userInfo:@{@"message": @"write error gif!"}];
                        myFile.CloseFile();
                        SXMPFiles::Terminate();
                        SXMPMeta::Terminate();
                        return NO;
                    }
                }
                else {
                    *error = [NSError errorWithDomain:XMPUtilsDomain code:-2 userInfo:@{@"message": @"write error!"}];
                    myFile.CloseFile();
                    SXMPFiles::Terminate();
                    SXMPMeta::Terminate();
                    return NO;
                }
            }
            
            myFile.CloseFile();
        }
        else
        {
            std::cout << "Unable to open " << filename << std::endl;
            *error = [NSError errorWithDomain:XMPUtilsDomain code:-3 userInfo:@{@"message": @"Unable to open"}];
            SXMPFiles::Terminate();
            SXMPFiles::Terminate();
            myFile.CloseFile();
            return NO;
        }
    }
    catch(XMP_Error & e)
    {
        std::cout << "ERROR: " << e.GetErrMsg() << std::endl;
        *error = [NSError errorWithDomain:XMPUtilsDomain code:-3 userInfo:@{@"message": @"write other error"}];
        SXMPFiles::Terminate();
        SXMPMeta::Terminate();
        return NO;
    }
    
    // Terminate the toolkit
    SXMPFiles::Terminate();
    SXMPMeta::Terminate();
    
    return YES;
}

/*
 + (NSDictionary*)getXmpInfo:(NSData*)imgData error:(NSError **) error
 {
 if (!imgData) return nil;
 
 if (![self initialize:error options:0]) {
 return nil;
 }
 
 // out temporary
 std::string filename = "/tmp/KZImageTemp";
 [imgData writeToFile:[NSString stringWithUTF8String:filename.c_str()] atomically:YES];
 
 try
 {
 // Options to open the file with - read only and use a file handler
 XMP_OptionBits opts = kXMPFiles_OpenForRead | kXMPFiles_OpenUseSmartHandler;
 
 bool ok;
 SXMPFiles myFile;
 std::string status = "";
 
 // First we try and open the file
 ok = myFile.OpenFile(filename, kXMP_UnknownFile, opts);
 if( ! ok )
 {
 status += "No smart handler available for " + filename + "\n";
 status += "Trying packet scanning.\n";
 
 // Now try using packet scanning
 opts = kXMPFiles_OpenForUpdate | kXMPFiles_OpenUsePacketScanning;
 ok = myFile.OpenFile(filename, kXMP_UnknownFile, opts);
 }
 
 
 // If the file is open then read the metadata
 if(ok)
 {
 std::cout << status << std::endl;
 std::cout << filename << " is opened successfully" << std::endl;
 
 // Create the xmp object and get the xmp data
 SXMPMeta meta;
 myFile.GetXMP(&meta);
 
 bool exists;
 
 // Read a simple property
 std::string simpleValue;  //Stores the value for the property
 exists = meta.GetProperty(kXMP_NS_XMP, "CreatorTool", &simpleValue, NULL);
 if(exists)
 std::cout << "CreatorTool = " << simpleValue << std::endl;
 else
 simpleValue.clear();
 
 // Get the first element in the dc:creator array
 std::string elementValue;
 exists = meta.GetArrayItem(kXMP_NS_DC, "creator", 1, &elementValue, NULL);
 if(exists)
 std::cout << "dc:creator = " << elementValue << std::endl;
 else
 elementValue.clear();
 
 // Get the the entire dc:subject array
 std::string propValue;
 int arrSize = meta.CountArrayItems(kXMP_NS_DC, "subject");
 for(int i = 1; i <= arrSize;i++)
 {
 meta.GetArrayItem(kXMP_NS_DC, "subject", i, &propValue, 0);
 std::cout << "dc:subject[" << i << "] = " << propValue << std::endl;
 }
 
 // Get the dc:title for English and French
 std::string itemValue;
 std::string actualLang;
 meta.GetLocalizedText(kXMP_NS_DC, "title", "en", "en-US", NULL, &itemValue, NULL);
 std::cout << "dc:title in English = " << itemValue << std::endl;
 
 meta.GetLocalizedText(kXMP_NS_DC, "title", "fr", "fr-FR", NULL, &itemValue, NULL);
 std::cout << "dc:title in French = " << itemValue << std::endl;
 
 // Get dc:MetadataDate
 XMP_DateTime myDate;
 if(meta.GetProperty_Date(kXMP_NS_XMP, "MetadataDate", &myDate, NULL))
 {
 // Convert the date struct into a convenient string and display it
 std::string myDateStr;
 SXMPUtils::ConvertFromDate(myDate, &myDateStr);
 std::cout << "meta:MetadataDate = " << myDateStr << std::endl;
 }
 
 // See if the flash struct exists and see if it was used
 std::string path, value;
 exists = meta.DoesStructFieldExist(kXMP_NS_EXIF, "Flash", kXMP_NS_EXIF,"Fired");
 if(exists)
 {
 bool flashFired;
 SXMPUtils::ComposeStructFieldPath(kXMP_NS_EXIF, "Flash", kXMP_NS_EXIF, "Fired", &path);
 meta.GetProperty_Bool(kXMP_NS_EXIF, path.c_str(), &flashFired, NULL);
 std::string flash = (flashFired) ? "True" : "False";
 
 std::cout << "Flash Used = " << flash << std::endl;
 }
 
 // Dump the current xmp object to a file
 std::ofstream dumpFile;
 dumpFile.open("XMPDump.txt", std::ios::out);
 meta.DumpObject(DumpXMPToFile, &dumpFile);
 dumpFile.close();
 std::cout << std::endl << "XMP dumped to XMPDump.txt" << std::endl;
 
 // Close the SXMPFile.  The resource file is already closed if it was
 // opened as read only but this call must still be made.
 myFile.CloseFile();
 }
 else
 {
 std::cout << "Unable to open " << filename << std::endl;
 }
 }
 catch(XMP_Error & e)
 {
 std::cout << "ERROR: " << e.GetErrMsg() << std::endl;
 }
 
 // Terminate the toolkit
 SXMPFiles::Terminate();
 SXMPMeta::Terminate();
 
 return nil;
 }
 
 XMP_Status DumpXMPToFile(void * refCon, XMP_StringPtr buffer, XMP_StringLen bufferSize)
 {
 XMP_Status status = 0;
 
 try
 {
 std::ofstream * outFile = static_cast<std::ofstream*>(refCon);
 (*outFile).write(buffer, bufferSize);
 }
 catch(XMP_Error & e)
 {
 std::cout << e.GetErrMsg() << std::endl;
 return -1;  // Return a bad status
 }
 
 return status;
 }*/
@end
