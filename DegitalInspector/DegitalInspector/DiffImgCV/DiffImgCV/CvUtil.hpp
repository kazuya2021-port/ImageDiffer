//
//  CvUtil.h
//  DiffImgCV
//
//  Created by 内山和也 on 2019/04/16.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#ifndef __DiffImgCV__CvUtil__
#define __DiffImgCV__CvUtil__

#include <stdio.h>
#include <vector>
#include <opencv2/opencv.hpp>
#include <opencv2/core/base.hpp>
//#include "Halide.h"

#define DBG_SAVE_PATH "/tmp/"
class CvUtil
{
public:
    CvUtil();
    ~CvUtil();

    enum AdjustMode {
        ADJUST_FILL = 1, // 小さい方を中心に塗り足して拡張
        ADJUST_CROP = 2, // 小さい方のサイズで大きい方を切り抜く
        ADJUST_FEATURE = 3,
        ADJUST_REGISTMARK = 4,
        ADJUST_POC = 5
    };
    
    struct LabelItem {
        cv::Rect rect;
        cv::RotatedRect rect_r;
        cv::Point2f center;
        double area;    // エリア内のピクセル数
        LabelItem();
        LabelItem(const cv::Rect rect, const cv::Point2f p, double area);
    };
    
    struct FoundImage{
        bool isFound = false;
        cv::Mat img;
        cv::Rect rect;
        int area;
        FoundImage();
    };
    
    struct MatchingResult{
        bool isMatch = false;
        double val = 0.0;
        std::vector<cv::Rect> ROI;
        MatchingResult();
    };
    void moveSafe(cv::Mat in, cv::Mat& out, cv::Point2d movePoint, cv::Scalar bgColor);
    void dbgInfo(const cv::Mat& mat);
    bool adjustSize(cv::Mat& src, cv::Mat& dst, cv::Scalar nuri, AdjustMode mode);
    MatchingResult tmplateMatch(cv::Mat rS, cv::Mat rT, double threshold, int scale);
    bool featureDetect(cv::Mat& rS, cv::Mat& rT);
    
    void dbgShow(cv::Mat img, std::string window_title="test", bool isDestroiWindow=true);
    void dbgSave(cv::Mat img, std::string file_name, std::string header);
//    void dbgSave(cv::Mat img, std::string file_name, bool iscmyk);
    void dbgSave(cv::Mat img, std::string file_name, int num);
    
    void dbgRemove(std::string file_name, int num);
    void rect_clustering(std::vector<cv::Rect> bounds, std::vector<cv::Rect>& out_bounds, double threshold);
    
    void binalize(cv::Mat src, cv::Mat& out, bool inv);
    void absDiffImg(cv::Mat src, cv::Mat targ, cv::Mat& out, bool isMorphology, bool isGray);
    void deleteMinimumArea(cv::Mat& img, int strong);
    void scanCharactors(cv::Mat img, std::vector<cv::Rect>& position);
    std::vector<LabelItem> getLabel(cv::Mat img, cv::Mat& labelImg, bool isGetRRect=false);
    void cropExtra(cv::Mat in, cv::Mat& out, cv::Rect cropSize, int aroundSize);
    FoundImage searchNearImg(std::vector<LabelItem> labels, cv::Mat labelImg, cv::Mat input, cv::Mat search);
    cv::Rect getRect(std::vector<cv::Point> cnt);
    void rgb2cmyk(cv::Mat& img);
    void cmyk2rgb(cv::Mat& img);
    void conv2Cyan(cv::Mat& img);
    void conv2Magenta(cv::Mat& img);
    void conv2Blue(cv::Mat& img);
    void conv2Red(cv::Mat& img);
    void cvtGrayIfColor(cv::Mat in, cv::Mat &out);
    void cvtBGR(cv::Mat in, cv::Mat &out);
    void fillMat(cv::Mat& src, cv::Mat& dst, cv::Scalar nuri, bool istl);
    cv::Rect cropSafe(cv::Mat in, cv::Mat& out, cv::Rect cropSize, bool isFill);
    bool isWhiteImage(cv::Mat img);
    cv::Point maxPoint(std::vector<cv::Point> contours);
    cv::Point minPoint(std::vector<cv::Point> contours);
    void divide(cv::Mat base, std::vector<cv::Mat>& chars, std::vector<cv::Mat>& masks, std::vector<cv::Rect>& rects);
    
    void resizeImage(cv::Mat src, cv::Mat& dst, double scale);
    cv::Rect getNotWhiteSpace(cv::Mat in);

    void getInteglal(cv::Mat in, cv::Mat& out){
        if(in.channels() != 1){
            cv::cvtColor(in, in, cv::COLOR_RGB2GRAY);
        }
        in.convertTo(in, CV_8UC1);
        cv::integral(in, out);
        return;
    }
    
    std::vector<cv::Range> searchColumns(cv::Mat integl){
        const int* srcLine = integl.ptr<int>(integl.rows - 1); // 積分画像の下端を見る
        std::vector<cv::Range> colRange;
        cv::Range rnge;
        rnge.start = -1;
        rnge.end = -1;
        for(int i = 1; i < integl.cols; i++){
            
            bool sameVal = (srcLine[i] == srcLine[i-1]);
            if(sameVal && rnge.start < 0){
                rnge.start = i - 1;
            }else if (!sameVal && rnge.start >= 0){
                rnge.end = i - 1;
                colRange.push_back(rnge);
                rnge.start = -1;
                rnge.end = -1;
            }
        }
        if(rnge.start >= 0 && rnge.end < 0){
            rnge.end = integl.cols - 1;
            colRange.push_back(rnge);
            rnge.start = -1;
            rnge.end = -1;
        }
        return colRange;
    }
    
    std::vector<cv::Range> searchRows(cv::Mat integl){
        std::vector<cv::Range> rowRange;
        cv::Range rnge;
        rnge.start = -1;
        rnge.end = -1;
        for (int y = 1; y < integl.rows; y++){
            int *ps = integl.ptr<int>(y-1);
            int *ns = integl.ptr<int>(y);
            bool sameVal = (ps[integl.cols-1] == ns[integl.cols-1]);
            
            if(sameVal && rnge.start < 0){
                rnge.start = y - 1;
            }else if (!sameVal && rnge.start >= 0){
                rnge.end = y - 1;
                rowRange.push_back(rnge);
                rnge.start = -1;
                rnge.end = -1;
            }
        }
        if(rnge.start >= 0 && rnge.end < 0){
            rnge.end = integl.rows - 1;
            rowRange.push_back(rnge);
        }
        return rowRange;
    }
    
    cv::Rect VecToRect(const std::vector<float> & vec)
    {
        return cv::Rect(cv::Point(vec[0], vec[1]), cv::Point(vec[2], vec[3]));
    }
    
    bool calcContrast(cv::Mat src, cv::Mat trg, cv::Mat df)
    {
        dbgSave(src,"src.tif",false);
        dbgSave(trg,"trg.tif",false);
        cv::Mat gS, gT;
        cvtGrayIfColor(src, gS);
        cvtGrayIfColor(trg, gT);
        double cntS = 0;
        double cntT = 0;
        int white_count = cv::countNonZero(df);
        if (white_count <= 300) {
            int allpix = gS.rows * gS.cols;
            for(int r = 0; r < gS.rows; r++){
                uchar* s = gS.ptr<uchar>(r);
                uchar* t = gT.ptr<uchar>(r);
                for (int c = 0; c < gS.cols; c++) {
                    cntS += s[c];
                    cntT += t[c];
                }
            }
            cntS /= allpix;
            cntT /= allpix;
            if (abs(cntS - cntT) > 10) return false;
            return true;
        }
        
        dbgSave(df,"df.tif",false);
        
        
        for(int r = 0; r < gS.rows; r++){
            uchar* b = df.ptr<uchar>(r);
            uchar* s = gS.ptr<uchar>(r);
            uchar* t = gT.ptr<uchar>(r);
            for (int c = 0; c < gS.cols; c++) {
                if (b[c] == 255) {
                    cntS += s[c];
                    cntT += t[c];
                }
            }
        }
        cntS /= white_count;
        cntT /= white_count;
        if (abs(cntS - cntT) > 10) return false;
        return true;
    }
    
//    static Halide::Buffer<uint8_t> convertMat2Halide(cv::Mat& src)
//    {
//        Halide::Buffer<uint8_t> dest;
//        dest = Halide::Buffer<uint8_t>(src.ptr<uchar>(0), src.cols, src.rows, src.channels());
//        return dest;
//    }
//    
//    static void convertHalide2Mat(Halide::Buffer<uint8_t>& src, cv::Mat& dest){
//        uchar* data = src.data();
//        memcpy(dest.data, data, src.size_in_bytes());
//    }
//    
//    static void convertHalide2Vector(Halide::Buffer<uint8_t>& src, std::vector<uchar>& dest){
//        dest = std::vector<uchar>(src.size_in_bytes());
//        memcpy(&dest[0], src.data(), src.size_in_bytes());
//    }
    
    cv::Scalar HSVtoRGBcvScalar(int H, int S, int V);
    
//    Halide::Func diff_img(Halide::Buffer<uint8_t>& src, Halide::Buffer<uint8_t>& trg);
//    Halide::Func thresh(Halide::Func src, int thresh);
//    Halide::Func threshBuf(Halide::Buffer<uint8_t>& src, int thresh);
    
private:
    struct RotateInfo{
        double angle = 0.0;
        double scale = 0.0;
        cv::Point2f center = cv::Point2f(0.0,0.0);
        RotateInfo();
    };
    
    struct FeatureInfo{
        cv::Point2f query_pt;
        cv::Point2f train_pt;
        int distance;
    };
    
    struct byAreaR {
        bool operator () (const cv::RotatedRect & a,const cv::RotatedRect & b) {
            return ((a.size.width * a.size.height) > (b.size.width * b.size.height));
        }
    };
    
    struct byDistance {
        bool operator () (const cv::DMatch & a,const cv::DMatch & b) {
            return (a.distance < b.distance);
        }
    };
    
    struct byOrgDistanceQuery {
        bool operator () (const FeatureInfo & a,const FeatureInfo & b) {
            double ad = std::sqrt(a.query_pt.x*a.query_pt.x+a.query_pt.y*a.query_pt.y);
            double bd = std::sqrt(b.query_pt.x*b.query_pt.x+b.query_pt.y*b.query_pt.y);
            return (ad < bd);
        }
    };
    
    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(6.0, cv::Size(3,3));
    
    
    
    
    
    
    
    // 領域を考慮して安全に切り出す
    // isFill -> あふれた箇所を拡張して切り抜く(xがマイナスならその分領域広げる)
    //
    
    
    // 領域を拡大して移動
    void translateImageExt(cv::Mat& inout, float dx, float dy, bool isTl){
        cv::Scalar nuri(255,255,255);
        cv::Mat makeIn(cv::Size(inout.cols + dx, inout.rows + dy), inout.type(), nuri);
        
        if(isTl)
        {
            cv::Mat remakeROI(makeIn, cv::Rect(dx,dy,inout.cols,inout.rows));
            inout.copyTo(remakeROI);
            
            if(dx != 0){
                cv::rectangle(makeIn, cv::Point(0,0), cv::Point(dx, inout.rows + dy), nuri, cv::FILLED);
            }
            if(dy != 0){
                cv::rectangle(makeIn, cv::Point(0,0), cv::Point(inout.cols + dx, dy), nuri, cv::FILLED);
            }
            inout = makeIn;
        }
        else{
            cv::Mat remakeROI(makeIn, cv::Rect(0,0,inout.cols,inout.rows));
            inout.copyTo(remakeROI);
            
            if(dx != 0){ // 幅
                cv::rectangle(makeIn, cv::Point(inout.cols,0), cv::Point(inout.cols + dx, inout.rows + dy), nuri, cv::FILLED);
            }
            if(dy != 0){ // 高さ
                cv::rectangle(makeIn, cv::Point(0,inout.rows), cv::Point(inout.cols + dx, inout.rows + dy), nuri, cv::FILLED);
            }
            inout = makeIn;
        }
    }
    
    bool checkImg(cv::Mat img){
        if(img.empty()){
            return false;
        }
        if(img.rows == 0 || img.cols == 0){
            return false;
        }
        return true;
    }
    
    
    void cropMat(cv::Mat& src, cv::Mat& dst){
        // 高さのサイズ
        if(src.rows > dst.rows || src.rows < dst.rows){
            cv::Mat smallImg, largeImg;
            smallImg = (src.rows > dst.rows)? dst:src;
            largeImg = (src.rows > dst.rows)? src:dst;
            
            int diffHeight = largeImg.rows - smallImg.rows;
            cv::Mat restored;
            
            cv::Rect cropArea(0, diffHeight / 2, largeImg.cols, smallImg.rows);
            restored = cv::Mat(largeImg, cropArea);
            
            if(src.rows > dst.rows) {
                src = restored;
                dst = smallImg;
            }
            else{
                src = smallImg;
                dst = restored;
            }
        }
        
        // 幅のサイズ
        if(src.cols < dst.cols || src.cols > dst.cols){
            cv::Mat smallImg, largeImg;
            smallImg = (src.cols > dst.cols)? dst:src;
            largeImg = (src.cols > dst.cols)? src:dst;
            
            int diffWidth = largeImg.cols - smallImg.cols;
            cv::Mat restored;
            
            cv::Rect cropArea(diffWidth / 2, 0, smallImg.cols, smallImg.rows);
            restored = cv::Mat(largeImg, cropArea);
            
            if(src.cols > dst.cols) {
                src = restored;
                dst = smallImg;
            }else{
                src = smallImg;
                dst = restored;
            }
        }
    }
    cv::Point2f minPointf(std::vector<cv::Point2f> contours){
        // 距離がpointを抽出
        cv::Point2f minDis;
        double mindist = 999999;
        for(int i = 0; i < contours.size(); i++){
            double minx = contours.at(i).x;
            double miny = contours.at(i).y;
            double d = sqrt(minx*minx+miny*miny);
            if(d < mindist){
                minDis = contours.at(i);
                mindist = d;
            }
        }
        return minDis;
    }
    cv::Point2f maxPointf(std::vector<cv::Point2f> contours){
        // 距離が遠いモノを抽出
        cv::Point2f maxDis;
        double maxdist = 0;
        for(int i = 0; i < contours.size(); i++){
            double maxx = contours.at(i).x;
            double maxy = contours.at(i).y;
            double d = sqrt(maxx*maxx+maxy*maxy);
            if(d > maxdist){
                maxDis = contours.at(i);
                maxdist = d;
            }
        }
        return maxDis;
    }
    
    
    RotateInfo getRotateInfo(cv::Point2f q1, cv::Point2f q2,
                             cv::Point2f t1, cv::Point2f t2, cv::Point2f srcCenter){
        double q_deg = atan2(q2.y - q1.y, q2.x - q1.x)*180/CV_PI;
        double t_deg = atan2(t2.y - t1.y, t2.x - t1.x)*180/CV_PI;
        double angle = abs(q_deg - t_deg);
        
        // q1,q2をangle度回転してみて角度に差がないかチェック
        cv::Rect q(q1,q2);
        cv::RotatedRect rq((q1+q2)*0.5,q.size(),angle);
        cv::Point2f vertices[4];
        rq.points(vertices); // The order is bottomLeft, topLeft, topRight, bottomRight
        double q_deg_rot = atan2(vertices[2].y - vertices[1].y, vertices[2].x - vertices[1].x)*180/CV_PI;
        int diffDeg = abs(q_deg_rot - t_deg);
        if(diffDeg > 3 && diffDeg != 180) return RotateInfo();
        else{
            RotateInfo info;
            cv::Point2f tc; // 求めたいセンター座標
            
            // 元センターとq1の角度
            double dxc = srcCenter.x - q1.x;
            double dyc = srcCenter.y - q1.y;
            double c_deg = atan2(dyc, dxc)*180/CV_PI;
            double c_len = sqrt(dxc*dxc+dyc*dyc);
            double tc_deg = 180 - (c_deg + angle);
            double tc_rad = (tc_deg * CV_PI) / 180;
            double th = c_len * sin(tc_rad);
            double tw = c_len * cos(tc_rad);
            if(angle > 0 && tc_deg < 0){
                tw *= -1;
            }else if(angle > 0 && tc_deg > 0){
                tw *= -1;
            }
            
            tc = cv::Point2f(t1.x+tw, t1.y+th);
            
            double q_len = round(sqrt((q2.x - q1.x)*(q2.x - q1.x)+(q2.y - q1.y)*(q2.y - q1.y)));
            double t_len = round(sqrt((t2.x - t1.x)*(t2.x - t1.x)+(t2.y - t1.y)*(t2.y - t1.y)));
            double scale = t_len / q_len;
            
            info.center = tc;
            info.angle = angle;
            info.scale = scale;
            
            return info;
        }
    }
    
    void splitGyou(cv::Mat img, cv::Mat binImg, bool isTate, std::vector<cv::Rect>& gyouPos, std::vector<cv::Mat>& gyou){
        std::vector<cv::Range> gyouRange;
        
        cv::Mat src;
        getInteglal(binImg, src);
        
        if(isTate){
            gyouRange = searchColumns(src);
        }else{
            gyouRange = searchRows(src);
        }
        
        std::vector<std::vector<cv::Point> > vctContours;
        cv::Mat colCutMask = cv::Mat::zeros(img.rows, img.cols, CV_8UC1);
        for(int x = 0; x < gyouRange.size(); x++){
            cv::Rect wPos;
            if(isTate){
                wPos = cv::Rect(gyouRange.at(x).start,
                                0,
                                gyouRange.at(x).end - gyouRange.at(x).start,
                                img.rows);
            }else{
                wPos = cv::Rect(0,
                                gyouRange.at(x).start,
                                img.cols,
                                gyouRange.at(x).end - gyouRange.at(x).start);
            }
            cv::rectangle(colCutMask, wPos.tl(), wPos.br(), cv::Scalar::all(255), -1, cv::LINE_8, 0);
        }
        cv::bitwise_not(colCutMask, colCutMask);
        cv::findContours(colCutMask, vctContours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
        for (int i = 0; i < vctContours.size(); i++){
            cv::Rect gyouRect = cv::boundingRect(vctContours.at(i));
            if(gyouRect.tl().x < 0){
                gyouRect = cv::Rect(cv::Point(0,gyouRect.tl().y), gyouRect.br());
            }
            if(gyouRect.tl().y < 0){
                gyouRect = cv::Rect(cv::Point(gyouRect.tl().x,0), gyouRect.br());
            }
            gyouPos.push_back(gyouRect);
            gyou.push_back(cv::Mat(img, gyouRect));
        }
        return;
    }
    
    void splitChar(cv::Mat gyou, cv::Mat binImg, bool isTate, std::vector<cv::Rect>& mojiPos, std::vector<cv::Mat>& chars){
        std::vector<cv::Range> charRange;
        std::vector<std::vector<cv::Point> > vctContours;
        
        cv::Mat src;
        getInteglal(binImg,src);
        if(isTate){
            charRange = searchRows(src);
        }else{
            charRange = searchColumns(src);
        }
        cv::Mat charCutMask = cv::Mat::zeros(gyou.rows, gyou.cols, CV_8UC1);
        cv::Rect cPos;
        for(int x = 0; x < charRange.size(); x++){
            if(isTate){
                cPos = cv::Rect(0,
                                charRange.at(x).start,
                                gyou.cols,
                                charRange.at(x).end - charRange.at(x).start);
            }else{
                cPos = cv::Rect(charRange.at(x).start,
                                0,
                                charRange.at(x).end - charRange.at(x).start,
                                gyou.rows);
            }
            cv::rectangle(charCutMask, cPos.tl(), cPos.br(), cv::Scalar::all(255), -1, cv::LINE_8, 0);
        }
        cv::bitwise_not(charCutMask, charCutMask);
        cv::findContours(charCutMask, vctContours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
        for (int i = 0; i < vctContours.size(); i++){
            cv::Rect charRect = cv::boundingRect(vctContours.at(i));
            if(charRect.tl().x < 0){
                charRect = cv::Rect(cv::Point(0,charRect.tl().y), charRect.br());
            }
            if(charRect.tl().y < 0){
                charRect = cv::Rect(cv::Point(charRect.tl().x,0), charRect.br());
            }
            
            mojiPos.push_back(charRect);
            chars.push_back(cv::Mat(gyou, charRect));
        }
        return;
    }
    
    // 面積計算アルゴリズム（画素数）
    int calculateArea(cv::Mat image) {
        cv::Mat grayMat;
        cv::cvtColor(image, grayMat, cv::COLOR_BGR2GRAY);
        return cv::countNonZero(grayMat);
    }
    
    // ユークリッドの互除法を用いてaとbの最大公約数を求める
    int Gcd(int a, int b) {
        if(a < b) {
            return Gcd(b, a); // a >= bとなるように
        }
        while(b != 0) {
            int temp = a % b;
            a = b;
            b = temp;
        }
        return a;
    }
    
};
#endif /* defined(__DiffImgCV__CvUtil__) */
