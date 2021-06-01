//
//  partse_pdf.hpp
//  DiffImgCV
//
//  Created by uchiyama_Macmini on 2020/02/21.
//  Copyright © 2020年 uchiyama_Macmini. All rights reserved.
//

#ifndef partse_pdf_hpp
#define partse_pdf_hpp

#include <stdio.h>
#include <iostream>
#include <vector>
#include <math.h>

#include <fpdfview.h>
#include <fpdf_structtree.h>
#include <fpdf_transformpage.h>
#include <fpdf_edit.h>
#include <fpdf_ext.h>
#include <fpdf_text.h>

using namespace std;
class PDFParser
{
public:
    float scale = 1.0;
    struct PdfPointF {
        float x;
        float y;
        PdfPointF() : x(0.0f), y(0.0f) {}
        PdfPointF(float x, float y) : x(x), y(y) {}
    };
    
    struct RectImageF {
        // Rect , origin=topLeft
        PdfPointF origin;
        float width;
        float height;
        
        RectImageF() : origin(0.0f, 0.0f), width(0.0f), height(0.0f) {}
        RectImageF(float x, float y, float width, float height) : origin(x,y), width(width), height(height) {}
        void setPdfCorrdinate(float left, float bottom, float right, float top, float doc_width, float doc_height) {
            origin.x = left;
            origin.y = doc_height - top;
            width = right - left;
            height = (doc_height - bottom) - origin.y;
        }
        
        void setOrigin(float x, float y) {
            origin.x = x;
            origin.y = y;
        }
        void setPdfBounds(float left, float bottom, float right, float top, float doc_height, float deg) {
            height = top - bottom;
            width = right - left;
            if (deg == 0.0f) {
                origin.x += left;
                origin.y = doc_height - ((bottom + origin.y) + height);
            }
            else if ((deg >= 89) && (deg <= 91)) {
                origin.x += bottom;
                origin.y = doc_height - (origin.y - left);
            }
            else if ((deg >= 179) && (deg <= 181)) {
                origin.x -= right;
                origin.y = doc_height - (origin.y - bottom);
            }
            else if ((deg >= 269) && (deg <= 271)) {
                origin.x -= top;
                origin.y = doc_height - ((left + origin.y) + width);
            }
            else {
                
            }
        }
        
        PdfPointF tl() {
            return origin;
        }
        PdfPointF tr() {
            return PdfPointF(origin.x+width,origin.y);
        }
        PdfPointF bl() {
            return PdfPointF(origin.x,origin.y+height);
        }
        PdfPointF br() {
            return PdfPointF(origin.x+width,origin.y+height);
        }
        
        bool operator == (const RectImageF& p0) const
        {
            return ((this->origin.x == p0.origin.x) && (this->origin.y == p0.origin.y) && (this->width == p0.width) && (this->height == p0.height));
        }
        
        bool operator != (const RectImageF& p0) const
        {
            return ((this->origin.x != p0.origin.x) || (this->origin.y != p0.origin.y) || (this->width != p0.width) || (this->height != p0.height));
        }
        
        bool isConatain(RectImageF rect) {
            float theRectTRY = rect.tr().y;
            float theRectTRX = rect.tr().x;
            bool isInHeight = ((this->tr().y <= theRectTRY) && (theRectTRY <= this->bl().y));
            bool isInWidth = ((this->bl().x <= theRectTRX) && (theRectTRX <= this->tr().x));
            
            return (isInHeight && isInWidth)? true : false;
        }
    };
    
//    std::vector<RectImageF> imgRects;
//    std::vector<RectImageF> textRects;
    RectImageF clip;
    PDFParser();
    ~PDFParser();
    void getFormObj(FPDF_PAGEOBJECT obj, float scale, float height, float deg, float orgx, float orgy, bool transparency, std::vector<RectImageF> &txtRects, std::vector<RectImageF> &imgRects);
    void parsePDF(const char *pdf_path, std::vector<RectImageF> &imgRects, std::vector<RectImageF> &textRects);
};
#endif /* partse_pdf_hpp */
