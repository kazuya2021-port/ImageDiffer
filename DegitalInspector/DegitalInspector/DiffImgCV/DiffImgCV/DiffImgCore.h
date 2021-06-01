//
//  DiffImgCore.h
//  DiffImgCV
//
//  Created by 内山和也 on 2019/04/16.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#ifndef __DiffImgCV__DiffImgCore__
#define __DiffImgCV__DiffImgCore__

#include "jansson.h"
#include <stdio.h>
#include <iostream>
#include <algorithm>
#include <set>
#include <opencv2/opencv.hpp>
#include <opencv2/core/base.hpp>
#include <opencv2/flann/miniflann.hpp>
#include "CvUtil.hpp"
#include "DBScan.h"

#import <Foundation/Foundation.h>
#import <KZImage/ImageEnum.h>

#define EXT_CROP_SIZE 30 // 比較対象の切り抜きサイズ
#define MATCH_THRESH 0.97 // 比較の閾値
#define BG_COLOR cv::Scalar(255) // 背景色
#define VIEW_SCALE 2.0 // マッチングの拡大率
#define THUMB_SIZE 0.5 // psd保存時のサムネイルサイズ

@class DiffImgCV;

class DiffImgCore
{
public:
    int ngCount = 0;
    
    struct DiffResult{
        std::vector<std::vector<std::vector<cv::Point> > > addAreas;
        std::vector<std::vector<std::vector<cv::Point> > > delAreas;
        std::vector<std::vector<std::vector<cv::Point> > > diffAreas;
        DiffResult();
    };
    
    enum CHECKResult {
        CHECK_OK = 1, // 差分なし
        CHECK_DIF = 2, // 差分
        CHECK_ADD = 3, // 追加
        CHECK_DEL = 4, // 削除
        CHECK_END = 99
    };
    
    struct SettingValue{
        float backConsentration = 0; // 半調の濃度
        float gapPix = 0; // 位置誤差
        int noizeReduction = 0; // モルフォジー回数
        int threthDiff = 0; // 誤差検知感度
        float matchThresh = 0.0; // templateMatchの閾値
        int adjustMode = 0; // adjust方式
        int lineThickness = 0; // 罫線の太さ
        bool isFillLine = false; // 塗りつぶし
        bool isAllDiffColor = false; // 全てを差分の色で
        bool isAllDelColor = false; // 全てを削除の色で
        bool isAllAddColor = false; // 全てを追加の色で
        cv::Scalar addColor = cv::Scalar::all(0); // 追加の色
        cv::Scalar delColor = cv::Scalar::all(0); // 削除の色
        cv::Scalar diffColor = cv::Scalar::all(0); // 差分の色
        cv::Scalar backAlphaColor = cv::Scalar::all(0); // 半調の色
        std::string diffDispMode = [NSLocalizedStringFromTable(@"DiffModeArround", @"Preference", nil) UTF8String]; // 差分の表示方法
        std::string aoAkaMode = [NSLocalizedStringFromTable(@"AoAkaModeNone", @"Preference", nil) UTF8String];
        std::string prefix = "";
        std::string suffix = "";
        int rasterDpi = 0; // ラスタライズ解像度
        int colorSpace = (int)KZColorSpace::SRGB; // 読み込みのカラーモード
        bool isSaveNoChange = false; // 差分ない場合保存するか
        bool isSaveLayered = true; // レイヤ保存
        bool isSaveColor = true; // カラー保存
        bool isForceResize = false; // ラスタライズ時のリサイズ
        int saveType = (int)KZFileFormat::PSD_FORMAT;
        
        //
        int startPage = 1; // 処理するページの範囲
        int endPage = 1; // 処理するページの範囲
    };
    
    SettingValue setting;
    cv::Mat bitDiffImg;
    cv::Mat bitDiffImgL;
    
    DiffImgCore();
    ~DiffImgCore();
    
    int eraseSamePos(cv::Mat orgDifS, cv::Mat orgDifT, cv::Mat orgDifSE, cv::Mat orgDifTE, cv::Mat &maskS, cv::Mat &maskT);
    // 濃度のチェック
    
    int adjustMaskPosition(cv::Mat source, cv::Mat trg, cv::Mat &maskS, cv::Mat &maskSorg, cv::Mat &maskSorgbin, bool isRound, cv::Point &shift);
    bool adjustMaskImage(cv::Mat &maskedS, cv::Mat &maskedT, cv::Mat binSE, cv::Mat binTE, cv::Rect roiRect);
    void registerSetting(char* jsonString);
    // saveは保存フォルダのパス

    void test(NSArray* ar,const char* file);
    cv::Mat openImg(NSData* img);
//    NSData* getRawDataFromCV(cv::Mat img);
    bool adjustSize(cv::Mat& src, cv::Mat& dst, int mode);
    void convertBlueRedImg(cv::Mat& imgBlue, cv::Mat& imgRed);
    NSData* encodeMatToData(cv::Mat img, const cv::String type);
    cv::Mat getAlphaBlendImg(cv::Mat src, cv::Mat trg);
    std::vector<cv::Rect> getDiffRects(cv::Mat imgS, cv::Mat imgT, NSMutableDictionary** info, std::vector<cv::Rect> &illustAreas, std::vector<cv::Rect> &txtAreas);
    void cvtGrayIfColor(cv::Mat in, cv::Mat &out);
    void resizeImage(cv::Mat src, cv::Mat& dst, double scale);
    //std::vector<cv::Rect>
    void diff(cv::Mat crpS, cv::Mat crpT, cv::Mat crpSBE, cv::Mat crpTBE, cv::Rect cropRect, DiffResult& diff_result, double match_thresh, bool isIllust, std::vector<cv::Rect> &textArea, int extCropSize);
    void drawDiffContours(cv::Mat& diffAdd, DiffResult res);
    
    void dbgSave(cv::Mat img, const char* name) {
        util->dbgSave(img, name, false);
    }
    
    

private:
    CvUtil *util;
    
    void diffprocess(DiffResult& diff_result, std::vector<std::vector<cv::Point> > curCnt);
    void delprocess(DiffResult& diff_result, std::vector<std::vector<cv::Point> > curCnt);
    void addprocess(DiffResult& diff_result, std::vector<std::vector<cv::Point> > curCnt);
    void makeShadeMask (cv::Mat rS, cv::Mat rT, cv::Mat maskS, cv::Mat maskT, float thresh, cv::Mat &result);
    void fillCheckedContour(cv::Mat &bitDiff, cv::Mat absMat);
    void getDiffArea(cv::Mat rS, cv::Mat rT, cv::Mat binS, cv::Mat binT, cv::Mat centerDiff, cv::Mat bitDiff, cv::Mat &outS, cv::Mat &outT, cv::Mat &mulCompo, int extCrop);
    
    
    
    
    
    
    
    std::vector<cv::Rect> getColRects(cv::Mat &img);
    std::vector<cv::Rect> getRowRects(cv::Mat &img);
    std::vector<cv::Rect> getMatrixRects(cv::Mat &img);
    
    cv::Mat openImg(const char* path);
    cv::Point getDiffPos(cv::Mat cmpS, cv::Mat cmpT);
    
    void getABSDiffImg(cv::Mat src, cv::Mat trg, cv::Mat& dst);
    // for writeContour
    bool getIfAllColor(cv::Scalar& fillColor);
    void writeContourMain(std::function<void(cv::Mat&,cv::Scalar,cv::Scalar,std::vector<std::vector<cv::Point>>,int,bool)> write,
                          cv::Mat& diffAdd, DiffResult res);
    
    // for setting
    void setColor(json_t *value, cv::Scalar *trg);
    
    // for diff
    cv::Rect checkMove(cv::Mat rS, cv::Mat rT, cv::Mat maskS, cv::Mat maskT, cv::Mat absMat,
                       cv::Rect cropRect, DiffResult& diff_result, int extCropSize,
                       double &poc_result, cv::Point &shift, cv::Mat &sikisa);
//    std::vector<cv::Mat> getAbstractComponent(cv::Mat rS, cv::Mat rT, cv::Mat sikisa, cv::Rect &roi, cv::Mat &abs);
    void getAbstractComponent(cv::Mat rS, cv::Mat rT, cv::Mat sikisa, cv::Rect &roi, cv::Mat &abs);
    std::vector<cv::Mat> splitComponent(cv::Mat img);
    
    struct ExtractInfo{
        int extractStatus = -1;
        std::vector<cv::Mat> srcMats; // 分解した差分イメージ
        std::vector<cv::Rect> srcRects;
        std::vector<cv::Mat> trgMats; // 分解した差分イメージ
        std::vector<cv::Rect> trgRects;
        std::vector<std::vector<std::vector<cv::Point>>> diffContours;
    };
    
    // 配列内の重複エリアをマージして返す
    std::vector<cv::Rect> mergeOverWrappedRect(std::vector<cv::Rect> in_rects)
    {
        std::vector<cv::Rect> out_rects, tmp_rects;
        for (int i = 0; i < in_rects.size(); i++) {
            cv::Rect over = in_rects.at(i);
            for (int j = 0; j < in_rects.size(); j++) {
                cv::Rect chk_over = in_rects.at(i) & in_rects.at(j);
                if (chk_over != cv::Rect(0,0,0,0)) {
                    over |= in_rects.at(j);
                }
            }
            tmp_rects.push_back(over);
        }

        for (int i = 0; i < tmp_rects.size(); ++i) {
            bool isSame = false;
            cv::Rect rc = tmp_rects.at(i);
            for (int j = 0; j < tmp_rects.size(); ++j) {
                if (isSame && rc == tmp_rects.at(j)) {
                    tmp_rects.erase(tmp_rects.begin() + j);
                }
                else if (rc == tmp_rects.at(j)) {
                    isSame = true;
                }
            }
        }
        
        out_rects = std::vector<cv::Rect>(tmp_rects);
        return out_rects;
    }
    
    // 入力画像を部品別に分解
    void splitImg(cv::Mat img_bin, cv::Mat img,
                  std::vector<cv::Rect>& split_rect,
                  std::vector<cv::Mat>& split_img)
    {
        std::vector<std::vector<cv::Point>> vcnt;
        std::vector<cv::Rect> rects, tmp_rects;
        std::vector<cv::Mat> masks;
        
        cv::findContours(img_bin, vcnt, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
        
        //util->dbgSave(img_bin, "img_bin.tif", false);
        //util->dbgSave(img, "img.tif", false);
        
        for (auto it = vcnt.begin(); it != vcnt.end(); ++it) {
            tmp_rects.push_back(cv::boundingRect(*it));
            std::vector<cv::Point> pts;
        }
        
        rects = mergeOverWrappedRect(tmp_rects);
        tmp_rects.clear();
        cv::Rect imgSize(0,0,img_bin.cols, img_bin.rows);
        bool isImgSize = false;
        for (auto it = rects.begin(); it != rects.end(); ++it) {
            if (imgSize == *it) {
                isImgSize = true;
                break;
            }
        }
        if (isImgSize) {
            rects.clear();
            rects.push_back(imgSize);
        }
        if (rects.size() != 1) {
            // 一つの四角にまとまらなかった場合、クラスタリング
            tmp_rects.clear();
            util->rect_clustering(rects,tmp_rects,1);
            rects.clear();
            rects = std::vector<cv::Rect>(tmp_rects);
            std::sort(rects.begin(), rects.end(), byCenterDist());
            
            for (auto it = rects.begin(); it != rects.end(); ++it) {
                if (split_rect.at(0).width != it->width && split_rect.at(0).height != it->height)
                    split_rect.push_back(*it);
            }
        }
        else {
            if (split_rect.at(0).width != rects.at(0).width && split_rect.at(0).height != rects.at(0).height)
                split_rect.push_back(rects.at(0));
        }
        
        if (split_rect.size() > 1) {
            for (int i = 1; i < split_rect.size(); i++) {
                cv::Rect it = split_rect.at(i);
                cv::Mat smat;
                util->cropSafe(img, smat, it, false);
                cv::Mat parts(img_bin.size(), img.type(), cv::Scalar::all(255));
                cv::Mat roi_parts;
                util->cropSafe(parts, roi_parts, it, false);
                smat.copyTo(roi_parts);
                split_img.push_back(parts);
                //util->dbgSave(parts, "split_img.tif", i);
            }
        }
        
    }
    
//    void subtractImg(cv::Mat rS, cv::Mat rT, cv::Mat& out, double th)
//    {
//        cv::Mat bS,bT,sub,tmp;
//        if (rS.channels() == 1) {
//            cvtColor(rS, bS, cv::COLOR_GRAY2BGR);
//        }
//        else {
//            bS = rS.clone();
//        }
//        if (rT.channels() == 1) {
//            cvtColor(rT, bT, cv::COLOR_GRAY2BGR);
//        }
//        else {
//            bT = rT.clone();
//        }
//        
//        if (th == 0) {
//            out = subtract_halide(bS, bT, setting.threthDiff);
//        }
//        else {
//            out = subtract_halide(bS, bT, th);
//        }
//        cv::Canny(out, tmp, 0, 10);
//        if (th == 0) {
//            cv::threshold(tmp, out, 0, 255.0, cv::THRESH_OTSU);
//        }
//        else {
//            cv::threshold(tmp, out, th, 255.0, cv::THRESH_BINARY);
//        }
//    }
//    
//    ExtractInfo extractDiffImgs(cv::Mat rS, cv::Mat rT, cv::Mat bigS, cv::Mat bigT, cv::Rect cropRect, double match_thresh)
//    {
//        ExtractInfo retInfo;
//        std::vector<std::vector<cv::Mat>> difMats;
//        std::vector<cv::Rect> realDiffAreas;
//        cv::Mat binS, binT;
//        cv::Mat curS,curT,bS,bT,extS,extT,sub;
//        cv::Mat tmp_s,tmp_t;
//        
//        cv::Rect big_crop_rect(cropRect.x * VIEW_SCALE,cropRect.y * VIEW_SCALE,cropRect.width * VIEW_SCALE,cropRect.height * VIEW_SCALE);
//        cv::Rect ext_big_crop((cropRect.x - EXT_CROP_SIZE) * VIEW_SCALE,
//                             (cropRect.y - EXT_CROP_SIZE) * VIEW_SCALE,
//                             (cropRect.width + (EXT_CROP_SIZE * 2)) * VIEW_SCALE,
//                             (cropRect.height + (EXT_CROP_SIZE * 2)) * VIEW_SCALE);
//        
//        // 差分エリア抽出
//        util->cropSafe(bigS, bS, big_crop_rect, false);
//        util->cropSafe(bigT, bT, big_crop_rect, false);
//        util->cropSafe(rS, curS, cropRect, false);
//        util->cropSafe(rT, curT, cropRect, false);
//        
//        retInfo.extractStatus = chkNoImg(curS,curT);
//        if (retInfo.extractStatus == 1 || retInfo.extractStatus == 2) {
//            std::vector<std::vector<cv::Point>> cnts;
//            getContours(curS, curT, cropRect.tl(), cnts);
//            retInfo.diffContours.push_back(cnts);
//            return retInfo;
//        }
//        
//        cv::Rect cropSize = util->cropSafe(bigS, extS, ext_big_crop, false);
//        util->cropSafe(bigT, extT, ext_big_crop, false);
//        
//        
//        util->absDiffImg(bS, bT, sub, false, true);
//        util->dbgSave(sub, "abs_tst.png", false);
//        
//        cv::threshold(sub, sub, (double)(setting.threthDiff) / 1.0, 255.0, cv::THRESH_BINARY);
//        util->dbgSave(sub, "th_tst.png", false);
//        cv::Mat tmp(cv::Size(cropSize.width, cropSize.height), sub.type(), cv::Scalar::all(0));
//        cv::Rect win(big_crop_rect.x - cropSize.x,
//                     big_crop_rect.y - cropSize.y,
//                     sub.cols, sub.rows);
//        cv::Mat roi;
//        util->cropSafe(tmp, roi, win, true);
//        sub.copyTo(roi);
//        tmp.copyTo(sub);
//        
//        extS.copyTo(tmp_s);
//        extT.copyTo(tmp_t);
//        
//        util->cvtGrayIfColor(tmp_s, tmp_s);
//        util->cvtGrayIfColor(tmp_t, tmp_t);
//        
//        cv::threshold(tmp_s, tmp_s, 220, 255, cv::THRESH_BINARY_INV);
//        cv::threshold(tmp_t, tmp_t, 220, 255, cv::THRESH_BINARY_INV);
//        
//        cv::Mat label_s,label_t;
//        auto labs_s = util->getLabel(tmp_s, label_s);
//        auto labs_t = util->getLabel(tmp_t, label_t);
//        auto found_s = util->searchNearImg(labs_s, label_s, tmp_s, sub);
//        auto found_t = util->searchNearImg(labs_t, label_t, tmp_t, sub);
//        if ((found_s.rect == cv::Rect(0,0,0,0)) && (found_t.rect == cv::Rect(0,0,0,0))) {
//            retInfo.extractStatus = 3;
//            std::vector<std::vector<cv::Point>> cnts;
//            DiffImgCore::getContours(curS, curT, cropRect.tl(), cnts);
//            retInfo.diffContours.push_back(cnts);
//            return retInfo;
//        }
//        else if (found_s.rect == cv::Rect(0,0,0,0)) {
//            found_s.rect = found_t.rect;
//        }
//        else if (found_t.rect == cv::Rect(0,0,0,0)) {
//            found_t.rect = found_s.rect;
//        }
//        
//        
//        if (round(abs(found_s.rect.x - found_t.rect.x) / VIEW_SCALE) >= setting.gapPix ||
//            round(abs(found_s.rect.y - found_t.rect.y) / VIEW_SCALE) >= setting.gapPix) {
//            // 見つかった領域の位置が設定よりズレている場合
//            CvUtil::MatchingResult result = util->tmplateMatch(bS, bT, match_thresh, 1);
//            if (!result.isMatch) {
//                retInfo.extractStatus = 3;
//                std::vector<std::vector<cv::Point>> cnts;
//                getContours(curS, curT, cropRect.tl(), cnts);
//                retInfo.diffContours.push_back(cnts);
//                return retInfo;
//            }
//            else {
//                retInfo.extractStatus = -1;
//                std::vector<std::vector<cv::Point>> cnts;
//                getContours(curS, curT, cropRect.tl(), cnts);
//                retInfo.diffContours.push_back(cnts);
//                return retInfo;
//            }
//        }
//        
//        // 差分エリアを分解
//        cv::Mat crpS,crpT;
//        cv::Mat fcrpS,fcrpT;
//        cv::Size largerSize((found_s.rect.width < found_t.rect.width)? found_s.rect.width : found_t.rect.width,
//                            (found_s.rect.height < found_t.rect.height)? found_s.rect.height : found_t.rect.height);
//        cv::Rect founds_merg(found_s.rect.x, found_s.rect.y,largerSize.width, largerSize.height);
//        cv::Rect foundt_merg(found_t.rect.x, found_t.rect.y,largerSize.width, largerSize.height);
//        cv::Rect mergSRect(cropSize.x + found_s.rect.x, cropSize.y + found_s.rect.y,largerSize.width, largerSize.height);
//        cv::Rect mergTRect(cropSize.x + found_t.rect.x, cropSize.y + found_t.rect.y,largerSize.width, largerSize.height);
//        util->cropSafe(extS, crpS, founds_merg, true);
//        util->cropSafe(extT, crpT, foundt_merg, true);
//        util->cropSafe(found_s.img, fcrpS, founds_merg, true);
//        util->cropSafe(found_t.img, fcrpT, foundt_merg, true);
//        
//        retInfo.srcMats.push_back(crpS);
//        retInfo.trgMats.push_back(crpT);
//        retInfo.srcRects.push_back(mergSRect);
//        retInfo.trgRects.push_back(mergTRect);
//        splitImg(fcrpS, crpS, retInfo.srcRects, retInfo.srcMats);
//        splitImg(fcrpT, crpT, retInfo.trgRects, retInfo.trgMats);
//        
//        // 輪郭情報取得
//        if (retInfo.srcMats.size() == retInfo.trgMats.size()) {
//            if (retInfo.srcMats.size() == 1) {
//                retInfo.extractStatus = 5;
//                std::vector<std::vector<cv::Point>> vcnt;
//                cv::Rect crop_s = retInfo.srcRects.at(0);
//                cv::Rect crop_t = retInfo.trgRects.at(0);
//                crop_s.x /= VIEW_SCALE; crop_s.y /= VIEW_SCALE;
//                crop_s.width /= VIEW_SCALE; crop_s.height /= VIEW_SCALE;
//                crop_t.x /= VIEW_SCALE; crop_t.y /= VIEW_SCALE;
//                crop_t.width /= VIEW_SCALE; crop_t.height /= VIEW_SCALE;
//                
//                util->cropSafe(rS, curS, crop_s, false);
//                util->cropSafe(rT, curT, crop_t, false);
//                getContours(curS, curT, crop_s.tl(), vcnt);
//                retInfo.diffContours.push_back(vcnt);
//                return retInfo;
//            }
//            else {
//                for (int i = 1; i < retInfo.srcRects.size(); i++) {
//                    
//                    std::vector<std::vector<cv::Point>> vcnt;
//                    cv::Rect sRect = retInfo.srcRects.at(i);
//                    sRect.x += mergSRect.x;
//                    sRect.y += mergSRect.y;
//                    
//                    cv::Rect tRect = retInfo.trgRects.at(i);
//                    tRect.x += mergTRect.x;
//                    tRect.y += mergTRect.y;
//                    
//                    if (sRect.width != tRect.width || sRect.height != tRect.height) {
//                        int w = (sRect.width < tRect.width)? sRect.width : tRect.width;
//                        int h = (sRect.height < tRect.height)? sRect.height : tRect.height;
//                        sRect.width = w;sRect.height = h;
//                        tRect.width = w;tRect.height = h;
//                        util->cropSafe(bigS, retInfo.srcMats.at(i), sRect, false);
//                        util->cropSafe(bigT, retInfo.trgMats.at(i), tRect, false);
//                        //util->dbgSave(retInfo.srcMats.at(i), "mat_s.tif", false);
//                        //util->dbgSave(retInfo.trgMats.at(i), "mat_t.tif", false);
//                    }
//                    
//                    if (sRect.width == 0 || tRect.width == 0 ||
//                        sRect.height == 0 || tRect.height == 0 ||
//                        sRect.x < 0 || sRect.y < 0 ||
//                        tRect.x < 0 || tRect.y < 0 ) {
//                        continue;
//                    }
//                    
//                    sRect.x /= VIEW_SCALE;
//                    sRect.y /= VIEW_SCALE;
//                    sRect.width /= VIEW_SCALE;
//                    sRect.height /= VIEW_SCALE;
//                    tRect.x /= VIEW_SCALE;
//                    tRect.y /= VIEW_SCALE;
//                    tRect.width /= VIEW_SCALE;
//                    tRect.height /= VIEW_SCALE;
//                    util->cropSafe(rS, curS, sRect, false);
//                    util->cropSafe(rT, curT, tRect, false);
//                    
//                    getContours(curS, curT, sRect.tl(), vcnt);
//                    retInfo.diffContours.push_back(vcnt);
//                }
//            }
//        }
//        else {
//            // 同じように分解できない場合
//            cv::Rect crop_s = retInfo.srcRects.at(0);
//            cv::Rect crop_t = retInfo.trgRects.at(0);
//            retInfo.extractStatus = 4;
//            std::vector<std::vector<cv::Point>> vcnt;
//            
//            if (crop_s.width != crop_t.width || crop_s.height != crop_t.height) {
//                int w = (crop_s.width < crop_t.width)? crop_s.width : crop_t.width;
//                int h = (crop_s.height < crop_t.height)? crop_s.height : crop_t.height;
//                crop_s.width = w;crop_s.height = h;
//                crop_t.width = w;crop_t.height = h;
//                util->cropSafe(bigS, retInfo.srcMats.at(0), crop_s, false);
//                util->cropSafe(bigT, retInfo.trgMats.at(0), crop_t, false);
//                //util->dbgSave(retInfo.srcMats.at(0), "mat_s.tif", false);
//                //util->dbgSave(retInfo.trgMats.at(0), "mat_t.tif", false);
//                crop_s.x /= VIEW_SCALE; crop_s.y /= VIEW_SCALE;
//                crop_s.width /= VIEW_SCALE; crop_s.height /= VIEW_SCALE;
//                crop_t.x /= VIEW_SCALE; crop_t.y /= VIEW_SCALE;
//                crop_t.width /= VIEW_SCALE; crop_t.height /= VIEW_SCALE;
//                util->cropSafe(rS, curS, crop_s, false);
//                util->cropSafe(rT, curT, crop_t, false);
//                getContours(curS, curT, crop_s.tl(), vcnt);
//                retInfo.diffContours.push_back(vcnt);
//            }
//            else {
//                crop_s.x /= VIEW_SCALE; crop_s.y /= VIEW_SCALE;
//                crop_s.width /= VIEW_SCALE; crop_s.height /= VIEW_SCALE;
//                crop_t.x /= VIEW_SCALE; crop_t.y /= VIEW_SCALE;
//                crop_t.width /= VIEW_SCALE; crop_t.height /= VIEW_SCALE;
//                
//                util->cropSafe(rS, curS, crop_s, false);
//                util->cropSafe(rT, curT, crop_t, false);
//                getContours(curS, curT, crop_s.tl(), vcnt);
//                retInfo.diffContours.push_back(vcnt);
//                return retInfo;
//            }
//        }
//        
//        retInfo.extractStatus = 0;
//        
//        return retInfo;
//    }
    
    
    
    bool chkNoImg(cv::Mat rS, cv::Mat rT, DiffResult& diff_result, std::vector<std::vector<cv::Point> > curCnt)
    {
        bool isNoImgS = false;
        bool isNoImgT = false;
        isNoImgS = util->isWhiteImage(rS);
        isNoImgT = util->isWhiteImage(rT);
        if(isNoImgS && !isNoImgT){
            addprocess(diff_result, curCnt);
            return false;
        }
        if(!isNoImgS && isNoImgT){
            delprocess(diff_result, curCnt);
            return false;
        }
        return true;
    }
    
    int chkNoImg(cv::Mat rS, cv::Mat rT)
    {
        bool isNoImgS = false;
        bool isNoImgT = false;
        
        isNoImgS = util->isWhiteImage(rS);
        isNoImgT = util->isWhiteImage(rT);
        if(isNoImgS && !isNoImgT){
            return 1; // add
        }
        if(!isNoImgS && isNoImgT){
            return 2; // del
        }
        return 0;
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    


    
    
    
    
    
    int chkCharacter(cv::Mat rS, cv::Mat rT, cv::Rect difPos, cv::Rect& chkSPos, cv::Rect& chkTPos)
    {
        /*bool isNoImgS = false;
        bool isNoImgT = false;
        
        std::vector<cv::Rect> sPos,tPos;
        cv::Mat chkS,chkT, imgS, imgT;
        cv::pyrUp(rS, imgS);
        cv::pyrUp(imgS, imgS);
        cv::pyrUp(rT, imgT);
        cv::pyrUp(imgT, imgT);
        
        util->scanCharactors(imgS,sPos);
        util->scanCharactors(imgT,tPos);
        
        std::map<int,int> overInfo; // Valueがインデックス、Keyがエリアの大きさ
        
        for(int i = 0; i < sPos.size(); i++){
            cv::Rect chkRect = difPos & sPos.at(i);
            if(chkRect.area() != 0){
                overInfo[chkRect.area()] = i;
            }
        }
        if(overInfo.size() == 0){
            isNoImgS = true;
        }else{
            auto pr = std::max_element(std::begin(overInfo), std::end(overInfo));
            // 最大エリアが中心のアイテム
            chkSPos = sPos.at(pr->second);
            util->cropSafe(imgS, chkS, chkSPos, true);
            
            overInfo.clear();
        }
        
        for(int i = 0; i < tPos.size(); i++){
            cv::Rect chkRect = difPos & tPos.at(i);
            if(chkRect.area() != 0){
                overInfo[chkRect.area()] = i;
            }
        }
        if(overInfo.size() == 0){
            isNoImgT = true;
        }else{
            auto pr = std::max_element(std::begin(overInfo), std::end(overInfo));
            // 最大エリアが中心のアイテム
            chkTPos = tPos.at(pr->second);
            util->cropSafe(imgT, chkT, chkTPos, true);
        }
        
        if((chkTPos.width / 4 == rT.cols) && (chkTPos.height / 4 == rT.rows)){
            chkTPos = cv::Rect(0,0,0,0);
        }
        if((chkSPos.width / 4 == rS.cols) && (chkSPos.height / 4 == rS.rows)){
            chkSPos = cv::Rect(0,0,0,0);
        }
        if(chkSPos.width > difPos.width && chkSPos.height > difPos.height){
            chkSPos = cv::Rect(0,0,0,0);
        }
        if(chkTPos.width > difPos.width && chkTPos.height > difPos.height){
            chkTPos = cv::Rect(0,0,0,0);
        }
        
        //if(chkSPos.width == 0 && chkTPos.width == 0){
         //   isTateS = true;
         //   isTateT = true;
         //}
        
        //if(!isNoImgS) isNoImgS = util->isWhiteImage(chkS);
        //if(!isNoImgT) isNoImgT = util->isWhiteImage(chkT);
        
        if(isNoImgS && !isNoImgT){
            return 1;
        }
        if(!isNoImgS && isNoImgT){
            
            return 2;
        }
        */
        return 0;
    }
    
    cv::Rect getNearestAreaRect(std::vector<CvUtil::LabelItem> list, int area){
        int i = 1;
        int num;
        int mina;
        if(1 > list.size()) return cv::Rect(0,0,0,0);
        
        num = 0;
        mina = abs(list.at(0).rect.area() - area);
        for(auto it = list.begin()+1; it != list.end(); ++it){
            if(abs(it->rect.area() - area) < mina){
                num = i;
                mina = abs(it->rect.area() - area);
            }
            ++i;
        }
        return list.at(num).rect;
    }
    
    struct byCenterDist {
        bool operator () (const cv::Rect & a, const cv::Rect & b){
            cv::Point2f ac = (a.tl() + a.br()) * 0.5;
            cv::Point2f bc = (b.tl() + b.br()) * 0.5;
            double ad = std::sqrt(ac.x*ac.x+ac.y*ac.y);
            double bd = std::sqrt(bc.x*bc.x+bc.y*bc.y);
            return (ad < bd);
        }
    };
    
    /*int chkPinPoint(cv::Mat overImgS, cv::Mat overImgT, cv::Mat overImgA)
    {
        cv::Mat S2,T2,labelS,labelT;
        std::vector<std::vector<cv::Point> > vctContoursA,vctContoursS,vctContoursT;
        util->cvtGrayIfColor(overImgS, overImgS);
        util->cvtGrayIfColor(overImgT, overImgT);
        cv::threshold(overImgS, S2, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
        cv::threshold(overImgT, T2, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
        cv::findContours(overImgA, vctContoursA, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
        cv::findContours(S2, vctContoursS, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
        cv::findContours(T2, vctContoursT, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
        
        auto nLabS = util->getLabel(S2, labelS);
        auto nLabT = util->getLabel(T2, labelT);
        auto foundS = util->searchNearImg(nLabS, labelS, overImgS, overImgA);
        auto foundT = util->searchNearImg(nLabT, labelT, overImgT, overImgA);
        
        if(!foundS.isFound && !foundT.isFound){
            std::cout << "ありえない！" << std::endl;
            return 3;
        }
        else if((foundS.isFound && !foundT.isFound) || (!foundS.isFound && foundT.isFound)){
            return 3;
        }
        
        cv::Rect cropOrg = foundS.rect | foundT.rect;
        int crop_pix_c = overImgS.cols / 5;
        int crop_pix_r = overImgS.rows / 5;
        int crop_pix = (crop_pix_c > crop_pix_r)? crop_pix_r : crop_pix_c;
        cv::Rect crop = cv::Rect(cropOrg.x + crop_pix,
                                 cropOrg.y + crop_pix,
                                 cropOrg.width - (crop_pix * 2),
                                 cropOrg.height - (crop_pix * 2));
        
        if(crop.width <= 1 || crop.height <= 1){
            crop = cropOrg;
        }
        
        cv::Mat tpl,targ,dImg;
        cv::Point2d shift;
        util->cropSafe(overImgT, tpl, crop, true);
        util->cropSafe(overImgS, targ, crop, true);

        CvUtil::MatchingResult rest = util->tmplateMatch(tpl, targ, 0.8, VIEW_SCALE);
        
        if(!rest.isMatch){
            return 3;
        }else{
            if(rest.val > 0.95) return 0;
            
            util->cropSafe(overImgT, tpl, crop, true);
            util->cropSafe(overImgS, targ, crop, true);
            
            double resl;
            cv::Mat hann, sbdiff, moved;
            
            std::cout << tpl.size().width << std::endl;
            std::cout << tpl.size().height << std::endl;
            cv::createHanningWindow(hann, tpl.size(), CV_32F);
            tpl.convertTo(S2, CV_32F);
            targ.convertTo(T2, CV_32F);
            cv::Point2d shift = cv::phaseCorrelate(S2, T2, hann, &resl);
            if(round(shift.x / 4) > setting.gapPix ||
                round(shift.y / 4) > setting.gapPix){
                return 3;
            }
            
            cv::Canny(tpl, S2, 0, 10);
            cv::Canny(targ, T2, 0, 10);
            util->deleteMinimumArea(S2);
            util->deleteMinimumArea(T2);
            
            cv::findContours(S2, vctContoursS, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
            cv::findContours(T2, vctContoursT, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
            
            std::vector<cv::Rect> src_v, trg_v;
            cv::Rect maxS, maxT;
            if(vctContoursS.size() != 1){
                for(int i = 0; i < vctContoursS.size(); i++){
                    cv::Rect rc =  cv::boundingRect(vctContoursS.at(i));
                    src_v.push_back(rc);
                }
                for(cv::Rect r : src_v)
                {
                    maxS |= r;
                }

            }else{
                maxS = cv::boundingRect(vctContoursS.at(0));
            }
            
            if(vctContoursT.size() != 1){
                for(int i = 0; i < vctContoursT.size(); i++){
                    cv::Rect rc =  cv::boundingRect(vctContoursT.at(i));
                    trg_v.push_back(rc);
                }
                for(cv::Rect r : trg_v)
                {
                    maxT |= r;
                }
            }else{
                maxT = cv::boundingRect(vctContoursT.at(0));
            }
            
            int totalDiffW = abs(maxS.width - maxT.width);
            int totalDiffH = abs(maxS.height - maxT.height);
            if(round(totalDiffW / 4) > setting.gapPix ||
               round(totalDiffH / 4) > setting.gapPix){
                return 3;
            }
            
        }
        
        return 0;
    }*/
    
    
    
    
    
    
    
    /*********************/
    
    std::bitset<64> computeHash(cv::Mat in) {
        cv::Mat tmpRes;
        std::bitset<64> ret(0);
        int bitIdx = 0;
        cv::resize(in, tmpRes, cv::Size(9,8), 0, 0, cv::INTER_CUBIC);
        
        for (int y = 0; y < tmpRes.rows; y++) {
            uchar *px = tmpRes.ptr<uchar>(y);
            for (int x = 0; x < tmpRes.cols - 1; x++) {
                if (px[x] < px[x + 1]) {
                    ret.set(bitIdx);
                }
                else {
                    ret.reset(bitIdx);
                }
                bitIdx++;
            }
        }
        
        return ret;
    }
    
    template <class T>
    inline std::string to_string (const T& t)
    {
        std::stringstream ss;
        ss << t;
        return ss.str();
    }
    
    double ceil2(double d_in, int n_len) {
        double d_out;
        d_out = d_in * pow(10.0, n_len);
        d_out = (double)(int)(d_out + 0.9);
        return d_out * pow(10.0, -n_len);
    }
    
    double floor2(double d_in, int n_len) {
        double d_out;
        d_out = d_in * pow(10.0, n_len);
        d_out = (double)(int)(d_out);
        return d_out * pow(10.0, -n_len);
    }
    
    double round2(double d_in, int n_len) {
        double d_out;
        d_out = d_in * pow(10.0, n_len);
        d_out = (double)(int)(d_out + 0.5);
        return d_out * pow(10.0, -n_len);
    }
    
    // 中心点が近い四角を探す
    cv::Rect getNearestRectCenter(std::vector<cv::Rect> list, cv::Point2f searchPoint, int kouho)
    {
        cv::Rect ret(0,0,0,0);
        std::vector<cv::Point2f> list_center;
        for(auto it = list.begin(); it != list.end(); ++it) {
            cv::Point2f c = (it->tl() + it->br()) * 0.5;
            list_center.push_back(c);
        }
        
        cv::flann::KDTreeIndexParams indexParams;
        cv::flann::Index kdtree(cv::Mat(list_center).reshape(1), indexParams);
        
        std::vector<float> query;
        query.push_back(searchPoint.x);
        query.push_back(searchPoint.y);
        
        std::vector<int> indices;
        std::vector<float> dists;
        kdtree.knnSearch(query, indices, dists, kouho);
        for (auto it = indices.begin(); it != indices.end(); ++it) {
            ret |= list.at(*it);
        }
        return ret;
    }
    
    // 詳しい差分エリア取得
//    cv::Rect getDiffRect(cv::Mat rS, cv::Mat rT, int thresh)
//    {
//        cv::Mat sub = subtract_halide(rS, rT, thresh);
//        std::vector<cv::Rect> cntAreas;
//        std::vector<std::vector<cv::Point>> vctContours;
//        cv::Rect diffArea;
//        // 閾値を下げて輪郭とる
//        cv::findContours(sub, vctContours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
//
//        for (auto it = vctContours.begin(); it != vctContours.end(); ++it) {
//            cntAreas.push_back(cv::boundingRect(*it));
//        }
//
//        for (auto it = cntAreas.begin(); it != cntAreas.end(); ++it) {
//            diffArea |= *it;
//        }
//
//        return diffArea;
//    }
    
//    cv::Rect getContourRect(cv::Mat img, int thresh)
//    {
//        cv::Mat thImg;
//        
//        cv::threshold(img, thImg, 255 - thresh, 255, cv::THRESH_BINARY_INV);
//        
//        std::vector<cv::Rect> cntAreas;
//        std::vector<std::vector<cv::Point>> vctContours;
//        cv::Rect diffArea;
//        
//        // 閾値を下げて輪郭とる
//        cv::findContours(thImg, vctContours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
//        
//        for (auto it = vctContours.begin(); it != vctContours.end(); ++it) {
//            cntAreas.push_back(cv::boundingRect(*it));
//        }
//        
//        for (auto it = cntAreas.begin(); it != cntAreas.end(); ++it) {
//            diffArea |= *it;
//        }
//        
//        return diffArea;
//    }
    
    cv::Rect getRealDiffRect(cv::Mat rS, cv::Mat rT, cv::Mat rA, cv::Rect& diffOver){
        cv::Mat bitS,bitT,bitA;
        std::vector<cv::Rect> cntAreasS, cntAreasT, cntAreasA;
        std::vector<std::vector<cv::Point>> vctContoursS, vctContoursT, vctContoursA;
        cv::Rect diffArea;
        // 閾値を下げて輪郭とる
        cv::threshold(rS, bitS, 235, 255, cv::THRESH_BINARY_INV);
        cv::threshold(rT, bitT, 235, 255, cv::THRESH_BINARY_INV);
        cv::threshold(rA, bitA, 20, 255, cv::THRESH_BINARY);
        
        cv::findContours(bitS, vctContoursS, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
        cv::findContours(bitT, vctContoursT, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
        cv::findContours(bitA, vctContoursA, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
        
        for (auto it = vctContoursS.begin(); it != vctContoursS.end(); ++it) {
            cntAreasS.push_back(cv::boundingRect(*it));
        }
        for (auto it = vctContoursT.begin(); it != vctContoursT.end(); ++it) {
            cntAreasT.push_back(cv::boundingRect(*it));
        }
        for (auto it = vctContoursA.begin(); it != vctContoursA.end(); ++it) {
            cntAreasA.push_back(cv::boundingRect(*it));
        }
        for (auto it = cntAreasA.begin(); it != cntAreasA.end(); ++it) {
            diffArea |= *it;
        }
        cv::Point2f diffCenter = (diffArea.tl() + diffArea.br()) * 0.5;
        cv::Rect chkS = getNearestRectCenter(cntAreasS, diffCenter, cntAreasA.size());
        cv::Rect chkT = getNearestRectCenter(cntAreasT, diffCenter, cntAreasA.size());
        
        cv::Rect result;
        
        /*for (auto it = cntAreas.begin(); it != cntAreas.end(); ++it) {
            result |= *it;
        }
        for (auto it = cntAreasA.begin(); it != cntAreasA.end(); ++it) {
            diffOver |= *it;
        }
        */
        
        return result;
    }
    
//    cv::Point2d getPOCPos(cv::Mat src, cv::Mat trg, double* res_poc)
//    {
//        //CV_Assert((src.channels() == 1) && (trg.channels() == 1));
//
//        cv::Mat hann;
//        cv::Mat grayS,grayT;
//        cv::Mat tmpS,tmpT;
//        
//        auto clahe = cv::createCLAHE();
//        util->cvtGrayIfColor(src, grayS);
//        util->cvtGrayIfColor(trg, grayT);
//        clahe->apply(grayS, tmpS);
//        clahe->apply(grayT, tmpT);
//        
//        tmpS.convertTo(tmpS, CV_32F);
//        tmpT.convertTo(tmpT, CV_32F);
//        cv::createHanningWindow(hann, src.size(), CV_32F);
//        
//        cv::Point2d shift = cv::phaseCorrelate(tmpS, tmpT, hann, res_poc);
//        
//        if(abs(round(shift.x)/VIEW_SCALE) > setting.gapPix || abs(round(shift.y)/VIEW_SCALE) > setting.gapPix){
//            util->cvtGrayIfColor(src, grayS);
//            util->cvtGrayIfColor(trg, grayT);
//            grayS.convertTo(grayS, CV_32F);
//            grayT.convertTo(grayT, CV_32F);
//            
//            shift = cv::phaseCorrelate(grayS, grayT, hann, res_poc);
//        }
//       
//        return shift;
//    }
    
    // 指定した位置分移動する
    void moveImg(cv::Mat& trg, cv::Point2d shift, cv::Rect cropArea)
    {
        cv::Mat parts, result;
        
        parts = cv::Mat(trg, cropArea);
        trg.copyTo(result);
        
        // 差異部分消去
        cv::rectangle(result, cropArea.tl(), cropArea.br(), BG_COLOR, cv::FILLED);

        cv::Point delta(cropArea.tl().x + round(shift.x), cropArea.tl().y + round(shift.y));
        cv::Mat mat = (cv::Mat_<double>(2,3)<<1.0, 0.0, delta.x, 0.0, 1.0, delta.y);
        cv::warpAffine(parts, result, mat, result.size(), cv::INTER_CUBIC, cv::BORDER_TRANSPARENT);
        
        result.copyTo(trg);
    }

    // 輪郭ごとのイメージ取得
    std::vector<cv::Mat> getContourImages(cv::Mat img)
    {
        cv::Mat bitImg;
        util->cvtGrayIfColor(img, img);
        cv::threshold(img, bitImg, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
        
        cv::Mat stats;
        cv::Mat centroids;
        cv::Mat labelImg;
        int nLab = cv::connectedComponentsWithStats(bitImg, labelImg, stats, centroids);
        std::vector<cv::Mat> tmpImgs;
        for (int i = 1; i < nLab; ++i) {
            tmpImgs.push_back(cv::Mat::zeros(bitImg.size(), bitImg.type()));
        }
        
        for(int y = 0; y < labelImg.rows; ++y){
            int *l = labelImg.ptr<int>(y);
            uchar *p = bitImg.ptr<uchar>(y);
            for(int x = 0; x < labelImg.cols; ++x){
                if (l[x] == 0) continue;
                uchar *retP = tmpImgs.at(l[x] - 1).ptr<uchar>(y);
                retP[x] = p[x];
            }
        }
        
        return tmpImgs;
    }
    
    /*********************/
    
    
    
    int chkPinPoint(cv::Mat overImgS, cv::Mat overImgT, cv::Mat overImgA)
    {
        cv::Mat S2,T2,labelS,labelT;
        std::vector<std::vector<cv::Point>> vctContoursA,vctContoursS,vctContoursT;
        util->cvtGrayIfColor(overImgS, overImgS);
        util->cvtGrayIfColor(overImgT, overImgT);
        cv::threshold(overImgS, S2, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
        cv::threshold(overImgT, T2, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
        cv::findContours(overImgA, vctContoursA, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
        cv::findContours(S2, vctContoursS, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
        cv::findContours(T2, vctContoursT, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
        
        auto nLabS = util->getLabel(S2, labelS);
        auto nLabT = util->getLabel(T2, labelT);
        auto foundS = util->searchNearImg(nLabS, labelS, overImgS, overImgA);
        auto foundT = util->searchNearImg(nLabT, labelT, overImgT, overImgA);
        
        if(!foundS.isFound && !foundT.isFound){
            std::cout << "ありえない！" << std::endl;
            util->dbgSave(overImgS, "overImgS_pin.tif", ngCount);
            util->dbgSave(overImgT, "overImgT_pin.tif", ngCount);
            util->dbgSave(overImgA, "overImgA_pin.tif", ngCount);
            return 3;
        }
        else if((foundS.isFound && !foundT.isFound) || (!foundS.isFound && foundT.isFound)){
            util->dbgSave(overImgS, "overImgS_pin.tif", ngCount);
            util->dbgSave(overImgT, "overImgT_pin.tif", ngCount);
            util->dbgSave(overImgA, "overImgA_pin.tif", ngCount);
            return 3;
        }
        
        cv::Rect cropOrg = foundS.rect | foundT.rect;
        int crop_pix_c = overImgS.cols / 5;
        int crop_pix_r = overImgS.rows / 5;
        int crop_pix = (crop_pix_c > crop_pix_r)? crop_pix_r : crop_pix_c;
        cv::Rect crop = cv::Rect(cropOrg.x + crop_pix,
                                 cropOrg.y + crop_pix,
                                 cropOrg.width - (crop_pix * 2),
                                 cropOrg.height - (crop_pix * 2));
        
        if(crop.width < 0 || crop.height < 0){
            crop = cropOrg;
        }
        
        cv::Mat tpl,targ,dImg;
        cv::Point2d shift;
        util->cropSafe(overImgT, tpl, crop, true);
        util->cropSafe(overImgS, targ, crop, true);
        
        util->dbgSave(overImgS, "overImgS_pin.tif", ngCount);
        util->dbgSave(overImgT, "overImgT_pin.tif", ngCount);
        util->dbgSave(overImgA, "overImgA_pin.tif", ngCount);
        util->dbgSave(tpl, "tpl_pin.tif", ngCount);
        util->dbgSave(targ, "targ_pin.tif", ngCount);
        CvUtil::MatchingResult rest = util->tmplateMatch(tpl, targ, 0.8, VIEW_SCALE);
        
        if(!rest.isMatch){
            util->dbgSave(overImgS, "overImgS_pin.tif", ngCount);
            util->dbgSave(overImgT, "overImgT_pin.tif", ngCount);
            util->dbgSave(overImgA, "overImgA_pin.tif", ngCount);
            util->dbgSave(tpl, "tpl_pin.tif", ngCount);
            util->dbgSave(targ, "targ_pin.tif", ngCount);
            return 3;
        }else{
            if(rest.val > 0.95) return 0;
            
            util->cropSafe(overImgT, tpl, crop, true);
            util->cropSafe(overImgS, targ, crop, true);
            
            double resl;
            cv::Mat hann, sbdiff, moved;
            cv::createHanningWindow(hann, cv::Size(crop.width, crop.height), CV_32F);
            tpl.convertTo(S2, CV_32F);
            targ.convertTo(T2, CV_32F);
            cv::Point2d shift = cv::phaseCorrelate(S2, T2, hann, &resl);
            if(round(shift.x / 4) > setting.gapPix ||
               round(shift.y / 4) > setting.gapPix){
                util->dbgSave(overImgS, "overImgS_pin.tif", ngCount);
                util->dbgSave(overImgT, "overImgT_pin.tif", ngCount);
                util->dbgSave(overImgA, "overImgA_pin.tif", ngCount);
                util->dbgSave(tpl, "tpl_pin.tif", ngCount);
                util->dbgSave(targ, "targ_pin.tif", ngCount);
                return 3;
            }
            
            cv::Canny(tpl, S2, 0, 10);
            cv::Canny(targ, T2, 0, 10);
            util->deleteMinimumArea(S2, setting.noizeReduction);
            util->deleteMinimumArea(T2, setting.noizeReduction);
            
            cv::findContours(S2, vctContoursS, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
            cv::findContours(T2, vctContoursT, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
            
            std::vector<cv::Rect> src_v, trg_v;
            cv::Rect maxS, maxT;
            if(vctContoursS.size() != 1){
                for(int i = 0; i < vctContoursS.size(); i++){
                    cv::Rect rc =  cv::boundingRect(vctContoursS.at(i));
                    src_v.push_back(rc);
                }
                std::for_each(src_v.begin(), src_v.end(), [&maxS](cv::Rect r){
                    maxS |= r;
                });
            }else{
                maxS = cv::boundingRect(vctContoursS.at(0));
            }
            
            if(vctContoursT.size() != 1){
                for(int i = 0; i < vctContoursT.size(); i++){
                    cv::Rect rc =  cv::boundingRect(vctContoursT.at(i));
                    trg_v.push_back(rc);
                }
                std::for_each(trg_v.begin(), trg_v.end(), [&maxT](cv::Rect r){
                    maxT |= r;
                });
            }else{
                maxT = cv::boundingRect(vctContoursT.at(0));
            }
            
            int totalDiffW = abs(maxS.width - maxT.width);
            int totalDiffH = abs(maxS.height - maxT.height);
            if(round(totalDiffW / 4) > setting.gapPix ||
               round(totalDiffH / 4) > setting.gapPix){
                util->dbgSave(overImgS, "overImgS_pin.tif", ngCount);
                util->dbgSave(overImgT, "overImgT_pin.tif", ngCount);
                util->dbgSave(overImgA, "overImgA_pin.tif", ngCount);
                util->dbgSave(S2, "S2_pin.tif", ngCount);
                util->dbgSave(T2, "T2_pin.tif", ngCount);
                return 3;
            }
            
        }
        
        return 0;
    }
};
#endif /* defined(__DiffImgCV__DiffImgCore__) */
