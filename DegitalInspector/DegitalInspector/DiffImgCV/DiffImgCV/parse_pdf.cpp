//
//  partse_pdf.cpp
//  DiffImgCV
//
//  Created by uchiyama_Macmini on 2020/02/21.
//  Copyright © 2020年 uchiyama_Macmini. All rights reserved.
//

#include "parse_pdf.hpp"
#include "public/cpp/fpdf_scopers.h"
#include <locale.h>
#include <mutex>
#include <codecvt>
using namespace std;
std::mutex mtx;


void ExampleUnsupportedHandler(UNSUPPORT_INFO*, int type) {
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
    cout << "Unsupported feature: " << feature << "." << endl;
}

std::wstring GetPlatformWString(FPDF_WIDESTRING wstr) {
    if (!wstr)
        return nullptr;
    
    size_t characters = 0;
    while (wstr[characters])
        ++characters;
    
    std::wstring platform_string(characters, L'\0');
    for (size_t i = 0; i < characters + 1; ++i) {
        const unsigned char* ptr = reinterpret_cast<const unsigned char*>(&wstr[i]);
        platform_string[i] = ptr[0] + 256 * ptr[1];
    }
    return platform_string;
}

PDFParser::PDFParser() {
    FPDF_LIBRARY_CONFIG config;
    config.version = 2;
    config.m_pUserFontPaths = nullptr;
    config.m_pIsolate = nullptr;
    config.m_v8EmbedderSlot = 0;
    FPDF_InitLibraryWithConfig(&config);
    UNSUPPORT_INFO unsuppored_info;
    memset(&unsuppored_info, '\0', sizeof(unsuppored_info));
    unsuppored_info.version = 1;
    unsuppored_info.FSDK_UnSupport_Handler = ExampleUnsupportedHandler;
    FSDK_SetUnSpObjProcessHandler(&unsuppored_info);
}

PDFParser::~PDFParser() {
    FPDF_DestroyLibrary();
}

FS_RECTF getClipPath(FPDF_PAGEOBJECT fObj, float scale, FS_RECTF orgRect)
{
    // calc clipping path
    FS_RECTF clippingRect;
    vector<FS_RECTF> clips;
    FPDF_CLIPPATH clp = FPDFPageObj_GetClipPath(fObj);
    int clps = FPDFClipPath_CountPaths(clp);
    if (clps != -1) {
        for (int i = 0; i < clps; i++) {
            int segs = FPDFClipPath_CountPathSegments(clp, i);
            
            vector<PDFParser::PdfPointF> pts;
            
            for (int k = 0; k < segs; k++) {
                FPDF_PATHSEGMENT seg = FPDFClipPath_GetPathSegment(clp, i, k);
                
                float x, y;
                FPDFPathSegment_GetPoint(seg, &x, &y);
                x *= scale;
                y *= scale;
                bool isClose = false;
                int typ = FPDFPathSegment_GetType(seg);
                if (FPDFPathSegment_GetClose(seg)) {
                    //                            cout << "CLOSE" << endl;
                    isClose = true;
                }
                if (typ == FPDF_SEGMENT_BEZIERTO) {
                    //                            cout << "BEZIERTO:" << " x = " << x << " y = " << y << endl;
                    pts.push_back(PDFParser::PdfPointF(x,y));
                    if (k == segs - 1)
                        isClose = true;
                }
                else if (typ == FPDF_SEGMENT_MOVETO) {
                    //                            cout << "MOVETO:" << " x = " << x << " y = " << y << endl;
                    pts.push_back(PDFParser::PdfPointF(x,y));
                }
                else if (typ == FPDF_SEGMENT_LINETO) {
                    //                            cout << "LINETO:" << " x = " << x << " y = " << y << endl;
                    pts.push_back(PDFParser::PdfPointF(x,y));
                }
                
                if (isClose) {
//                    cout << pts.size() << endl;
                    // close path
                    vector<PDFParser::PdfPointF> tmpX;
                    PDFParser::PdfPointF bl;
                    PDFParser::PdfPointF tr;
                    float min_x = 99999.9f;
                    float min_y = 99999.9f;
                    float max_x = -9999.0f;
                    float max_y = -9999.0f;
                    if (pts.size() == 4) {
                        for (int l = 0; l < pts.size(); l++) {
                            PDFParser::PdfPointF thePt = pts.at(l);
                            if (thePt.x < min_x)  min_x = thePt.x;
                        }
                        for (int l = 0; l < pts.size(); l++) {
                            PDFParser::PdfPointF thePt = pts.at(l);
                            if (thePt.x == min_x) tmpX.push_back(thePt);
                        }
                        for (int l = 0; l < tmpX.size(); l++) {
                            PDFParser::PdfPointF thePt = tmpX.at(l);
                            if (thePt.y < min_y) min_y = thePt.y;
                        }
                        for (int l = 0; l < pts.size(); l++) {
                            PDFParser::PdfPointF thePt = pts.at(l);
                            if ((thePt.x == min_x) && (thePt.y == min_y)) {
                                bl = thePt;
                            }
                        }
                        
                        tmpX.clear();
                        
                        for (int l = 0; l < pts.size(); l++) {
                            PDFParser::PdfPointF thePt = pts.at(l);
                            if (thePt.x > max_x)  max_x = thePt.x;
                        }
                        for (int l = 0; l < pts.size(); l++) {
                            PDFParser::PdfPointF thePt = pts.at(l);
                            if (thePt.x == max_x) tmpX.push_back(thePt);
                        }
                        for (int l = 0; l < tmpX.size(); l++) {
                            PDFParser::PdfPointF thePt = tmpX.at(l);
                            if (thePt.y > max_y) max_y = thePt.y;
                        }
                        for (int l = 0; l < pts.size(); l++) {
                            PDFParser::PdfPointF thePt = pts.at(l);
                            if ((thePt.x == max_x) && (thePt.y == max_y)) {
                                tr = thePt;
                            }
                        }
                    }
                    else {
                        for (int l = 0; l < pts.size(); l++) {
                            PDFParser::PdfPointF thePt = pts.at(l);
                            if (thePt.x < min_x)  min_x = thePt.x;
                        }
                        for (int l = 0; l < pts.size(); l++) {
                            PDFParser::PdfPointF thePt = pts.at(l);
                            if (thePt.y < min_y)  min_y = thePt.y;
                        }
                        for (int l = 0; l < pts.size(); l++) {
                            PDFParser::PdfPointF thePt = pts.at(l);
                            if (thePt.x > max_x) max_x = thePt.x;
                        }
                        for (int l = 0; l < pts.size(); l++) {
                            PDFParser::PdfPointF thePt = pts.at(l);
                            if (thePt.y > max_y) max_y = thePt.y;
                        }
                        tr.x = max_x;
                        tr.y = max_y;
                        bl.x = min_x;
                        bl.y = min_y;
                    }
    
                    FS_RECTF tmp;
                    
                    tmp.top = tr.y;
                    tmp.bottom = bl.y;
                    tmp.left = bl.x;
                    tmp.right = tr.x;
                    
                    //                            if (pts.size() == 4)
                    clips.push_back(tmp);
                    
                    pts.clear();
                }
            }
        }
        
    }
    if (clips.size() > 1) {
        clippingRect = clips.at(clips.size() - 1);
    }
    else if (clips.size() == 1) {
        clippingRect = clips.at(0);
    }
    else if (clips.size() == 0) {
        clippingRect.left = orgRect.left;
        clippingRect.right = orgRect.right;
        clippingRect.top = orgRect.top;
        clippingRect.bottom = orgRect.bottom;
    }
    
    return clippingRect;
}

void PDFParser::getFormObj(FPDF_PAGEOBJECT obj, float scale, float height, float deg, float orgx, float orgy, bool transparency, std::vector<RectImageF> &txtRects, std::vector<RectImageF> &imgRects)
{
    int formCount = FPDFFormObj_CountObjects(obj);
//    cout << "2.formCount ------ " << formCount << endl;
    
    for (int j = 0; j < formCount; j++) {
//        cout << "---------- No." << j << " obj_form" << endl;
//        if (j == 1011) {
//            cout << "---------- No." << j << " obj_form" << endl;
//        }
        FPDF_PAGEOBJECT fObj = FPDFFormObj_GetObject(obj, j);
        int type = FPDFPageObj_GetType(fObj);

//        if (type == FPDF_PAGEOBJ_UNKNOWN)
//            cout << "FPDF_PAGEOBJ_UNKNOWN" << endl;
//        if (type == FPDF_PAGEOBJ_TEXT)
//            cout << "FPDF_PAGEOBJ_TEXT" << endl;
//        if (type == FPDF_PAGEOBJ_PATH)
//            cout << "FPDF_PAGEOBJ_PATH" << endl;
//        if (type == FPDF_PAGEOBJ_IMAGE)
//            cout << "FPDF_PAGEOBJ_IMAGE" << endl;
//        if (type == FPDF_PAGEOBJ_SHADING)
//            cout << "FPDF_PAGEOBJ_SHADING" << endl;
//        if (type == FPDF_PAGEOBJ_FORM)
//            cout << "FPDF_PAGEOBJ_FORM" << endl;
        FS_RECTF rc;
        
        FPDFPageObj_GetBounds(fObj, &rc.left, &rc.bottom, &rc.right, &rc.top);
        rc.left *= scale;
        rc.bottom *= scale;
        rc.right *= scale;
        rc.top *= scale;
        bool isTransparency = false;
        int markCount = FPDFPageObj_CountMarks(fObj);
        bool isPlacedPDF = false;
        bool isArtifact = false;
        bool isOC = false;
        for (int i = 0; i < markCount; i++) {
            FPDF_PAGEOBJECTMARK mark = FPDFPageObj_GetMark(fObj, i);
            char buffer[256];
            unsigned long name_len = 999u;
            FPDFPageObjMark_GetName(mark, buffer, sizeof(buffer), &name_len);
            std::wstring name = GetPlatformWString(reinterpret_cast<unsigned short*>(buffer));
            
//            wcout << name << endl;
            
            if (name == L"Artifact")
                isArtifact = true;
            else if (name == L"PlacedPDF") {
                // set clip path to org
                isPlacedPDF = true;
            }
            else if (name == L"OC") {
                isOC = true;
            }
        }
        
        bool isImageObject = false;
        unsigned int R, G, B, A;
        FPDF_BOOL stroke;
        int mode = 0;
        
        if (type == FPDF_PAGEOBJ_TEXT) {
            
            FS_RECTF clipPath = getClipPath(fObj, scale, rc);
            RectImageF clipRect;
            clipRect.setOrigin(orgx, orgy);
            clipRect.setPdfBounds(clipPath.left, clipPath.bottom, clipPath.right, clipPath.top, height, deg);
            PDFParser::RectImageF txtRect;
            
            txtRect.setOrigin(orgx, orgy);
            
            // 画像を含むフォームを入れるなら単純にフォームのクリップをスタック
            txtRect.setPdfBounds(rc.left, rc.bottom, rc.right, rc.top, height, deg);
            
            bool isExist = false;
//            cout << txtRects.size() << endl;
            for (auto it = txtRects.begin(); it != txtRects.end(); ++it) {
                
                if ((txtRect.origin.x == it->origin.x) && (txtRect.origin.y == it->origin.y) && (txtRect.width == it->width) && (txtRect.height == it->height)) {
                    isExist = true;
                    break;
                }
            }
            if (!isExist) {
                if (clipRect.isConatain(txtRect))
                    txtRects.emplace_back(txtRect);
            }
        }
        else if (FPDF_PAGEOBJ_PATH == type) {
            FPDFPath_GetDrawMode(fObj, &mode, &stroke);
            FPDFPageObj_GetFillColor(fObj, &R, &G, &B, &A);
            
            if (((R != 255) && (R != 209) && (R != 0) && (R != 35)) ||
                ((G != 255) && (G != 210) && (G != 0) && (G != 31)) ||
                ((B != 255) && (B != 212) && (B != 0) && (B != 32))) {
                // no white or black fill
                isImageObject = true;
            }
            if (!isImageObject && stroke) {
                FPDFPageObj_GetStrokeColor(fObj, &R, &G, &B, &A);
                if (((R != 255) && (R != 0) && (R != 35)) ||
                    ((G != 255) && (G != 0) && (G != 31)) ||
                    ((B != 255) && (B != 0) && (B != 32))) {
                    // no white or black stroke
                    isImageObject = true;
                }
            }
            
            if (!isImageObject) {
                if (transparency) {
                    isImageObject = true;
                }
            }
            if (isArtifact)
                isImageObject = false;
        }
        else if (FPDF_PAGEOBJ_FORM == type) {
            if (FPDFPageObj_HasTransparency(fObj)) {
//                cout << "とうめい" << endl;
                isTransparency = true;
            }
            getFormObj(fObj, scale, height, deg, orgx, orgy, isTransparency, txtRects, imgRects);
        }
        else if (type == FPDF_PAGEOBJ_SHADING) {
            isImageObject = true;
        }
        else if (type == FPDF_PAGEOBJ_IMAGE) {
//            cout << "left = " << rc.left << " bottom = " << rc.bottom << " right = " << rc.right << " top = " << rc.top << endl;
//            cout << "degree = " << deg << endl;
            isImageObject = true;
        }
        
        if (isImageObject) {
            if (clip.width < 0 || clip.height < 0 || clip.origin.x < 0 || clip.origin.y < 0)
                continue;

            bool isExist = false;
            for (auto it = imgRects.begin(); it != imgRects.end(); ++it) {
                if ((clip.origin.x == it->origin.x) && (clip.origin.y == it->origin.y) && (clip.width == it->width) && (clip.height == it->height)) {
                    isExist = true;
                    break;
                }
            }
            if (!isExist) {
                imgRects.emplace_back(clip);
            }
        }
    }
}

void PDFParser::parsePDF(const char *pdf_path, std::vector<RectImageF> &imgRects, std::vector<RectImageF> &textRects)
{
    FPDF_DOCUMENT pdfDoc;
    {
        std::lock_guard<std::mutex> lock(mtx);
        pdfDoc = FPDF_LoadDocument(pdf_path, nullptr);
    }
    int pageCount = FPDF_GetPageCount(pdfDoc);
    for (int i = 0; i < pageCount; i++) {
        FPDF_PAGE page;
        {
            std::lock_guard<std::mutex> lock(mtx);
            page = FPDF_LoadPage(pdfDoc, i);
        }
        
        float pageHeight = FPDF_GetPageHeight(page);
        float pageWidth = FPDF_GetPageWidth(page);
        pageHeight *= scale;
        pageWidth *= scale;
        
        int rot = FPDFPage_GetRotation(page);
        
        int objCount = FPDFPage_CountObjects(page);
        
        for (int j = 0; j < objCount; j++) {
//                cout << "=========== No." << j << " obj" << endl;
            if (j == 1) {
//                    cout << "=========== No." << j << " obj" << endl;
            }
            vector<RectImageF> imageR;
            FPDF_PAGEOBJECT obj = FPDFPage_GetObject(page, j);
            int objType = FPDFPageObj_GetType(obj);
            FS_RECTF rect;
            FPDFPageObj_GetBounds(obj, &rect.left, &rect.bottom, &rect.right, &rect.top);
            rect.left *= scale;
            rect.bottom *= scale;
            rect.right *= scale;
            rect.top *= scale;
            
            bool isTransparency = false;
            if (FPDFPageObj_HasTransparency(obj)) {
//                    cout << "とうめい" << endl;
                isTransparency = true;
            }
            
            // 領域外オブジェクト
            if ((rect.bottom > pageHeight) || (rect.top < 0) || (rect.right < 0) || (rect.left > pageWidth)) {
                continue;
            }
            
//                cout << "1.objectRect ------ " << endl;
//                cout << "left = " << rect.left << " bottom = " << rect.bottom << " right = " << rect.right << " top = " << rect.top << endl;
            
            if (objType == FPDF_PAGEOBJ_PATH) {
                FPDF_BOOL stroke;
                int mode = 0;
                FPDFPath_GetDrawMode(obj, &mode, &stroke);
                unsigned int R, G, B, A;
                FPDFPageObj_GetFillColor(obj, &R, &G, &B, &A);
//                    cout << "fill R = " << R << " G = " << G << " B = " << B << endl;
                if (((R != 255) && (R != 0) && (R != 35)) ||
                    ((G != 255) && (G != 0) && (G != 31)) ||
                    ((B != 255) && (B != 0) && (B != 32))) {
//                        cout <<  "no white or black fill" << endl;
                }
                if (stroke) {
                    FPDFPageObj_GetStrokeColor(obj, &R, &G, &B, &A);
//                        cout << "stroke R = " << R << " G = " << G << " B = " << B << endl;
                    if (((R != 255) && (R != 0) && (R != 35)) ||
                        ((G != 255) && (G != 0) && (G != 31)) ||
                        ((B != 255) && (B != 0) && (B != 32))) {
//                            cout <<  "no white or black stroke" << endl;
                    }
                }
                
            }
            else if (objType == FPDF_PAGEOBJ_FORM) {
                float deg = 0.0f;
                FS_MATRIX mat;
                FPDFFormObj_GetMatrix(obj,&mat);
//                    cout << "a = " << mat.a << " e = " << mat.e * scale << " f = " << mat.f * scale << endl;
                if (mat.a <= 1 && mat.a >= -1) {
                    double rad = acos(mat.a);
                    float unit_r = 180 / M_PI;
                    deg = round(rad * unit_r);
                    if (rot == 1) deg += 90;
                    if (rot == 2) deg += 180;
                    if (rot == 3) deg += 270;
                    if (deg > 360) {
                        deg -= 360;
                    }
                }
                // 原点が0,0の場合のクリップ
                FS_RECTF clipPath = getClipPath(obj, scale, rect);
                FS_RECTF clipPath_ajst;
                float origin_x = mat.e * scale;
                float origin_y = mat.f * scale;
                if (deg == 0.0f) {
                    clipPath_ajst.left = clipPath.left - origin_x;
                    clipPath_ajst.right = clipPath_ajst.left + (abs(clipPath.left - clipPath.right));
                    clipPath_ajst.bottom = clipPath.bottom - origin_y;
                    clipPath_ajst.top = clipPath_ajst.bottom + (abs(clipPath.top - clipPath.bottom));
                }
                else if ((deg >= 89) && (deg <= 91)) {
                    clipPath_ajst.left = clipPath.left - origin_x;
                    clipPath_ajst.right = clipPath_ajst.left + (abs(clipPath.left - clipPath.right));
                    clipPath_ajst.bottom = clipPath.top - origin_y;
                    clipPath_ajst.top = clipPath_ajst.bottom + (abs(clipPath.top - clipPath.bottom));
                }
                else if ((deg >= 179) && (deg <= 181)) {
                    clipPath_ajst.left = origin_x - clipPath.right;
                    clipPath_ajst.right = clipPath_ajst.left + (abs(clipPath.left - clipPath.right));
                    clipPath_ajst.bottom = origin_y - clipPath.top;
                    clipPath_ajst.top = clipPath_ajst.bottom + (abs(clipPath.top - clipPath.bottom));
                }
                else if ((deg >= 269) && (deg <= 271)) {
                    clipPath_ajst.left = origin_x - clipPath.right;
                    clipPath_ajst.right = clipPath_ajst.left + (abs(clipPath.left - clipPath.right));
                    clipPath_ajst.bottom = origin_y - clipPath.bottom;
                    clipPath_ajst.top = clipPath_ajst.bottom + (abs(clipPath.top - clipPath.bottom));
                }
                
                std::vector<RectImageF> tmpF;

                clip.setOrigin(origin_x, origin_y);
                clip.setPdfBounds(clipPath_ajst.left, clipPath_ajst.bottom, clipPath_ajst.right, clipPath_ajst.top, pageHeight, deg);
                
                getFormObj(obj, scale, pageHeight, deg, origin_x, origin_y, isTransparency, textRects, imgRects);
            }
            else if (objType == FPDF_PAGEOBJ_IMAGE) {
                double a,b,c,d,e,f;
                float deg = 0.0f;
                FPDFImageObj_GetMatrix(obj, &a,&b,&c,&d,&e,&f);
                if (a <= 1 && a >= -1) {
                    double rad = acos(a);
                    float unit_r = 180 / M_PI;
                    deg = round(rad * unit_r);
                    if (rot == 1) deg += 90;
                    if (rot == 2) deg += 180;
                    if (rot == 3) deg += 270;
                    if (deg > 360) {
                        deg -= 360;
                    }
                }
                RectImageF rcImg;
                rcImg.setOrigin(e * scale, f * scale);
                FS_RECTF rc;
                FPDFPageObj_GetBounds(obj, &rc.left, &rc.bottom, &rc.right, &rc.top);
                rc.left *= scale;
                rc.bottom *= scale;
                rc.right *= scale;
                rc.top *= scale;
                rcImg.setPdfBounds(rc.left, rc.bottom, rc.right, rc.top, pageHeight, deg);
                imgRects.push_back(rcImg);
            }

//                cout << "------------------------------" << endl;

        }
        {
            std::lock_guard<std::mutex> lock(mtx);
            FPDF_ClosePage(page);
        }
    }
    {
        std::lock_guard<std::mutex> lock(mtx);
        FPDF_CloseDocument(pdfDoc);
    }
}
