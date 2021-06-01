 //
//  DiffImgCore.cpp
//  DiffImgCV
//
//  Created by 内山和也 on 2019/04/16.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#include "DiffImgCore.h"
#import "DiffImgCV.h"
#include <numeric>

NSData* encodeMatToData(cv::Mat img, const cv::String type);

using namespace std;
using namespace Halide;

#pragma mark -
#pragma mark Construct/Destruct

DiffImgCore::DiffResult::DiffResult(){
}

DiffImgCore::DiffImgCore()
{
    util = new CvUtil;
}

DiffImgCore::~DiffImgCore()
{
}

#pragma mark -
#pragma mark Halide

cv::Mat DiffImgCore::subtract_halide(cv::Mat src, cv::Mat trg, int threth){
    Func dst;
    
    cv::Mat result(src.size(), src.type());
    
    auto S = CvUtil::convertMat2Halide(src);
    auto T = CvUtil::convertMat2Halide(trg);
    
    Var x{"x"}, y{"y"}, c{"c"};
    Func dfimg = util->diff_img(S,T);
    Func th = util->thresh(dfimg, threth);
    Halide::Buffer<uint8_t> output = th.realize(S.width(), S.height(), S.channels());
    CvUtil::convertHalide2Mat(output, result);
    
    output.deallocate();
    
    return result;
}



#pragma mark -
#pragma mark Private Methods


NSData* encodeMatToData(cv::Mat img, const cv::String type)
{
    std::vector<uchar> buf;
    cv::imencode(type, img, buf);
    NSData *retData = [[NSData alloc] initWithBytes:buf.data() length:buf.size()];
    
    return retData;
}

cv::Mat DiffImgCore::getAlphaBlendImg(cv::Mat top, cv::Mat bottom){
    cv::Mat result;
    
    double a = 1 - (setting.backConsentration / 100.0);
    double b = (setting.backConsentration / 100.0);
    
    if(bottom.channels() != top.channels()) {
        if (top.channels() == 1) {
            util->cvtGrayIfColor(bottom, bottom);
        }
        else if (top.channels() == 3) {
            cv::cvtColor(bottom, bottom, cv::COLOR_GRAY2BGR);
        }
    }
    
    cv::addWeighted(bottom, a, top, b, 0.0, result);
    return result;
}

std::string DiffImgCore::getFileName(const std::string &str){
    string orgFileName = getLastPathComponent(str);
    std::vector<std::string> tmp = split(orgFileName, '.');
    if(tmp.size() == 2){
        return tmp[0];
    }else{
        std::string retFileName = tmp[0];
        for(int i = 1; i < tmp.size() - 1; i++){
            retFileName += ("." + tmp[i]);
        }
        return retFileName;
    }
}

std::string DiffImgCore::getLastPathComponent(const std::string &str){
    std::vector<std::string> tmp = split(str, '/');
    string orgFileName = tmp[tmp.size() - 1];
    
    return orgFileName;
}

std::vector<std::string> DiffImgCore::split(const std::string &str, char sep){
    std::vector<std::string> v;
    std::stringstream ss(str);
    std::string buffer;
    while( std::getline(ss, buffer, sep) ) {
        v.push_back(buffer);
    }
    return v;
}

bool DiffImgCore::getIfAllColor(cv::Scalar& color)
{
    if(setting.isAllAddColor){
        color = setting.addColor;
    }
    else if(setting.isAllDelColor){
        color = setting.delColor;
    }
    else if(setting.isAllDiffColor){
        color = setting.diffColor;
    }
    else{
        return false;
    }
    
    return true;
}

void DiffImgCore::writeContourMain(std::function<void(cv::Mat&,cv::Scalar,cv::Scalar,std::vector<std::vector<cv::Point>>,int,bool)> write,
                                   cv::Mat& diffAdd, DiffResult res){
    cv::Scalar fillColor;
    
    bool isAllColor = getIfAllColor(fillColor);
    
    for (int i = 0; i < res.addAreas.size(); i++) {
        auto contour = res.addAreas.at(i);
        if(isAllColor){
            write(diffAdd, fillColor, setting.backAlphaColor, contour, setting.lineThickness, setting.isFillLine);
        }
        else{
            write(diffAdd, setting.addColor, setting.backAlphaColor, contour, setting.lineThickness, setting.isFillLine);
        }
    }
    
    for (int i = 0; i < res.delAreas.size(); i++) {
        auto contour = res.delAreas.at(i);
        if(isAllColor){
            write(diffAdd, fillColor, setting.backAlphaColor, contour, setting.lineThickness, setting.isFillLine);
        }
        else{
            write(diffAdd, setting.addColor, setting.backAlphaColor, contour, setting.lineThickness, setting.isFillLine);
        }
    }
    
    for (int i = 0; i < res.diffAreas.size(); i++) {
        auto contour = res.diffAreas.at(i);
        if(isAllColor){
            write(diffAdd, fillColor, setting.backAlphaColor, contour, setting.lineThickness, setting.isFillLine);
        }
        else{
            write(diffAdd, setting.addColor, setting.backAlphaColor, contour, setting.lineThickness, setting.isFillLine);
        }
    }
}

void writeContour(cv::Mat& diffAdd ,cv::Scalar color, cv::Scalar fillcolor, std::vector<std::vector<cv::Point>>contour, int thick, bool isFill)
{
    
    if (isFill) {
        for (int i = 0; i < contour.size(); i++) {
            if(thick > 10) {
                cv::drawContours(diffAdd, contour, i, color, thick);
                cv::drawContours(diffAdd, contour, i, fillcolor, cv::FILLED);
            }
            else {
                cv::drawContours(diffAdd, contour, i, color, cv::FILLED);
            }
        }

    }
    else {
        for (int i = 0; i < contour.size(); i++)
            cv::drawContours(diffAdd, contour, i, color, thick);
        
    }
}

void rectContour(cv::Mat& diffAdd ,cv::Scalar color, cv::Scalar fillcolor, std::vector<std::vector<cv::Point>>contour, int thick, bool isFill)
{
    cv::Rect rc(0,0,0,0);
    for (auto it = contour.begin(); it != contour.end(); ++it) {
        rc |= cv::boundingRect(*it);
    }
    
    if (isFill) {
        cv::rectangle(diffAdd, rc.tl(), rc.br(), color, -1, cv::LINE_8, 0);
        for (int i = 0; i < contour.size(); i++) {
            cv::drawContours(diffAdd, contour, i, color, thick);
            cv::drawContours(diffAdd, contour, i, fillcolor, cv::FILLED);
        }
    }
    else {
        cv::rectangle(diffAdd, rc.tl(), rc.br(), color, thick, cv::LINE_8, 0);
    }
    
}

cv::Mat DiffImgCore::openImg(NSData* img)
{
    if (setting.colorSpace == (int)KZColorSpace::SRGB) {
        return cv::imdecode(cv::Mat(1, (int)img.length, CV_8UC3, (void*)img.bytes), cv::IMREAD_COLOR);
    }
    else {
        return cv::imdecode(cv::Mat(1, (int)img.length, CV_8UC1, (void*)img.bytes), cv::IMREAD_GRAYSCALE);
    }
}

cv::Mat DiffImgCore::openImg(const char* path)
{
    if (setting.colorSpace == (int)KZColorSpace::SRGB) {
        return cv::imread(path, cv::IMREAD_COLOR);
    }
    else {
        return cv::imread(path, cv::IMREAD_GRAYSCALE);
    }
}

void DiffImgCore::setColor(json_t *value, cv::Scalar *trg)
{
    const char *key_c;
    json_t *value_c;
    int bgrColor[3] = {0,0,0};
    int cmykColor[4] = {0,0,0,0};
    bool isCMYK = false;
    
    json_object_foreach(value, key_c, value_c) {
        switch (json_typeof(value_c)) {
            case JSON_INTEGER:
                if(!strcmp(key_c, "R")){
                    bgrColor[2] = (int)json_integer_value(value_c);
                }
                else if(!strcmp(key_c, "G")){
                    bgrColor[1] = (int)json_integer_value(value_c);
                }
                else if(!strcmp(key_c, "B")){
                    bgrColor[0] = (int)json_integer_value(value_c);
                }
                else if(!strcmp(key_c, "C")){
                    isCMYK = true;
                    cmykColor[2] = (int)json_integer_value(value_c);
                }
                else if(!strcmp(key_c, "M")){
                    cmykColor[1] = (int)json_integer_value(value_c);
                }
                else if(!strcmp(key_c, "Y")){
                    cmykColor[0] = (int)json_integer_value(value_c);
                }
                else if(!strcmp(key_c, "K")){
                    cmykColor[3] = (int)json_integer_value(value_c);
                }
                break;
                
            default:
                break;
        }
    }
    if(isCMYK){
        *trg = cv::Scalar(cmykColor[0],cmykColor[1],cmykColor[2],cmykColor[3]);
    }else{
        *trg = cv::Scalar(bgrColor[0],bgrColor[1],bgrColor[2]);
    }
}





//void DiffImgCore::diff(cv::Mat rS, cv::Mat rT, cv::Mat absImg, cv::Rect cropRect, DiffResult& diff_result, std::vector<std::vector<cv::Point> >& curCnt)
void DiffImgCore::diff(cv::Mat rS, cv::Mat rT, cv::Mat bigS, cv::Mat bigT, cv::Rect cropRect, DiffResult& diff_result)
{
    CvUtil::MatchingResult result;
    cv::Mat crpS, crpT;
    
    // rS, rTは元の全体画像の参照
    // cropRectは差分位置(おおまか)
    
    cv::Rect extCrop(cropRect.x - EXT_CROP_SIZE,
                     cropRect.y - EXT_CROP_SIZE,
                     cropRect.width + (EXT_CROP_SIZE * 2),
                     cropRect.height + (EXT_CROP_SIZE * 2));
    
    cv::Rect bigCrop(cropRect.x * VIEW_SCALE,
                     cropRect.y * VIEW_SCALE,
                     cropRect.width * VIEW_SCALE,
                     cropRect.height * VIEW_SCALE);
    
    // 1.差分の対象を切り出す(詳細に)
    auto diffInfo = extractDiffImgs(rS, rT, bigS, bigT, cropRect);
    
    if (diffInfo.extractStatus == -1) {
        return;
    }
    else if (diffInfo.extractStatus != 0) {
        switch(diffInfo.extractStatus) {
            case 1:
                addprocess(diff_result, diffInfo.diffContours[0]);
                break;
                
            case 2:
                delprocess(diff_result, diffInfo.diffContours[0]);
                break;
                
            case 3:
                diffprocess(diff_result, diffInfo.diffContours[0]);
                break;

        }
        if (diffInfo.extractStatus == 4) {
            // 差異部分のズレ補正
            cv::Mat s, t;
            cv::Rect sr,tr;
            s = diffInfo.srcMats.at(0);
            t = diffInfo.trgMats.at(0);
            sr = diffInfo.srcRects.at(0);
            tr = diffInfo.trgRects.at(0);

            //util->dbgSave(s, "s.tif", false);
            //util->dbgSave(t, "t.tif", false);
            double poc_result = 0;
            cv::Point2d shift;
            shift = getPOCPos(s, t, &poc_result);
            if (abs(shift.x) / VIEW_SCALE >= setting.gapPix || abs(shift.y) / VIEW_SCALE >= setting.gapPix) {
                diffprocess(diff_result, diffInfo.diffContours[0]);
                return;
            }
            
            if (abs(floor2(poc_result,2)) != 0.00 &&
                (abs(round2(shift.x,2)) >= 1.00 || abs(round2(shift.y,2)) >= 1.00)) {
                sr.x -= round(shift.x);
                sr.y -= round(shift.y);
                util->cropSafe(bigS, crpS, sr, true);
            }
            else {
                crpS = s;
            }
            result = util->tmplateMatch(crpS, t, MATCH_THRESH, 1);
            if (!result.isMatch) {
                diffprocess(diff_result, diffInfo.diffContours[0]);
                return;
            }
            std::cout << "check" << std::endl;
        }
        else if (diffInfo.extractStatus == 5) {
            cv::Mat s, t;
            s = diffInfo.srcMats.at(0);
            t = diffInfo.trgMats.at(0);
            
            result = util->tmplateMatch(s, t, MATCH_THRESH, 1);
            
            if (!result.isMatch) {
                diffprocess(diff_result, diffInfo.diffContours[0]);
                return;
            }
        }
        return;
    }
    
    if (diffInfo.srcMats.size() == diffInfo.trgMats.size()) {
        for(int i = 1; i < diffInfo.srcMats.size(); i++) {
            cv::Mat s, t, src, trg;
            
            s = diffInfo.srcMats.at(i);
            t = diffInfo.trgMats.at(i);
            
            cv::Mat sub;
            std::vector<std::vector<cv::Point>> vcnt;
            util->absDiffImg(s, t, sub, false, true);
            cv::threshold(sub, sub, setting.threthDiff, 255, cv::THRESH_BINARY);
            cv::findContours(sub, vcnt, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
            if (vcnt.size() == 0) continue;
            
            result = util->tmplateMatch(s, t, MATCH_THRESH, 1);
            if (!result.isMatch) {
                if (diffInfo.diffContours.at(i - 1).size() == 0) {
                    continue;
                }
                else {
                    diffprocess(diff_result, diffInfo.diffContours.at(i - 1));
                    continue;
                }
            }
            else if (result.val >= 0.9){
                continue;
            }
            
            util->resizeImage(s, src, 1 / VIEW_SCALE);
            util->resizeImage(t, trg, 1 / VIEW_SCALE);
            
            std::bitset<64> bs = computeHash(src);
            std::bitset<64> bt = computeHash(trg);
            std::bitset<64> bs_xor_bt(bs ^ bt);
            size_t hamm = bs_xor_bt.count();
            
            if (hamm == 0) {
                continue;
            }
            else if (hamm > 9) {
                diffprocess(diff_result, diffInfo.diffContours.at(i - 1));
                continue;
            }
            
            continue;
        }
    }
    else {
        std::cout << "ありえない" << std::endl;
    }
    /*
    
    if ((absAreas.size() == 3) && (absAreas[0] == cv::Rect(1,0,0,0))) {
        // ほぼ同じものが検出できた場合
        util->cropSafe(rS, crpS, absAreas[1], true);
        util->cropSafe(rT, crpT, absAreas[2], true);
        result = util->tmplateMatch(crpS, crpT, 0.90, VIEW_SCALE);
        if (!result.isMatch) {
            util->dbgSave(crpS, "crpS.tif", ngCount);
            util->dbgSave(crpT, "crpT.tif", ngCount);
            diffprocess(diff_result, diff_contours[0]);
            return;
        }
        return;
    }
    
    // 2.各々のエリアに対して詳細にチェック
    int i = 0;
    for (i = 0; i < absAreas.size(); i++) {
        cv::Rect diff_area = absAreas.at(i);
        cv::Rect big_diff_area(diff_area.x * VIEW_SCALE,
                               diff_area.y * VIEW_SCALE,
                               diff_area.width * VIEW_SCALE,
                               diff_area.height * VIEW_SCALE);
        std::vector<std::vector<cv::Point>> diff_cnt = diff_contours.at(i);
        
        // どちらかが白なら差異とする
        util->cropSafe(bigS, crpS, big_diff_area, true);
        util->cropSafe(bigT, crpT, big_diff_area, true);
        
        util->dbgSave(crpS, "crpS.tif", false);
        util->dbgSave(crpT, "crpT.tif", false);
        if (!chkNoImg(crpS, crpT, diff_result, diff_cnt))
            continue;
        
        // 差異部分のズレ補正
        double poc_result = 0;
        cv::Point2d shift;
        bool isGap = false;
        
        for(int k = 0; k < 2; k++) {
            shift = getPOCPos(crpS, crpT, &poc_result);
            
            if (abs(shift.x) / VIEW_SCALE >= setting.gapPix || abs(shift.y) / VIEW_SCALE >= setting.gapPix) {
                isGap = true;
                break;
            }
            
            if (abs(floor2(poc_result,2)) != 0.00 &&
                (abs(round2(shift.x,2)) >= 1.00 || abs(round2(shift.y,2)) >= 1.00)) {
                big_diff_area.x -= round(shift.x);
                big_diff_area.y -= round(shift.y);
                util->cropSafe(bigS, crpS, big_diff_area, true);
            }
        }
        
        if (isGap) {
                util->dbgSave(crpS, "crpS.tif", ngCount);
                util->dbgSave(crpT, "crpT.tif", ngCount);
            diffprocess(diff_result, diff_cnt);
            continue;
        }
        
        cv::Mat sub;
        std::vector<std::vector<cv::Point>> vcnt;
        util->absDiffImg(crpS, crpT, sub, false, true);
        cv::threshold(sub, sub, setting.threthDiff, 255, cv::THRESH_BINARY);
        cv::findContours(sub, vcnt, cv::RETR_LIST, cv::CHAIN_APPROX_NONE);
        if (vcnt.size() == 0) continue;
        
        cv::Mat trg(cv::Size(crpT.cols + (EXT_CROP_SIZE * 2), crpT.rows + (EXT_CROP_SIZE * 2)), crpT.type(), cv::Scalar::all(255));
        cv::Rect window(EXT_CROP_SIZE, EXT_CROP_SIZE, crpT.cols, crpT.rows);
        cv::Mat roi;
        
        util->cropSafe(trg, roi, window, true);
        crpT.copyTo(roi);
        util->dbgSave(trg, "trg.tif", ngCount);
        result = util->tmplateMatch(crpS, trg, 0.81, 1);
        if (!result.isMatch) {
                util->dbgSave(crpS, "crpS.tif", ngCount);
                util->dbgSave(crpT, "crpT.tif", ngCount);
            diffprocess(diff_result, diff_cnt);
            continue;
        }
        else if (result.val >= 0.90) {
            continue;
        }
        
        util->resizeImage(crpS, crpS, 1 / VIEW_SCALE);
        util->resizeImage(crpT, crpT, 1 / VIEW_SCALE);
        
        std::bitset<64> s = computeHash(crpS);
        std::bitset<64> t = computeHash(crpT);
        std::bitset<64> s_xor_t(s ^ t);
        size_t hamm = s_xor_t.count();
        
        if (hamm == 0) {
            continue;
        }
        else if (hamm > 9) {
                util->dbgSave(crpS, "crpS.tif", ngCount);
                util->dbgSave(crpT, "crpT.tif", ngCount);
            diffprocess(diff_result, diff_cnt);
            continue;
        }
    }
    
    
    */
    
    
    /*bool isLargeArea = false;
    cv::Mat bigS,bigT;
    cv::Mat crpS,crpT;
    
    int retState = chkNoImg(rS, rT);
    
    // どちらかが白ならNG
    if(retState != 0){
        if(retState == 1){
            addprocess(diff_result, curCnt);
        }
        else if(retState == 2){
            delprocess(diff_result, curCnt);
        }
        return;
    }
    
    // 大きなエリア同士の場合は差分あり
    if (cropRect.area() > 9000 ||
        cropRect.width > 100 ||
        cropRect.height > 100) {
        isLargeArea = true;
    }
    
    // 拡大処理
    util->resizeImage(rS, bigS, VIEW_SCALE);
    util->resizeImage(rT, bigT, VIEW_SCALE);
    
    
    
    cv::Mat sub = subtract_halide(bigS, bigT, setting.threthDiff);
    std::vector<cv::Rect> cntAreas;
    std::vector<std::vector<cv::Point>> vcnt;
    cv::Rect diffAreaOrg;
    
    // 閾値を下げて輪郭とる
    cv::findContours(sub, vcnt, cv::RETR_LIST, cv::CHAIN_APPROX_NONE);
    
    curCnt.clear();
    
    for (auto it = vcnt.begin(); it != vcnt.end(); ++it) {
        cntAreas.push_back(cv::boundingRect(*it));
        std::vector<cv::Point> c;
        for (auto pt = it->begin(); pt != it->end(); ++pt) {
            cv::Point realPt(cropRect.x - EXT_CROP_SIZE, cropRect.y - EXT_CROP_SIZE);
            realPt.x += pt->x / VIEW_SCALE;
            realPt.y += pt->y / VIEW_SCALE;
            c.push_back(realPt);
        }
        curCnt.push_back(c);
    }
    
    for (auto it = cntAreas.begin(); it != cntAreas.end(); ++it) {
        diffAreaOrg |= *it;
    }
    
    if (diffAreaOrg.area() == 0) return;
    
    // 差分部分の領域計算
    cv::Rect diffRect = getDiffRect(bigS,bigT, 20);
    
    int differenceArea = abs(diffAreaOrg.area() - diffRect.area());
    if (differenceArea > 2000) {
        std::cout << "領域えらー" << std::endl;
        int th = 20;
        while (true) {
            diffRect = getDiffRect(bigS,bigT, th);
            if (diffRect.area() == 0) break;
            th+=8;
            differenceArea = abs(diffAreaOrg.area() - diffRect.area());
            if (differenceArea <= 2000) break;
            if (th >= setting.threthDiff) break;
        }
        
        if (diffRect.area() == 0) return;
    }
    
    if (diffRect.width == 0 || diffRect.height == 0) {
        return;
    }
    
    // 差分切り出し
    util->cropSafe(bigS, crpS, diffRect, true);
    util->cropSafe(bigT, crpT, diffRect, true);
    
    
    
    retState = chkNoImg(crpS, crpT);
    
    // どちらかが白ならNG
    if(retState != 0){
        if(retState == 1){
            addprocess(diff_result, curCnt);
        }
        else if(retState == 2){
            delprocess(diff_result, curCnt);
        }
        util->dbgSave(crpS, "crpS.tif", ngCount);
        util->dbgSave(crpT, "crpT.tif", ngCount);
        return;
    }
    
    cv::Rect tRect,sRect;
    
    sRect = getContourRect(crpS, 20);
    tRect = getContourRect(crpT, 20);
    
    int dx = abs(sRect.x - tRect.x);
    int dy = abs(sRect.y - tRect.y);
    
    if (dx / VIEW_SCALE >= setting.gapPix || dy / VIEW_SCALE >= setting.gapPix) {
        util->dbgSave(bigS, "bigS.tif", ngCount);
        util->dbgSave(bigT, "bigT.tif", ngCount);
        util->dbgSave(crpS, "crpS.tif", ngCount);
        util->dbgSave(crpT, "crpT.tif", ngCount);
        diffprocess(diff_result, curCnt);
        return;
    }
    
    if ((sRect.width == 0 || sRect.height == 0) && (tRect.width == 0 || tRect.height == 0)) {
        util->dbgSave(bigS, "bigS.tif", ngCount);
        util->dbgSave(bigT, "bigT.tif", ngCount);
        util->dbgSave(crpS, "crpS.tif", ngCount);
        util->dbgSave(crpT, "crpT.tif", ngCount);
        return;
    }
    else if ((sRect.width == 0 || sRect.height == 0) && (tRect.width != 0 || tRect.height != 0)) {
        util->dbgSave(bigS, "bigS.tif", ngCount);
        util->dbgSave(bigT, "bigT.tif", ngCount);
        util->dbgSave(crpS, "crpS.tif", ngCount);
        util->dbgSave(crpT, "crpT.tif", ngCount);
        addprocess(diff_result, curCnt);
        return;
    }
    else if ((sRect.width != 0 || sRect.height != 0) && (tRect.width == 0 || tRect.height == 0)) {
        util->dbgSave(bigS, "bigS.tif", ngCount);
        util->dbgSave(bigT, "bigT.tif", ngCount);
        util->dbgSave(crpS, "crpS.tif", ngCount);
        util->dbgSave(crpT, "crpT.tif", ngCount);
        delprocess(diff_result, curCnt);
        return;
    }
    
    util->cropSafe(crpS, crpS, sRect, true);
    util->cropSafe(crpT, crpT, tRect, true);
    
    retState = chkNoImg(crpS, crpT);
    
    // どちらかが白ならNG
    if(retState != 0){
        if(retState == 1){
            util->dbgSave(crpS, "crpS.tif", ngCount);
            util->dbgSave(crpT, "crpT.tif", ngCount);
            addprocess(diff_result, curCnt);
        }
        else if(retState == 2){
            util->dbgSave(crpS, "crpS.tif", ngCount);
            util->dbgSave(crpT, "crpT.tif", ngCount);
            delprocess(diff_result, curCnt);
        }
        return;
    }
    
    // POCでズレ計算 & 移動
    util->cropSafe(bigS, crpS, diffRect, true);
    util->cropSafe(bigT, crpT, diffRect, true);
    
    if (!(sRect.width == 1 || sRect.height == 1) && !(tRect.width == 1 || tRect.height == 1)) {
        double poc_result = 0;
        cv::Point2d shift = getPOCPos(crpS, crpT, &poc_result);
        if (abs(floor2(poc_result,2)) != 0.00 &&
            (abs(round2(shift.x,2)) >= 1.00 || abs(round2(shift.y,2)) >= 1.00)) {
            cv::Mat moved(bigS.size(), bigS.type(), cv::Scalar::all(255));
            cv::Mat mat = (cv::Mat_<double>(2,3)<<1.0, 0.0, shift.x, 0.0, 1.0, shift.y);
            cv::warpAffine(bigS, moved, mat, bigS.size(), cv::INTER_CUBIC, cv::BORDER_TRANSPARENT );
            util->cropSafe(moved, crpS, diffRect, true);
            //moved.copyTo(crpS);
        }
    }
    
    util->absDiffImg(crpS, crpT, sub, false, true);
    cv::threshold(sub, sub, setting.threthDiff, 255, cv::THRESH_BINARY);
    cv::findContours(sub, vcnt, cv::RETR_LIST, cv::CHAIN_APPROX_NONE);
    if (vcnt.size() == 0) return;
    
    CvUtil::MatchingResult result = util->tmplateMatch(crpS, crpT, 0.81, 1);
    if (!result.isMatch) {
        util->dbgSave(crpS, "crpS.tif", ngCount);
        util->dbgSave(crpT, "crpT.tif", ngCount);
        diffprocess(diff_result, curCnt);
        return;
    }
    else if (result.val >= 0.90) {
        return;
    }
    
    util->resizeImage(crpS, crpS, 1 / VIEW_SCALE);
    util->resizeImage(crpT, crpT, 1 / VIEW_SCALE);
    
    std::bitset<64> s = computeHash(crpS);
    std::bitset<64> t = computeHash(crpT);
    std::bitset<64> s_xor_t(s ^ t);
    size_t hamm = s_xor_t.count();
    
    if (hamm == 0) {
        return;
    }
    else if ((isLargeArea && hamm > 0) || hamm > 9) {
        util->dbgSave(crpS, "crpS.tif", ngCount);
        util->dbgSave(crpT, "crpT.tif", ngCount);
        diffprocess(diff_result, curCnt);
        return;
    }
     */
     
     
     
     
    /*cv::Mat A2, S2, T2;
    vector<vector<cv::Point>> vctContoursA;
    cv::Rect chkSPos(0,0,0,0);
    cv::Rect chkTPos(0,0,0,0);
    
    cv::pyrUp(absImg, A2);
    cv::pyrUp(A2, A2);
    cv::threshold(A2, A2, 0, 255, CV_THRESH_OTSU);
    cv::pyrUp(rS, S2);
    cv::pyrUp(S2, S2);
    cv::pyrUp(rT, T2);
    cv::pyrUp(T2, T2);
    cv::findContours(A2, vctContoursA, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_NONE);
    vector<cv::Rect> difPos_v;
    cv::Rect difPos;
    
    for(int i = 0; i < vctContoursA.size(); i++){
        difPos_v.push_back(cv::boundingRect(vctContoursA.at(i)));
    }
    for(auto it=difPos_v.begin(); it != difPos_v.end(); ++it){
        difPos |= *it;
    }
    
    // どちらかが真っ白なデータかどうか
    int result_func = chkNoImg(rS, rT);
    if(result_func != 0){
        util->dbgSave(rS, "rS.tif", ngCount);
        util->dbgSave(rT, "rT.tif", ngCount);
        util->dbgSave(absImg, "rA.tif", ngCount);
        if(result_func == 1){
            addprocess(diff_result, curCnt);
        }
        else if(result_func == 2){
            delprocess(diff_result, curCnt);
        }
        return;
    }
    
    // 文字単位で切り出し
    bool isTate = false;
    result_func = chkCharacter(rS, rT, difPos, chkSPos, chkTPos, isTate);
    if(result_func != 0){
        util->dbgSave(rS, "rS.tif", ngCount);
        util->dbgSave(rT, "rT.tif", ngCount);
        util->dbgSave(absImg, "rA.tif", ngCount);
        if(result_func == 1){
            addprocess(diff_result, curCnt);
        }
        else if(result_func == 2){
            delprocess(diff_result, curCnt);
        }
        else if(result_func == 3){
            diffprocess(diff_result, curCnt);
        }
        return;
    }
    
    // SとTの重なる部分を抽出
    cv::Mat overImgS,overImgT,overImgA;
    
    cv::Rect overRect = chkSPos & chkTPos | difPos;
    
    if(overRect.area() == 0){
        if((chkSPos & difPos).area() == 0){
            util->dbgSave(rS, "rS.tif", ngCount);
            util->dbgSave(rT, "rT.tif", ngCount);
            util->dbgSave(absImg, "rA.tif", ngCount);
            delprocess(diff_result, curCnt);
            return;
        }else if((chkTPos & difPos).area() == 0){
            util->dbgSave(rS, "rS.tif", ngCount);
            util->dbgSave(rT, "rT.tif", ngCount);
            util->dbgSave(absImg, "rA.tif", ngCount);
            addprocess(diff_result, curCnt);
            return;
        }else{
            diffprocess(diff_result, curCnt);
            util->dbgSave(rS, "rS.tif", ngCount);
            util->dbgSave(rT, "rT.tif", ngCount);
            util->dbgSave(absImg, "rA.tif", ngCount);
            return;
        }
    }
    util->cropSafe(S2, overImgS, overRect, true);
    util->cropSafe(T2, overImgT, overRect, true);
    util->cropSafe(A2, overImgA, overRect, true);
    
    cv::Mat tmpS,tmpT;
    cv::Mat grayS, grayT;
    
    double resl;
    cv::Mat hann, moved;
    cv::createHanningWindow(hann, overImgS.size(), CV_32F);
    
    auto clahe = cv::createCLAHE();
    util->cvtGrayIfColor(overImgS, grayS);
    util->cvtGrayIfColor(overImgT, grayT);
    clahe->apply(grayS, tmpS);
    clahe->apply(grayT, tmpT);
    
    tmpS.convertTo(tmpS, CV_32F);
    tmpT.convertTo(tmpT, CV_32F);
    
    cv::Point2d shift = cv::phaseCorrelate(tmpS, tmpT, hann, &resl);
    
    if(abs(round(shift.x)/4) > setting.gapPix || abs(round(shift.y)/4) > setting.gapPix){
        util->cvtGrayIfColor(overImgS, grayS);
        util->cvtGrayIfColor(overImgT, grayT);
        grayS.convertTo(grayS, CV_32F);
        grayT.convertTo(grayT, CV_32F);
        
        shift = cv::phaseCorrelate(grayS, grayT, hann, &resl);
    }
    
    cout << "move: x = " << round(shift.x) << "y = " << round(shift.y) << endl;
    
    
    if(abs(round(shift.x)/4) > setting.gapPix || abs(round(shift.y)/4) > setting.gapPix){
    }
    else{
        util->cropSafe(S2, overImgS, cv::Rect(overRect.tl().x + (round(shift.x) * -1),
                                              overRect.tl().y + (round(shift.y) * -1),
                                              overRect.width, overRect.height), true);
    }
    
    cv::Mat tpl,targ;
    cv::Rect cropSize((overRect.tl().x - EXT_CROP_SIZE / 2 < 0)? 0 : overRect.tl().x - (EXT_CROP_SIZE / 2),
                      (overRect.tl().y - EXT_CROP_SIZE / 2 < 0)? 0 : overRect.tl().y - (EXT_CROP_SIZE / 2),
                      (overRect.width + EXT_CROP_SIZE > S2.cols)? S2.cols : overRect.width + EXT_CROP_SIZE,
                      (overRect.height + EXT_CROP_SIZE > S2.rows)? S2.rows : overRect.height + EXT_CROP_SIZE);
    
    if(chkSPos.area() < chkTPos.area()){
        tpl = overImgS;
        util->cropSafe(T2, targ, cropSize, false);
    }else{
        tpl = overImgT;
        util->cropSafe(S2, targ, cropSize, false);
    }
    
    CvUtil::MatchingResult rest = util->tmplateMatch(tpl, targ, 0.81, VIEW_SCALE);
    
    if(!rest.isMatch){
        util->dbgSave(rS, "rS.tif", ngCount);
        util->dbgSave(rT, "rT.tif", ngCount);
        util->dbgSave(absImg, "rA.tif", ngCount);
        util->dbgSave(tpl, "tpl.tif", ngCount);
        util->dbgSave(targ, "targ.tif", ngCount);
        diffprocess(diff_result, curCnt);
    }
    else{
        if(rest.val < 0.99){
            result_func = chkPinPoint(overImgS, overImgT, overImgA);
            
            if(result_func != 0){
                util->dbgSave(rS, "rS.tif", ngCount);
                util->dbgSave(rT, "rT.tif", ngCount);
                util->dbgSave(absImg, "rA.tif", ngCount);
                if(result_func == 1){
                    addprocess(diff_result, curCnt);
                }
                else if(result_func == 2){
                    delprocess(diff_result, curCnt);
                }
                else if(result_func == 3){
                    diffprocess(diff_result, curCnt);
                }
                return;
            }
        }

        return;
    }*/
    
}

#pragma mark -
#pragma mark Public Methods

void DiffImgCore::registerSetting(char* jsonString){
    ngCount = 0;
    // settingに値を設定
    json_t *root;
    json_error_t error;
    root = json_loads(jsonString, 0, &error);
    
    // 必ずJSON_OBJECTのみのはず
    if(root && json_typeof(root) == JSON_OBJECT){
        const char *key;
        json_t *value;
        
        json_object_foreach(root, key, value) {
            switch (json_typeof(value)) {
                case JSON_OBJECT:
                    if(!strcmp(key,"addColor")){
                        setColor(value, &setting.addColor);
                    }
                    else if(!strcmp(key,"delColor")){
                        setColor(value, &setting.delColor);
                    }
                    else if(!strcmp(key,"diffColor")){
                        setColor(value, &setting.diffColor);
                    }
                    else if(!strcmp(key,"backAlphaColor")){
                        setColor(value, &setting.backAlphaColor);
                    }
                    break;
                    
                case JSON_ARRAY:
                    break;
                    
                case JSON_STRING:

                    if(!strcmp(key,"diffDispMode")){
                        setting.diffDispMode = std::string(json_string_value(value));
                    }
                    else if(!strcmp(key,"aoAkaMode")){
                        setting.aoAkaMode = std::string(json_string_value(value));
                    }
                    else if(!strcmp(key,"filePrefix")){
                        setting.prefix = std::string(json_string_value(value));
                    }
                    else if(!strcmp(key,"fileSuffix")){
                        setting.suffix = std::string(json_string_value(value));
                    }
                    break;
                    
                case JSON_INTEGER:
                    if(!strcmp(key,"noizeReduction")){
                        setting.noizeReduction = (int)json_integer_value(value);
                    }
                    else if(!strcmp(key,"threthDiff")){
                        setting.threthDiff = (int)json_integer_value(value);
                    }
                    else if(!strcmp(key,"lineThickness")){
                        setting.lineThickness = (int)json_integer_value(value);
                    }
                    else if(!strcmp(key,"rasterDpi")){
                        setting.rasterDpi = (int)json_integer_value(value);
                    }
                    else if(!strcmp(key,"colorSpace")){
                        setting.colorSpace = (int)json_integer_value(value);
                    }
                    else if(!strcmp(key,"saveType")){
                        setting.saveType = (int)json_integer_value(value);
                    }
                    else if(!strcmp(key,"backConsentration")){
                        setting.backConsentration = (float)json_integer_value(value);
                    }
                    else if(!strcmp(key,"gapPix")){
                        setting.gapPix = (float)json_integer_value(value);
                    }

                    break;
                    
                case JSON_REAL:
                    if(!strcmp(key,"backConsentration")){
                        setting.backConsentration = (float)json_real_value(value);
                    }
                    else if(!strcmp(key,"gapPix")){
                        setting.gapPix = (float)json_real_value(value);
                    }
                    break;
                    
                case JSON_TRUE:
                    if(!strcmp(key,"isFillLine")){
                        setting.isFillLine = true;
                    }
                    else if(!strcmp(key,"isAllDiffColor")){
                        setting.isAllDiffColor = true;
                    }
                    else if(!strcmp(key,"isAllDelColor")){
                        setting.isAllDelColor = true;
                    }
                    else if(!strcmp(key,"isAllAddColor")){
                        setting.isAllAddColor = true;
                    }
                    else if(!strcmp(key,"isSaveNoChange")){
                        setting.isSaveNoChange = true;
                    }
                    else if(!strcmp(key,"isSaveLayered")){
                        setting.isSaveLayered = true;
                    }
                    else if(!strcmp(key,"isSaveColor")){
                        setting.isSaveColor = true;
                    }

                    break;
                    
                case JSON_FALSE:
                    if(!strcmp(key,"isFillLine")){
                        setting.isFillLine = false;
                    }
                    else if(!strcmp(key,"isAllDiffColor")){
                        setting.isAllDiffColor = false;
                    }
                    else if(!strcmp(key,"isAllDelColor")){
                        setting.isAllDelColor = false;
                    }
                    else if(!strcmp(key,"isAllAddColor")){
                        setting.isAllAddColor = false;
                    }
                    else if(!strcmp(key,"isSaveNoChange")){
                        setting.isSaveNoChange = false;
                    }
                    else if(!strcmp(key,"isSaveLayered")){
                        setting.isSaveLayered = false;
                    }
                    else if(!strcmp(key,"isSaveColor")){
                        setting.isSaveColor = false;
                    }
                    break;
                    
                case JSON_NULL:
                    break;
                    
                default:
                    fprintf(stderr, "unrecognized JSON type %d\n", json_typeof(root));
            }
        }
    }
    json_decref(root);
    
    return;
}

void DiffImgCore::test(NSArray* ar, const char* file) {
    std::vector<std::vector<std::vector<cv::Point>>> allcontours;
    int maxX = 0;
    int maxY = 0;
    for (int i = 0; i < ar.count; i++) {
        NSArray *cnts = ar[i];
        std::vector<std::vector<cv::Point>> contours;
        for (int j = 0; j < [cnts count]; j++) {
            NSMutableArray *ar = cnts[j];
            std::vector<cv::Point> cnt1;
            for(int k = 0; k < [ar count]; k++) {
                NSValue *v = ar[k];
                NSPoint p = [v pointValue];
                cv::Point cp(p.x, p.y);
                cnt1.push_back(cp);
                if (maxX < p.x) maxX = p.x;
                if (maxY < p.y) maxY = p.y;
            }
            contours.push_back(cnt1);
        }
        allcontours.push_back(contours);
    }
    
    cv::Mat img = openImg(file);
    cv::Mat cntImg(img.rows,img.cols, CV_8UC1, cv::Scalar::all(0));
    
    for (int i = 0; i < allcontours.at(0).size(); i++) {
        cv::drawContours(cntImg, allcontours.at(0), i, cv::Scalar::all(255), cv::FILLED);
    }
    util->dbgSave(cntImg, "cntImg.tif", false);
}

NSMutableDictionary* DiffImgCore::processBeforeAfter(NSData* src, NSData* targ, char* save, void* delegate, void* obj){
    const cv::String enc_format(".tif");
    cv::Mat imgS = openImg(src);
    cv::Mat imgT = openImg(targ);
    
    cv::Mat BS,RT;
    
    id<DiffImgCVDelegate> _delegate = (__bridge id<DiffImgCVDelegate>)delegate;
    NSMutableDictionary *muDic = [NSMutableDictionary dictionary];
    
    bool isUseAoAka = false;
    
    if (!imgS.data) {
        cerr << "No actual image data" << endl;
        [_delegate skipProcess:(__bridge id)obj];
        return nil;
    }
    
    if (!imgT.data) {
        cerr << "No actual image data" << endl;
        [_delegate skipProcess:(__bridge id)obj];
        return nil;
    }
    
    // サイズ調整
    util->adjustSize(imgS, imgT, cv::Scalar::all(255), CvUtil::ADJUST_POC);
    
    if(imgS.size != imgT.size){
        cerr << "No actual image data" << endl;
        [_delegate skipProcess:(__bridge id)obj];
        return nil;
    }
    
    cv::Mat diffAdd;
    if(setting.isSaveColor){
        diffAdd = cv::Mat(imgS.rows, imgS.cols, CV_8UC3, setting.backAlphaColor);
    }else{
        diffAdd = cv::Mat(imgS.rows, imgS.cols, CV_8UC1, setting.backAlphaColor);
    }
    
    // 青赤処理
    if(!strcmp(setting.aoAkaMode.c_str(), [NSLocalizedStringFromTable(@"AoAkaModeRB", @"Preference", nil) UTF8String])){
        imgS.copyTo(BS);
        imgT.copyTo(RT);
        util->conv2Blue(BS);
        util->conv2Red(RT);
        isUseAoAka = true;
    }else if (!strcmp(setting.aoAkaMode.c_str(), [NSLocalizedStringFromTable(@"AoAkaModeCM", @"Preference", nil) UTF8String])){
        imgS.copyTo(BS);
        imgT.copyTo(RT);
        util->conv2Cyan(BS);
        util->conv2Magenta(RT);
        isUseAoAka = true;
    }
    else {
        isUseAoAka = false;
    }
    
    // 比較なしの場合
    if(!strcmp(setting.diffDispMode.c_str(), [NSLocalizedStringFromTable(@"DiffModeNone", @"Preference", nil) UTF8String])){
        cv::Mat diff, blend;
        
        if (isUseAoAka) {
            cv::bitwise_and(BS, RT, diff);
            [muDic setObject:encodeMatToData(BS, enc_format) forKey:@"oldImage"];
            [muDic setObject:encodeMatToData(RT, enc_format) forKey:@"newImage"];
        }
        else {
            cv::bitwise_and(imgS, imgT, diff);
            blend = getAlphaBlendImg(diffAdd, diff);
            [muDic setObject:encodeMatToData(imgS, enc_format) forKey:@"oldImage"];
            [muDic setObject:encodeMatToData(imgT, enc_format) forKey:@"newImage"];
        }
        
        
        [muDic setObject:encodeMatToData(diff, enc_format) forKey:@"diffImage"];
        if (!isUseAoAka) [muDic setObject:encodeMatToData(blend, enc_format) forKey:@"blendImage"];
        
        [muDic setObject:@[] forKey:@"addPos"];
        [muDic setObject:@[] forKey:@"delPos"];
        [muDic setObject:@[] forKey:@"diffPos"];
        
        return muDic;
    }
    
    cv::Mat bitImg, bitImgS, bitImgT, bitEdge;
    cv::Mat result;
    cv::Mat tmp1, tmp2;
    cv::Mat minS, minT;
    DiffResult res;
    vector<vector<cv::Point>> vctContours;
    if (setting.colorSpace == (int)KZColorSpace::GRAY) {
        util->cvtGrayIfColor(imgS,tmp1);
        util->cvtGrayIfColor(imgT,tmp2);
        util->absDiffImg(tmp1, tmp2, bitImg, false, true);
    }
    else {
        bitImg = subtract_halide(imgS, imgT, setting.threthDiff);
    }
    /*
    cv::Canny(bitImg, bitEdge, 0, 10);
    cv::dilate(bitEdge, bitImg, cv::Mat());
    cv::threshold(bitImg, bitImg, setting.threthDiff, 255, cv::THRESH_BINARY);
    util->dbgSave(bitImg, "bitImg.tif", false);
    */
    util->cvtGrayIfColor(bitImg,bitImg);
    cv::threshold(bitImg, bitImg, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY);
    util->dbgSave(bitImg, "bitImg.tif", false);
    
    if (setting.noizeReduction != 0) {
        util->deleteMinimumArea(bitImg, setting.noizeReduction);
    }
    
    cv::rectangle(bitImg, cv::Point(0,0), cv::Point(bitImg.cols, bitImg.rows), cv::Scalar(0), 2);
    
    cv::findContours(bitImg, vctContours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    
    if (!setting.isSaveNoChange && vctContours.size() == 0) {
        // 差分無しの時は何も保存しないで終わる
        [muDic setObject:@[] forKey:@"addPos"];
        [muDic setObject:@[] forKey:@"delPos"];
        [muDic setObject:@[] forKey:@"diffPos"];
        
        return muDic;
    }
    
    std::vector<cv::Rect> dbs_rects;
    for (auto it = vctContours.begin(); it != vctContours.end(); ++it) {
        dbs_rects.push_back(cv::boundingRect(*it));
    }
    
    cout << "allDiffAreas: " << (int)dbs_rects.size() << endl;
    
    std::vector<cv::Rect> diff_rects;
    rect_clustering(dbs_rects, diff_rects, 5);
   
    if(diff_rects.size() != 0 &&
       strcmp(setting.diffDispMode.c_str(), [NSLocalizedStringFromTable(@"DiffModeNone", @"Preference", nil) UTF8String])){
        cout << "maxDiffAreas: " << (int)diff_rects.size() << endl;
        
        [_delegate maxDiffAreas:(int)diff_rects.size() object:(__bridge id)obj];
        cv::Mat rS, rT;
        
        // グレー化
        util->cvtGrayIfColor(imgS,rS);
        util->cvtGrayIfColor(imgT,rT);

        cv::Mat bigS, bigT;
        
        util->resizeImage(rS, bigS, VIEW_SCALE);
        util->resizeImage(rT, bigT, VIEW_SCALE);
        
        for(int i = 0; i < diff_rects.size(); i++){
            std::cout << i << std::endl;
            //if (i == 427){
            if (i == 299){
                std::cout << i << std::endl;
            }
            diff(imgS, imgT, bigS, bigT, diff_rects.at(i), res);
            [_delegate notifyProcess:(__bridge id)obj];
        }
        
        NSMutableArray *arAddm = [NSMutableArray array];
        NSMutableArray *arDelm = [NSMutableArray array];
        NSMutableArray *arDiffm = [NSMutableArray array];
        
        for(int i = 0; i < res.addAreas.size(); i++){
            NSMutableArray *cnts = [NSMutableArray array];
            for (auto it = res.addAreas.at(i).begin(); it != res.addAreas.at(i).end(); ++it) {
                NSMutableArray *pts = [NSMutableArray array];
                for (auto ct = it->begin(); ct != it->end(); ++ct) {
                    NSValue *value = [NSValue valueWithPoint:NSMakePoint(ct->x, ct->y)];
                    [pts addObject:value];
                }
                [cnts addObject:pts];
            }
            [arAddm addObject:cnts];
        }
        for(int i = 0; i < res.delAreas.size(); i++){
            NSMutableArray *cnts = [NSMutableArray array];
            for (auto it = res.delAreas.at(i).begin(); it != res.delAreas.at(i).end(); ++it) {
                NSMutableArray *pts = [NSMutableArray array];
                for (auto ct = it->begin(); ct != it->end(); ++ct) {
                    NSValue *value = [NSValue valueWithPoint:NSMakePoint(ct->x, ct->y)];
                    [pts addObject:value];
                }
                [cnts addObject:pts];
            }
            [arDelm addObject:cnts];
        }
        for(int i = 0; i < res.diffAreas.size(); i++){
            NSMutableArray *cnts = [NSMutableArray array];
            for (auto it = res.diffAreas.at(i).begin(); it != res.diffAreas.at(i).end(); ++it) {
                NSMutableArray *pts = [NSMutableArray array];
                for (auto ct = it->begin(); ct != it->end(); ++ct) {
                    NSValue *value = [NSValue valueWithPoint:NSMakePoint(ct->x, ct->y)];
                    [pts addObject:value];
                }
                [cnts addObject:pts];
            }
            [arDiffm addObject:cnts];
        }
        
        [muDic setObject:[arAddm copy] forKey:@"addContours"];
        [muDic setObject:[arDelm copy] forKey:@"delContours"];
        [muDic setObject:[arDiffm copy] forKey:@"diffContours"];
        
        if(!strcmp(setting.diffDispMode.c_str(), [NSLocalizedStringFromTable(@"DiffModeRect", @"Preference", nil) UTF8String])){
            writeContourMain(rectContour, diffAdd, res);
        }else if(!strcmp(setting.diffDispMode.c_str() ,[NSLocalizedStringFromTable(@"DiffModeArround", @"Preference", nil) UTF8String])){
            writeContourMain(writeContour, diffAdd, res);
        }
    }
    else {
        [muDic setObject:@[] forKey:@"addPos"];
        [muDic setObject:@[] forKey:@"delPos"];
        [muDic setObject:@[] forKey:@"diffPos"];
    }
    
    if(!setting.isSaveNoChange &&
       (res.addAreas.size() == 0 && res.delAreas.size() == 0 && res.diffAreas.size() == 0)){
        // 差分無しの時は何も保存しないで終わる
        [muDic setObject:@[] forKey:@"addPos"];
        [muDic setObject:@[] forKey:@"delPos"];
        [muDic setObject:@[] forKey:@"diffPos"];
        
        return muDic;
    }
    
    cv::Mat blendImage;
    
    if(isUseAoAka)
    {
        cv::Mat aoaka;
        cv::bitwise_and(BS, RT, aoaka);
        blendImage = getAlphaBlendImg(diffAdd, aoaka);
        if (((KZFileFormat)(setting.saveType) == KZFileFormat::PSD_FORMAT) || ((KZFileFormat)(setting.saveType) == KZFileFormat::PNG_FORMAT)) {
            muDic[@"oldImage"] = encodeMatToData(BS, enc_format);
            muDic[@"newImage"] = encodeMatToData(aoaka, enc_format);
            muDic[@"diffImage"] = encodeMatToData(diffAdd, enc_format);
        }
        else if ((KZFileFormat)(setting.saveType) == KZFileFormat::GIF_FORMAT) {
            util->dbgInfo(blendImage);
            muDic[@"oldImage"] = encodeMatToData(blendImage, enc_format);
            muDic[@"newImage"] = encodeMatToData(aoaka, enc_format);
        }
    }
    else
    {
        blendImage = getAlphaBlendImg(diffAdd, imgT);
        muDic[@"oldImage"] = encodeMatToData(imgS, enc_format);
        muDic[@"newImage"] = encodeMatToData(imgT, enc_format);
        muDic[@"diffImage"] = encodeMatToData(diffAdd, enc_format);
    }
    
    // 保存先の名前を考える
    
    muDic[@"blendImage"] = encodeMatToData(blendImage, enc_format);
    bitImg.release();
    blendImage.release();
    diffAdd.release();
    imgT.release();
    imgS.release();
    return muDic;
}
