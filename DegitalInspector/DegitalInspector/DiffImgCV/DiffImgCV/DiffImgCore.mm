//
//  DiffImgCore.cpp
//  DiffImgCV
//
//  Created by 内山和也 on 2019/04/16.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#include <algorithm>
#include <omp.h>
#include "opencv2/reg/mapaffine.hpp"
#include "opencv2/reg/mapshift.hpp"
#include "opencv2/reg/mapprojec.hpp"
#include "opencv2/reg/mappergradshift.hpp"
#include "opencv2/reg/mappergradeuclid.hpp"
#include "opencv2/reg/mappergradsimilar.hpp"
#include "opencv2/reg/mappergradaffine.hpp"
#include "opencv2/reg/mappergradproj.hpp"
#include "opencv2/reg/mapperpyramid.hpp"
#include "opencv2/img_hash.hpp"

#include <dlib/opencv.h>
#include <dlib/image_io.h>
#include <dlib/image_transforms.h>


#include "DiffImgCore.h"
#import "DiffImgCV.h"
#include <numeric>
#include <array>
#include "ColorUtils.hpp"
#include "cluster.h"

using namespace cv::reg;
using namespace cv::img_hash;

NSData* encodeMatToData(cv::Mat img, const cv::String type);

using namespace std;
//using namespace Halide;

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
#pragma mark Private Methods Use

struct byDistCenter {
     bool operator () (const cv::Rect & a, const cv::Rect & b){
          cv::Point2f ac = (a.tl() + a.br()) * 0.5;
          cv::Point2f bc = (b.tl() + b.br()) * 0.5;
          double ad = std::sqrt(ac.x*ac.x+ac.y*ac.y);
          double bd = std::sqrt(bc.x*bc.x+bc.y*bc.y);
          return (ad < bd);
     }
};

double medianMat(cv::Mat Input)
{
     Input = Input.reshape(0,1);// spread Input Mat to single row
     std::vector<double> vecFromMat;
     Input.copyTo(vecFromMat); // Copy Input Mat to vector vecFromMat
     std::nth_element(vecFromMat.begin(), vecFromMat.begin() + vecFromMat.size() / 2, vecFromMat.end());
     return vecFromMat[vecFromMat.size() / 2];
}


void my_canny(cv::Mat src, cv::Mat &out, bool isTiny, float sigma=0.33)
{
     if (!isTiny) {
          cv::GaussianBlur( src, src, cv::Size(1, 1), 0, 0);
          double v = medianMat(src);
          int lower = (int)max(0.0,(1.0-sigma)*v);
          int upper = (int)min(255.0,(1.0+sigma)*v);
          cv::Canny(src, out, lower, upper, 3);
     }
     else {
          cv::Canny(src, out, 0, 255);
     }
     
}

// crop => オリジナルの注目領域
// extSize => 拡張領域
// scale => 拡大サイズ
void getContours(cv::Mat rS, cv::Mat rT, cv::Rect crop, std::vector<std::vector<cv::Point> >& diff_contours, int extSize=0, float scale=1.0f)
{
     if (rS.empty() || rT.empty()) {
          return;
     }
     
     if(!( (rS.rows == rT.rows) && (rS.cols == rT.cols) )) {
          std::cout << "Invalid Image Size!!" << std::endl;
     }
     bool eq = std::equal(rS.begin<uchar>(), rS.end<uchar>(), rT.begin<uchar>());
     
     cv::Mat sub, tmpS, tmpT;
     if (scale != 1.0f) {
          cv::InterpolationFlags flg = cv::INTER_CUBIC;
          if (scale < 1.0) {
               flg = cv::INTER_AREA;
          }
          cv::resize(rS, tmpS, cv::Size(scale*rS.cols, scale*rS.rows), flg);
          cv::resize(rT, tmpT, cv::Size(scale*rT.cols, scale*rT.rows), flg);
     }
     else {
          rS.copyTo(tmpS);
          rT.copyTo(tmpT);
     }
     
     if (!eq) {
          cv::bitwise_xor(tmpS, tmpT, sub);
          cv::threshold(sub, sub, 0.0, 255.0, cv::THRESH_OTSU);
     }
     else {
          tmpS.copyTo(sub);
     }
     
     std::vector<std::vector<cv::Point>> theC;
     cv::findContours(sub, theC, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
     
     cv::Point adjustPoint;
     cv::Rect ext(crop.x - extSize,
                  crop.y - extSize,
                  crop.width + (extSize * 2),
                  crop.height + (extSize * 2));
     
     for (int i = 0; i < theC.size(); ++i) {
          std::vector<cv::Point> it = theC.at(i);
          std::vector<cv::Point> ttt;
          for (auto jt = it.begin(); jt != it.end(); ++jt) {
               cv::Point p = *jt;
               p.x += ext.tl().x;
               p.y += ext.tl().y;
               ttt.push_back(p);
          }
          diff_contours.push_back(ttt);
     }
}

// 成分を含む四角を取得（黒白画像）
cv::Rect getContourRect(cv::Mat binImg, cv::Rect roi, int extSize=0) {
     std::vector<std::vector<cv::Point>> cnt;
     cv::findContours(binImg, cnt, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
     cv::Rect rc;
     for (auto it = cnt.begin(); it != cnt.end(); ++it) {
          cv::Rect theRC = cv::boundingRect(*it);
          cv::Rect chk(0,0,0,0);
          chk = theRC & roi;
          if ((chk.area() > 0) || roi == cv::Rect()) {
               rc |= theRC;
          }
     }

     if (extSize != 0) {
          int x,y,w,h;
          if ((rc.x - extSize) < 0) x = 0;
          else x = rc.x - extSize;
          if ((rc.y - extSize) < 0) y = 0;
          else y = rc.y - extSize;
          if ((x + rc.width + extSize*2) > binImg.cols) w = (binImg.cols - x);
          else w = rc.width + extSize*2;
          if ((y + rc.height + extSize*2) > binImg.rows) h = (binImg.rows - y);
          else h = rc.height + extSize*2;
          return cv::Rect(x,y,w,h);
     }
     else {
          return rc;
     }
}

std::vector<cv::Rect> getContourRects(cv::Mat binImg) {
     std::vector<cv::Rect> ret;
     std::vector<std::vector<cv::Point>> cnt;
     cv::findContours(binImg, cnt, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
     for (auto it = cnt.begin(); it != cnt.end(); ++it) {
          ret.push_back(cv::boundingRect(*it));
     }
     return ret;
}

// 成分の存在確認（黒白画像）
bool isExistsContour(cv::Mat &binImg) {
     std::vector<std::vector<cv::Point>> cnt;
     cv::findContours(binImg, cnt, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
     if (cnt.size() == 0) {
          return false;
     }
     return true;
}

// 小さい画像を指定した位置とサイズに合わせる
void toSize(cv::Mat in, cv::Mat &out, cv::Size to, cv::Rect roi, cv::Scalar back)
{
     cv::Mat makeImg(to, in.type(), back);
     cv::Mat remakeROI(makeImg, roi);
     in.copyTo(remakeROI);
     makeImg.copyTo(out);
}

// 指定サイズの領域を持つ成分を削除（黒白画像）
void delMinAreaWhite(cv::Mat &img, int delSize=VIEW_SCALE)
{
     cv::Mat stats, centroids, label;
     int nLab = cv::connectedComponentsWithStats(img, label, stats, centroids, 4, CV_32S);
     if (nLab == 1) return;
     std::vector<int> deleteLabels;
     for (int l = 1; l < nLab; l++) {
          int *param = stats.ptr<int>(l);
          int a = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          
          if ((a <= delSize) ||
              ((w <= VIEW_SCALE) || (h <= VIEW_SCALE) )) {
               bool isContain = false;
               for (auto it = deleteLabels.begin(); it != deleteLabels.end(); it++) {
                    if (l == *it) {
                         isContain = true;
                         break;
                    }
               }
               if (!isContain) deleteLabels.push_back(l);
          }
     }
     
     #pragma omp parallel for
     for (int r = 0; r < img.rows; r++) {
          uchar* p = img.ptr<uchar>(r);
          int* lp = label.ptr<int>(r);
          for (int c = 0; c < img.cols; c++) {
               for (auto it = deleteLabels.begin(); it != deleteLabels.end(); it++) {
                    if (lp[c] == *it) {
                         p[c] = 0;
                    }
               }
          }
     }
}

template <typename T>
inline double hash_check(const std::string &title, const cv::Mat &a, const cv::Mat &b)
{
     cout << "=== " << title << " ===" << endl;
     cv::TickMeter tick;
     cv::Mat hashA, hashB;
     cv::Ptr<ImgHashBase> func;
     func = T::create();
     
     tick.reset(); tick.start();
     func->compute(a, hashA);
     tick.stop();
          cout << "compute1: " << tick.getTimeMilli() << " ms" << endl;

     tick.reset(); tick.start();
     func->compute(b, hashB);
     tick.stop();
          cout << "compute2: " << tick.getTimeMilli() << " ms" << endl;
     
     double ret = func->compare(hashA, hashB);
          cout << "compare: " << ret << endl << endl;
     return ret;
}

float checkHash(std::string title, cv::Mat checkS, cv::Mat checkT)
{
//     return hash_check<MarrHildrethHash>("MarrHildrethHash", checkS, checkT);
//     return hash_check<AverageHash>("AverageHash", checkS, checkT);
//     return hash_check<BlockMeanHash>("BlockMeanHash0", checkS, checkT);
//     return hash_check<BlockMeanHash>("BlockMeanHash0", checkS, checkT);
//     return hash_check<ColorMomentHash>("ColorMomentHash", checkS, checkT);
//     return hash_check<PHash>("PHash", checkS, checkT);
     return hash_check<RadialVarianceHash>(title, checkS, checkT);
}

cv::Mat getHullMask(cv::Mat mask, bool isNear = false)
{
     std::vector<cv::Point> contours_flat;
     cv::Mat maskPoly(mask.size(), mask.type(), cv::Scalar::all(0));
     if (isNear) {
          std::vector<std::vector<cv::Point>> contours_tl, contours_br;
          cv::findContours(mask, contours_tl, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE, cv::Point(-1,-1));
          cv::findContours(mask, contours_br, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE, cv::Point(1,1));
          
          for (auto contour = contours_tl.begin(); contour != contours_tl.end(); contour++){
               for (auto pt = contour->begin(); pt != contour->end(); pt++){
                    contours_flat.push_back(*pt);
               }
          }
          for (auto contour = contours_br.begin(); contour != contours_br.end(); contour++){
               for (auto pt = contour->begin(); pt != contour->end(); pt++){
                    contours_flat.push_back(*pt);
               }
          }
     }
     else {
          std::vector<std::vector<cv::Point>> contours;
          cv::findContours(mask, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
          for (auto contour = contours.begin(); contour != contours.end(); contour++){
               for (auto pt = contour->begin(); pt != contour->end(); pt++){
                    contours_flat.push_back(*pt);
               }
          }
     }
     
     
     std::vector<cv::Point> hull;
     if (contours_flat.size() != 0) {
          cv::convexHull(contours_flat, hull);
          cv::fillConvexPoly(maskPoly, hull, cv::Scalar::all(255));
          return maskPoly;
     }
     else {
          return cv::Mat();
     }
     
}

void cropImageFromRect(cv::Rect area, cv::Mat &img, cv::Scalar color)
{
     #pragma omp parallel for
     for (int r = 0; r < img.rows; r++) {
          uchar* p = img.ptr<uchar>(r);
          for (int c = 0; c < img.cols; c++) {
               cv::Point pt(c, r);
               if (!area.contains(pt)) {
                    p[c] = color[0];
               }
          }
     }
}

void cropImageFromRects(std::vector<cv::Rect> areas, cv::Mat &img, cv::Scalar color, BOOL isFillInside = NO)
{
     #pragma omp parallel for
     for (int r = 0; r < img.rows; r++) {
          uchar* p = img.ptr<uchar>(r);
          for (int c = 0; c < img.cols; c++) {
               cv::Point pt(c, r);
               bool isInside = false;
               for (auto i = areas.begin(); i != areas.end(); ++i) {
                    if (pt.inside(*i))
                         isInside = true;
               }
               if (!isFillInside) {
                    if (!isInside) p[c] = color[0];
               }
               else {
                    if (isInside) p[c] = color[0];
               }
          }
     }
}

void cropImageFromMask(cv::Mat mask, cv::Mat &img, cv::Scalar color)
{
     cv::Mat maskPoly = getHullMask(mask, false);
     
     if (maskPoly.empty()) {
          img = cv::Mat();
          return;
     }
     
     #pragma omp parallel for
     for (int r = 0; r < img.rows; r++) {
          uchar* p = img.ptr<uchar>(r);
          uchar* m = maskPoly.ptr<uchar>(r);
          for (int c = 0; c < img.cols; c++) {
               if (m[c] == 0) {
                    p[c] = color[0];
               }
          }
     }
}

void cropImageFromMaskP(cv::Mat mask, cv::Mat &img, cv::Scalar color)
{
#pragma omp parallel for
     for (int r = 0; r < img.rows; r++) {
          uchar* p = img.ptr<uchar>(r);
          uchar* m = mask.ptr<uchar>(r);
          for (int c = 0; c < img.cols; c++) {
               if (m[c] == 0) {
                    p[c] = color[0];
               }
          }
     }
}




// 指定したラベルを取得
void getLabelComponent(cv::Mat label, std::vector<int> labelNo, cv::Mat src, cv::Mat &out)
{
     cv::Mat masked = cv::Mat::zeros(src.rows, src.cols, src.type());
     #pragma omp parallel for
     for (int r = 0; r < src.rows; r++) {
          uchar* msp = masked.ptr<uchar>(r);
          int* lp = label.ptr<int>(r);
          for (int c = 0; c < src.cols; c++) {
               for (auto it = labelNo.begin(); it != labelNo.end(); it++) {
                    if (lp[c] == *it) {
                         msp[c] = 255;
                    }
               }
          }
     }
     masked.copyTo(out);
}

void getComponentFromMask(cv::Mat img, cv::Mat mask, cv::Mat &out)
{
     cv::Mat stats, centroids, label;
     cv::connectedComponentsWithStats(img, label, stats, centroids, 4, CV_32S);
     
     std::vector<int> maskCompo;
     cv::Mat tmpMask;
     cv::bitwise_and(mask, img, tmpMask);
     
#pragma omp parallel for
     for (int r = 0; r < img.rows; r++) {
          uchar* msp = tmpMask.ptr<uchar>(r);
          int* lp = label.ptr<int>(r);
          for (int c = 0; c < img.cols; c++) {
               if (msp[c] == 255) {
#pragma omp critical
                    {
                         bool isContain = false;
                         for (auto it = maskCompo.begin(); it != maskCompo.end(); it++) {
                              if (*it == lp[c]) {
                                   isContain = true;
                                   break;
                              }
                         }
                         
                         if (!isContain) maskCompo.push_back(lp[c]);
                    }
               }
          }
     }
     out = cv::Mat::zeros(img.rows, img.cols, img.type());
     
     
#pragma omp parallel for
     for (int r = 0; r < img.rows; r++) {
          uchar* oup = out.ptr<uchar>(r);
          int* lp = label.ptr<int>(r);
          for (int c = 0; c < img.cols; c++) {
               bool isContain = false;
               for (auto it = maskCompo.begin(); it != maskCompo.end(); it++) {
                    if (*it == lp[c]) {
                         isContain = true;
                         break;
                    }
               }
               if (isContain) {
                    oup[c] = 255;
               }
          }
     }
}

void getComponentFromRect(cv::Mat img, cv::Rect roi, cv::Mat &out)
{
     cv::Mat stats, centroids, label;
     int nLab = cv::connectedComponentsWithStats(img, label, stats, centroids, 4, CV_32S);
     std::vector<int> maskCompo;
     for (int l = 1; l < nLab; l++) {
          int *param = stats.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          cv::Rect theRect(x,y,w,h);
          if ((roi & theRect).area() > 0) {
               bool isContain = false;
               for (auto it = maskCompo.begin(); it != maskCompo.end(); it++) {
                    if (*it == l) {
                         isContain = true;
                         break;
                    }
               }
               if (!isContain) maskCompo.push_back(l);
          }
     }
     getLabelComponent(label, maskCompo, img, out);
}

cv::Point normalizeShiftValue(cv::Point2d shift)
{
     cv::Point retPoint;
     float roundGapX = (float)shift.x * 100.0;
     float roundGapY = (float)shift.y * 100.0;
     
     float X = roundGapX;
     float Y = roundGapY;
     int lowestX = ((int)roundGapX % 10);  roundGapX /= 10;
     int lowX = ((int)roundGapX % 10);
     int lowestY = ((int)roundGapY % 10);  roundGapY /= 10;
     int lowY = ((int)roundGapY % 10);
     
     if ((lowX >= 5) && (lowestX < 5)) {
          X -= 10.0;
     }
     else if ((lowX <= -5) && (lowestX > -5)) {
          X += 10.0;
     }
     if ((lowY >= 5) && (lowestY < 5)) {
          Y -= 10.0;
     }
     else if ((lowY <= -5) && (lowestY > -5)) {
          Y += 10.0;
     }
     
     X /= 100.0;
     Y /= 100.0;
     
     retPoint.x = round(X);
     retPoint.y = round(Y);
     return retPoint;
}

cv::Point2d getPOCPos(cv::Mat src, cv::Mat trg, double* res_poc, float gap)
{
     //CV_Assert((src.channels() == 1) && (trg.channels() == 1));
     
     cv::Mat hann;
     cv::Mat grayS,grayT;
     cv::Mat tmpS,tmpT;
     
     auto clahe = cv::createCLAHE();
     clahe->apply(src, tmpS);
     clahe->apply(trg, tmpT);
     
     tmpS.convertTo(tmpS, CV_32F);
     tmpT.convertTo(tmpT, CV_32F);
     cv::createHanningWindow(hann, src.size(), CV_32F);
     
     cv::Point2d shift = cv::phaseCorrelate(tmpS, tmpT, hann, res_poc);
     
     if(abs(round(shift.x)/VIEW_SCALE) > gap || abs(round(shift.y)/VIEW_SCALE) > gap) {
          src.convertTo(grayS, CV_32F);
          trg.convertTo(grayT, CV_32F);
          shift = cv::phaseCorrelate(grayS, grayT, hann, res_poc);
     }
     
     return shift;
}

// 切り抜かれたグレー画像に対して
cv::Point getShiftPoint(cv::Mat rS, cv::Mat rT, float gap)
{
     cv::Mat img1, img2;
     rS.copyTo(img1);
     rT.copyTo(img2);
     img1.convertTo(img1, CV_64FC3);
     img2.convertTo(img2, CV_64FC3);
     cv::Ptr<MapperGradShift> mapper = cv::makePtr<MapperGradShift>();
     MapperPyramid mappPyr(mapper);
     cv::Ptr<Map> mapPtr = mappPyr.calculate(img1, img2);
     // Print result
     MapShift* mapShift = dynamic_cast<MapShift*>(mapPtr.get());
     auto sft = mapShift->getShift();
     cv::Point shift;
     cv::Point2d shift_org = cv::Point2d(sft[0], sft[1]);
     shift = normalizeShiftValue(shift_org);
     
     
     if ((shift_org.x == 0) && (shift_org.y == 0)) {
          
          double res_poc = 0.0;
          cv::Mat binS, binT;
          cv::threshold(rS, binS, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
          cv::threshold(rT, binT, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
          shift_org = getPOCPos(rS, rT, &res_poc, gap);
          
          shift = normalizeShiftValue(shift_org);
          
          if ((shift.x == 0) && (shift.y == 0)) {
               cout << "no move" << endl;
          }
     }
     return shift;
}

bool isSameRect(cv::Rect a, cv::Rect b)
{
     if ((a.x == b.x) && (a.y == b.y) && (a.width == b.width) && (a.height == b.height)) {
          return true;
     }
     return false;
}
/*
// dlibで分割した領域と、色差差分の同じコンポーネントを取得
void getLabelMaskImage(cv::Mat img, cv::Mat mask, cv::Mat& out)
{
     CV_Assert(img.type() == CV_8UC1);
     CV_Assert(mask.type() == CV_8UC1);
     CV_Assert(!img.empty());
     CV_Assert(!mask.empty());
     
     cv::Mat invMat;
     cv::bitwise_not(img, invMat);
     //     cv::imwrite("/tmp/inv.tif", invMat);
     
     dlib::cv_image<unsigned char> dimg(invMat);
     dlib::array2d<unsigned char> mimg;
     dlib::array2d<unsigned int> label;
     dlib::assign_image(mimg, dimg);
     unsigned long nLab = dlib::label_connected_blobs_watershed(mimg, label);
     
     std::vector<int> fillLabel;
     
#pragma omp parallel for
     for(int i = 0; i < label.nr(); i++ ) {
          uchar* p = mask.ptr<uchar>(i);
          for(int j = 0; j < label.nc(); j++ ) {
               int index = label[i][j];
               if( index == -1 ) {}
               else if( index <= 0 || index > nLab ) {}
               else {
                    if (p[j] == 255) {
#pragma omp critical
                         {
                              bool isContain = false;
                              for (auto it = fillLabel.begin(); it != fillLabel.end(); ++it) {
                                   if (*it == index) {
                                        isContain = true;
                                        break;
                                   }
                              }
                              if (!isContain)
                                   fillLabel.push_back(index);
                         }
                    }
               }
          }
     }
     
     out = cv::Mat(img.size(), CV_8UC1, cv::Scalar::all(0));
     
#pragma omp parallel for
     for(int i = 0; i < mask.rows; i++ ) {
          uchar* s = out.ptr<uchar>(i);
          for(int j = 0; j < mask.cols; j++ ) {
               int lab = label[i][j];
               bool isFill = false;
               for (auto it = fillLabel.begin(); it != fillLabel.end(); ++it) {
                    if (*it == lab) {
                         isFill = true;
                         break;
                    }
               }
               if (isFill) s[j] = 255;
          }
     }
}*/

/*vector<cv::Mat> getCompoImgs(cv::Mat img)
{
     vector<cv::Mat> retImgs;
     cv::Mat stats, centroids, label;
     int nLab = cv::connectedComponentsWithStats(img, label, stats, centroids, 4, CV_32S);
     vector<cv::Rect> compoRects;
     map<cv::Rect, int> mCompo;
     for (int l = 1; l < nLab; l++) {
          int *param = stats.ptr<int>(l);
          cv::Rect theR(param[cv::ConnectedComponentsTypes::CC_STAT_LEFT],
                        param[cv::ConnectedComponentsTypes::CC_STAT_TOP],
                        param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH],
                        param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT]);
          compoRects.push_back(theR);
          mCompo[theR] = l;
     }
     std::sort(compoRects.begin(), compoRects.end(), byDistCenter());
     
     for (int i = 0; i < compoRects.size(); i++) {
          int theLabel = mCompo[compoRects.at(i)];
          cv::Mat msk(img.size(), img.type(), cv::Scalar::all(0));
          #pragma omp parallel for
          for(int r = 0; r < msk.rows; r++ ){
               uchar* s = msk.ptr<uchar>(r);
               int* l = label.ptr<int>(r);
               for(int c = 0; c < msk.cols; c++ ) {
                    if (theLabel == l[c]) {
                         s[c] = 255;
                    }
               }
          }
          retImgs.push_back(msk);
     }
     return retImgs;
}*/

void doMultipleImg(cv::Mat rS, cv::Mat rT, cv::Mat &out)
{
     cv::Mat tmpOr_Org, tmpOr;
     out = cv::Mat(rS.size(), rS.type(), cv::Scalar::all(255));
#pragma omp parallel for
     for (int r = 0; r < rS.rows; r++) {
          uchar* s = rS.ptr<uchar>(r);
          uchar* t = rT.ptr<uchar>(r);
          uchar* rs = out.ptr<uchar>(r);
          for (int c = 0; c < rS.cols; c++) {
               rs[c] = cv::saturate_cast<uchar>(t[c]*s[c] / 255.);
          }
     }
}

// 中心にあるコンポーネントを取得
void cropCenterComponent(cv::Mat bin, cv::Mat &out, cv::Rect crpE, int extCrop)
{
     cv::Mat stats, centroids, label;
     int nLab = cv::connectedComponentsWithStats(bin, label, stats, centroids, 8, CV_32S);
     int delta = extCrop / 3;
     cv::Rect c(extCrop - delta,
                extCrop - delta,
                crpE.width - (extCrop * 2) + (delta * 2),
                crpE.height - (extCrop * 2) + (delta * 2));
     if (c.x < 0) c.x = crpE.x;
     if (c.y < 0) c.y = crpE.y;
     if (c.width < 0) c.width = crpE.width - c.x;
     if (c.height < 0) c.height = crpE.height - c.y;
     
     vector<int> remains;
     
     for (int l = 1; l < nLab; l++) {
          int *param = stats.ptr<int>(l);
          cv::Rect theR(param[cv::ConnectedComponentsTypes::CC_STAT_LEFT],
                        param[cv::ConnectedComponentsTypes::CC_STAT_TOP],
                        param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH],
                        param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT]);
          if ((c & theR).area() > 0) {
               remains.push_back(l);
          }
     }
     out = cv::Mat::zeros(bin.rows, bin.cols, bin.type());
     for (int r = 0; r < bin.rows; r++) {
          int* s = label.ptr<int>(r);
          uchar* o = out.ptr<uchar>(r);
          for (int c = 0; c < bin.cols; c++) {
               for (auto it = remains.begin(); it != remains.end(); ++it) {
                    if (*it == s[c]) o[c] = 255;
               }
          }
     }
     vector<vector<cv::Point>> cnt;
     cv::findContours(out, cnt, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
     cv::Rect rc;
     for (auto it = cnt.begin(); it != cnt.end(); ++it) {
          rc |= cv::boundingRect(*it);
     }
     
     cropImageFromRect(rc, out, cv::Scalar::all(0));
}

std::vector<cv::Range> searchRows(cv::Mat integl, int thresh){
     std::vector<cv::Range> rowRange;
     cv::Range rnge;
     rnge.start = -1;
     rnge.end = -1;
     for (int y = 1; y < integl.rows; y++){
          int *ns = integl.ptr<int>(y-1);
          int *ps = integl.ptr<int>(y);
          bool lessTh = (abs(ns[integl.cols-1] - ps[integl.cols-1]) >= thresh);
          if ( lessTh && (rnge.start < 0)) {
               rnge.start = y - 1;
          }
          else if (!lessTh && (rnge.start >= 0)) {
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

std::vector<cv::Range> searchCols(cv::Mat integl, int thresh)
{
     const int* srcLine = integl.ptr<int>(integl.rows - 1); // 積分画像の下端を見る
     std::vector<cv::Range> colRange;
     cv::Range rnge;
     rnge.start = -1;
     rnge.end = -1;
     for (int i = 1; i < integl.cols; i++) {
          bool lessTh = (abs(srcLine[i] - srcLine[i-1]) >= thresh);
          
          if(lessTh && rnge.start < 0){
               rnge.start = i - 1;
          }else if (!lessTh && rnge.start >= 0){
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

std::vector<cv::Rect> getComponentRects(cv::Mat crpMul, int thresh)
{
     cv::Mat intMul, invMul;
     cv::bitwise_not(crpMul, invMul);
     cv::integral(invMul, intMul);
     auto colRngs = searchCols(intMul, thresh);
     auto rowRngs = searchRows(intMul, thresh);
     
     bool isVertical = (rowRngs.size() > colRngs.size());
     
     cv::Rect minRect;
     vector<cv::Rect> lines, rects;
//     vector<int> lineWhites;
     
     if (isVertical) {
          
          for(int x = 0; x < colRngs.size(); x++){
               cv::Rect wPos;
               wPos = cv::Rect((colRngs.at(x).start == 0)? 0 : colRngs.at(x).start-1,
                               0,
                               (colRngs.at(x).end - colRngs.at(x).start)+2,
                               crpMul.rows);
               if (crpMul.cols < (wPos.x + wPos.width) ) {
                    wPos.width = crpMul.cols - wPos.x;
               }
               minRect |= wPos;
          }
          
          for(int y = 0; y < rowRngs.size(); y++){
               cv::Rect wPos;
               
               wPos = cv::Rect(0,
                               (rowRngs.at(y).start == 0)? 0 : rowRngs.at(y).start-1,
                               crpMul.cols,
                               (rowRngs.at(y).end - rowRngs.at(y).start)+2);
               if (crpMul.rows < (wPos.y + wPos.height) ) {
                    wPos.height = crpMul.rows - wPos.y;
               }
               lines.push_back(wPos);
//               cv::Mat m(invMul, wPos);
//               int warea = cv::countNonZero(m);
//               lineWhites.push_back(warea);
          }
     }
     else {
          for(int y = 0; y < rowRngs.size(); y++){
               cv::Rect wPos;
               
               wPos = cv::Rect(0,
                               (rowRngs.at(y).start == 0)? 0 : rowRngs.at(y).start-1,
                               crpMul.cols,
                               (rowRngs.at(y).end - rowRngs.at(y).start)+2);
               if (crpMul.rows < (wPos.y + wPos.height) ) {
                    wPos.height = crpMul.rows - wPos.y;
               }
               minRect |= wPos;
          }
          
          for(int x = 0; x < colRngs.size(); x++){
               cv::Rect wPos;
               wPos = cv::Rect((colRngs.at(x).start == 0)? 0 : colRngs.at(x).start-1,
                               0,
                               (colRngs.at(x).end - colRngs.at(x).start)+2,
                               crpMul.rows);
               if (crpMul.cols < (wPos.x + wPos.width)) {
                    wPos.width = crpMul.cols - wPos.x;
               }
               lines.push_back(wPos);
               
//               cv::Mat m(invMul, wPos);
//               int warea = cv::countNonZero(m);
//               lineWhites.push_back(warea);
          }
     }
     
     cv::Mat mx(invMul, minRect);
     int maxWhite = cv::countNonZero(mx);
     if (isSameRect(minRect, cv::Rect(0,0,0,0))) {
          maxWhite = 0;
     }
     
     int totalArea = 0;
     for (int i = 0; i < lines.size(); i++) {
          cv::Rect theR;
          if (isSameRect(minRect, cv::Rect(0,0,0,0))) {
               theR = lines[i];
               mx = cv::Mat(invMul, theR);
               maxWhite += cv::countNonZero(mx);
          }
          else {
               theR = lines[i] & minRect;
          }
          cv::Mat m(invMul, theR);
          int warea = cv::countNonZero(m);
          if (warea == 0) {
               cv::Mat img(crpMul, theR);
               cv::Mat bin;
               vector<vector<cv::Point>> contour;
               cv::threshold(img, bin, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
               cv::findContours(bin, contour, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
               cv::Rect whiteRc;
               for (auto it = contour.begin(); it != contour.end(); ++it) {
                    whiteRc |= cv::boundingRect(*it);
               }
               m = cv::Mat(invMul, whiteRc);
               warea = cv::countNonZero(m);
               rects.push_back(whiteRc);
          }
          else {
               rects.push_back(theR);
          }
          totalArea += warea;
     }
     
     if (abs(totalArea - maxWhite) > 10) {
          rects.clear();
          cv::Mat img;
          if (isSameRect(minRect, cv::Rect(0,0,0,0))) {
               img = cv::Mat(crpMul, minRect);
          }
          else {
               img = cv::Mat(crpMul, minRect);
          }
          
          cv::Mat bin;
          vector<vector<cv::Point>> contour;
          cv::threshold(img, bin, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
          cv::findContours(bin, contour, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
          cv::Rect whiteRc;
          for (auto it = contour.begin(); it != contour.end(); ++it) {
               whiteRc |= cv::boundingRect(*it);
          }
          
          if (isVertical) {
               minRect.y = whiteRc.y;
               minRect.height = whiteRc.height;
          }
          else {
               minRect.x = whiteRc.x;
               minRect.width = whiteRc.width;
          }
          rects.push_back(minRect);
          cout << "daijyoubu" << endl;
          
     }
     return rects;
}

// no use
bool isSameComponent(cv::Mat binS, cv::Mat binT, cv::Mat &labelS, cv::Mat &labelT, int &sLab, int &tLab)
{
     cv::Mat statusT, statusS, centroidsS, centroidsT;
     sLab = cv::connectedComponentsWithStats(binS, labelS, statusS, centroidsS, 8, CV_32S);
     tLab = cv::connectedComponentsWithStats(binT, labelT, statusT, centroidsT, 8, CV_32S);
     map<int,cv::Rect> slabs, tlabs;
     map<int,int> sareas, tareas;
     for (int l = 1; l < sLab; l++) {
          int *param = statusS.ptr<int>(l);
          cv::Rect theR(param[cv::ConnectedComponentsTypes::CC_STAT_LEFT],
                        param[cv::ConnectedComponentsTypes::CC_STAT_TOP],
                        param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH],
                        param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT]);
          slabs[l] = theR;
          sareas[l] = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
     }
     
     bool ret = true;
     for (int l = 1; l < tLab; l++) {
          int *param = statusT.ptr<int>(l);
          cv::Rect theR(param[cv::ConnectedComponentsTypes::CC_STAT_LEFT],
                        param[cv::ConnectedComponentsTypes::CC_STAT_TOP],
                        param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH],
                        param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT]);
          int area = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
          cv::Rect sR;
          int lIdx = 9999;
          for (auto it = slabs.begin(); it != slabs.end(); ++it) {
               if ((abs(it->second.width - theR.width) <= 1) && (abs(it->second.height - theR.height) <= 1)) {
                    lIdx = it->first;
                    break;
               }
          }
          if (lIdx == 9999) {
               ret = false;
               break;
          }
     }
     return ret;
}


// no use
void deleteDuplicateRect(std::vector<cv::Rect> org, std::vector<cv::Rect> trg, cv::Mat rS, cv::Mat rT, std::vector<cv::Rect> &orgUniq, std::vector<cv::Rect> &trgUniq)
{
     cv::Mat invS, invT;
     cv::bitwise_not(rS, invS);
     cv::bitwise_not(rT, invT);
     
     orgUniq = std::vector<cv::Rect>(org.begin(), org.end());
     trgUniq = std::vector<cv::Rect>(trg.begin(), trg.end());
     for (auto o = org.begin(); o != org.end(); ++o) {
          bool isSame = false;
          for (auto t = trg.begin(); t != trg.end(); ++t) {
               if (isSameRect(*o, *t)) {
                    isSame = true;
                    cv::Mat rcMatS(invS, *o);
                    cv::Mat rcMatT(invT, *t);
                    for (int r = 0; r < rcMatS.rows; ++r) {
                         uchar *s = rcMatS.ptr<uchar>(r);
                         uchar *t = rcMatT.ptr<uchar>(r);
                         for (int c = 0; c < rcMatS.cols; ++c) {
                              if(s[c] != t[c]) {
                                   isSame = false;
                                   break;
                              }
                         }
                    }
                    if (!isSame) break;
               }
          }
          if (isSame) {
               cout << "----del rect----" << endl;
               cout << "x = " << o->x << " y = " << o->y << " w = " << o->width << " h = " << o->height << endl;
               orgUniq.erase(std::remove(orgUniq.begin(), orgUniq.end(), *o), orgUniq.end());
               trgUniq.erase(std::remove(trgUniq.begin(), trgUniq.end(), *o), trgUniq.end());
          }
     }
}

// no use
void getDuplicateRect(std::vector<cv::Rect> org, std::vector<cv::Rect> trg, cv::Mat rS, cv::Mat rT, std::vector<cv::Rect> &sameRects)
{
     cv::Mat invS, invT;
     cv::bitwise_not(rS, invS);
     cv::bitwise_not(rT, invT);

     for (auto o = org.begin(); o != org.end(); ++o) {
          bool isSame = false;
          for (auto t = trg.begin(); t != trg.end(); ++t) {
               if (isSameRect(*o, *t)) {
                    isSame = true;
                    cv::Mat rcMatS(invS, *o);
                    cv::Mat rcMatT(invT, *t);
                    for (int r = 0; r < rcMatS.rows; ++r) {
                         uchar *s = rcMatS.ptr<uchar>(r);
                         uchar *t = rcMatT.ptr<uchar>(r);
                         for (int c = 0; c < rcMatS.cols; ++c) {
                              if(s[c] != t[c]) {
                                   isSame = false;
                                   break;
                              }
                         }
                    }
                    if (!isSame) break;
               }
          }
          if (isSame) {
               sameRects.push_back(*o);
          }
     }
}

// no use
void getAbstractImg(cv::Mat rS, cv::Mat rT, cv::Mat absMat, cv::Mat& outS, cv::Mat& outT)
{
     cv::Mat trgS, trgT;
     cv::Mat binS, binT;
     
     rS.copyTo(trgS);
     rT.copyTo(trgT);
     cv::Rect absRect = getContourRect(absMat, cv::Rect());
     cropImageFromRect(absRect, trgS, cv::Scalar::all(255));
     cropImageFromRect(absRect, trgT, cv::Scalar::all(255));
     
     cv::threshold(trgS, binS, 180, 255, cv::THRESH_BINARY_INV);
     cv::threshold(trgT, binT, 180, 255, cv::THRESH_BINARY_INV);
     
     cv::Rect sRect = getContourRect(binS, cv::Rect());
     cv::Rect tRect = getContourRect(binT, cv::Rect());
     outS = cv::Mat(trgS, sRect);
     outT = cv::Mat(trgT, tRect);
}

// no use
void getCroppedComponentImg(cv::Mat rS, cv::Mat rT, cv::Mat sikisa, cv::Mat& outS, cv::Mat& outT, bool isNoUseBin)
{
     cv::Mat trgS, trgT;
     cv::Mat binS, binT;
     
     rS.copyTo(trgS);
     rT.copyTo(trgT);
     
     cropImageFromMask(sikisa, trgS, cv::Scalar::all(255));
     cropImageFromMask(sikisa, trgT, cv::Scalar::all(255));
     
     if (isNoUseBin) {
          cv::Rect sRect = getContourRect(sikisa, cv::Rect());
          outS = cv::Mat(trgS, sRect);
          outT = cv::Mat(trgT, sRect);
     }
     else {
          cv::threshold(trgS, binS, 191, 255, cv::THRESH_BINARY_INV);
          cv::threshold(trgT, binT, 191, 255, cv::THRESH_BINARY_INV);
          
          cv::Rect sRect = getContourRect(binS, cv::Rect());
          cv::Rect tRect = getContourRect(binT, cv::Rect());
          
          outS = cv::Mat(trgS, sRect);
          outT = cv::Mat(trgT, tRect);
     }

}

bool tmplateMatch(cv::Mat rS, cv::Mat rT, double threshold)
{
     cv::Mat result_img;
     cv::Point min_pt,max_pt;
     double minVal,maxVal;
     /*
      CV_TM_SQDIFF        =0,
      CV_TM_SQDIFF_NORMED =1, 0に近い方が正解
      CV_TM_CCORR         =2,
      CV_TM_CCORR_NORMED  =3,
      CV_TM_CCOEFF        =4,
      CV_TM_CCOEFF_NORMED =5  1に近い方が正解
      */

     cv::UMat uSrc, uTmp;
     rS.copyTo(uSrc);
     rT.copyTo(uTmp);
     cv::matchTemplate(uSrc, uTmp, result_img, cv::TM_CCOEFF_NORMED);
     cv::minMaxLoc(result_img, &minVal, &maxVal, &min_pt, &max_pt);
     cv::Rect roi_rect(max_pt, cv::Point(max_pt.x+ rT.cols, max_pt.y+rT.rows));
#ifdef DEBUG
     cout << "MaxVal: " << maxVal << endl;
#endif
     if(maxVal < threshold) {
          return false;
     }
     return true;
}

void fillSamePix(cv::Mat rS, cv::Mat rT, cv::Mat &outS, cv::Mat &outT, cv::Scalar fill)
{
     rS.copyTo(outS);
     rT.copyTo(outT);
     for(int i = 0; i < rS.rows; i++ ) {
          uchar* s = outS.ptr<uchar>(i);
          uchar* t = outT.ptr<uchar>(i);
          for(int j = 0; j < rS.cols; j++ ) {
               if (s[j] == t[j]) {
                    s[j] = fill[0];
                    t[j] = fill[0];
               }
          }
     }
}

void delWhiteCompo(cv::Mat binS, cv::Mat binT, cv::Mat img, cv::Mat &outS, cv::Mat &outT)
{
     binS.copyTo(outS);
     binT.copyTo(outT);
     cv::Mat labelS, labelT, statusT, statusS, centroidsS, centroidsT;
     
     int sLab = cv::connectedComponentsWithStats(binS, labelS, statusS, centroidsS, 4, CV_32S);
     int tLab = cv::connectedComponentsWithStats(binT, labelT, statusT, centroidsT, 4, CV_32S);
     
     vector<int> sDelLabs, tDelLabs;
     for (int l = 1; l < sLab; l++) {
          int *param = statusS.ptr<int>(l);
          int areaL = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
          int theArea = 0;
          for(int i = 0; i < binS.rows; i++ ) {
               int* lb = labelS.ptr<int>(i);
               uchar* imgP = img.ptr<uchar>(i);
               for(int j = 0; j < binS.cols; j++ ) {
                    if (imgP[j] == 255 && lb[j] == l) {
                         theArea++;
                    }
               }
          }
          if (theArea == areaL) {
               bool isContain = false;
               for (auto it = sDelLabs.begin(); it != sDelLabs.end(); ++it) {
                    if (*it == l) {
                         isContain = true;
                         break;
                    }
               }
               if (!isContain) sDelLabs.push_back(l);
          }
     }
     
     for (int l = 1; l < tLab; l++) {
          int *param = statusT.ptr<int>(l);
          int areaL = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
          int theArea = 0;
          for(int i = 0; i < binT.rows; i++ ) {
               int* lb = labelT.ptr<int>(i);
               uchar* imgP = img.ptr<uchar>(i);
               for(int j = 0; j < binT.cols; j++ ) {
                    if (imgP[j] == 255 && lb[j] == l) {
                         theArea++;
                    }
               }
          }
          if (theArea == areaL) {
               bool isContain = false;
               for (auto it = tDelLabs.begin(); it != tDelLabs.end(); ++it) {
                    if (*it == l) {
                         isContain = true;
                         break;
                    }
               }
               if (!isContain) tDelLabs.push_back(l);
          }
     }
     
     for(int i = 0; i < binS.rows; i++ ) {
          uchar* s = outS.ptr<uchar>(i);
          uchar* t = outT.ptr<uchar>(i);
          int* lt = labelT.ptr<int>(i);
          int* ls = labelS.ptr<int>(i);
          for(int j = 0; j < binS.cols; j++ ) {
               bool isDelS = false;
               bool isDelT = false;
               for (auto it = sDelLabs.begin(); it != sDelLabs.end(); ++it) {
                    if (*it == ls[j]) {
                         isDelS = true;
                         break;
                    }
               }
               for (auto it = tDelLabs.begin(); it != tDelLabs.end(); ++it) {
                    if (*it == lt[j]) {
                         isDelT = true;
                         break;
                    }
               }
               if (isDelS) s[j] = 0;
               if (isDelT) t[j] = 0;
          }
     }
}

// dlibで分割した領域と、色差差分の同じコンポーネントを取得
void getLabelMaskImage(cv::Mat img, cv::Mat mask, cv::Mat& out)
{
     CV_Assert(img.type() == CV_8UC1);
     CV_Assert(mask.type() == CV_8UC1);
     CV_Assert(!img.empty());
     CV_Assert(!mask.empty());
     
     cv::Mat invMat;
     cv::bitwise_not(img, invMat);
     //     cv::imwrite("/tmp/inv.tif", invMat);
     
     dlib::cv_image<unsigned char> dimg(invMat);
     dlib::array2d<unsigned char> mimg;
     dlib::array2d<unsigned int> label;
     dlib::assign_image(mimg, dimg);
     unsigned long nLab = dlib::label_connected_blobs_watershed(mimg, label);
     
     std::vector<int> fillLabel;
     
#pragma omp parallel for
     for(int i = 0; i < label.nr(); i++ ) {
          uchar* p = mask.ptr<uchar>(i);
          for(int j = 0; j < label.nc(); j++ ) {
               int index = label[i][j];
               if( index == -1 ) {}
               else if( index <= 0 || index > nLab ) {}
               else {
                    if (p[j] == 255) {
                         #pragma omp critical
                         {
                              bool isContain = false;
                              for (auto it = fillLabel.begin(); it != fillLabel.end(); ++it) {
                                   if (*it == index) {
                                        isContain = true;
                                        break;
                                   }
                              }
                              if (!isContain)
                                   fillLabel.push_back(index);
                         }
                    }
               }
          }
     }
     
     out = cv::Mat(img.size(), CV_8UC1, cv::Scalar::all(0));
     
#pragma omp parallel for
     for(int i = 0; i < mask.rows; i++ ) {
          uchar* s = out.ptr<uchar>(i);
          for(int j = 0; j < mask.cols; j++ ) {
               int lab = label[i][j];
               bool isFill = false;
               for (auto it = fillLabel.begin(); it != fillLabel.end(); ++it) {
                    if (*it == lab) {
                         isFill = true;
                         break;
                    }
               }
               if (isFill) s[j] = 255;
          }
     }
}

void getHullCompos(cv::Mat org, cv::Mat del, cv::Mat bin, cv::Mat diff, vector<cv::Rect> dfRects, cv::Mat &out)
{
     cv::Mat label, status, centroids;
     int lab = cv::connectedComponents(bin, label);
     
     vector<cv::Mat> spt;
     vector<vector<cv::Point>> contours;
     
     for (int l = 1; l < lab; l++) {
          cv::Mat sMat(bin.size(), bin.type(), cv::Scalar::all(0));
          for(int i = 0; i < label.rows; i++ ) {
               int* lb = label.ptr<int>(i);
               uchar* s = sMat.ptr<uchar>(i);
               for(int j = 0; j < label.cols; j++ ) {
                    if (lb[j] == l) s[j] = 255;
               }
          }
          
          cv::findContours(sMat, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
          cv::Rect theRc;
          for (int i = 0; i < contours.size(); i++) {
               cv::drawContours(sMat, contours, i, cv::Scalar::all(255), cv::FILLED);
               theRc |= cv::boundingRect(contours.at(i));
          }
          bool isDel = false;
          
          for (auto it = dfRects.begin(); it != dfRects.end(); ++it) {
               if ((*it & theRc).area()) {
                    isDel = true;
                    break;
               }
          }
          if (isDel) spt.push_back(sMat);
     }
     cv::Mat outTmp(bin.size(), bin.type(), cv::Scalar::all(0));
     for (auto it = spt.begin(); it != spt.end(); ++it) {
          cv::bitwise_or(*it, outTmp, outTmp);
     }
     contours.clear();
     vector<cv::Rect> cropAreas;
     vector<cv::Mat> sptCany, sptLabel;
     cv::findContours(outTmp, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
     for (int i = 0; i < contours.size(); i++) {
          cv::Rect theRc = cv::boundingRect(contours.at(i));
          bool isDel = false;
          for (auto it = dfRects.begin(); it != dfRects.end(); ++it) {
               if ((*it & theRc).area()) {
                    isDel = true;
                    break;
               }
          }
          if (isDel) cropAreas.push_back(theRc);
     }
     
     cv::imwrite("/tmp/oTmp.tif", outTmp);
     cv::Mat cany, labMat;
     my_canny(del, cany, false);
     getLabelMaskImage(org, outTmp, labMat);
     
     cropImageFromRects(cropAreas, cany, cv::Scalar::all(0));
     cropImageFromRects(cropAreas, labMat, cv::Scalar::all(0));
     cv::imwrite("/tmp/cany.tif", cany);
     cv::imwrite("/tmp/lab.tif", labMat);
     
     
     cv::bitwise_or(outTmp, cany, outTmp);
     cv::bitwise_or(outTmp, labMat, outTmp);
     outTmp.copyTo(out);
//
//     getComponentFromMask(outTmp, diff, outTmp);
//     cv::Mat allHull = getHullMask(outTmp);
//
//     cv::Mat xorBin;
//     cv::bitwise_xor(outTmp, allHull, xorBin);
//     for(int i = 0; i < xorBin.rows; i++ ) {
//          uchar* o = org.ptr<uchar>(i);
//          uchar* h = outTmp.ptr<uchar>(i);
//          uchar* d = del.ptr<uchar>(i);
//          uchar* x = xorBin.ptr<uchar>(i);
//          for(int j = 0; j < xorBin.cols; j++ ) {
//               if (x[j] == 255) { // 注目エリア
//                    if (d[j] == 255) {
//                         if (o[j] <= 250) h[j] = 255;
//                         else h[j] = 0;
//                    }
//                    else {
//                         cv::Point pt(j, i);
//                         if (o[j] == 255) {
//                              h[j] = 0;
//                         }
//                         else {
//                              h[j] = 255;
//                         }
//                    }
//               }
//          }
//     }
//
//     outTmp.copyTo(out);
}


#pragma mark -
#pragma mark Private Class Methods Use

void DiffImgCore::diffprocess(DiffResult& diff_result, std::vector<std::vector<cv::Point> > curCnt)
{
     diff_result.diffAreas.push_back(curCnt);
     ngCount++;
     return;
}

void DiffImgCore::delprocess(DiffResult& diff_result, std::vector<std::vector<cv::Point> > curCnt)
{
     diff_result.delAreas.push_back(curCnt);
     ngCount++;
     return;
}

void DiffImgCore::addprocess(DiffResult& diff_result, std::vector<std::vector<cv::Point> > curCnt)
{
     diff_result.addAreas.push_back(curCnt);
     ngCount++;
     return;
}

void DiffImgCore::makeShadeMask(cv::Mat rS, cv::Mat rT, cv::Mat maskS, cv::Mat maskT, float thresh, cv::Mat &result)
{
     cv::Rect crpArea;
     cv::Mat srcImg, trgImg, mS, mT;
     if (maskS.empty() || maskT.empty()) {
          rS.copyTo(srcImg);
          rT.copyTo(trgImg);
          maskS.copyTo(mS);
          maskT.copyTo(mT);
          crpArea = cv::Rect(0,0,srcImg.cols,srcImg.rows);
     }
     else {
          cv::Mat orMask;
          cv::bitwise_or(maskS, maskT, orMask);
          crpArea = getContourRect(orMask, cv::Rect());
          util->cropSafe(rS, srcImg, crpArea, true);
          util->cropSafe(rT, trgImg, crpArea, true);
          util->cropSafe(maskS, mS, crpArea, true);
          util->cropSafe(maskT, mT, crpArea, true);
     }
     
     result = cv::Mat(srcImg.size(), srcImg.type(), cv::Scalar::all(0));
     
#pragma omp parallel
     {
#pragma omp for schedule(static)
          for (int r = 0; r < srcImg.rows; r++) {
               uchar *sp = srcImg.ptr<uchar>(r);
               uchar *tp = trgImg.ptr<uchar>(r);
               uchar *hp = result.ptr<uchar>(r);
               for (int c = 0; c < srcImg.cols; c++) {
                    ColorUtils::rgbColor c1(static_cast<unsigned int>(sp[c]), sp[c], sp[c]);
                    ColorUtils::rgbColor c2(static_cast<unsigned int>(tp[c]), tp[c], tp[c]);
                    float de = ColorUtils::getColorDeltaE(c1, c2);
                    if (de >= thresh) {
                         hp[c] = 255;
                    }
               }
          }
     }
     
     if (!isExistsContour(result)) {
          result = cv::Mat();
          return;
     }
     if (maskS.empty() || maskT.empty()) {
     }
     else {
          toSize(result, result, maskS.size(), crpArea, cv::Scalar::all(0));
     }
}

// チェック済みのエリアを定義(周囲1px広くする)
void DiffImgCore::fillCheckedContour(cv::Mat &bitDiff, cv::Mat absMat)
{
     vector<vector<cv::Point>> contours;
     cv::Mat outDf;
     if (absMat.empty()) {
          return;
     }
//     util->dbgSave(bitDiff, "bitDiff.tif", "df");
     getComponentFromMask(bitDiff, absMat, outDf);
//     util->dbgSave(outDf, "outDf.tif", "df");
     cv::findContours(outDf, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
     
     for (int i = 0; i < contours.size(); i++) {
          cv::drawContours(bitDiff, contours, i, cv::Scalar::all(0), cv::FILLED);
     }
//     util->dbgSave(bitDiffImgL, "bitDiffImgL.tif", "df");
     return;
}

void DiffImgCore::getDiffArea(cv::Mat rS, cv::Mat rT, cv::Mat binS, cv::Mat binT, cv::Mat centerDiff, cv::Mat bitDiff, cv::Mat &outS, cv::Mat &outT, cv::Mat &mulCompo, int extCrop)
{
     cv::Mat dS, dT, mST, rST, msk, msk_a;
     cv::Mat bR, bF;
     // 変化の無い箇所を削除
     fillSamePix(rS, rT, dS, dT, cv::Scalar::all(255));
     
     // 残った箇所のHullマスク作成
     doMultipleImg(dS, dT, mST);
     doMultipleImg(rS, rT, rST);
     cv::threshold(mST, msk, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
     cv::adaptiveThreshold(mST, msk_a, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY_INV, 27, 10);
     cv::bitwise_or(msk, msk_a, bR);
     cv::imwrite("/tmp/bR.tif",bR);
     cv::threshold(rST, msk, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
     cv::adaptiveThreshold(rST, msk_a, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY_INV, 27, 10);
     cv::bitwise_or(msk, msk_a, bF);
     cv::imwrite("/tmp/bF.tif",bF);
     cv::Mat valMask;
     bF.copyTo(valMask);
     getComponentFromMask(bF, bR, valMask);
     cv::imwrite("/tmp/valMask.tif",valMask);
     cv::Rect crpRect = getContourRect(valMask, cv::Rect());
     cv::Mat crpImg;
     rST.copyTo(crpImg);
     cropImageFromRect(crpRect, crpImg, cv::Scalar::all(255));
     cv::imwrite("/tmp/crpImg.tif",crpImg);
     vector<cv::Rect> rects = getComponentRects(crpImg, 180);
     cv::Rect valRect;
     for (auto it = rects.begin(); it != rects.end(); ++it) {
          if ((*it & crpRect).area() > 0) {
               valRect |= *it;
          }
     }
     
     cv::Mat hull = getHullMask(msk);
     cv::Mat binRst;
     
     
     
     getComponentFromMask(msk, hull, valMask);
     
     
     cv::Mat outMask;
     valMask.copyTo(outMask);
     
     
     
     
     
     cropImageFromRect(valRect, outMask, cv::Scalar::all(0));
     cv::imwrite("/tmp/outMask.tif",outMask);
     vector<vector<cv::Point>> contours;
     cv::findContours(msk, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
     vector<cv::Rect> dfRects, clsRects;
     for (auto it = contours.begin(); it != contours.end(); ++it) {
          cv::Rect rc = cv::boundingRect(*it);
          if (rc.x != 0 &&
              rc.y != 0 &&
              (rc.x + rc.width) != rS.cols &&
              (rc.y + rc.height) != rS.rows) {
               cout << "x = " << rc.x << " y = " << rc.y << " w = " << rc.width << " h = " << rc.height << endl;
               dfRects.push_back(rc);
          }
     }
     
     cout << "dfRects.size = " << dfRects.size() << endl;
     cv::Mat sMask;
     getHullCompos(rST, mST, msk, centerDiff, dfRects, sMask);
     cv::imwrite("/tmp/sMask.tif",sMask);
     
     // 差分箇所のHullマスクを残す
     getComponentFromMask(sMask, centerDiff, sMask);
     
     // 差分箇所の切り抜き
     getComponentFromMask(bitDiff, sMask, mulCompo);
     cv::imwrite("/tmp/mulCompo.tif",mulCompo);
     
     // Hullマスクで切り抜く
     rS.copyTo(outS);
     rT.copyTo(outT);
     cropImageFromMaskP(sMask, outS, cv::Scalar::all(255));
     cropImageFromMaskP(sMask, outT, cv::Scalar::all(255));
     
     
     //
     //     vector<vector<cv::Point>> contours;
     //     cv::findContours(bitDiff, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
     //     vector<cv::Rect> dfRects;
     //     for (auto it = contours.begin(); it != contours.end(); ++it) {
     //          dfRects.push_back(cv::boundingRect(*it));
     //     }
     //
     //     cv::Mat mulImg, mulImgBin;
     //     doMultipleImg(rS, rT, mulImg);
     //     cv::threshold(mulImg, mulImgBin, 190, 255, cv::THRESH_BINARY_INV);
     //     cv::Rect rcDiff = getContourRect(bitDiff, cv::Rect());
     //     getComponentFromRect(mulImgBin, rcDiff, mulCompo);
     //     cv::Mat bin(mulCompo, rcDiff);
     //     bool isNoUseBin = false;
     //     if (cv::countNonZero(bin) < 10) {
     //          isNoUseBin = true;
     //          bitDiff.copyTo(mulCompo);
     //     }
     //     cv::Mat bS, bT;
     //     rS.copyTo(bS);
     //     bS = cv::Mat(bS, rcDiff);
     //     rT.copyTo(bT);
     //     bT = cv::Mat(bT, rcDiff);
     //
     //     int dContArea = cv::countNonZero(bitDiff);
     //     cv::bitwise_not(bS, bS);
     //     cv::bitwise_not(bT, bT);
     ////     cv::imwrite("/tmp/bS.tif",bS);
     //     if ((cv::countNonZero(bS) < dContArea) || (cv::countNonZero(bT) < dContArea)) {
     //          isNoUseBin = true;
     //          bitDiff.copyTo(mulCompo);
     //     }
     ////     cv::imwrite("/tmp/mulCompo.tif",mulCompo);
     //
     //     cv::Mat crpSMin, crpTMin;
     //     cv::Mat crpS, crpT;
     //     cv::Mat crpBS, crpBT;
     //     cv::Mat invS, invT;
     //     rS.copyTo(crpS);
     //     rT.copyTo(crpT);
     //     getCroppedComponentImg(rS, rT, mulCompo, crpSMin, crpTMin, isNoUseBin);
     ////     cv::imwrite("/tmp/crpSM.tif",crpSMin);
     ////     cv::imwrite("/tmp/crpTM.tif",crpTMin);
     //     float hash = checkHash("RadialVarianceHash", crpSMin, crpTMin);
     //     if (hash >= 0.9) {
     //          return;
     //     }
     //
     //     cropImageFromMask(mulCompo, crpS, cv::Scalar::all(255));
     //     cropImageFromMask(mulCompo, crpT, cv::Scalar::all(255));
     ////     cv::imwrite("/tmp/crpS.tif",crpS);
     ////     cv::imwrite("/tmp/crpT.tif",crpT);
     //
     //     cv::bitwise_not(crpS, invS);
     //     cv::bitwise_not(crpT, invT);
     //     int sw = cv::countNonZero(invS);
     //     int tw = cv::countNonZero(invT);
     //     if (tmplateMatch((sw > tw)? crpSMin : crpTMin,
     //                      (sw > tw)? crpT : crpS, 0.95)) {
     //          if (abs(sw - tw) < 10) {
     //               return;
     //          }
     //     }
     //
     //     vector<cv::Rect> rectsS = getComponentRects(crpS, 200);
     //     vector<cv::Rect> rectsT = getComponentRects(crpT, 200);
     //     vector<cv::Rect> tmpRectS, tmpRectT, diffRectS, diffRectT;
     //     if ((rectsS.size() == 0) || (rectsT.size() == 0)) {
     //
     //     }
     //     else {
     //          if ((rectsS.size() == rectsT.size()) && (rectsS.size() == 1)) {
     //               tmpRectS = rectsS;
     //               tmpRectT = rectsT;
     //          }
     //          else {
     //               binS.copyTo(crpBS);
     //               binT.copyTo(crpBT);
     //               cropImageFromMask(mulCompo, crpBS, cv::Scalar::all(0));
     //               cropImageFromMask(mulCompo, crpBT, cv::Scalar::all(0));
     //               deleteDuplicateRect(rectsS, rectsT, crpBS, crpBT, tmpRectS, tmpRectT);
     //          }
     //          cropImageFromRects(tmpRectS, crpS, cv::Scalar::all(255));
     //          cropImageFromRects(tmpRectT, crpT, cv::Scalar::all(255));
     //
     //          cout << "tmpRectS = " << tmpRectS.size() << endl;
     //          cout << "tmpRectT = " << tmpRectT.size() << endl;
     //
     //     }
     //
     //     cv::threshold(crpS, crpBS, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
     //     cv::threshold(crpT, crpBT, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
     //     cropImageFromMask(mulCompo, crpBS, cv::Scalar::all(0));
     //     cropImageFromMask(mulCompo, crpBT, cv::Scalar::all(0));
     //     cv::imwrite("/tmp/crpS_out.tif",crpS);
     //     cv::imwrite("/tmp/crpT_out.tif",crpT);
     //     cv::imwrite("/tmp/crpSB.tif",crpBS);
     //     cv::imwrite("/tmp/crpTB.tif",crpBT);
     //
     //
     //
     //
     //     cv::Mat tmpS, tmpT;
     //     crpBS.copyTo(tmpS);
     //     crpBT.copyTo(tmpT);
     //
     //     if ((tmpRectT.size() != 1) && (tmpRectS.size() != 1)) {
     //          vector<cv::Rect> sameRects;
     //          rectsS = getContourRects(crpBS);
     //          rectsT = getContourRects(crpBT);
     //          getDuplicateRect(rectsS, rectsT, crpBS, crpBT, sameRects);
     //          cropImageFromRects(sameRects, crpS, cv::Scalar::all(255), YES);
     //          cropImageFromRects(sameRects, crpT, cv::Scalar::all(255), YES);
     //     }
     //
     //
     //
     //
     
     
     //
     //     getComponentFromMask(crpBS, bitDiff, tmpS);
     //     getComponentFromMask(crpBT, bitDiff, tmpT);
     //
     //     for (auto it = tmpRectS.begin(); it != tmpRectS.end(); ++it) {
     //          for (auto jt = dfRects.begin(); jt != dfRects.end(); ++jt) {
     //               cv::Rect overRc = (*it & *jt);
     //               if (overRc.area() > 0) {
     //                    cout << "x = " << it->x << " y = " << it->y << " w = " << it->width << " h = " << it->height << endl;
     //                    diffRectS.push_back(*it);
     //               }
     //          }
     //
     //     }
     //
     //
     //     for(int i = 0; i < bitDiff.rows; i++ ) {
     //          uchar* s = tmpS.ptr<uchar>(i);
     //          uchar* t = tmpT.ptr<uchar>(i);
     //          for(int j = 0; j < bitDiff.cols; j++ ) {
     //               cv::Point p(j,i);
     //               bool isInside = false;
     //               for (auto c = diffRects.begin(); c != diffRects.end(); ++c) {
     //                     if (p.inside(*c))
     //                          isInside = true;
     //               }
     //
     //               if (!isInside) {
     //                    s[j] = 0;
     //                    t[j] = 0;
     //               }
     //          }
     //     }
     
     
     
     
     
     //
     
     
     
     //     vector<cv::Rect> tmpRectS, tmpRectT, diffRects;
     //     if ((rectsS.size() == rectsT.size()) && (rectsS.size() == 1)) {
     //          tmpRectS = rectsS;
     //          tmpRectT = rectsT;
     //     }
     //     else {
     //          binS.copyTo(crpBS);
     //          binT.copyTo(crpBT);
     //          cropImageFromMask(mulCompo, crpBS, cv::Scalar::all(0));
     //          cropImageFromMask(mulCompo, crpBT, cv::Scalar::all(0));
     //          deleteDuplicateRect(rectsS, rectsT, crpBS, crpBT, tmpRectS, tmpRectT);
     //     }
     //
     //     cropImageFromRects(tmpRectS, crpS, cv::Scalar::all(255));
     //     cropImageFromRects(tmpRectT, crpT, cv::Scalar::all(255));
     
     //     for (auto it = tmpRects.begin(); it != tmpRects.end(); ++it) {
     //          for (auto jt = dfRects.begin(); jt != dfRects.end(); ++jt) {
     //               cv::Rect overRc = (*it & *jt);
     //               if (overRc.area() > 0) {
     //                    cout << "x = " << it->x << " y = " << it->y << " w = " << it->width << " h = " << it->height << endl;
     //                    diffRects.push_back(*it);
     //               }
     //          }
     //
     //     }
     //     cv::imwrite("/tmp/crpMul.tif",crpMul);
     //     cv::threshold(crpMul, mulImgBin, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
     //
     //     //rectsに各コンポーネントの四角が格納される
     //     vector<cv::Rect> rects = getComponentRects(crpMul, 230);
     //
     //     for (auto it = rects.begin(); it != rects.end(); ++it) {
     //          for (auto df = dfRects.begin(); df != dfRects.end(); ++df) {
     //               cv::Rect overRc = (*it & *df);
     //               if (overRc.area() > 0) {
     //                    cv::Mat tmp(mulImgBin, overRc);
     //                    if (cv::countNonZero(tmp) > 1) {
     //                         bool isContain = false;
     //                         for (auto c = diffRects.begin(); c != diffRects.end(); ++c) {
     //                              if (isSameRect(*c, *it)) {
     //                                   isContain = true;
     //                                   break;
     //                              }
     //                         }
     //                         if (!isContain) {
     //                              cout << "x = " << it->x << " y = " << it->y << " w = " << it->width << " h = " << it->height << endl;
     //                              diffRects.push_back(*it);
     //                         }
     //                    }
     //               }
     //          }
     //     }
     //
     //     cv::Mat tmpS, tmpT;
     //     binS.copyTo(tmpS);
     //     binT.copyTo(tmpT);
     //     cropImageFromRects(diffRects, tmpS, cv::Scalar::all(0));
     //     cropImageFromRects(diffRects, tmpT, cv::Scalar::all(0));
     //     getComponentFromMask(binS, bitDiff, tmpS);
     //     getComponentFromMask(binT, bitDiff, tmpT);
     //
     //
     //     for(int i = 0; i < bitDiff.rows; i++ ) {
     //          uchar* s = tmpS.ptr<uchar>(i);
     //          uchar* t = tmpT.ptr<uchar>(i);
     //          for(int j = 0; j < bitDiff.cols; j++ ) {
     //               cv::Point p(j,i);
     //               bool isInside = false;
     //               for (auto c = diffRects.begin(); c != diffRects.end(); ++c) {
     //                     if (p.inside(*c))
     //                          isInside = true;
     //               }
     //
     //               if (!isInside) {
     //                    s[j] = 0;
     //                    t[j] = 0;
     //               }
     //          }
     //     }
     //     cv::imwrite("/tmp/tmpS.tif",tmpS);
     //     cv::imwrite("/tmp/tmpT.tif",tmpT);
     //
     //     cv::Mat labelT, labelS;
     //     int sLab, tLab;
     //     if (isSameComponent(tmpS, tmpT, labelS, labelT, sLab, tLab)) {
     //          tmpS.copyTo(outS);
     //          tmpT.copyTo(outT);
     //          cv::imwrite("/tmp/outS.tif",outS);
     //          cv::imwrite("/tmp/outT.tif",outT);
     //          return;
     //     }
     //
     //
     //     cv::Mat xorBin;
     //     cv::bitwise_xor(tmpS, tmpT, xorBin);
     //     cv::imwrite("/tmp/xorBin.tif",xorBin);
     //     vector<int> delLabS, delLabT;
     //     for (int t = 1; t < sLab; t++) {
     //          bool isAllClear = true;
     //          for (int i = 0; i < mulCompo.rows; i++ ) {
     //               uchar* x = xorBin.ptr<uchar>(i);
     //               int* l = labelS.ptr<int>(i);
     //               for (int j = 0; j < mulCompo.cols; j++ ) {
     //                    if ((l[j] == t) && (x[j] != 0) ) {
     //                         isAllClear = false;
     //                         break;
     //                    }
     //               }
     //               if (!isAllClear) break;
     //          }
     //          if (isAllClear)
     //               delLabS.push_back(t);
     //     }
     //     for (int t = 1; t < tLab; t++) {
     //          bool isAllClear = true;
     //          for (int i = 0; i < mulCompo.rows; i++ ) {
     //               uchar* x = xorBin.ptr<uchar>(i);
     //               int* l = labelT.ptr<int>(i);
     //               for (int j = 0; j < mulCompo.cols; j++ ) {
     //                    if ((l[j] == t) && (x[j] != 0) ) {
     //                         isAllClear = false;
     //                         break;
     //                    }
     //               }
     //               if (!isAllClear) break;
     //          }
     //          if (isAllClear)
     //               delLabT.push_back(t);
     //     }
     //
     //     if (delLabS.size() > 0) {
     //          for (int i = 0; i < mulCompo.rows; i++ ) {
     //               uchar* s = tmpS.ptr<uchar>(i);
     //               uchar* t = tmpT.ptr<uchar>(i);
     //               int* l = labelS.ptr<int>(i);
     //               for (int j = 0; j < mulCompo.cols; j++ ) {
     //                    bool isDelLabel = false;
     //                    for (auto it = delLabS.begin(); it != delLabS.end(); ++it) {
     //                         if (*it == l[j]) isDelLabel = true; break;
     //                    }
     //                    if (isDelLabel) {
     //                         s[j] = 0;
     //                         t[j] = 0;
     //                    }
     //               }
     //          }
     //     }
     //     if (delLabT.size() > 0) {
     //          for (int i = 0; i < mulCompo.rows; i++ ) {
     //               uchar* s = tmpS.ptr<uchar>(i);
     //               uchar* t = tmpT.ptr<uchar>(i);
     //               int* l = labelT.ptr<int>(i);
     //               for (int j = 0; j < mulCompo.cols; j++ ) {
     //                    bool isDelLabel = false;
     //                    for (auto it = delLabT.begin(); it != delLabT.end(); ++it) {
     //                         if (*it == l[j]) isDelLabel = true; break;
     //                    }
     //                    if (isDelLabel) {
     //                         s[j] = 0;
     //                         t[j] = 0;
     //                    }
     //               }
     //          }
     //     }
     //     tmpS.copyTo(outS);
     //     tmpT.copyTo(outT);
     //
     //     cv::imwrite("/tmp/outS.tif",outS);
     //     cv::imwrite("/tmp/outT.tif",outT);
     
}

#pragma mark -
#pragma mark Private Methods







cv::Point normalizeShiftStrict(cv::Point2d shift)
{
     cv::Point retPoint;
     float roundGapX = (float)shift.x * 100.0;
     float roundGapY = (float)shift.y * 100.0;
     
     float X = roundGapX;
     float Y = roundGapY;
     int lowestX = ((int)roundGapX % 10);  roundGapX /= 10;
     int lowX = ((int)roundGapX % 10);
     int lowestY = ((int)roundGapY % 10);  roundGapY /= 10;
     int lowY = ((int)roundGapY % 10);
     
     if ((lowX >= 5) && (lowestX < 5)) {
          X -= 10.0;
     }
     if ((lowY >= 5) && (lowestY < 5)) {
          Y -= 10.0;
     }
     
     X /= 100.0;
     Y /= 100.0;
     
     retPoint.x = round(X);
     retPoint.y = round(Y);
     return retPoint;
}




// 画像から、外周に接する部品を削除
void removeAround(cv::Mat &img, int delPix)
{
     cv::Mat stats, centroids, label;
     int nLab = cv::connectedComponentsWithStats(img, label, stats, centroids, 4, CV_32S);
     std::vector<int> maskRemove;
     cv::Mat lastmask(img.size(), img.type(), cv::Scalar::all(0));

     for (int l = 1; l < nLab; l++) {
          int *param = stats.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          cv::Rect rc = cv::Rect(x,y,w,h);

          if (rc.x >= 0 && rc.x <= delPix) {
               if (rc.width != img.cols) {
                    maskRemove.push_back(l);
               }
          }
          else if (rc.y >= 0 && rc.y <= delPix) {
               if (rc.height != img.rows) {
                    maskRemove.push_back(l);
               }
          }
          else if (((rc.x + rc.width) <= img.cols) &&
                   ((rc.x + rc.width) >= (img.cols - delPix))) {
               maskRemove.push_back(l);
          }
          else if (((rc.y + rc.height) <= img.rows) &&
                   ((rc.y + rc.height) >= (img.rows - delPix))) {
               maskRemove.push_back(l);
          }
     }
     for (int r = 0; r < img.rows; r++) {
          uchar* p = lastmask.ptr<uchar>(r);
          int* lp = label.ptr<int>(r);
          for (int c = 0; c < img.cols; c++) {
               bool isContain = false;
               for (auto it = maskRemove.begin(); it != maskRemove.end(); it++) {
                    if (lp[c] == *it) {
                         isContain = true;
                         break;
                    }
               }
               if (!isContain && lp[c] != 0) p[c] = 255;
          }
     }
     lastmask.copyTo(img);
}

// くっつき分離
void splitStick(cv::Mat &rS, cv::Mat &rT)
{
     cv::Mat andST;
     int curS = cv::countNonZero(rS);
     int curT = cv::countNonZero(rT);
     cv::bitwise_and(rS, rT, andST);
     cv::Mat statsA, centroidsA, labelA;
     cv::Mat statsS, centroidsS, labelS;
     cv::Mat statsT, centroidsT, labelT;
     int aLab = cv::connectedComponentsWithStats(andST, labelA, statsA, centroidsA, 4, CV_32S);
     int sLab = cv::connectedComponentsWithStats(rS, labelS, statsS, centroidsS, 4, CV_32S);
     int tLab = cv::connectedComponentsWithStats(rT, labelT, statsT, centroidsT, 4, CV_32S);
     std::map<int, cv::Rect> sInfo, tInfo, aInfo;
     std::map<int, int> saInfo, taInfo, aaInfo;
     for (int l = 1; l < sLab; l++) {
          int *param = statsS.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          int area = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
          cv::Rect roi(x,y,w,h);
          sInfo[l] = roi;
          saInfo[l] = area;
     }
     
     for (int l = 1; l < tLab; l++) {
          int *param = statsT.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          int area = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
          cv::Rect roi(x,y,w,h);
          tInfo[l] = roi;
          taInfo[l] = area;
     }
     
     for (int l = 1; l < aLab; l++) {
          int *param = statsA.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          int area = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
          cv::Rect roi(x,y,w,h);
          aInfo[l] = roi;
          aaInfo[l] = area;
     }
     
     std::vector<int> sameLabelSA, sameLabelTA; // S-Aの同じコンポ or T-Aの同じコンポ
     for (auto it = aInfo.begin(); it != aInfo.end(); ++it) {
          for (auto jt = sInfo.begin(); jt != sInfo.end(); ++jt) {
               int ax = abs(it->second.tl().x - jt->second.tl().x);
               int ay = abs(it->second.tl().y - jt->second.tl().y);
               int aw = abs(it->second.width - jt->second.width);
               int ah = abs(it->second.height - jt->second.height);
               if ((it->second == jt->second) || ((aw == 2) && (ah == 2) && (ax == 2) && (ay == 2) )) {
                    int aarea = aaInfo[it->first];
                    int sarea = saInfo[jt->first];
                    if (abs(aarea - sarea) <= 10) {
                         sameLabelSA.push_back(jt->first);
                         break;
                    }
               }
          }
     }
     for (auto it = aInfo.begin(); it != aInfo.end(); ++it) {
          for (auto jt = tInfo.begin(); jt != tInfo.end(); ++jt) {
               int ax = abs(it->second.tl().x - jt->second.tl().x);
               int ay = abs(it->second.tl().y - jt->second.tl().y);
               int aw = abs(it->second.width - jt->second.width);
               int ah = abs(it->second.height - jt->second.height);
               if ((it->second == jt->second) || ((aw == 0) && (ah == 0) && (ax == 0) && (ay == 0) )) {
                    int aarea = aaInfo[it->first];
                    int tarea = taInfo[jt->first];
                    if (abs(aarea - tarea) <= 10) {
                         sameLabelTA.push_back(jt->first);
                         break;
                    }
               }
          }
     }

     if (sameLabelSA.size() != 0) {
          for (auto it = sameLabelSA.begin(); it != sameLabelSA.end(); ++it) {
               for (int r = 0; r < rS.rows; r++) {
                    uchar* sp = rS.ptr<uchar>(r);
                    uchar* tp = rT.ptr<uchar>(r);
                    int* lsp = labelS.ptr<int>(r);
                    for (int c = 0; c < rS.cols; c++) {
                         if (lsp[c] == *it) {
                              sp[c] = 0;
                              tp[c] = 0;
                         }
                    }
               }
          }
     }
     else if (sameLabelTA.size() != 0) {
          for (auto it = sameLabelTA.begin(); it != sameLabelTA.end(); ++it) {
               for (int r = 0; r < rT.rows; r++) {
                    uchar* sp = rS.ptr<uchar>(r);
                    uchar* tp = rT.ptr<uchar>(r);
                    int* lsp = labelT.ptr<int>(r);
                    for (int c = 0; c < rT.cols; c++) {
                         if (lsp[c] == *it) {
                              sp[c] = 0;
                              tp[c] = 0;
                         }
                    }
               }
          }
     }
     
     int finS = cv::countNonZero(rS);
     int finT = cv::countNonZero(rT);
     if (curS == finS && curT == finT) {
          // xorマスクを使った分離
          cv::Mat xorST, src, trg;
          curS = cv::countNonZero(rS);
          curT = cv::countNonZero(rT);
          cv::bitwise_xor(rS, rT, xorST);
          if (curS > curT) {
               rS.copyTo(src);
               rT.copyTo(trg);
          }
          else {
               rS.copyTo(trg);
               rT.copyTo(src);
          }
     }
     
}

// 指定した両方の画像から、位置と大きさが同じで、領域の差が10以内の部品を削除
void removeSame(cv::Mat &rS, cv::Mat &rT)
{
     cv::Mat statsS, centroidsS, labelS;
     cv::Mat statsT, centroidsT, labelT;
     std::map<int, cv::Rect> sInfo, tInfo;
     std::map<int, int> saInfo, taInfo;
     int sLab = cv::connectedComponentsWithStats(rS, labelS, statsS, centroidsS, 4, CV_32S);
     int tLab = cv::connectedComponentsWithStats(rT, labelT, statsT, centroidsT, 4, CV_32S);
     std::vector<int> removeLabelS, removeLabelT;
     
     for (int l = 1; l < sLab; l++) {
          int *param = statsS.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          int area = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
          cv::Rect roi(x,y,w,h);
          sInfo[l] = roi;
          saInfo[l] = area;
     }
     for (int l = 1; l < tLab; l++) {
          int *param = statsT.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          int area = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
          cv::Rect roi(x,y,w,h);
          tInfo[l] = roi;
          taInfo[l] = area;
     }
     for (auto it = sInfo.begin(); it != sInfo.end(); ++it) {
          for (auto jt = tInfo.begin(); jt != tInfo.end(); ++jt) {
               int ax = abs(it->second.tl().x - jt->second.tl().x);
               int ay = abs(it->second.tl().y - jt->second.tl().y);
               int aw = abs(it->second.width - jt->second.width);
               int ah = abs(it->second.height - jt->second.height);
               if ((it->second == jt->second) || ((aw == 0) && (ah == 0) && (ax == 0) && (ay == 0) )) {
                    int sarea = saInfo[it->first];
                    int tarea = taInfo[jt->first];
                    if (abs(sarea - tarea) <= 10) {
                         removeLabelS.push_back(it->first);
                         removeLabelT.push_back(jt->first);
                         break;
                    }
               }
          }
     }
     
     for (int r = 0; r < rS.rows; r++) {
          uchar* sp = rS.ptr<uchar>(r);
          uchar* tp = rT.ptr<uchar>(r);
          int* lsp = labelS.ptr<int>(r);
          int* ltp = labelT.ptr<int>(r);
          for (int c = 0; c < rS.cols; c++) {
               for (auto it = removeLabelS.begin(); it != removeLabelS.end(); it++) {
                    if (lsp[c] == *it) {
                         sp[c] = 0;
                         break;
                    }
               }
               for (auto it = removeLabelT.begin(); it != removeLabelT.end(); it++) {
                    if (ltp[c] == *it) {
                         tp[c] = 0;
                         break;
                    }
               }
          }
     }
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
            write(diffAdd, setting.delColor, setting.backAlphaColor, contour, setting.lineThickness, setting.isFillLine);
        }
    }
    
    for (int i = 0; i < res.diffAreas.size(); i++) {
        auto contour = res.diffAreas.at(i);
        if(isAllColor){
            write(diffAdd, fillColor, setting.backAlphaColor, contour, setting.lineThickness, setting.isFillLine);
        }
        else{
            write(diffAdd, setting.diffColor, setting.backAlphaColor, contour, setting.lineThickness, setting.isFillLine);
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



cv::Mat DiffImgCore::openImg(const char* path)
{
    return cv::imread(path, cv::IMREAD_COLOR);
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




/*
 cv::Rect extCrop(cropRect.x - extCropSize,
 cropRect.y - extCropSize,
 cropRect.width + (extCropSize * 2),
 cropRect.height + (extCropSize * 2));
 
 cv::Rect bigCropExt(extCrop.x * VIEW_SCALE,
 extCrop.y * VIEW_SCALE,
 extCrop.width * VIEW_SCALE,
 extCrop.height * VIEW_SCALE);
 
 cv::Rect bigCrop(cropRect.x * VIEW_SCALE,
 cropRect.y * VIEW_SCALE,
 cropRect.width * VIEW_SCALE,
 cropRect.height * VIEW_SCALE);
 */



//void removeSameComponent(cv::Mat &maskedS, cv::Mat &maskedT)
//{
//    cv::Mat statsS,statsT;
//    cv::Mat centroidsS,centroidsT;
//    cv::Mat labelSE, labelTE;
//    std::vector<std::vector<size_t> > sameIndex;
//    int sLab = cv::connectedComponentsWithStats(maskedS, labelSE, statsS, centroidsS, 4, CV_32S);
//    int tLab = cv::connectedComponentsWithStats(maskedT, labelTE, statsT, centroidsT, 4, CV_32S);
//    cv::Rect totalRectS,totalRectT;
//    std::vector<cv::Size> sSize, tSize;
//    std::vector<cv::Rect> sRect, tRect;
//    std::vector<int> sArea, tArea;
//
//    for(int i = 1; i < tLab; ++i){
//        int *param = statsT.ptr<int>(i);
//        int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
//        int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
//        int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
//        int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
//        int a = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
//        cv::Rect theR(x,y,w,h);
//        tRect.push_back(theR);
//        totalRectT |= theR;
//        tSize.push_back(cv::Size(w,h));
//        tArea.push_back(a);
//    }
//    for(int i = 1; i < sLab; ++i){
//        int *param = statsS.ptr<int>(i);
//        int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
//        int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
//        int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
//        int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
//        int a = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
//        cv::Rect theR(x,y,w,h);
//        sRect.push_back(theR);
//        totalRectS |= theR;
//        sSize.push_back(cv::Size(w,h));
//        sArea.push_back(a);
//    }
//
//    for (auto it = sRect.begin(); it != sRect.end(); it++) {
//        for (auto jt = tRect.begin(); jt != tRect.end(); jt++) {
//            if (*it == *jt) {
//                bool isContain = false;
//                std::vector<size_t> indexes;
//                size_t indexS = std::distance(sRect.begin(), it);
//                size_t indexT = std::distance(tRect.begin(), jt);
//                int sA = sArea.at(indexS);
//                int tA = tArea.at(indexT);
//                indexes.push_back(indexS);
//                indexes.push_back(indexT);
//                for (auto kt = sameIndex.begin(); kt != sameIndex.end(); kt++) {
//                    if (*kt == indexes) {
//                        isContain = true;
//                        break;
//                    }
//                }
//                if (!isContain && sA == tA && sA < 40) {
//                    sameIndex.push_back(indexes);
//                }
//                break;
//            }
//        }
//    }
//    if (sameIndex.size() != 0) {
//        if ((sLab == 2) && (tLab == 2)) return;
//        for (int r = 0; r < maskedS.rows; r++) {
//            uchar* msp = maskedS.ptr<uchar>(r);
//            int* slp = labelSE.ptr<int>(r);
//            for (int c = 0; c < maskedS.cols; c++) {
//                bool isDel = false;
//                for (auto it = sameIndex.begin(); it != sameIndex.end(); it++) {
//                    if (slp[c] == (int)(it->at(0)) + 1) {
//                        isDel = true;
//                        break;
//                    }
//                }
//                if (isDel) msp[c] = 0;
//            }
//        }
//        for (int r = 0; r < maskedT.rows; r++) {
//            uchar* mtp = maskedT.ptr<uchar>(r);
//            int* tlp = labelTE.ptr<int>(r);
//            for (int c = 0; c < maskedT.cols; c++) {
//                bool isDel = false;
//                for (auto it = sameIndex.begin(); it != sameIndex.end(); it++) {
//                    if (tlp[c] == (int)(it->at(1)) + 1) {
//                        isDel = true;
//                        break;
//                    }
//                }
//                if (isDel) mtp[c] = 0;
//            }
//        }
//    }
//}



std::vector<cv::Mat> splitImage(cv::Mat imgCnt)
{
    cv::imwrite("/tmp/imgCnt.tif", imgCnt);
    cv::Mat stats, centroids, label;
    cv::connectedComponentsWithStats(imgCnt, label, stats, centroids, 4, CV_32S);
    std::vector<cv::Mat> maskCompo;
    std::vector<int> writeArrange;

    // 出現順に書き込む
    for (int r = 0; r < imgCnt.rows; r++) {
        int* lpe = label.ptr<int>(r);
        for (int c = 0; c < imgCnt.cols; c++) {
            if (lpe[c] != 0) {
                bool isContain = false;
                for (auto kt = writeArrange.begin(); kt != writeArrange.end(); kt++) {
                    if (*kt == lpe[c]) {
                        isContain = true;
                        break;
                    }
                }
                if (!isContain) {
                    writeArrange.push_back(lpe[c]);
                }
            }
        }
    }
    if (writeArrange.size() == 1) {
        maskCompo.push_back(imgCnt);
        return maskCompo;
    }
    for (auto l = writeArrange.begin(); l != writeArrange.end(); l++) {
        cv::Mat theImg(imgCnt.size(), imgCnt.type(), cv::Scalar::all(0));
        for (int r = 0; r < imgCnt.rows; r++) {
            uchar *wp = theImg.ptr<uchar>(r);
            int* lpe = label.ptr<int>(r);
            for (int c = 0; c < imgCnt.cols; c++) {
                if (lpe[c] == *l) {
                    wp[c] = 255;
                }
            }
        }
        cv::imwrite("/tmp/theImg.tif", theImg);
        maskCompo.push_back(theImg);
    }

    return maskCompo;
}

void moveImageWhite(cv::Mat src, cv::Mat &dst, int dx, int dy, bool inv) {
     cv::Mat moveMat;
     if (!inv)
          moveMat = (cv::Mat_<double>(2,3)<<1.0, 0.0, dx, 0.0, 1.0, dy);
     else
          moveMat = (cv::Mat_<double>(2,3)<<1.0, 0.0, -1.0 * dx, 0.0, 1.0, -1.0 * dy);
     dst = cv::Mat(src.rows, src.cols, src.type(), cv::Scalar::all(255));
     cv::warpAffine(src, dst, moveMat, dst.size(), cv::INTER_CUBIC, cv::BORDER_REPLICATE, cv::Scalar::all(255));
}

void moveImage(cv::Mat src, cv::Mat &dst, int dx, int dy, bool inv) {
     cv::Mat moveMat;
     if (!inv)
          moveMat = (cv::Mat_<double>(2,3)<<1.0, 0.0, dx, 0.0, 1.0, dy);
     else
          moveMat = (cv::Mat_<double>(2,3)<<1.0, 0.0, -1.0 * dx, 0.0, 1.0, -1.0 * dy);
    dst = cv::Mat::zeros(src.rows, src.cols, src.type());
    cv::warpAffine(src, dst, moveMat, dst.size(), cv::INTER_CUBIC, cv::BORDER_REPLICATE, cv::Scalar::all(0));
}

// srcとdstでお互いに白の部分を合成
//void mergeImage(cv::Mat src, cv::Mat &dst) {
//    for (int r = 0; r < src.rows; r++) {
//        uchar* sp = src.ptr<uchar>(r);
//        uchar* dp = dst.ptr<uchar>(r);
//
//        for (int c = 0; c < src.cols; c++) {
//            if (sp[c] == 255) {
//                dp[c] = 255;
//            }
//        }
//    }
//}







// 指定したMat同士で、同じエリアの白を消す
void delSameAreaWhite(cv::Mat dued, cv::Mat &trg)
{
    cv::Mat stats, centroids, label;
    cv::Mat statst, centroidst, labelt;
    int nLab = cv::connectedComponentsWithStats(dued, label, stats, centroids, 8, CV_32S);
    int tLab = cv::connectedComponentsWithStats(trg, labelt, statst, centroidst, 8, CV_32S);
    
    std::vector<int> imgAreaSize, trgArea;
    for (int l = 1; l < nLab; l++) {
        int *param = stats.ptr<int>(l);
        int a = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
        bool isContain = false;
        for (auto it = imgAreaSize.begin(); it != imgAreaSize.end(); it++) {
            if (a == *it) {
                isContain = true;
                break;
            }
        }
        if (!isContain) imgAreaSize.push_back(a);
    }
    for (int l = 1; l < tLab; l++) {
        int *param = statst.ptr<int>(l);
        int a = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
        bool isTrg = false;
        for (auto it = imgAreaSize.begin(); it != imgAreaSize.end(); it++) {
            if (a == *it) {
                isTrg = true;
                break;
            }
        }
        if (isTrg) {
            bool isContain = false;
            for (auto it = trgArea.begin(); it != trgArea.end(); it++) {
                if (l == *it) {
                    isContain = true;
                    break;
                }
            }
            if (!isContain) trgArea.push_back(l);
        }
    }
    for (int r = 0; r < trg.rows; r++) {
        uchar* p = trg.ptr<uchar>(r);
        int* lp = labelt.ptr<int>(r);
        for (int c = 0; c < trg.cols; c++) {
            bool isDel = false;
            for (auto it = trgArea.begin(); it != trgArea.end(); it++) {
                if (lp[c] == *it) {
                    isDel = true;
                    break;
                }
            }
            if (isDel) {
                p[c] = 0;
            }
        }
    }
}

void removeSameWhite(cv::Mat &imgS, cv::Mat &imgT)
{
    for (int r = 0; r < imgS.rows; r++) {
        uchar* sp = imgS.ptr<uchar>(r);
        uchar* tp = imgT.ptr<uchar>(r);
        for (int c = 0; c < imgS.cols; c++) {
            if ((sp[c] == tp[c]) && sp[c] == 255) {
                sp[c] = 0;
                tp[c] = 0;
            }
        }
    }
}



// 面積計算アルゴリズム（画素数）
int calculateArea(cv::Mat image) {
    cv::Mat grayMat;
    cv::cvtColor(image, grayMat, cv::COLOR_BGR2GRAY);
    return cv::countNonZero(grayMat);
}

// 画像の分割アルゴリズム
void divide(cv::Mat base, cv::Mat &divLabel) {
    // Watershed分割
    // グレースケール
    cv::Mat thresh;
    cv::threshold(base, thresh, 0, 255, cv::THRESH_BINARY | cv::THRESH_OTSU);
    cv::imwrite("/tmp/thresh.png", thresh);
    
    // 背景領域抽出
    cv::Mat sure_bg;
    cv::Mat kernel(3, 3, CV_8U, cv::Scalar(1));
    cv::dilate(thresh, sure_bg, kernel, cv::Point(-1,-1), 3);
    cv::imwrite("/tmp/sure_bg.png", sure_bg);
    
    // 前景領域抽出
    cv::Mat dist_transform;
    cv::distanceTransform(thresh, dist_transform, cv::DIST_L2, 3);
    
    cv::Mat sure_fg;
    double minVal, maxVal;
    cv::Point minLoc, maxLoc;
    cv::minMaxLoc(dist_transform, &minVal, &maxVal, &minLoc, &maxLoc);
    cv::threshold(dist_transform, sure_fg, 0.3*maxVal, 255, 0);
    dist_transform = dist_transform/maxVal;
    cv::imwrite("/tmp/dist_transform.png", dist_transform);
    cv::imwrite("/tmp/sure_fg.png", sure_fg);
    
    // 不明領域抽出
    cv::Mat unknown, sure_fg_uc1;
    sure_fg.convertTo(sure_fg_uc1, CV_8UC1);
    cv::subtract(sure_bg, sure_fg_uc1, unknown);
    cv::imwrite("/tmp/unknown.png", unknown);
    
    
    // 前景ラベリング
    int compCount = 0;
    std::vector<std::vector<cv::Point> > contours;
    std::vector<cv::Vec4i> hierarchy;
    sure_fg.convertTo(sure_fg, CV_32SC1, 1.0);
    cv::findContours(sure_fg, contours, hierarchy, cv::RETR_CCOMP, cv::CHAIN_APPROX_SIMPLE);
    if( contours.empty() ) return;
    divLabel = cv::Mat::zeros(sure_fg.rows, sure_fg.cols, CV_32SC1);
    int idx = 0;
    for( ; idx >= 0; idx = hierarchy[idx][0], compCount++ )
        cv::drawContours(divLabel, contours, idx, cv::Scalar::all(compCount+1), -1, cv::LINE_8, hierarchy, INT_MAX);
    divLabel = divLabel+1;
    
    // 不明領域は今のところゼロ
    for(int i=0; i<divLabel.rows; i++){
        for(int j=0; j<divLabel.cols; j++){
            unsigned char &v = unknown.at<unsigned char>(i, j);
            if(v==255){
                divLabel.at<int>(i, j) = 0;
            }
        }
    }
    
    // 分水嶺
    cv::Mat m_src;
    base.copyTo(m_src);
    cv::cvtColor(m_src, m_src, cv::COLOR_GRAY2BGR);
    cv::watershed( m_src, divLabel );
    
    cv::Mat wshed(divLabel.size(), CV_8UC3);
    std::vector<cv::Vec3b> colorTab;
    for(int i = 0; i < compCount; i++ )
    {
        int b = cv::theRNG().uniform(0, 255);
        int g = cv::theRNG().uniform(0, 255);
        int r = cv::theRNG().uniform(0, 255);
        
        colorTab.push_back(cv::Vec3b((uchar)b, (uchar)g, (uchar)r));
    }
    
    // paint the watershed image
    for(int i = 0; i < divLabel.rows; i++ ){
        for(int j = 0; j < divLabel.cols; j++ )
        {
            int index = divLabel.at<int>(i,j);
            if( index == -1 )
                wshed.at<cv::Vec3b>(i,j) = cv::Vec3b(255,255,255);
            else if( index <= 0 || index > compCount )
                wshed.at<cv::Vec3b>(i,j) = cv::Vec3b(0,0,0);
            else
                wshed.at<cv::Vec3b>(i,j) = colorTab[index - 1];
        }
    }
    cv::Mat imgG;
    cv::cvtColor(base, imgG, cv::COLOR_GRAY2BGR);
    wshed = wshed*0.5 + imgG*0.5;
    cv::imwrite("/tmp/watershed transform.png", wshed);
}



void getRectFromComponentImg(cv::Mat img, cv::Rect &roi)
{
     std::vector<std::vector<cv::Point>> cnt;
     cv::findContours(img, cnt, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
     roi = cv::Rect();
     if (cnt.size() != 0) {
          for (auto it = cnt.begin(); it != cnt.end(); ++it) {
               roi |= cv::boundingRect(*it);
          }
     }
}

// コンポーネントごとに画像を分離
std::vector<cv::Mat> splitComponent(cv::Mat img, std::vector<cv::Rect> rois)
{
     std::vector<cv::Mat> retImgs;
     
     for (auto it = rois.begin(); it != rois.end(); ++it) {
          
          cv::Mat piece;
          getComponentFromRect(img, *it, piece);
          bool isContain = false;
          for (auto mt = retImgs.begin(); mt != retImgs.end(); ++mt) {
               if (std::equal(mt->begin<uchar>(), mt->end<uchar>(), piece.begin<uchar>())) {
                    isContain = true;
                    break;
               }
          }
          if (!isContain) {
               if (cv::countNonZero(piece) != 0)
                    retImgs.push_back(piece);
          }
     }
     
     return retImgs;
}




//bool DiffImgCore::checkShade (cv::Mat rS, cv::Mat rT, cv::Mat maskS, cv::Mat maskT)
//{
//     cv::Mat orMask;
//     cv::bitwise_or(maskS, maskT, orMask);
//     std::vector<cv::Rect> rows = getRowRects(orMask);
//     std::vector<cv::Rect> cols = getColRects(orMask);
//     std::vector<cv::Mat> sImgs, tImgs;
//
//     double res_poc = 0;
//     auto sht = getPOCPos(maskS, maskT, &res_poc, setting.gapPix);
//     auto shift = normalizeShiftValue(sht);
//
//
//     if ((rows.size() != 1) || (cols.size() != 1)) {
//          if (rows.size() > cols.size()) {
//               sImgs = splitComponent(maskS, rows);
//               tImgs = splitComponent(maskT, rows);
//          }
//          else {
//               sImgs = splitComponent(maskS, cols);
//               tImgs = splitComponent(maskT, cols);
//          }
//          if (sImgs.size() != tImgs.size()) {
//               sImgs.push_back(maskS);
//               tImgs.push_back(maskT);
//          }
//     }
//     else {
//          std::vector<cv::Rect> rowsS = getRowRects(maskS);
//          std::vector<cv::Rect> colsS = getColRects(maskS);
//          std::vector<cv::Rect> rowsT = getRowRects(maskT);
//          std::vector<cv::Rect> colsT = getColRects(maskT);
//          if (((rowsS.size() == 1) && (colsS.size() == 1)) &&
//              ((rowsT.size() == 1) && (colsT.size() == 1))) {
//               sImgs.push_back(maskS);
//               tImgs.push_back(maskT);
//          }
//          else {
//
//               sImgs = splitImage(maskS);
//               tImgs = splitImage(maskT);
//               if (sImgs.size() != tImgs.size()) {
//                    cv::Mat mv;
//                    moveImage(maskS, mv, shift.x, shift.y, false);
//                    cv::bitwise_and(mv, maskT, maskT);
//                    sImgs.clear();
//                    tImgs.clear();
//                    sImgs = splitImage(maskS);
//                    tImgs = splitImage(maskT);
//                    if (sImgs.size() != tImgs.size()) {
//                         sImgs.clear();
//                         tImgs.clear();
//                         sImgs.push_back(maskS);
//                         tImgs.push_back(maskT);
//                    }
//
//               }
//          }
//     }
//
//     bool isFalse = false;
//     for (int i = 0; i < sImgs.size(); i++) {
//          cv::Mat maskedS = sImgs.at(i);
//          cv::Mat maskedT = tImgs.at(i);
//          cv::Rect rcS = getContourRect(maskedS, cv::Rect());
//          cv::Rect rcT = getContourRect(maskedT, cv::Rect());
//          cv::Mat diffS, diffT;
//
//          if (rcS.size() != rcT.size()) {
//               rcS.width = rcT.width;
//               rcS.height = rcT.height;
//          }
//          util->cropSafe(rS, diffS, rcS, true);
//          util->cropSafe(rT, diffT, rcT, true);
//          sht = getPOCPos(diffS, diffT, &res_poc, setting.gapPix);
//          shift = normalizeShiftValue(sht);
//          if (shift != cv::Point())
//               moveImageWhite(diffS, diffS, shift.x, shift.y, false);
//
//          util->dbgSave(diffS, "diffS.tif", 0);
//          util->dbgSave(diffT, "diffT.tif", 0);
//          cv::Mat eraseMat;
//          cv::bitwise_xor(diffS, diffT, eraseMat);
//          cv::threshold(eraseMat, eraseMat, 0, 255, cv::THRESH_BINARY);
//          delMinAreaWhite(eraseMat, 2);
//          util->dbgSave(eraseMat, "0_eraseMat.tif", false);
//          if (!isExistsContour(eraseMat)) return true;
//
//          cv::Mat hikaku = cv::Mat::zeros(diffS.rows, diffS.cols, diffS.type());
//          for (int r = 0; r < diffS.rows; r++) {
//               uchar* sp = diffS.ptr<uchar>(r);
//               uchar* tp = diffT.ptr<uchar>(r);
//               uchar* ep = eraseMat.ptr<uchar>(r);
//               uchar* hp = hikaku.ptr<uchar>(r);
//               for (int c = 0; c < diffS.cols; c++) {
//                    if (ep[c] == 255) {
//                         int absVal = abs(sp[c] - tp[c]);
//                         if (absVal > 60) {
//                              hp[c] = 255;
//                         }
//                    }
//               }
//          }
//          util->dbgSave(hikaku, "1_hikaku.tif", false);
//          if (!isExistsContour(hikaku)) {
//               continue;
//          }
//
//          int whiteHikaku = cv::countNonZero(hikaku);
//          float hiritsu = 0.0;
//          float hiritsu_base = rcS.height;
//          if (rcS.width == rcS.height) {
//               hiritsu = 1.0;
//          }
//          else if (rcS.width < rcS.height) {
//               hiritsu = (float)(rcS.height) / (float)(rcS.width);
//          }
//          else if (rcS.width > rcS.height) {
//               hiritsu =  (float)(rcS.width) / (float)(rcS.height);
//               hiritsu_base = rcS.width;
//          }
//
//          if (whiteHikaku > (hiritsu * hiritsu_base) * 1.1) {
//
////               auto re = util->tmplateMatch(rT, diffS, 0.98, 1);
////               if (re.isMatch) continue;
////               else {
////                    util->cropSafe(binS, diffS, srect, false);
////                    util->cropSafe(binT, diffT, trect, false);
////                    util->dbgSave(diffS, "1_diffS.tif", false);
////                    util->dbgSave(diffT, "1_diffT.tif", false);
////                    double similarity = cv::matchShapes(diffS, diffT, cv::CONTOURS_MATCH_I1, 0);    // huモーメントによるマッチング
////                    if (similarity == 0) continue;
////                    else if (similarity > 0.004) {
//                         isFalse = true;
////                    }
////               }
//
//          }
//     }
//
//     if (isFalse) return false;
//     return true;
//}


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

std::vector<cv::Rect> DiffImgCore::getRowRects(cv::Mat& img)
{
    cv::Mat bin, integlal;
    cv::threshold(img, bin, 0, 255, cv::THRESH_BINARY);
     cv::imwrite("/tmp/bin.tif", bin);
    util->getInteglal(bin, integlal);
    std::vector<cv::Range> rowRange;
    rowRange = util->searchRows(integlal);
    cv::Mat rowCutMask = cv::Mat::zeros(bin.rows, bin.cols, CV_8UC1);
    for(int y = 0; y < rowRange.size(); y++){
        cv::Rect wPos;
        
        wPos = cv::Rect(0,
                        rowRange.at(y).start,
                        img.cols,
                        (rowRange.at(y).end - rowRange.at(y).start));
        cv::rectangle(rowCutMask, wPos.tl(), wPos.br(), cv::Scalar::all(255), -1, cv::LINE_8, 0);
    }
    cv::imwrite("/tmp/rowCutMask.tif", rowCutMask);
    cv::bitwise_not(rowCutMask, rowCutMask);
    std::vector<std::vector<cv::Point> > vctContours;
    std::vector<cv::Rect> rowRects;
    cv::findContours(rowCutMask, vctContours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
    for (auto it = vctContours.begin(); it != vctContours.end(); it++) {
        cv::Rect theRect = cv::boundingRect(*it);
        rowRects.push_back(theRect);
    }
    return rowRects;
}

std::vector<cv::Rect> DiffImgCore::getColRects(cv::Mat& img)
{
    cv::Mat bin, integlal;
    cv::threshold(img, bin, 0, 255, cv::THRESH_BINARY);
    util->getInteglal(bin, integlal);
    std::vector<cv::Range> colRange;
    colRange = util->searchColumns(integlal);
    cv::Mat colCutMask = cv::Mat::zeros(bin.rows, bin.cols, CV_8UC1);
    for(int x = 0; x < colRange.size(); x++){
        cv::Rect wPos;
         wPos = cv::Rect(colRange.at(x).start,
                        0,
                        (colRange.at(x).end - colRange.at(x).start),
                        img.rows);
        cv::rectangle(colCutMask, wPos.tl(), wPos.br(), cv::Scalar::all(255), -1, cv::LINE_8, 0);
    }
    cv::imwrite("/tmp/colCutMask.tif", colCutMask);
    cv::bitwise_not(colCutMask, colCutMask);
    std::vector<std::vector<cv::Point> > vctContours;
    std::vector<cv::Rect> colRects;
    cv::findContours(colCutMask, vctContours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
    for (auto it = vctContours.begin(); it != vctContours.end(); it++) {
        cv::Rect theRect = cv::boundingRect(*it);
        colRects.push_back(theRect);
    }
    return colRects;
}









// bin に含まれる白と重なる binE を抽出
bool getMaskImage(cv::Mat bin, cv::Mat binE, cv::Mat &mask, cv::Rect &roi)
{
    cv::Mat stats, centroids, label;
    cv::connectedComponentsWithStats(binE, label, stats, centroids, 4, CV_32S);
    std::vector<int> maskCompo;
    for (int r = 0; r < binE.rows; r++) {
        uchar* bp = bin.ptr<uchar>(r);
        uchar* bpe = binE.ptr<uchar>(r);
        int* lpe = label.ptr<int>(r);
        for (int c = 0; c < binE.cols; c++) {
             if (bp[c] == 255 && bpe[c] == 255) {
                bool isContain = false;
                for (auto it = maskCompo.begin(); it != maskCompo.end(); it++) {
                    if (lpe[c] == *it) {
                        isContain = true;
                        break;
                    }
                }
                if (!isContain) maskCompo.push_back(lpe[c]);
            }
        }
    }
    
    if (maskCompo.size() == 0) return false;
    
    getLabelComponent(label, maskCompo, binE, mask);

    int nLab = cv::connectedComponentsWithStats(mask, label, stats, centroids, 4, CV_32S);
    if (nLab == 1) return false;
    roi = cv::Rect(0,0,0,0);
    for (int l = 1; l < nLab; l++) {
        int *param = stats.ptr<int>(l);
        int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
        int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
        int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
        int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
        roi |= cv::Rect(x,y,w,h);
    }
    return true;
}


// どちらかに余分なマスクがある場合の処理
// 白が多いエリアに合わせる
void adjustMask(cv::Mat &binS, cv::Mat &binT, cv::Mat binSE, cv::Mat binTE, float gap)
{
     double poc_result = 0;
     cv::Point2d shift_org;
     shift_org = getPOCPos(binS, binT, &poc_result, gap);
     cv::Point shift = normalizeShiftValue(shift_org);
     int sW = cv::countNonZero(binS);
     int tW = cv::countNonZero(binT);
     int isMove = 0;
     if (sW < tW) isMove = 1; // Tに合わせる
     else isMove = 2; // Sに合わせる
     cv::Mat warpBin;
     cv::Rect roi;
     // まずは位置あわせ
     if (isMove == 1) {
          std::cout << "    Adjust to Trg" << std::endl;
          moveImage(binT, warpBin, shift.x, shift.y, true);
          getMaskImage(warpBin, binSE, binS, roi);
     }
     else if (isMove == 2) {
          std::cout << "    Adjust to Src" << std::endl;
          moveImage(binS, warpBin, shift.x, shift.y, false);
          getMaskImage(warpBin, binTE, binT, roi);
     }
}

// 二つのマスクから、外れのコンポーネントを統合
void delOutComponent(cv::Mat &rS, cv::Mat &rT)
{
     cv::Mat src, trg, trgl, mvs;
     
     double res;
     auto sh = getPOCPos(rS, rT, &res, 4);
     auto shift = normalizeShiftValue(sh);
     
     int sW = cv::countNonZero(rS);
     int tW = cv::countNonZero(rT);
     
     if (sW > tW) {
          rS.copyTo(src);
          rT.copyTo(trg);
     }
     else {
          rS.copyTo(trg);
          rT.copyTo(src);
     }
     
     moveImage(src, mvs, shift.x, shift.y, false);

     cv::Mat stats, centroids, label;
     cv::Mat statst, centroidst, labelt;
     int nLab = cv::connectedComponentsWithStats(mvs, label, stats, centroids, 8, CV_32S);
     int tLab = cv::connectedComponentsWithStats(trg, labelt, statst, centroidst, 8, CV_32S);
     
     std::map<int, cv::Rect> sRects, tRects;
     
     for (int l = 1; l < nLab; l++) {
          int *param = stats.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          cv::Rect rc(x,y,w,h);
          
          bool isContain = false;
          for (auto it = sRects.begin(); it != sRects.end(); it++) {
               if (rc == it->second) {
                    isContain = true;
                    break;
               }
          }
          if (!isContain) sRects[l] = rc;
     }
     
     for (int l = 1; l < tLab; l++) {
          int *param = statst.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          cv::Rect rc(x,y,w,h);
          
          bool isContain = false;
          for (auto it = tRects.begin(); it != tRects.end(); it++) {
               if (rc == it->second) {
                    isContain = true;
                    break;
               }
          }
          if (!isContain) tRects[l] = rc;
     }
     
     std::map<int, cv::Rect> addRects;
     for (auto it = sRects.begin(); it != sRects.end(); it++) {
          cv::Rect rc = it->second;
          bool isTarg = true;
          for (auto jt = tRects.begin(); jt != tRects.end(); jt++) {
               if ((jt->second & it->second) != cv::Rect()) {
                    isTarg = false;
               }
          }
          if (isTarg) addRects[it->first] = it->second;
     }
     
     for (int r = 0; r < trg.rows; r++) {
          uchar* p = trg.ptr<uchar>(r);
          int* lp = label.ptr<int>(r);
          for (int c = 0; c < trg.cols; c++) {
               bool isAdd = false;
               for (auto it = addRects.begin(); it != addRects.end(); it++) {
                    if (lp[c] == it->first) {
                         isAdd = true;
                         break;
                    }
               }
               if (isAdd) {
                    p[c] = 255;
               }
          }
     }
     if (sW > tW) {
          src.copyTo(rS);
          trg.copyTo(rT);
     }
     else {
          trg.copyTo(rS);
          src.copyTo(rT);
     }
}

// 座標順にコンポーネント分割
std::vector<std::vector<cv::Mat>> divideComponent(cv::Mat imgS, cv::Mat imgT)
{
     std::vector<std::vector<cv::Mat>> ret;
     std::vector<cv::Mat> imgsS;
     std::vector<cv::Mat> imgsT;
     cv::Mat statsS, centroidsS, labelS;
     cv::Mat statsT, centroidsT, labelT;
     int nLab = cv::connectedComponentsWithStats(imgS, labelS, statsS, centroidsS, 4, CV_32S);
     std::map<int, cv::Rect> rectsS, rectsT;
     for (int l = 1; l < nLab; l++) {
          int *param = statsS.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          rectsS[l] = cv::Rect(x,y,w,h);
     }
     nLab = cv::connectedComponentsWithStats(imgT, labelT, statsT, centroidsT, 4, CV_32S);
     for (int l = 1; l < nLab; l++) {
          int *param = statsT.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          rectsT[l] = cv::Rect(x,y,w,h);
     }
     std::vector<int> labelsT;

     for (auto it = rectsS.begin(); it != rectsS.end(); ++it) {
          for (auto jt = rectsT.begin(); jt != rectsT.end(); ++jt) {
               if ((jt->second & it->second) != cv::Rect()) {
                    labelsT.push_back(jt->first);
                    break;
               }
          }
     }
     
     
     
     std::cout << "calced" << std::endl;
     ret.push_back(imgsS);
     ret.push_back(imgsT);
     return ret;
}





int DiffImgCore::adjustMaskPosition(cv::Mat source, cv::Mat trg, cv::Mat &maskS, cv::Mat &maskSorg, cv::Mat &maskSorgbin, bool isRound, cv::Point &shift)
{
     double poc_result = 0;
     cv::Point2d shift_org;
     shift_org = getPOCPos(source, trg, &poc_result, setting.gapPix);
     shift = cv::Point(round(shift_org.x), round(shift_org.y));
     if (isRound)
          shift = normalizeShiftValue(shift_org);
     
     if ((shift.x != 0) || (shift.y != 0)) {
          cv::Mat movedMask, movedBin, movedSrc;
          moveImage(maskS, movedMask, shift.x, shift.y, false);
          movedMask.copyTo(maskS);
          if (!maskSorgbin.empty()) {
               moveImage(maskSorgbin, movedBin, shift.x, shift.y, false);
               movedBin.copyTo(maskSorgbin);
          }
          
          if (!maskSorg.empty()) {
               moveImageWhite(maskSorg, movedSrc, shift.x, shift.y, false);
               movedSrc.copyTo(maskSorg);
          }
     }
     std::cout << "poc = " << poc_result << std::endl;
     if (poc_result >= 0.98) return 0;
     if (poc_result < 0.4) {
          std::cout << "違う画像の可能性大" << std::endl;
          return 1;
     }
     if (abs(shift.x) >= (setting.gapPix * VIEW_SCALE) || abs(shift.y) >= (setting.gapPix * VIEW_SCALE)) {
          std::cout << "設定よりズレが大きい" << std::endl;
          return 2;
     }
     
     return 3;
}

// おおまかなマスクから、色差の大きな部分のみのマスクを作成
void getColorDiff(cv::Mat &srcImg, cv::Mat &trgImg, cv::Mat &result, float thresh, int min, int max)
{
     
     
}



bool DiffImgCore::adjustMaskImage(cv::Mat &maskedS, cv::Mat &maskedT, cv::Mat binSE, cv::Mat binTE, cv::Rect roiRect)
{
     cv::Rect maskAreaS = getContourRect(maskedS, cv::Rect());
     cv::Rect maskAreaT = getContourRect(maskedT, cv::Rect());
     cv::Rect roiOrS = (maskAreaS | roiRect);
     cv::Rect roiOrT = (maskAreaT | roiRect);
     float gap = (setting.gapPix * VIEW_SCALE);
     bool isSuccess = true;
     if ((roiOrS != roiRect) && (roiOrT != roiRect)) {
          
//          int whiteS = cv::countNonZero(maskedS);
//          int whiteT = cv::countNonZero(maskedT);
//          int absArea = abs(whiteS - whiteT);
//          if (absArea > 50) {
               // maskSとmaskTが差分エリアより大きい場合
               cv::Mat tmpMask;
               cv::Rect roi;
               cropImageFromRect(roiRect, maskedS, cv::Scalar::all(0));
               cropImageFromRect(roiRect, maskedT, cv::Scalar::all(0));
               cv::bitwise_and(maskedS, maskedT, tmpMask);
               bool res = getMaskImage(tmpMask, binSE, maskedS, roi);
               if (!res) {
                    cout << "noImg" << endl;
               }
               res = getMaskImage(tmpMask, binTE, maskedT, roi);
               if (!res) {
                    cout << "noImg" << endl;
               }
               maskAreaS = getContourRect(maskedS, cv::Rect());
               maskAreaT = getContourRect(maskedT, cv::Rect());
               double poc_result = 0;
               cv::Point2d shift_org;
               cv::Point shift;
               
               if ( (maskAreaS.width > maskAreaT.width) || (maskAreaS.height > maskAreaT.height) ) {
                    shift_org = getPOCPos(maskedT, maskedS, &poc_result, setting.gapPix);
                    shift = normalizeShiftValue(shift_org);
                    
                    if ((abs(shift.x) > gap) || (abs(shift.y) > gap)) {
                         isSuccess = false;
                    }
                    else {
                         moveImage(maskedT, tmpMask, shift.x, shift.y, false);
                         cv::bitwise_and(tmpMask, maskedS, maskedS);
                    }
               }
               else {
                    shift_org = getPOCPos(maskedS, maskedT, &poc_result, setting.gapPix);
                    shift = normalizeShiftValue(shift_org);
                    if ((abs(shift.x) > gap) || (abs(shift.y) > gap)) {
                         isSuccess = false;
                    }
                    else {
                         moveImage(maskedS, tmpMask, shift.x, shift.y, false);
                         cv::bitwise_and(tmpMask, maskedT, maskedT);
                    }
               }
//          }
          
     }
     else if ((maskAreaS | roiRect) != roiRect) {
          // maskSが差分エリアより大きい場合
          cv::Mat tmpMask;
          cv::Rect roi;
          bool res = getMaskImage(maskedT, maskedS, tmpMask, roi);
          if (!res) {
               cout << "noImg" << endl;
          }
          roi = getContourRect(tmpMask, cv::Rect());
          if ((roi | roiRect) != roiRect) {
               double poc_result = 0;
               cv::Point2d shift_org;
               shift_org = getPOCPos(maskedT, maskedS, &poc_result, setting.gapPix);
               cv::Point shift = normalizeShiftValue(shift_org);
               if ((abs(shift.x) > gap) || (abs(shift.y) > gap)) {
                    isSuccess = false;
               }
               else {
                    moveImage(maskedT, tmpMask, shift.x, shift.y, false);
                    cv::bitwise_and(tmpMask, maskedS, maskedS);
               }
          }
          else {
               tmpMask.copyTo(maskedS);
          }
          
     }
     else if ((maskAreaT | roiRect) != roiRect) {
          // maskTが差分エリアより大きい場合
          cv::Mat tmpMask;
          cv::Rect roi;
          bool res = getMaskImage(maskedS, maskedT, tmpMask, roi);
          if (!res) {
               cout << "noImg" << endl;
          }
          roi = getContourRect(tmpMask, cv::Rect());
          if ((roi | roiRect) != roiRect) {
               double poc_result = 0;
               cv::Point2d shift_org;
               shift_org = getPOCPos(maskedS, maskedT, &poc_result, setting.gapPix);
               cv::Point shift = normalizeShiftValue(shift_org);
               if ((abs(shift.x) > gap) || (abs(shift.y) > gap)) {
                    isSuccess = false;
               }
               else {
                    moveImage(maskedS, tmpMask, shift.x, shift.y, false);
                    cv::bitwise_and(tmpMask, maskedT, maskedT);
               }
          }
          else {
               tmpMask.copyTo(maskedT);
          }
     }
     return isSuccess;
}

// in　のroi中で同じエリアのコンポーネント以外を削除
void chooseContoursFromRect(cv::Mat &in, cv::Rect roi)
{
     cv::Mat crp;
     in.copyTo(crp);
     cropImageFromRect(roi, crp, cv::Scalar::all(0));
     cv::Mat statsOrg, centroidsOrg, labelOrg;
     cv::Mat statsCrp, centroidsCrp, labelCrp;
     int orgLab = cv::connectedComponentsWithStats(in, labelOrg, statsOrg, centroidsOrg, 8, CV_32S);
     int crpLab = cv::connectedComponentsWithStats(crp, labelCrp, statsCrp, centroidsCrp, 8, CV_32S);
     std::map<int, cv::Rect> rectsOrg, rectsCrp;
     std::map<int, int> areaOrg, areaCrp;
     vector<int> delLabelsCrp;
     for (int l = 1; l < orgLab; l++) {
          int *param = statsOrg.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          int a = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
          rectsOrg[l] = cv::Rect(x,y,w,h);
          areaOrg[l] = a;
     }
     for (int l = 1; l < crpLab; l++) {
          int *param = statsCrp.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          int a = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
          rectsCrp[l] = cv::Rect(x,y,w,h);
          areaCrp[l] = a;
     }
//     std::vector<int> remainLabel;
//     for (auto it = rectsOrg.begin(); it != rectsOrg.end(); it++) {
//          int theL = 9999;
//          for (auto jt = rectsCrp.begin(); jt != rectsCrp.end(); jt++) {
//               if (jt->second == it->second) {
//                    theL = jt->first;
//                    break;
//               }
//          }
//          if (theL != 9999) {
     
//          }
//     }
     cv::Mat tmp(crp.size(), crp.type(), cv::Scalar::all(0));
     std::vector<int> remainLabel;
     
     for (int r = 0; r < crp.rows; r++) {
//          uchar* i = in.ptr<uchar>(r);
          uchar* p = crp.ptr<uchar>(r);
          int* lp = labelOrg.ptr<int>(r);
          for (int c = 0; c < crp.cols; c++) {
               if (p[c] == 255) {
                    bool isContain = false;
                    for (auto it = remainLabel.begin(); it != remainLabel.end(); it++) {
                         if (lp[c] == *it) {
                              isContain = true;
                              break;
                         }
                    }
                    if (!isContain) remainLabel.push_back(lp[c]);
               }
          }
     }
     for (int r = 0; r < crp.rows; r++) {
          uchar* p = tmp.ptr<uchar>(r);
          int* lp = labelOrg.ptr<int>(r);
          for (int c = 0; c < crp.cols; c++) {
               bool isRemain = false;
               for (auto it = remainLabel.begin(); it != remainLabel.end(); it++) {
                    if (lp[c] == *it) {
                         isRemain = true;
                         break;
                    }
               }
               if (isRemain) p[c] = 255;
          }
     }
     tmp.copyTo(in);
}




void extractRect(cv::Rect& rc, int ext, cv::Mat img) {
     if (rc.x != 0)
          rc.x -= ext;
     if (rc.y != 0)
          rc.y -= ext;
     if (rc.width + rc.x + (ext * 2) <= img.cols)
          rc.width += (ext * 2);
     if (rc.height + rc.y + (ext * 2) <= img.rows)
          rc.height += (ext * 2);
}



float checkTemplate(cv::Mat checkS, cv::Mat checkT)
{
     float val;
     cv::Mat result_img;
     cv::Point min_pt, max_pt;
     double minVal, maxVal;
     
     cv::UMat uSrc, uTmp;
     checkS.copyTo(uSrc);
     checkT.copyTo(uTmp);
     cv::matchTemplate(uSrc, uTmp, result_img, cv::TM_CCOEFF_NORMED);
     cv::minMaxLoc(result_img, &minVal, &maxVal, &min_pt, &max_pt);
     cv::Rect roi_rect(max_pt, cv::Point(max_pt.x+ checkT.cols, max_pt.y+checkT.rows));
     val = maxVal;
     
     return val;
}





void doUnsharpMaskAmount(cv::Mat in, cv::Mat &out, float amount, float radius, float threshold)
{
     cv::Mat tmp;
     cv::GaussianBlur(in, tmp, cv::Size(), radius, radius);
     cv::Mat lowConstrastMask = cv::abs(in - tmp) < threshold;
     cv::Mat sharpened = in*(1+amount) + tmp*(-amount);
     in.copyTo(sharpened, lowConstrastMask);
     sharpened.copyTo(out);
}



void doMinusImg(cv::Mat rS, cv::Mat rT, cv::Mat &out)
{
     cv::Mat tmpOr_Org, tmpOr;
     out = cv::Mat(rS.size(), rS.type(), cv::Scalar::all(255));
     #pragma omp parallel for
     for (int r = 0; r < rS.rows; r++) {
          uchar* s = rS.ptr<uchar>(r);
          uchar* t = rT.ptr<uchar>(r);
          uchar* rs = out.ptr<uchar>(r);
          for (int c = 0; c < rS.cols; c++) {
               rs[c] = cv::saturate_cast<uchar>(s[c]-t[c]);
          }
     }
}




DiffImgCore::CHECKResult checkSikisaDiff(cv::Mat rS, cv::Mat rT, cv::Rect absRect)
{
     cv::Mat cmpSAbin,cmpTAbin;
     cv::Mat cmpS,cmpT;
     rS.copyTo(cmpS);
     rT.copyTo(cmpT);
     cv::adaptiveThreshold(rS, cmpSAbin, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY_INV, 27, 10);
     cv::adaptiveThreshold(rT, cmpTAbin, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY_INV, 27, 10);
     cropImageFromRect(absRect, cmpSAbin, cv::Scalar::all(0));
     cropImageFromRect(absRect, cmpTAbin, cv::Scalar::all(0));
     cropImageFromRect(absRect, cmpS, cv::Scalar::all(255));
     cropImageFromRect(absRect, cmpT, cv::Scalar::all(255));
//     cv::imwrite("/tmp/cmpSAbin.tif", cmpSAbin);
//     cv::imwrite("/tmp/cmpTAbin.tif", cmpTAbin);
//     cv::imwrite("/tmp/cmpS.tif", cmpS);
//     cv::imwrite("/tmp/cmpT.tif", cmpT);
     bool isNoS = (!isExistsContour(cmpSAbin));
     bool isNoT = (!isExistsContour(cmpTAbin));
     if (isNoS && isNoT) {
          return DiffImgCore::CHECK_OK;
     }
     else if (isNoS) {
          return DiffImgCore::CHECK_ADD;
     }
     else if (isNoT) {
          return DiffImgCore::CHECK_DEL;
     }
     return DiffImgCore::CHECK_DIF;
}




cv::Point DiffImgCore::getDiffPos(cv::Mat cmpOrgS, cv::Mat cmpOrgT)
{
     // まずは２値画像で
     double poc_result = 0;
     cv::Point2d shift_org;
     cv::Point shift;
     cv::Mat binSE, binTE;
     cv::threshold(cmpOrgS, binSE, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
     cv::threshold(cmpOrgT, binTE, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
     shift_org = getPOCPos(binSE, binTE, &poc_result, setting.gapPix);
     shift = normalizeShiftValue(shift_org);
     if ((shift.x == 0) && (shift.y == 0)) {
          shift_org = getPOCPos(cmpOrgS, cmpOrgT, &poc_result, setting.gapPix);
          shift = normalizeShiftValue(shift_org);
          if ((shift.x == 0) && (shift.y == 0)) {
               cv::Mat flS, flT;
               cmpOrgS.convertTo(flS, CV_64FC3);
               cmpOrgT.convertTo(flT, CV_64FC3);
               cv::Ptr<MapperGradShift> mapper = cv::makePtr<MapperGradShift>();
               MapperPyramid mappPyr(mapper);
               cv::Ptr<Map> mapPtr = mappPyr.calculate(flS, flT);
               MapShift* mapShift = dynamic_cast<MapShift*>(mapPtr.get());
               auto sft = mapShift->getShift();
               shift_org = cv::Point2d(sft[0], sft[1]);
               shift = normalizeShiftValue(shift_org);
               if ((shift.x == 0) && (shift.y == 0)) {
                    cout << "no move" << endl;
               }
          }
     }
     return shift;
}



// コンポーネントごとに画像を分離 重なった部分は一つのコンポーネントとする
std::vector<cv::Mat> DiffImgCore::splitComponent(cv::Mat img)
{
     cv::TickMeter tick;
     tick.reset(); tick.start();
     
     std::vector<cv::Mat> retImgs;
//     cv::imwrite("/tmp/imgCnt.tif", img);
     cv::Mat stats, centroids, label;
     int nLab = cv::connectedComponentsWithStats(img, label, stats, centroids, 8, CV_32S);
     std::vector<cv::Rect> cmpRects;
     
     // 重なりを考慮した四角を取得
     for (int l = 1; l < nLab; l++) {
          int *param = stats.ptr<int>(l);
          int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
          int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
          int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
          int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
          cv::Rect theRect(x,y,w,h);
          bool isOver = false;
          cv::Rect overRect;
          
          for (auto it = cmpRects.begin(); it != cmpRects.end(); ++it) {
               if ((*it & theRect).area() > 0) {
                    theRect |= *it;
                    isOver = true;
                    overRect = *it;
                    break;
               }
          }
          
          if (!isOver) {
               cmpRects.push_back(theRect);
          }
          else {
               cmpRects.erase(std::remove(cmpRects.begin(), cmpRects.end(), overRect), cmpRects.end());
               cmpRects.push_back(theRect);
          }
     }

     std::vector<std::vector<int>> cmpLabels;
     
     std::vector<cv::Rect> clsRects;
     util->rect_clustering(cmpRects, clsRects, VIEW_SCALE);
     
     for (int i = 0; i < clsRects.size(); ++i) {
          cv::Rect cmpRect = clsRects.at(i);
          std::vector<int> theLabels;
          for (int l = 1; l < nLab; l++) {
               int *param = stats.ptr<int>(l);
               int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
               int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
               int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
               int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
               cv::Rect theRect(x,y,w,h);

               if ((cmpRect & theRect).area() > 0) {
                    theLabels.push_back(l);
               }
          }
          cmpLabels.push_back(theLabels);
     }
     
     for (int i = 0; i < cmpLabels.size(); ++i) {
          std::vector<int> theLabel = cmpLabels.at(i);
          cv::Mat theImg(img.size(), img.type(), cv::Scalar::all(0));
          for (int r = 0; r < img.rows; r++) {
               uchar* p = theImg.ptr<uchar>(r);
               int* lblp = label.ptr<int>(r);
               for (int c = 0; c < img.cols; c++) {
                    bool isCompo = false;
                    for (auto it = theLabel.begin(); it != theLabel.end(); ++it) {
                         if (lblp[c] == *it) {
                              isCompo = true;
                              break;
                         }
                    }
                    if (isCompo) {
                         p[c] = 255;
                    }
               }
          }
//          cv::imwrite("/tmp/theImg.tif", theImg);
          retImgs.push_back(theImg);
     }
     tick.stop();
     cout << "splitComponent: " << tick.getTimeMilli() << " ms" << endl;
     return retImgs;
}

// 差分マスクの取得
void DiffImgCore::getAbstractComponent(cv::Mat rS, cv::Mat rT, cv::Mat sikisa, cv::Rect &roi, cv::Mat &absM)
{
     cv::imwrite("/tmp/a_sikisa.tif", sikisa);
     
     // 元画像を乗算
     cv::Mat mergedCompos, mergedComposBin;
     doMultipleImg(rS, rT, mergedCompos);
     cv::imwrite("/tmp/a_mergedCompos.tif", mergedCompos);
     cv::threshold(mergedCompos, mergedComposBin, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
     cv::imwrite("/tmp/a_mergedComposBin.tif", mergedComposBin);
     
     // 色差のあるコンポ取得(おおまかに)
     cv::Mat maskCompos;
     getComponentFromMask(mergedComposBin, sikisa, maskCompos);
     cv::imwrite("/tmp/a_maskCompos.tif", maskCompos);
     
     // 色差から注目エリアを取得
     cv::Mat absSikisa;
     getComponentFromRect(maskCompos, roi, absSikisa);
     cv::bitwise_and(sikisa, absSikisa, absSikisa);
     cv::imwrite("/tmp/a_absSikisa.tif", absSikisa);
     if (!isExistsContour(absSikisa)) {
          return;
     }
     
     float hash = checkHash("", absSikisa, sikisa);
     if (hash >= 0.9) {
          maskCompos.copyTo(absM);
          return;
     }
     std::vector<std::vector<cv::Point> > contours;
     cv::findContours(absSikisa, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
     cv::Mat sikisaEdge(absSikisa.size(), absSikisa.type(), cv::Scalar::all(0));
     for (int i = 0; i < contours.size(); i++) {
          cv::drawContours(sikisaEdge, contours, i, cv::Scalar::all(255));
     }
     cv::imwrite("/tmp/a_sikisaEdge.tif", sikisaEdge);
     contours.clear();
     
     cv::Mat tmp;
     getLabelMaskImage(mergedCompos, absSikisa, tmp);
     cv::imwrite("/tmp/a_tmp.tif", tmp);
     
     cv::Mat edgeImageS, edgeImageT, edgeImage, tmpS, tmpT;
     cv::threshold(rS, tmpS, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
     cv::threshold(rT, tmpT, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
     
     my_canny(tmpS, edgeImageS, true);
     my_canny(tmpT, edgeImageT, true);
     cv::bitwise_or(edgeImageS, edgeImageT, edgeImage);
     cv::imwrite("/tmp/a_edgeImage.tif", edgeImage);
     cv::Mat diffEdge;
     edgeImage.copyTo(diffEdge);
     cropImageFromMask(tmp, diffEdge, cv::Scalar::all(0));
     cv::imwrite("/tmp/a_diffEdge1.tif", diffEdge);
     cv::Mat diffEdgeMin;
     doMinusImg(diffEdge, tmp, diffEdgeMin);
     delMinAreaWhite(diffEdgeMin, VIEW_SCALE);
     
     cv::bitwise_or(diffEdge, sikisaEdge, diffEdge);
     cv::imwrite("/tmp/a_diffEdge2.tif", diffEdge);
     doMinusImg(diffEdge, diffEdgeMin, diffEdge);
     cv::imwrite("/tmp/a_diffEdge3.tif", diffEdge);
     // 閉じた線を取り出す
     std::vector<cv::Vec4i> hierarchy;
     cv::findContours(diffEdge, contours, hierarchy, cv::RETR_CCOMP, cv::CHAIN_APPROX_NONE);
     std::vector<std::vector<cv::Point> > closedLines;
     cv::Vec4i info = hierarchy.at(0);
     bool isChild = false;
     while(true) {
          vector<cv::Vec4i>::iterator itr;
          itr = std::find(hierarchy.begin(), hierarchy.end(), info);
          if (itr == hierarchy.end()) {
               cout << "search failed" << endl;
               break;
          }
          const int wanted_index = (int)std::distance(hierarchy.begin(), itr);
          
          if ((info[0] == -1) && (info[2] == -1) && (info[3] == -1)) {
               break;
          }
          else if (isChild) {
               if (info[0] != -1) {
                    closedLines.push_back(contours.at(info[0]));
                    info = hierarchy.at(info[0]);
                    continue;
               }
               else {
                    isChild = false;
                    if (wanted_index == (hierarchy.size() - 1)) {
                         break;
                    }
                    info = hierarchy.at(wanted_index+1);
               }
          }
          else {
               if (info[2] != -1) {
                    closedLines.push_back(contours.at(info[2]));
                    info = hierarchy.at(info[2]);
                    isChild = true;
                    continue;
               }
               else {
                    if (wanted_index == (hierarchy.size() - 1)) {
                         break;
                    }
                    info = hierarchy.at(wanted_index+1);
               }
          }
          
     }
     
     cv::Mat closedImage(diffEdge.size(), diffEdge.type(), cv::Scalar::all(0));
     for (int i = 0; i < closedLines.size(); i++) {
          cv::drawContours(closedImage, closedLines, i, cv::Scalar::all(255), cv::FILLED);
     }
//     cv::imwrite("/tmp/a_closedImage.tif", closedImage);
     
     cv::Mat tmpABS;
     getComponentFromMask(closedImage, sikisa, tmpABS);
//     cv::imwrite("/tmp/a_tmpABS.tif", tmpABS);

     
     std::vector<cv::Mat> allMasks = splitComponent(tmpABS);
     cout << allMasks.size() << endl;
     std::vector<cv::Mat> retMasks;
     cv::Mat allMaskImg = cv::Mat::zeros(tmpABS.rows, tmpABS.cols, tmpABS.type());
     for (int i = 0; i < allMasks.size(); i++) {
          
          cv::Mat cmp = allMasks.at(i);
          std::vector<std::vector<cv::Point> > cmpConts;
          std::vector<cv::Point> contours_flat;
          cv::findContours(cmp, cmpConts, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
          
          for (auto contour = cmpConts.begin(); contour != cmpConts.end(); contour++){
               for (auto pt = contour->begin(); pt != contour->end(); pt++) contours_flat.push_back(*pt);
          }
          
          cv::Mat mask = cv::Mat::zeros(cmp.rows, cmp.cols, cmp.type());
          std::vector<cv::Point> hull;
          if (contours_flat.size() != 0) {
               cv::convexHull(contours_flat, hull);
               cv::fillConvexPoly(mask, hull, cv::Scalar::all(255));
               cv::Mat partCmp;
               cv::bitwise_and(mask, mergedComposBin, partCmp);
               retMasks.push_back(partCmp);
               cv::bitwise_or(allMaskImg, partCmp, allMaskImg);
          }
     }
     
     allMaskImg.copyTo(absM);
     
     if (!isExistsContour(absM) || cv::countNonZero(absM) < 10) {
          sikisa.copyTo(absM);
//          return splitComponent(absM);
     }
     return;
//     return retMasks;
}

// 移動して色差チェック
cv::Rect DiffImgCore::checkMove(cv::Mat rS, cv::Mat rT, cv::Mat maskS, cv::Mat maskT, cv::Mat absMat,
                                cv::Rect cropRect, DiffResult& diff_result, int extCropSize,
                                double &poc_result, cv::Point &shift, cv::Mat &sikisa)
{
     cv::Point2d shift_org;
     shift_org = getPOCPos(maskS, maskT, &poc_result, setting.gapPix);
     shift = normalizeShiftValue(shift_org);
     cv::Rect dfRect;
     std::vector<std::vector<cv::Point>> diff_cnt;
     cv::Mat tmpS, tmpT;
     rS.copyTo(tmpS);
     rT.copyTo(tmpT);
     cropImageFromMask(maskS, tmpS, cv::Scalar::all(255));
     cropImageFromMask(maskT, tmpT, cv::Scalar::all(255));
     getContours(tmpS, tmpT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
     for (auto it = diff_cnt.begin(); it != diff_cnt.end(); ++it)
          dfRect |= cv::boundingRect(*it);
     
     if (abs(shift.x) >= (setting.gapPix * VIEW_SCALE) || abs(shift.y) >= (setting.gapPix * VIEW_SCALE)) {
          sikisa = cv::Mat();
          
          std::cout << "設定よりズレが大きい" << std::endl;
          diffprocess(diff_result, diff_cnt);
          return dfRect;
     }
     
     cv::Mat tmp, tmpor;
     moveImage(rS, tmp, shift.x, shift.y, false);
     makeShadeMask(tmp, rT, cv::Mat(), cv::Mat(), 17, sikisa);
     
     if (sikisa.empty()) {
          return dfRect;
     }
     else {
          if (isExistsContour(sikisa)) {
               delMinAreaWhite(sikisa, 4);
               cv::bitwise_and(absMat, sikisa, sikisa);
          }
     }
     
     return dfRect;
}

//std::vector<cv::Rect>
void DiffImgCore::diff(cv::Mat crpS, cv::Mat crpT, cv::Mat crpSBE, cv::Mat crpTBE, cv::Rect cropRect, DiffResult& diff_result, double match_thresh, bool isIllust, std::vector<cv::Rect> &textArea, int extCropSize)
{
     cv::TickMeter tick;
     tick.reset(); tick.start();
     
     std::vector<std::vector<cv::Point>> diff_cnt;
     cv::Rect extCrop(cropRect.x - extCropSize,
                      cropRect.y - extCropSize,
                      cropRect.width + (extCropSize * 2),
                      cropRect.height + (extCropSize * 2));
     bool isEdgeImg = false;
     if (extCrop.width + extCrop.x > bitDiffImg.cols) {
          extCrop.width = bitDiffImg.cols - extCrop.x;
          isEdgeImg = true;
     }
     if (extCrop.height + extCrop.y > bitDiffImg.rows) {
          extCrop.height = bitDiffImg.rows - extCrop.y;
          isEdgeImg = true;
     }
     
     cv::Rect bigCropExt(extCrop.x * VIEW_SCALE,
                         extCrop.y * VIEW_SCALE,
                         extCrop.width * VIEW_SCALE,
                         extCrop.height * VIEW_SCALE);
     
     cv::Rect bigCrop(cropRect.x * VIEW_SCALE,
                      cropRect.y * VIEW_SCALE,
                      cropRect.width * VIEW_SCALE,
                      cropRect.height * VIEW_SCALE);
     
     cv::Rect roiRect(cropRect.x - extCrop.x -1,
                      cropRect.y - extCrop.y -1,
                      cropRect.width,
                      cropRect.height);
     
     if (!isIllust) {
          if (((cropRect.height > 300) && (cropRect.width > 80)) || ((cropRect.width > 300) && (cropRect.height > 80)) ) {
               tick.stop();
               cout << "NG:差分が巨大" << endl;
               cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
               cv::rectangle(bitDiffImgL, cropRect.tl(), cropRect.br(), cv::Scalar::all(0));
               getContours(crpS, crpT, cropRect, diff_cnt, extCropSize);
               diffprocess(diff_result, diff_cnt);
               return;
          }
     }
     
     // このモード時は rS, rTともにグレーとなっている
     if (setting.colorSpace == (int)KZColorSpace::GRAY) {
          // 画像調整
          cv::Mat binTE, binSE;
          cv::Mat binT, binS;
          cv::Mat shpT, shpS;
          cv::Mat sikisa;
          cv::Rect roiS, roiT;
          float deltaThresh = 12.0;
          
          if (isIllust) {
               makeShadeMask(crpS, crpT, cv::Mat(), cv::Mat(), deltaThresh-2, sikisa);
          }
          else {
               cv::Mat bitDiff = cv::Mat(bitDiffImgL, extCrop);
               
               cv::Mat centerSikisa;
               cropCenterComponent(bitDiff, centerSikisa, extCrop, extCropSize);
               
               if (!isExistsContour(centerSikisa) && !isEdgeImg) {
                    tick.stop();
                    cout << "already checked" << endl;
                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
                    return;
               }
               else if (isEdgeImg) {
                    bitDiff.copyTo(centerSikisa);
               }
               cv::threshold(crpS, binS, 191, 255, cv::THRESH_BINARY_INV);
               cv::threshold(crpT, binT, 191, 255, cv::THRESH_BINARY_INV);
#ifdef DEBUG
               util->dbgSave(crpS, "crpS.tif", "dbg");
               util->dbgSave(crpT, "crpT.tif", "dbg");
               util->dbgSave(binS, "binS.tif", "dbg");
               util->dbgSave(binT, "binT.tif", "dbg");
               util->dbgSave(centerSikisa, "centerSikisa.tif", "dbg");
#endif
               cv::Mat absS, absT, mulCompo;
               getDiffArea(crpS, crpT, binS, binT, centerSikisa, bitDiff, absS, absT, mulCompo, extCropSize);

               if (absT.empty() && absS.empty()) {
                    tick.stop();
                    cout << "same image!" << endl;
                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
                    fillCheckedContour(bitDiff, mulCompo);
                    return;
               }
               
#ifdef DEBUG
               util->dbgSave(absS, "absS.tif", "dbg");
               util->dbgSave(absT, "absT.tif", "dbg");
#endif
               
#ifdef DEBUG
               util->dbgSave(mulCompo, "mulCompo.tif", "dbg");
#endif
               
               fillCheckedContour(bitDiff, mulCompo);
               
               cv::Mat invS, invT;
               cv::bitwise_not(absS, invS);
               cv::bitwise_not(absT, invT);
               int sCount = cv::countNonZero(invS);
               int tCount = cv::countNonZero(invT);
               if (sCount == 0 && tCount == 0) {
                    tick.stop();
                    cout << "no compomemt!" << endl;
                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
                    return;
               }
               else if (sCount == 0 && tCount != 0) {
                    tick.stop();
                    cout << "追加" << endl;
                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
                    getContours(mulCompo, mulCompo, cropRect, diff_cnt, extCropSize);
                    addprocess(diff_result, diff_cnt);
                    return;
               }
               else if (sCount != 0 && tCount == 0) {
                    tick.stop();
                    cout << "削除" << endl;
                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
                    getContours(mulCompo, mulCompo, cropRect, diff_cnt, extCropSize);
                    delprocess(diff_result, diff_cnt);
                    return;
               }
               
               
//               cv::Mat bitDiffTrg = cv::Mat(bitDiffImgL, cropRect);
//               if (!isExistsContour(bitDiff)) {
//                    // already checked
//                    return checkedRects;
//               }
//               cv::Mat outSiki;
//               toSize(bitDiffTrg, outSiki, extCrop.size(), cv::Rect(cropRect.x - extCrop.x,
//                                                                cropRect.y - extCrop.y,
//                                                                cropRect.width, cropRect.height), cv::Scalar::all(0));
//               util->resizeImage(outSiki, sikisa, VIEW_SCALE);
//               util->resizeImage(bitDiff, bitDiff, VIEW_SCALE);
//               cv::Mat mergedCompos, mergedComposBin;
//               doMultipleImg(crpSBE, crpTBE, mergedCompos);
//               cv::threshold(mergedCompos, mergedComposBin, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
//               getComponentFromMask(mergedComposBin, sikisa, outSiki);
//#ifdef DEBUG
//               util->dbgSave(mergedComposBin, "mergedComposBin.tif", "dbg");
//               util->dbgSave(outSiki, "outSiki.tif", "dbg");
//               util->dbgSave(sikisa, "sikisa.tif", "dbg");
//#endif
//               tick.stop();
//               cout << "crop sikisa: " << tick.getTimeMilli() << " ms" << endl;
//               tick.reset(); tick.start();
//
//               checkedRects = getCheckedRect(sikisa, bigCropExt, bitDiff);
//
               
               
               
               
               
               
//               cv::Mat crpAbs;
//               cv::bitwise_xor(binS, binT, crpAbs);
//               cv::bitwise_or(crpAbs, sikisa, crpAbs);
//
//
//               getComponentFromRect(crpAbs,
//                                    cv::Rect(extCropSize,extCropSize,cropRect.width,cropRect.height),
//                                    sikisa);
//#ifdef DEBUG
//               util->dbgSave(sikisa, "sikisa.tif", "dbg1");
//               util->dbgSave(crpAbs, "crpAbs.tif", "dbg1");
//#endif
//               if (sikisa.empty() || !isExistsContour(sikisa)) {
//                    tick.stop();
//                    cout << "!!!! OK - no sikisa !!!!" << endl;
//                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
//                    checkedRects.push_back(cropRect);
//                    return checkedRects;
//               }
//
//               cv::Mat trgS, trgT;
//               binS.copyTo(trgS);
//               binT.copyTo(trgT);
//               getComponentFromMask(binS, crpAbs, trgS);
//               getComponentFromMask(binT, crpAbs, trgT);
//               cv::Rect roiSikisa = getContourRect(sikisa, cv::Rect());
//               roiS = getContourRect(trgS, cv::Rect());
//               roiT = getContourRect(trgT, cv::Rect());
//               util->dbgSave(trgS, "trgS.tif", "dbg");
//               util->dbgSave(trgT, "trgT.tif", "dbg");
//               if ((abs(roiS.width - roiT.width) >= 1) ||
//                   (abs(roiS.height - roiT.height) >= 1) ) {
//                    getLabelMaskImage(crpS, crpAbs, trgS);
//                    getLabelMaskImage(crpT, crpAbs, trgT);
////                    getAbstractComponent(crpS, crpT, sikisa, roiRect, crpAbs);
////                    binS.copyTo(trgS);
////                    binT.copyTo(trgT);
////                    cropImageFromMask(crpAbs, trgS, cv::Scalar::all(0));
////                    cropImageFromMask(crpAbs, trgT, cv::Scalar::all(0));
//               }
//
//#ifdef DEBUG
//               util->dbgSave(crpAbs, "crpAbs.tif", "dbg");
//               util->dbgSave(trgS, "trgS.tif", "dbg");
//               util->dbgSave(trgT, "trgT.tif", "dbg");
//#endif
//               int whiteS = cv::countNonZero(trgS);
//               int whiteT = cv::countNonZero(trgT);
//               bool isLargeS = whiteS > whiteT;
//               int dfWhite = abs(whiteS - whiteT);
//
//               if (dfWhite > 10) {
//                    // ちがうサイズ
//                    cout << "ちがうよ" << endl;
//               }
//
//               cv::bitwise_or(trgS, trgT, crpAbs);
//
//               checkedRects = getCheckedRect(crpAbs, extCrop);
//
//               if (!isExistsContour(trgS) && !isExistsContour(trgT)) {
//                    tick.stop();
//                    cout << "!!!! OK - no contour !!!!" << endl;
//                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
//                    return checkedRects;
//               }
//               else if (!isExistsContour(trgS)) {
//                    tick.stop();
//                    cout << "追加" << endl;
//                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
//                    getContours(crpAbs, crpAbs, cropRect, diff_cnt, extCropSize);
//                    addprocess(diff_result, diff_cnt);
//                    return checkedRects;
//               }
//               else if (!isExistsContour(trgT)) {
//                    tick.stop();
//                    cout << "削除" << endl;
//                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
//                    getContours(crpAbs, crpAbs, cropRect, diff_cnt, extCropSize);
//                    delprocess(diff_result, diff_cnt);
//                    return checkedRects;
//               }
//
               
               
//               cv::Mat shapeMin, shapeL;
//               cv::Rect rcShape;
//               if (whiteS > whiteT) {
//                    rcShape = getContourRect(trgT, cv::Rect());
//                    shapeMin = cv::Mat(trgT,rcShape);
//                    trgS.copyTo(shapeL);
//               }
//               else {
//                    rcShape = getContourRect(trgS, cv::Rect());
//                    shapeMin = cv::Mat(trgS,rcShape);
//                    trgT.copyTo(shapeL);
//               }
//               auto matchRet = util->tmplateMatch(shapeMin, shapeL, match_thresh, 1);
//               if (matchRet.isMatch) {
//                    tick.stop();
//                    cout << "!!!! OK - same Shape !!!!" << endl;
//                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
//                    checkedRects.push_back(cropRect);
//                    return checkedRects;
//               }
////               double similarity = cv::matchShapes(shapeMin, shapeL, cv::CONTOURS_MATCH_I1, 0);
//
//
//               cout << "sikisa white abs = " << abs(whiteS - whiteT) << endl;
//               if (abs(whiteS - whiteT) == 0) {
//                    tick.stop();
//                    cout << "!!!! OK - same contour !!!!" << endl;
//                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
//                    checkedRects.push_back(cropRect);
//                    return checkedRects;
//               }
//               if (abs(whiteS - whiteT) > 10) {
//                    cv::Mat absMat;
//                    getAbstractComponent(crpS, crpT, crpAbs, roiRect, absMat);
//                    absMat.copyTo(crpAbs);
//#ifdef DEBUG
//                    util->dbgSave(crpAbs, "crpAbs2.tif", "dbg");
//#endif
//               }
//               util->resizeImage(crpAbs, sikisa, VIEW_SCALE);
//               cv::threshold(sikisa, sikisa, 0, 255, cv::THRESH_OTSU);
//#ifdef DEBUG
//               cv::Mat crcrS,crcrT;
//               crpSBE.copyTo(crcrS);
//               crpTBE.copyTo(crcrT);
//               cropImageFromMask(sikisa, crcrS, cv::Scalar::all(255));
//               cropImageFromMask(sikisa, crcrT, cv::Scalar::all(255));
//               util->dbgSave(trgS, "trgS.tif", "dbg");
//               util->dbgSave(trgT, "trgT.tif", "dbg");
//               util->dbgSave(crcrS, "crcrS.tif", "dbg");
//               util->dbgSave(crcrT, "crcrT.tif", "dbg");
//               util->dbgSave(crpAbs, "crpAbs.tif", "dbg");
//
//#endif
               
//               cv::Mat rT, rS;
//               getCroppedComponentImg(crpSBE, crpTBE, sikisa, rS, rT, false);
//#ifdef DEBUG
//               util->dbgSave(rS, "rS.tif", "dbg");
//               util->dbgSave(rT, "rT.tif", "dbg");
//#endif
//               cv::Point shift = getShiftPoint(crcrS, crcrT, setting.gapPix);
//               if (abs(shift.x) >= (setting.gapPix * VIEW_SCALE) ||
//                   abs(shift.y) >= (setting.gapPix * VIEW_SCALE)) {
//                    tick.stop();
//                    cout << "NG:設定よりズレが大きい" << endl;
//                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
//                    getContours(sikisa, sikisa, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    diffprocess(diff_result, diff_cnt);
//                    checkedRects.push_back(cropRect);
//                    return checkedRects;
//               }
//               cout << "x = " << shift.x << " y = " << shift.y << endl;
//
//               float hash = checkHash("最初の比較",rS, rT);
//               if (hash >= 0.9) {
//                    tick.stop();
//                    cout << "!!!! OK2 !!!!" << endl;
//                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
//                    checkedRects.push_back(cropRect);
//                    return checkedRects;
//               }
//               else if (hash <= 0.4) {
//                    tick.stop();
//                    cout << "NG:全く違う" << endl;
//                    cout << "diff end: " << tick.getTimeMilli() << " ms" << endl;
//                    getContours(crpS, crpT, cropRect, diff_cnt, extCropSize);
//                    diffprocess(diff_result, diff_cnt);
//                    checkedRects.push_back(cropRect);
//                    return checkedRects;
//               }
//
//
//
//
//
//
//          }
//
//          if (sikisa.empty()) {
//               checkedRects.push_back(cropRect);
//               return checkedRects;
//          }
//
//          if (isIllust) {
//               vector<cv::Rect> theDiff;
//               for (auto it = textArea.begin(); it != textArea.end(); ++it) {
//                    if ((*it & cropRect).area() > 0) {
//                         cv::Rect absoluteRc = *it;
//                         absoluteRc.x -= cropRect.x;
//                         absoluteRc.y -= cropRect.y;
//                         extractRect(absoluteRc, 2, sikisa);
//                         theDiff.push_back(absoluteRc);
//                    }
//               }
//               for (auto it = theDiff.begin(); it != theDiff.end(); ++it) {
//                    cv::rectangle(sikisa, it->tl(), it->br(), cv::Scalar::all(0), cv::FILLED);
//               }
//
//               util->dbgSave(sikisa, "sikisa.tif", 0);
//               if (!isExistsContour(sikisa)){
//                    checkedRects.push_back(cropRect);
//                    return checkedRects;
//               }
//               cout << "イラスト差分" << endl;
//               getContours(sikisa, sikisa, cropRect, diff_cnt);
//               diffprocess(diff_result, diff_cnt);
//               checkedRects.push_back(cropRect);
//               return checkedRects;
//          }
//
//          // 差分コンポーネント取得
//          cv::Mat absMat;
//          cv::Rect absRect;
//          util->dbgSave(sikisa, "sikisa.tif", 0);
//          auto masks = getAbstractComponent(crpSBE, crpTBE, sikisa, roiRect, absMat);
//
//          if (masks.size() == 0) {
//               cout << "全くちがう" << endl;
//               getContours(binSE, binTE, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               diffprocess(diff_result, diff_cnt);
//               checkedRects.push_back(cropRect);
//               return checkedRects;
//          }
//
//          if (absMat.empty()) {
//               checkedRects.push_back(cropRect);
//               return checkedRects;
//          }
//
//          absRect = getContourRect(absMat, cv::Rect());
//
//          // 抽出した差分エリアをチェック済みに追加
//          auto checked = getCheckedRect(absMat, cropRect.tl(), extCropSize);
//
//          cv::Mat absS, absT;
//          cv::Rect sRect,tRect;
//          getComponentFromMask(binSE, absMat, absS);
//          getComponentFromMask(binTE, absMat, absT);
//          sRect = getContourRect(absS, cv::Rect());
//          tRect = getContourRect(absT, cv::Rect());
//          util->dbgSave(absMat, "absMatAll.tif", 0);
//          if (((sRect.width > (absRect.width * 1.2)) ||
//               (sRect.height > (absRect.height * 1.2))) ||
//              ((tRect.width > (absRect.width * 1.2)) ||
//               (tRect.height > (absRect.height * 1.2)))) {
//                   cropImageFromMask(absMat, absS, cv::Scalar::all(0));
//                   cropImageFromMask(absMat, absT, cv::Scalar::all(0));
//          }
//          int dfWhite = cv::countNonZero(absS) - cv::countNonZero(absT);
//          if (abs(dfWhite) > 50) {
//               if (dfWhite < 0) {
//                    cv::bitwise_and(absT, absMat, absT);
//               }
//               else {
//                    cv::bitwise_and(absS, absMat, absS);
//               }
//          }
//          util->dbgSave(absS, "absS.tif", 0);
//          util->dbgSave(absT, "absT.tif", 0);
//
//
//          if (!isExistsContour(absS)) {
//               cout << "追加" << endl;
//               getContours(absMat, absMat, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               addprocess(diff_result, diff_cnt);
//               return checked;
//          }
//          else if (!isExistsContour(absT)) {
//               cout << "削除" << endl;
//               getContours(absMat, absMat, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               delprocess(diff_result, diff_cnt);
//               return checked;
//          }
//          else {
//               cv::Mat chkDf;
//               cv::bitwise_and(absS, absT, chkDf);
//               if (!isExistsContour(chkDf)) {
//                    cout << "全くちがう" << endl;
//                    getContours(absMat, absMat, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    diffprocess(diff_result, diff_cnt);
//                    return checked;
//               }
//          }
//
//          cv::Mat trgS, trgT;
//          getAbstractImg(crpSBE, crpTBE, absMat, trgS, trgT);
//          if (trgS.empty()) {
//               cout << "追加" << endl;
//               getContours(absMat, absMat, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               addprocess(diff_result, diff_cnt);
//               return checked;
//          }
//          else if (trgT.empty()) {
//               cout << "削除" << endl;
//               getContours(absMat, absMat, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               delprocess(diff_result, diff_cnt);
//               return checked;
//          }
//          util->dbgSave(trgS, "trgS.tif", 0);
//          util->dbgSave(trgT, "trgT.tif", 0);
//
//          cout << "masks = " << masks.size() << endl;
//          // マスク先頭の要素からズレ計算
//          cv::Mat zureS,zureT;
//          shpS.copyTo(zureS);
//          shpT.copyTo(zureT);
//          cv::Mat zureAbs;
//          masks.at(0).copyTo(zureAbs);
//
//          cropImageFromMask(zureAbs, zureS, cv::Scalar::all(255));
//          cropImageFromMask(zureAbs, zureT, cv::Scalar::all(255));
//          cv::Point shift = getDiffPos(zureS,zureT);
//
//          if (masks.size() == 1) {
//               if (abs(shift.x) >= (setting.gapPix * VIEW_SCALE) ||
//                   abs(shift.y) >= (setting.gapPix * VIEW_SCALE)) {
//                    cout << "設定よりズレが大きい" << endl;
//                    getContours(crpS, crpT, cropRect, diff_cnt, extCropSize);
//                    diffprocess(diff_result, diff_cnt);
//                    checkedRects.push_back(cropRect);
//                    return checkedRects;
//               }
//          }
//          cv::Mat minTrgS, minTrgT;
//          if ((trgS.cols < VIEW_SCALE || trgS.rows < VIEW_SCALE)  ||
//              (trgT.cols < VIEW_SCALE || trgT.rows < VIEW_SCALE)) {
//               trgS.copyTo(minTrgS);
//               trgT.copyTo(minTrgT);
//          }
//          else {
//               util->resizeImage(trgS, minTrgS, 1 / VIEW_SCALE);
//               util->resizeImage(trgT, minTrgT, 1 / VIEW_SCALE);
//
//          }
//
//          float hash = checkHash("",minTrgS, minTrgT);
//
//          hash = roundf(hash);
//          if (hash <= 30) {
//               return checked;
//          }
//
//
//
//
//
//          if (shift.x != 0 || shift.y != 0) {
//               cout << "shift x = " << shift.x << " y = " << shift.y << ";" << endl;
//
//               // ズレ補正(大元をずらして、色差の計算)
//               cv::Mat zureRes;
//               cv::Mat zureTmp;
//               shpT.copyTo(zureT);
//
//               moveImage(shpS, zureS, shift.x, shift.y, false);
//               cv::threshold(zureS, zureS, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
//               cv::threshold(zureT, zureT, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
//               cv::bitwise_xor(zureS, zureT, zureRes);
//               cv::bitwise_and(zureRes, absMat, zureRes);
//               delMinAreaWhite(zureRes, VIEW_SCALE);
//
//               if (!isExistsContour(zureRes)) {
//                    checkedRects.push_back(cropRect);
//                    return checkedRects;
//               }
//
//               getComponentFromMask(absMat, zureRes, absMat);
//               util->dbgSave(absMat, "absMatAll.tif", 1);
//               masks.clear();
//               masks = splitComponent(absMat);
//          }
//
//          cout << "masks = " << masks.size() << endl;
//
//          // 各差分コンポーネントに対して比較
//          std::vector<cv::Mat> diffImgs;
//          std::vector<cv::Mat> addImgs;
//          std::vector<cv::Mat> delImgs;
//          for (int it = 0; it < masks.size(); ++it) {
//
//               cv::Mat cmpAbs;
//               masks.at(it).copyTo(cmpAbs);
//               cv::Mat cmpSbin,cmpTbin;
//               cv::Mat cmpS,cmpT;
//               shpS.copyTo(cmpS);
//               shpT.copyTo(cmpT);
//               binSE.copyTo(cmpSbin);
//               binTE.copyTo(cmpTbin);
//
//               util->dbgSave(cmpAbs, "absMat.tif", it);
//               cv::Rect absRect = getContourRect(cmpAbs, cv::Rect(), 1);
//
//               // 色差での存在比較
//               bool isContinue = false;
//               cropImageFromRect(absRect, cmpS, cv::Scalar::all(255));
//               cropImageFromRect(absRect, cmpT, cv::Scalar::all(255));
//               switch (checkSikisaDiff(cmpS, cmpT, absRect)) {
//                    case DiffImgCore::CHECK_OK:
//                         isContinue = true;
//                         break;
//                    case DiffImgCore::CHECK_ADD:
//                         isContinue = true;
//                         std::cout << "追加" << std::endl;
//                         addImgs.push_back(cmpAbs);
//                         break;
//                    case DiffImgCore::CHECK_DEL:
//                         isContinue = true;
//                         std::cout << "削除" << std::endl;
//                         delImgs.push_back(cmpAbs);
//                         break;
//                    default:
//                         break;
//               }
//               if (isContinue) {
//                    util->dbgRemove("absMat.tif", it);
//                    continue;
//               }
//
//               cv::Point shift = getDiffPos(cmpS,cmpT);
//               if (abs(shift.x) >= (setting.gapPix * VIEW_SCALE) || abs(shift.y) >= (setting.gapPix * VIEW_SCALE)) {
//                    cout << "設定よりズレが大きい" << endl;
//                    diffImgs.push_back(cmpAbs);
//                    util->dbgRemove("absMat.tif", it);
//                    continue;
//               }
//               cout << "shift x = " << shift.x << " y = " << shift.y << ";" << endl;
//
//               // きりぬかないで、ずらす
//               cv::Mat tmpsikisa;
//               cv::Mat tmpS, tmpT;
//               shpT.copyTo(tmpT);
//               moveImage(shpS, tmpS, shift.x, shift.y, false);
//               makeShadeMask(tmpS, tmpT, cv::Mat(), cv::Mat(), deltaThresh, tmpsikisa);
//               cv::bitwise_and(tmpsikisa, cmpAbs, tmpsikisa);
//               delMinAreaWhite(tmpsikisa, VIEW_SCALE);
//               if (!isExistsContour(tmpsikisa)) {
//                    util->dbgRemove("absMat.tif", it);
//                    continue;
//               }
//               util->dbgSave(tmpsikisa, "tmpsikisa.tif", it);
//               cv::Rect sikisaRect = getContourRect(tmpsikisa, cv::Rect());
//               if ((sikisaRect.width <= VIEW_SCALE * 1.5) && (sikisaRect.height <= VIEW_SCALE * 1.5)) {
//                    continue;
//               }
//
//               cv::Mat crpSS,crpTT,crpSrc, crpTrg;
//               cv::Mat crpSBin,crpTBin,crpSBinSrc,crpTBinSrc;
//               cv::Mat msk = getHullMask(cmpAbs, true);
//               cv::Rect rcMsk = getContourRect(msk, cv::Rect());
//               crpSS = cv::Mat(rcMsk.height, rcMsk.width, crpSBE.type(), cv::Scalar::all(255));
//               crpTT = cv::Mat(rcMsk.height, rcMsk.width, crpSBE.type(), cv::Scalar::all(255));
//               crpSBin = cv::Mat(rcMsk.height, rcMsk.width, binSE.type(), cv::Scalar::all(0));
//               crpTBin = cv::Mat(rcMsk.height, rcMsk.width, binSE.type(), cv::Scalar::all(0));
//               crpSBE.copyTo(crpSrc);
//               crpTBE.copyTo(crpTrg);
//               binSE.copyTo(crpSBinSrc);
//               binTE.copyTo(crpTBinSrc);
//               crpSBinSrc = cv::Mat(crpSBinSrc, rcMsk);
//               crpTBinSrc = cv::Mat(crpTBinSrc, rcMsk);
//               crpSrc = cv::Mat(crpSrc, rcMsk);
//               crpTrg = cv::Mat(crpTrg, rcMsk);
//               msk = cv::Mat(msk, rcMsk);
//               for (int r = 0; r < msk.rows; r++) {
//                    uchar* p = msk.ptr<uchar>(r);
//                    uchar* ss = crpSrc.ptr<uchar>(r);
//                    uchar* ts = crpTrg.ptr<uchar>(r);
//                    uchar* ssb = crpSBinSrc.ptr<uchar>(r);
//                    uchar* tsb = crpTBinSrc.ptr<uchar>(r);
//                    uchar* s = crpSS.ptr<uchar>(r);
//                    uchar* t = crpTT.ptr<uchar>(r);
//                    uchar* sb = crpSBin.ptr<uchar>(r);
//                    uchar* tb = crpTBin.ptr<uchar>(r);
//                    for (int c = 0; c < msk.cols; c++) {
//                         if (p[c] == 255) {
//                              s[c] = ss[c];
//                              t[c] = ts[c];
//                              sb[c] = ssb[c];
//                              tb[c] = tsb[c];
//                         }
//
//                    }
//               }
//
//               util->dbgSave(crpSS, "crpS.tif", it);
//               util->dbgSave(crpTT, "crpT.tif", it);
//               util->dbgSave(crpSBin, "crpSBin.tif", it);
//               util->dbgSave(crpTBin, "crpTBin.tif", it);
//               cv::Mat crpSMin,crpTMin;
//               if ((crpSS.cols < VIEW_SCALE || crpSS.rows < VIEW_SCALE)  ||
//                   (crpTT.cols < VIEW_SCALE || crpTT.rows < VIEW_SCALE)) {
//                    crpSS.copyTo(crpSMin);
//                    crpTT.copyTo(crpTMin);
//               }
//               else {
//                    util->resizeImage(crpSS, crpSMin, 1 / VIEW_SCALE);
//                    util->resizeImage(crpTT, crpTMin, 1 / VIEW_SCALE);
//               }
//               CvUtil::MatchingResult result;
//               float hash = checkHash("", crpSMin, crpTMin);
//               result = util->tmplateMatch(cmpT, crpSS, 0.8, 1);
//               if (hash < 0.4) {
//                    cout << "違う画像" << endl;
//                    diffImgs.push_back(cmpAbs);
//                    continue;
//               }
//               if (hash <= 30) {
//                    if (result.isMatch) {
//                         continue;
//                    }
//                    bool isLargeS = (cv::countNonZero(crpSBin) > cv::countNonZero(crpTBin));
//                    double similarity = cv::matchShapes((isLargeS)? crpTBin : crpSBin,
//                                                        (isLargeS)? crpSBin : crpTBin,
//                                                        cv::CONTOURS_MATCH_I1, 0);    // huモーメントによるマッチング
//                    if (similarity == 0)
//                         continue;
//                    else if (similarity > 0.004) {
//                         cout << "違う画像" << endl;
//                         diffImgs.push_back(cmpAbs);
//                         util->dbgRemove("absMat.tif", it);
//                         util->dbgRemove("tmpsikisa.tif", it);
//                         util->dbgRemove("tmpS.tif", it);
//                         util->dbgRemove("tmpT.tif", it);
//                         util->dbgRemove("cmpS.tif", it);
//                         util->dbgRemove("cmpT.tif", it);
//                         continue;
//                    }
//               }
//
//               if (!result.isMatch) {
//                    diffImgs.push_back(cmpAbs);
//                    continue;
//               }
//
//
//               util->dbgRemove("absMat.tif", it);
//               util->dbgRemove("tmpsikisa.tif", it);
//               util->dbgRemove("tmpS.tif", it);
//               util->dbgRemove("tmpT.tif", it);
//               util->dbgRemove("cmpS.tif", it);
//               util->dbgRemove("cmpT.tif", it);
//
//          }
//
//          if (diffImgs.size() != 0) {
//               diff_cnt.clear();
//               for (auto it = diffImgs.begin(); it != diffImgs.end(); ++it) {
//                    getContours(*it, *it, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    diffprocess(diff_result, diff_cnt);
//               }
//          }
//          if (addImgs.size() != 0) {
//               diff_cnt.clear();
//               for (auto it = addImgs.begin(); it != addImgs.end(); ++it) {
//                    getContours(*it, *it, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    addprocess(diff_result, diff_cnt);
//               }
//          }
//          if (delImgs.size() != 0) {
//               diff_cnt.clear();
//               for (auto it = delImgs.begin(); it != delImgs.end(); ++it) {
//                    getContours(*it, *it, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    delprocess(diff_result, diff_cnt);
//               }
//          }
          }
          tick.stop();
          cout << "diff: " << tick.getTimeMilli() << " ms" << endl;
          cout << "end" << endl;
          return;
//          return checkedRects;
//          cv::Mat cmpS, cmpT;
//          binSE.copyTo(cmpS);
//          binTE.copyTo(cmpT);
//          cropImageFromMask(absMat, cmpS, cv::Scalar::all(0));
//          cropImageFromMask(absMat, cmpT, cv::Scalar::all(0));
//
//          if (!isExistsContour(cmpS) && !isExistsContour(cmpT)) {
//               return cropRect;
//          }
//          else if (!isExistsContour(cmpS)) {
//               std::cout << "追加" << std::endl;
//               getContours(crpS, crpT, cropRect, diff_cnt);
//               addprocess(diff_result, diff_cnt);
//               return cropRect;
//          }
//          else if (!isExistsContour(cmpT)) {
//               std::cout << "削除" << std::endl;
//               getContours(crpS, crpT, cropRect, diff_cnt);
//               delprocess(diff_result, diff_cnt);
//               return cropRect;
//          }
//
//          double poc_result = 0;
//          cv::Point shift;
//
//          cv::Rect dfRect = checkMove(crpSBE, crpTBE, cmpS, cmpT, absMat, cropRect, diff_result, extCropSize, poc_result, shift, sikisa);
//          if (sikisa.empty() || !isExistsContour(sikisa)) {
//               return dfRect;
//          }
//
//          cv::Mat andMat;
//          cv::bitwise_and(cmpS, cmpT, andMat);
//
//          if (!isExistsContour(andMat)) {
//               std::cout << "全く違う位置" << std::endl;
//               getContours(crpS, crpT, cropRect, diff_cnt);
//               diffprocess(diff_result, diff_cnt);
//               return dfRect;
//          }
//
//          cv::Rect sikisaRect;
//          getRectFromComponentImg(sikisa, sikisaRect);
//          if ((sikisaRect & roiRect).area() == 0)
//               return dfRect;
//
//          util->dbgSave(sikisa, "sikisa.tif", 0);
//          util->dbgSave(cmpS, "cmpS.tif", 0);
//          util->dbgSave(cmpT, "cmpT.tif", 0);

//
//          int whiteS = cv::countNonZero(cmpS);
//          int whiteT = cv::countNonZero(cmpT);
//          int absWhite = abs(whiteS - whiteT);
//
//          if (absWhite != 0) {
//               cv::Mat smallCompo, largeCompo;
//               cv::Mat smallOrg, largeOrg;
//               cv::Mat smallRes, largeRes;
//               if (whiteS < whiteT) {
//                    cmpS.copyTo(smallCompo);
//                    cmpT.copyTo(largeCompo);
//                    crpSBE.copyTo(smallOrg);
//                    crpTBE.copyTo(largeOrg);
//               }
//               else {
//                    cmpT.copyTo(smallCompo);
//                    cmpS.copyTo(largeCompo);
//                    crpTBE.copyTo(smallOrg);
//                    crpSBE.copyTo(largeOrg);
//               }
////               cv::dilate(smallCompo, smallCompo, cv::Mat());
//               getLabelMaskImage(largeOrg, largeCompo, largeRes);
//               getLabelMaskImage(smallOrg, largeCompo, smallRes);
//
//               if (whiteS < whiteT) {
//                    smallRes.copyTo(cmpS);
//                    largeRes.copyTo(cmpT);
//               }
//               else {
//                    smallRes.copyTo(cmpT);
//                    largeRes.copyTo(cmpS);
//               }
//          }
//
//          util->dbgSave(cmpS, "cmpS.tif", 1);
//          util->dbgSave(cmpT, "cmpT.tif", 1);
//
//          if (!isExistsContour(cmpS) && !isExistsContour(cmpT)) {
//               return cropRect;
//          }
//          else if (!isExistsContour(cmpS)) {
//               std::cout << "追加" << std::endl;
//               getContours(crpS, crpT, cropRect, diff_cnt);
//               addprocess(diff_result, diff_cnt);
//               return cropRect;
//          }
//          else if (!isExistsContour(cmpT)) {
//               std::cout << "削除" << std::endl;
//               getContours(crpS, crpT, cropRect, diff_cnt);
//               delprocess(diff_result, diff_cnt);
//               return cropRect;
//          }
//
//          getRectFromComponentImg(cmpS, roiS);
//          getRectFromComponentImg(cmpT, roiT);
//
//          cv::Rect diffRect;
//          cv::Mat diffImg;
//          cv::bitwise_or(cmpS, cmpT, diffImg);
//          getRectFromComponentImg(diffImg, diffRect);
//          diffRect.x /= VIEW_SCALE;
//          diffRect.y /= VIEW_SCALE;
//          diffRect.width /= VIEW_SCALE;
//          diffRect.height /= VIEW_SCALE;
//          diffRect.x += cropRect.x - EXT_CROP_SIZE;
//          diffRect.y += cropRect.y - EXT_CROP_SIZE;
//
//          cv::Rect crpRealS,crpRealT;
//          bool isLargeS = false;
//          if (roiS.area() < roiT.area()) {
//               crpRealS = roiS;
//               crpRealT = roiT;
//               crpRealT.width = crpRealS.width;
//               if (cmpT.cols < (crpRealT.width + crpRealT.x)) crpRealT.width -= (crpRealT.width + crpRealT.x) - cmpT.cols;
//               crpRealT.height = crpRealS.height;
//               if (cmpT.rows < (crpRealT.height + crpRealT.y)) crpRealT.height -= (crpRealT.height + crpRealT.y) - cmpT.rows;
//               isLargeS = true;
//          }
//          else {
//               crpRealS = roiS;
//               crpRealT = roiT;
//               crpRealS.width = crpRealT.width;
//               if (cmpS.cols < (crpRealS.width + crpRealS.x)) crpRealS.width -= (crpRealS.width + crpRealS.x) - cmpS.cols;
//               crpRealS.height = crpRealT.height;
//               if (cmpS.rows < (crpRealS.height + crpRealS.y)) crpRealS.height -= (crpRealS.height + crpRealS.y) - cmpS.rows;
//          }
//
//          cv::Mat checkS, checkT, eraseSrc, eraseTrg;
//          checkS = cv::Mat(crpSBE, crpRealS);
//          checkT = cv::Mat(crpTBE, crpRealT);
//          crpSBE.copyTo(eraseSrc);
//          crpTBE.copyTo(eraseTrg);
//          cropImageFromRect(crpRealS, eraseSrc, cv::Scalar::all(255));
//          cropImageFromRect(crpRealT, eraseTrg, cv::Scalar::all(255));
///*
////          cv::bitwise_or(xorMat, sikisa, absMat);
////          delMinAreaWhite(absMat, 3);
////          if (!isExistsContour(absMat))
////               return cropRect;
////          util->dbgSave(absMat, "absMat.tif", 0);
////
////          cropImageFromMask(absMat, cmpS, cv::Scalar::all(0));
////          cropImageFromMask(absMat, cmpT, cv::Scalar::all(0));
////
////
////          util->dbgSave(cmpS, "cmpS.tif", 2);
////          util->dbgSave(cmpT, "cmpT.tif", 2);
////
////
////
////          if (!isExistsContour(cmpS) && !isExistsContour(cmpT)) {
////               return cropRect;
////          }
////
//
////
////          // ズレ補正＆色差
////          shift_org = getPOCPos(cmpS, cmpT, &poc_result, setting.gapPix);
////          shift = normalizeShiftValue(shift_org);
////          if (poc_result >= 1.0) return diffRect;
////          if ((shift.x == 0) && (shift.y == 0)) {
////               cv::Mat img1, img2;
////               crpSBE.copyTo(img1);
////               crpTBE.copyTo(img2);
////               cropImageFromMask(cmpS, img1, cv::Scalar::all(255));
////               cropImageFromMask(cmpT, img2, cv::Scalar::all(255));
////               shift_org = getPOCPos(img1, img2, &poc_result, setting.gapPix);
////               shift = normalizeShiftValue(shift_org);
////               if ((shift.x == 0) && (shift.y == 0)) {
////                    img1.convertTo(img1, CV_64FC3);
////                    img2.convertTo(img2, CV_64FC3);
////                    cv::Ptr<MapperGradShift> mapper = cv::makePtr<MapperGradShift>();
////                    MapperPyramid mappPyr(mapper);
////                    cv::Ptr<Map> mapPtr = mappPyr.calculate(img1, img2);
////                    // Print result
////                    MapShift* mapShift = dynamic_cast<MapShift*>(mapPtr.get());
////
////                    auto sft = mapShift->getShift();
////                    shift_org = cv::Point2d(sft[0], sft[1]);
////                    shift = normalizeShiftValue(shift_org);
////
////                    if ((shift.x == 0) && (shift.y == 0)) {
////                         cout << "no move" << endl;
////                    }
////               }
////          }
////
////          if (abs(shift.x) >= (setting.gapPix * VIEW_SCALE) || abs(shift.y) >= (setting.gapPix * VIEW_SCALE)) {
////               std::cout << "設定よりズレが大きい" << std::endl;
////               cv::Mat img1, img2;
////               crpSBE.copyTo(img1);
////               crpTBE.copyTo(img2);
////               cropImageFromMask(cmpS, img1, cv::Scalar::all(255));
////               cropImageFromMask(cmpT, img2, cv::Scalar::all(255));
////               getContours(img1, img2, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
////               diffprocess(diff_result, diff_cnt);
////               return diffRect;
////          }
////          cout << "shift x = " << shift.x << " y = " << shift.y << ";" << endl;
////
////          getRectFromComponentImg(cmpS, roiS);
////          getRectFromComponentImg(cmpT, roiT);
////
////
//*/
//
//
//          util->dbgSave(checkS, "checkS.tif", 0);
//          util->dbgSave(checkT, "checkT.tif", 0);
//          util->dbgSave(eraseSrc, "eraseSrc.tif", 0);
//          util->dbgSave(eraseTrg, "eraseTrg.tif", 0);
//
//          cv::Mat resMat;
//          shift_org = getPOCPos(eraseSrc, eraseTrg, &poc_result, setting.gapPix);
//          shift = normalizeShiftValue(shift_org);
//          moveImage(eraseSrc, tmp, shift.x, shift.y, false);
//          makeShadeMask(tmp, eraseTrg, cv::Mat(), cv::Mat(), deltaThresh + 10, resMat);
//          if (resMat.empty() || !isExistsContour(resMat)) {
//               return diffRect;
//          }
//
//          delMinAreaWhite(resMat, 3);
//          util->dbgSave(resMat, "resMat.tif", 0);
//          if (resMat.empty() || !isExistsContour(resMat))
//               return diffRect;
//
//          float hash = checkHash(checkS, checkT);
//          if (hash >= 0.9)
//               return diffRect;
//
//          float temp_val = checkTemplate((isLargeS)? checkT : checkS,
//                                         (isLargeS)? eraseSrc : eraseTrg);
//          cout << "match : " << temp_val << endl;
//
//          if (temp_val < 0.8) {
//               cout << "違う画像" << endl;
//               getContours(eraseSrc, eraseTrg, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               diffprocess(diff_result, diff_cnt);
//               return diffRect;
//          }
//
//          if ( temp_val < setting.matchThresh) {
//               cv::Mat checkSbin, checkTbin, eraseSrcBin, eraseTrgBin;
//                checkSbin = cv::Mat(cmpS, crpRealS);
//               checkTbin = cv::Mat(cmpT, crpRealT);
//               binSE.copyTo(eraseSrcBin);
//               binTE.copyTo(eraseTrgBin);
//               cropImageFromRect(crpRealS, eraseSrcBin, cv::Scalar::all(0));
//               cropImageFromRect(crpRealT, eraseTrgBin, cv::Scalar::all(0));
//               double similarity = cv::matchShapes((isLargeS)? checkTbin : checkSbin,
//                                                   (isLargeS)? eraseSrcBin : eraseTrgBin,
//                                                   cv::CONTOURS_MATCH_I1, 0);    // huモーメントによるマッチング
//               if (similarity == 0)
//                    return diffRect;
//               else if (similarity > 0.004) {
//                    cout << "違う形状" << endl;
//                    getContours(eraseSrc, eraseTrg, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    diffprocess(diff_result, diff_cnt);
//                    return diffRect;
//               }
//          }
//


          

          
          
          
          
          
          
          
          
          
          
          
//          return diffRect;
//          getComponentFromRect(binSE, roiRect, cmpS);
//          getComponentFromRect(binTE, roiRect, cmpT);
//          util->dbgSave(cmpS, "cmpS.tif", 0);
//          util->dbgSave(cmpT, "cmpT.tif", 0);
//
//          cv::bitwise_or(cmpS, cmpT, absRealMat);
//          util->dbgSave(absRealMat, "absRealMat.tif", 0);
//
//
//

//          util->dbgSave(maskedS, "maskedS.tif", 0);
//          util->dbgSave(maskedT, "maskedT.tif", 0);
//
//

//
          
//          cv::bitwise_xor(binSE, binTE, xorMat);
//          util->dbgSave(xorMat, "xorMat.tif", 0);
//          cv::bitwise_or(xorMat, sikisa, absMat);
//          util->dbgSave(absMat, "absMat.tif", 0);
//
//          getLabelMaskImage(crpSBE, absMat, maskedS);
//          util->dbgSave(maskedS, "maskedS.tif", 0);
//          getLabelMaskImage(crpTBE, absMat, maskedT);
//          util->dbgSave(maskedT, "maskedT.tif", 0);
//
//          if (!isExistsContour(absMat)) {
//               return;
//          }
//
//          if (!isExistsContour(maskedS)) {
//               std::cout << "追加" << std::endl;
//               getContours(crpS, crpT, cropRect, diff_cnt);
//               addprocess(diff_result, diff_cnt);
//               return;
//          }
//          if (!isExistsContour(maskedT)) {
//               std::cout << "削除" << std::endl;
//               getContours(crpS, crpT, cropRect, diff_cnt);
//               delprocess(diff_result, diff_cnt);
//               return;
//          }

//

//
//          int whiteS = cv::countNonZero(maskedS);
//          int whiteT = cv::countNonZero(maskedT);
//          int absWhite = abs(whiteS - whiteT);
//
//          if (absWhite != 0) {
//               if (whiteS < whiteT) {
//                    shift_org = getPOCPos(maskedS, maskedT, &poc_result, setting.gapPix);
//                    shift = normalizeShiftValue(shift_org);
//               }
//               else {
//                    shift_org = getPOCPos(maskedT, maskedS, &poc_result, setting.gapPix);
//                    shift = normalizeShiftValue(shift_org);
//               }
//

//
//               if (poc_result >= 1.0) return;
//               if (poc_result < 0.3) {
//                    std::cout << "全く違う画像" << std::endl;
//                    getContours(crpS, crpT, cropRect, diff_cnt);
//                    diffprocess(diff_result, diff_cnt);
//                    return;
//               }
//
//               if ((shift.x == 0) && (shift.y == 0)) {
//                    cv::Rect absArea = getContourRect(absMat, cv::Rect());
//                    cropImageFromRect(absArea, maskedS, cv::Scalar::all(0));
//                    cropImageFromRect(absArea, maskedT, cv::Scalar::all(0));
//               }
//               else {
//                    cv::Mat tmp;
//                    if (whiteS < whiteT) {
//                         moveImage(maskedS, tmp, shift.x, shift.y, false);
//                         cv::bitwise_and(tmp, maskedT, maskedT);
//                    }
//                    else {
//                         moveImage(maskedT, tmp, shift.x, shift.y, false);
//                         cv::bitwise_and(tmp, maskedS, maskedS);
//                    }
//               }
//
//               util->dbgSave(maskedS, "maskedS.tif", 1);
//               util->dbgSave(maskedT, "maskedT.tif", 1);
//               cout << "diff mask" << endl;
//          }
//
//
//
//          cv::Mat checkS,checkT;
//          getRectFromComponentImg(maskedS, roiS);
//          getRectFromComponentImg(maskedT, roiT);
//
//          if ((roiS == cv::Rect()) || (roiT == cv::Rect()))
//               return;

//
//          checkS = cv::Mat(maskedS, crpRealS);
//          checkT = cv::Mat(maskedT, crpRealT);
//
//          util->dbgSave(checkS, "checkS.tif", false);
//          util->dbgSave(checkT, "checkT.tif", false);
//
//          double hash = hash_check<RadialVarianceHash>("RadialVarianceHash", checkS, checkT);

//
//
//
//
//
//
//
//          // ズレ補正
//          shift_org = getPOCPos(maskedS, maskedT, &poc_result, setting.gapPix);
//          shift = normalizeShiftValue(shift_org);

//

//          cv::Mat img1, img2;
//          crpSBE.copyTo(img1);
//          crpTBE.copyTo(img2);
//
//
//
//          getRectFromComponentImg(maskedS, roiS);
//          getRectFromComponentImg(maskedT, roiT);
//          if ((roiS == cv::Rect()) || (roiT == cv::Rect()))
//               return;
//
//          extractRect(roiS, 1, img1);
//          extractRect(roiT, 1, img2);
//          cropImageFromRect(roiS, img1, cv::Scalar::all(255));
//          cropImageFromRect(roiT, img2, cv::Scalar::all(255));
////          cropImageFromMask(maskedS, img1, cv::Scalar::all(255));
////          cropImageFromMask(maskedT, img2, cv::Scalar::all(255));
//
//          checkS = cv::Mat(crpSBE, roiS);
//          checkT = cv::Mat(crpTBE, roiT);
//          result = util->tmplateMatch((isLargeS)? checkS : checkT,
//                                      (isLargeS)? img2 : img1,
//                                      match_thresh, 1);
//
//
//          util->dbgSave(checkS, "checkS.tif", false);
//          util->dbgSave(checkT, "checkT.tif", false);
//          util->dbgSave(img1, "crpSBE.tif", false);
//          util->dbgSave(img2, "crpTBE.tif", false);
//          if (result.val < 0.9495) {
//               if (result.val < 0.5) {
//                    getContours(sikisa, sikisa, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    diffprocess(diff_result, diff_cnt);
//                    return;
//               }
//               cv::Mat shapeS, shapeT;
//               shapeS = cv::Mat(maskedS, crpRealS);
//               shapeT = cv::Mat(maskedT, crpRealT);
//               double similarity = cv::matchShapes(shapeS, shapeT, cv::CONTOURS_MATCH_I1, 0);    // huモーメントによるマッチング
//               if (similarity == 0) return;
//               else if (similarity > 0.004) {
//                    if (abs(shift.x) > 0 || abs(shift.y) > 0) {
//                         cv::Mat tmp;
//
//                         moveImage(crpSBE, tmp, shift.x, shift.y, false);
//                         makeShadeMask(tmp, crpTBE, maskedS, maskedT, deltaThresh*2, sikisa);
//                         if (sikisa.empty()) return;
//                         util->dbgSave(tmp, "src.tif", false);
//                         util->dbgSave(crpTBE, "trg.tif", false);
//                         util->dbgSave(sikisa, "result.tif", false);
//                    }
//                    else {
//                         makeShadeMask(crpSBE, crpTBE, maskedS, maskedT, deltaThresh*2, sikisa);
//                         if (sikisa.empty()) return;
//                         util->dbgSave(crpSBE, "src.tif", false);
//                         util->dbgSave(crpTBE, "trg.tif", false);
//                         util->dbgSave(sikisa, "result.tif", false);
//                    }
//                    getContours(sikisa, sikisa, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    diffprocess(diff_result, diff_cnt);
//               }
//          }
          

//          int whiteS = cv::countNonZero(maskedS);
//          int whiteT = cv::countNonZero(maskedT);
//          int absArea = abs(whiteS - whiteT);
//          if (absArea > 50) {
//               cv::Rect maskAreaS = getContourRect(maskedS, roiRect);
//               cv::Rect maskAreaT = getContourRect(maskedT, roiRect);
//               cv::Mat tmp;
//               bool isSuccess = true;
//               if ( (maskAreaS.width > maskAreaT.width) || (maskAreaS.height > maskAreaT.height) ) {
//                    shift_org = getPOCPos(maskedT, maskedS, &poc_result, setting.gapPix);
//                    shift = normalizeShiftValue(shift_org);
//                    if ((abs(shift.x) > gap) || (abs(shift.y) > gap)) {
//                         isSuccess = false;
//                    }
//                    else {
//                         moveImage(maskedT, tmp, shift.x, shift.y, false);
//                         cv::bitwise_and(tmp, maskedS, maskedS);
//                    }
//               }
//               else {
//                    shift_org = getPOCPos(maskedS, maskedT, &poc_result, setting.gapPix);
//                    shift = normalizeShiftValue(shift_org);
//                    if ((abs(shift.x) > gap) || (abs(shift.y) > gap)) {
//                         isSuccess = false;
//                    }
//                    else {
//                         moveImage(maskedS, tmp, shift.x, shift.y, false);
//                         cv::bitwise_and(tmp, maskedT, maskedT);
//                    }
//               }
//               if (!isSuccess) {
//                    std::cout << "許容範囲よりズレてる" << std::endl;
//                    getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    diffprocess(diff_result, diff_cnt);
//                    return;
//               }
//          }
//          cv::bitwise_xor(maskedS, maskedT, absMat);
//          absRect = getContourRect(absMat, cv::Rect());
//
//          cropImageFromRect(absRect, maskedS, cv::Scalar::all(0));
//          cropImageFromRect(absRect, maskedT, cv::Scalar::all(0));
//          util->dbgSave(maskedS, "maskedS.tif", 1);
//          util->dbgSave(maskedT, "maskedT.tif", 1);
//

//
//
//          bool isNoMove = false;
//          if ((shift.x == 0) && (shift.y == 0)) {
//               shift_org = getPOCPos(maskedS, maskedT, &poc_result, setting.gapPix);
//               shift = normalizeShiftValue(shift_org);
//               if ((shift.x == 0) && (shift.y == 0)) {
//                    isNoMove = true;
//               }
//          }
          



//
//          bool isNoMove = false;
//          if ((shift.x == 0) && (shift.y == 0)) {
//               isNoMove = true;
//          }
//
//          cv::Mat tmpMask;
//          moveImageWhite(crpSBE, tmpMask, shift.x, shift.y, false);
//          tmpMask.copyTo(crpSBE);
//
//          int whiteS = cv::countNonZero(maskedS);
//          int whiteT = cv::countNonZero(maskedT);
//          int absArea = abs(whiteS - whiteT);
//          if (absArea > 80) {
//
//               // 小さいマスクに合わせる
//               if (whiteS > whiteT) {
//                    moveImage(maskedT, tmpMask, shift.x, shift.y, true);
//                    cv::bitwise_and(tmpMask, maskedS, tmpMask);
//                    delMinAreaWhite(tmpMask, 4);
//                    tmpMask.copyTo(maskedS);
//               }
//               else {
//                    moveImage(maskedS, tmpMask, shift.x, shift.y, false);
//                    cv::bitwise_and(tmpMask, maskedT, tmpMask);
//                    delMinAreaWhite(tmpMask, 4);
//                    tmpMask.copyTo(maskedT);
//               }
//
//          }
//          else {
//               moveImage(maskedS, tmpMask, shift.x, shift.y, false);
//               tmpMask.copyTo(maskedS);
//          }
//          util->dbgSave(crpSBE, "crpSBE.tif", 0);
//          util->dbgSave(crpTBE, "crpTBE.tif", 0);
//          util->dbgSave(maskedS, "maskedS.tif", 1);
//          util->dbgSave(maskedT, "maskedT.tif", 1);
//          // 色差比較
//
//
//          makeShadeMask(crpSBE, crpTBE, maskedS, maskedT, deltaThresh, hikaku);
//          cv::Mat orMask;
//          cv::bitwise_or(maskedS, maskedT, orMask);
//
//          cropImageFromRect(getContourRect(orMask, cv::Rect()), hikaku, cv::Scalar::all(0));
//          delMinAreaWhite(hikaku, 4);
//          if (hikaku.empty()) return;
//          if (!isExistsContour(hikaku)) return;
//          cv::Mat diffS, diffT;
//          cv::bitwise_and(maskedS, hikaku, diffS);
//          cv::bitwise_and(maskedT, hikaku, diffT);
//          if ((diffS.empty() || !isExistsContour(diffS)) && (diffT.empty() || !isExistsContour(diffT))) return;
//          util->dbgSave(hikaku, "hikaku.tif", 2);
//          cout << endl << "------------------" << endl;

          
          
          
          
          //
//
//
//          int whiteS = cv::countNonZero(maskedS);
//          int whiteT = cv::countNonZero(maskedT);
//          int absArea = abs(whiteS - whiteT);
//          if (absArea > 100) {
//               std::cout << "mask invalid" << std::endl;
////               cv::Mat suS,suT;
////               dnn_sr->upsample(crpSE, suS);
////               dnn_sr->upsample(crpTE, suT);
//
//               // どちらかのマスクに余分な部品が存在
//               util->dbgSave(maskedS, "maskedS.tif", 0);
//               util->dbgSave(maskedT, "maskedT.tif", 0);
//               adjustMask(maskedS, maskedT, binSE, binTE, setting.gapPix);
//               util->dbgSave(maskedS, "maskedS.tif", 1);
//               util->dbgSave(maskedT, "maskedT.tif", 1);
//               splitStick(maskedS, maskedT);
//
//               util->dbgSave(maskedS, "maskedS.tif", 2);
//               util->dbgSave(maskedT, "maskedT.tif", 2);
//               if (!isExistsContour(maskedS)) {
//                    std::cout << "追加" << std::endl;
//                    util->dbgSave(crpSBE, "NGbigSExt.tif", 0);
//                    util->dbgSave(crpTBE, "NGbigTExt.tif", 0);
//                    getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    addprocess(diff_result, diff_cnt);
//                    return;
//               }
//               else if (!isExistsContour(maskedT)) {
//                    std::cout << "削除" << std::endl;
//                    util->dbgSave(crpSBE, "NGbigSExt.tif", 0);
//                    util->dbgSave(crpTBE, "NGbigTExt.tif", 0);
//                    getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    delprocess(diff_result, diff_cnt);
//                    return;
//               }
//          }
//
//          cv::Mat bigSExt, bigTExt, hikaku;
//
//          crpSBE.copyTo(bigSExt);
//          crpTBE.copyTo(bigTExt);
//
//          // ズレ補正
//          cv::Point shift;
//
//          int retAdjust = adjustMaskPosition(maskedS, maskedT, maskedS, bigSExt, binSE, true, shift);
//          if (retAdjust == 0)
//               return;
//          else if (retAdjust == 1 || retAdjust == 2) {
//               util->dbgSave(bigSExt, "NGbigSExt.tif", 0);
//               util->dbgSave(bigTExt, "NGbigTExt.tif", 0);
//               util->dbgSave(maskedS, "maskedS.tif", 0);
//               util->dbgSave(maskedT, "maskedT.tif", 0);
//               getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               diffprocess(diff_result, diff_cnt);
//               return;
//          }
//
//          bool isNoMove = false;
//          bool isMoveX = (shift.x != 0)? true : false;
//          if ((shift.x == 0) && (shift.y == 0)) {
//               isNoMove = true;
//          }
//
//          // 色差比較
//          float deltaThresh = 14.0;
//          makeShadeMask(bigSExt, bigTExt, maskedS, maskedT, deltaThresh, hikaku);
//          delMinAreaWhite(hikaku, 4);
//          if (hikaku.empty()) return;
//          if (!isExistsContour(hikaku)) return;
//
//          auto hikakus = splitComponent(hikaku);
//          std::vector<cv::Mat> ngHikakus;
//          for (auto it = hikakus.begin(); it != hikakus.end(); ++it) {
//               if (cv::countNonZero(*it) > 14) {
//                    util->dbgSave(*it, "h.tif", 0);
//                    ngHikakus.push_back(*it);
//               }
//          }
//          if (ngHikakus.size() == 0) return;
//          cv::Mat mergeHikaku(hikaku.size(), hikaku.type(), cv::Scalar::all(0));
//          for (auto it = ngHikakus.begin(); it != ngHikakus.end(); ++it) {
//               cv::bitwise_or(*it, mergeHikaku, mergeHikaku);
//          }
//          util->dbgSave(mergeHikaku, "mergeHikaku.tif", 0);
//
//          cv::Mat diffS, diffT;
//          cv::bitwise_and(maskedS, mergeHikaku, diffS);
//          cv::bitwise_and(maskedT, mergeHikaku, diffT);
//          if ((diffS.empty() || !isExistsContour(diffS)) && (diffT.empty() || !isExistsContour(diffT))) return;
//
//          // hikakuエリアが注目領域外なら無視
//          cv::Mat watchMat;
//          util->cropSafe(mergeHikaku, watchMat, roiRect, false);
//          if (watchMat.empty() || !isExistsContour(watchMat)) return;
//
//          util->dbgSave(watchMat, "watchMat.tif", 0);
//          util->dbgSave(diffS, "diffS.tif", 0);
//          util->dbgSave(diffT, "diffT.tif", 0);
//          util->dbgSave(binSE, "binSE.tif", 0);
//          util->dbgSave(binTE, "binTE.tif", 0);
//          util->dbgSave(bigSExt, "bigSExt.tif", 0);
//          util->dbgSave(bigTExt, "bigTExt.tif", 0);
//          util->dbgSave(maskedS, "maskedS.tif", 0);
//          util->dbgSave(maskedT, "maskedT.tif", 0);
//
//          // diffSかdiffTのどちらかがemptyの場合,hikakuをずらして マスク取得？ 位置をずらして
//          // 残った差分の位置補正
//          std::cout << "nan" << std::endl;
          
          
          
          
          
          
          
          
          
          
          
          
//
//          if (!getMaskImage(hikaku, binSE, maskedS, roiS)) {
//               if (!getMaskImage(hikaku, binTE, maskedT, roiT)) {
//                    // maskS, Tはそのままつかう
//               }
//               getMaskImage(maskedT, binSE, maskedS, roiS);
//               if (!getMaskImage(hikaku, binTE, maskedT, roiT)) {
//                    getMaskImage(maskedS, binTE, maskedT, roiS);
//               }
//          }
//          else {
//               if (!getMaskImage(hikaku, binTE, maskedT, roiT)) {
//                    getMaskImage(maskedS, binTE, maskedT, roiS);
//               }
//          }
//          
//          whiteS = cv::countNonZero(maskedS);
//          whiteT = cv::countNonZero(maskedT);
//          absArea = abs(whiteS - whiteT);
//          
//          if (absArea > 50) {
//               std::cout << "mask invalid" << std::endl;
//               adjustMask(maskedS, maskedT, binSE, binTE, setting.gapPix);
//               splitStick(maskedS, maskedT);
//          }
//          
//          util->dbgSave(maskedS, "maskedS.tif", 0);
//          util->dbgSave(maskedT, "maskedT.tif", 0);
//          
//          if (isNoMove) {
//               // 比較とマスクを抽出、小さい方に合わせた結果をみる
//               std::cout << "色差差分！" << std::endl;
//               util->dbgSave(bigSExt, "NGbigSExt.tif", 0);
//               util->dbgSave(bigTExt, "NGbigTExt.tif", 0);
//               getContours(hikaku, hikaku, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               diffprocess(diff_result, diff_cnt);
//               return;
//          }
//          
//          cv::bitwise_or(maskedS, maskedT, absMat);
//          absRect = getContourRect(absMat, cv::Rect());
//          
//          cv::Mat watchMatS,watchMatT;
//          bigSExt.copyTo(watchMatS);
//          bigTExt.copyTo(watchMatT);
//          cropImageFromMask(maskedS, watchMatS, cv::Scalar::all(255));
//          cropImageFromMask(maskedT, watchMatT, cv::Scalar::all(255));
//          util->dbgSave(watchMatS, "watchMatS.tif", 0);
//          util->dbgSave(watchMatT, "watchMatT.tif", 0);
//          retAdjust = adjustMaskPosition(watchMatS, watchMatT, maskedS, bigSExt, binSE, true, shift);
//          if (retAdjust == 0)
//               return;
//          else if (retAdjust == 1 || retAdjust == 2) {
//               util->dbgSave(bigSExt, "NGbigSExt.tif", 0);
//               util->dbgSave(bigTExt, "NGbigTExt.tif", 0);
//               getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               diffprocess(diff_result, diff_cnt);
//               return;
//          }
//          
//          cv::Mat moveHikaku;
//          makeShadeMask(bigSExt, bigTExt, maskedS, maskedT, deltaThresh, moveHikaku);
//          util->dbgSave(moveHikaku, "moveHikaku.tif", 0);
//          if (moveHikaku.empty() || !isExistsContour(moveHikaku)) return;
//          cv::bitwise_and(hikaku, moveHikaku, absMat);
//          if (absMat.empty() || !isExistsContour(absMat)) return;
//          if (cv::countNonZero(absMat) < 15) return;
//          
//          util->dbgSave(absMat, "hikakuAnd.tif", 0);
//          delMinAreaWhite(absMat, 10);
//          if (!getMaskImage(absMat, binSE, maskedS, roiS)) {
//               if (!getMaskImage(hikaku, binTE, maskedT, roiT)) {
//                    // maskS, Tはそのままつかう
//               }
//               getMaskImage(maskedT, binSE, maskedS, roiS);
//               if (!getMaskImage(absMat, binTE, maskedT, roiT)) {
//                    getMaskImage(maskedS, binTE, maskedT, roiS);
//               }
//          }
//          else {
//               if (!getMaskImage(absMat, binTE, maskedT, roiT)) {
//                    getMaskImage(maskedS, binTE, maskedT, roiS);
//               }
//          }
//          
//          whiteS = cv::countNonZero(maskedS);
//          whiteT = cv::countNonZero(maskedT);
//          absArea = abs(whiteS - whiteT);
//          
//          if (absArea > 50) {
//               std::cout << "mask invalid" << std::endl;
//               adjustMask(maskedS, maskedT, binSE, binTE, setting.gapPix);
//               splitStick(maskedS, maskedT);
//          }
//          
//          
//
//          
//          cv::bitwise_or(maskedS, maskedT, absMat);
//          absRect = getContourRect(absMat, cv::Rect());
//          
//          bigSExt.copyTo(watchMatS);
//          bigTExt.copyTo(watchMatT);
//          cropImageFromMask(maskedS, watchMatS, cv::Scalar::all(255));
//          cropImageFromMask(maskedT, watchMatT, cv::Scalar::all(255));
//          util->dbgSave(watchMatS, "watchMatS.tif", 0);
//          util->dbgSave(watchMatT, "watchMatT.tif", 0);
//          retAdjust = adjustMaskPosition(watchMatS, watchMatT, maskedS, bigSExt, binSE, true, shift);
//          if (retAdjust == 0)
//               return;
//          else if (retAdjust == 1 || retAdjust == 2) {
//               util->dbgSave(bigSExt, "NGbigSExt.tif", 0);
//               util->dbgSave(bigTExt, "NGbigTExt.tif", 0);
//               getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               diffprocess(diff_result, diff_cnt);
//               return;
//          }
//          
//          cv::Mat lastHikaku;
//          makeShadeMask(bigSExt, bigTExt, maskedS, maskedT, deltaThresh, lastHikaku);
//          util->dbgSave(lastHikaku, "lastHikaku.tif", 0);
//          if (lastHikaku.empty() || !isExistsContour(lastHikaku)) return;
//          cv::bitwise_and(hikaku, lastHikaku, absMat);
//          if (absMat.empty() || !isExistsContour(absMat)) return;
//          if (cv::countNonZero(absMat) < 15) return;
//          
//          util->dbgSave(absMat, "lastHikakuAnd.tif", 0);
//
          
          /*
          
          
          
          if (isNoMove) {
               cv::Mat tmp;
               cv::resize(hikaku, tmp, cv::Size((1/VIEW_SCALE)*hikaku.cols, (1/VIEW_SCALE)*hikaku.rows), cv::INTER_AREA);
               std::vector<std::vector<cv::Point>> theC;
               cv::findContours(tmp, theC, cv::RETR_LIST, cv::CHAIN_APPROX_NONE);
               cv::Point adjustPoint;
               cv::Rect ext(cropRect.x - extCropSize,
                            cropRect.y - extCropSize,
                            cropRect.width + (extCropSize * 2),
                            cropRect.height + (extCropSize * 2));
               
               for (int i = 0; i < theC.size(); ++i) {
                    std::vector<cv::Point> it = theC.at(i);
                    std::vector<cv::Point> ttt;
                    for (auto jt = it.begin(); jt != it.end(); ++jt) {
                         cv::Point p = *jt;
                         p.x += ext.tl().x;
                         p.y += ext.tl().y;
                         ttt.push_back(p);
                    }
                    diff_cnt.push_back(ttt);
               }
               diffprocess(diff_result, diff_cnt);
          }
          
          getMaskImage(hikaku, maskedS, maskedS, roiS);
          getMaskImage(hikaku, maskedT, maskedT, roiT);
          
          whiteS = cv::countNonZero(maskedS);
          whiteT = cv::countNonZero(maskedT);
          if (abs(whiteS - whiteT) > 50) {
               adjustMask(maskedS, maskedT, binSE, binTE, setting.gapPix);
          }
          
          // ズレ補正
          retAdjust = adjustMaskPosition(maskedS, maskedT, maskedS, bigSExt, binSE, true, shift);
          if (retAdjust == 0)
               return;
          else if (retAdjust == 1 || retAdjust == 2) {
               getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
               diffprocess(diff_result, diff_cnt);
               return;
          }
          
          // 色差比較
          makeShadeMask(bigSExt, bigTExt, maskedS, maskedT, deltaThresh, hikaku);
          if (hikaku.empty()) return;
          delMinAreaWhite(hikaku, 4);
          if (!isExistsContour(hikaku)) return;

          getMaskImage(hikaku, maskedS, maskedS, roiS);
          getMaskImage(hikaku, maskedT, maskedT, roiT);
          
          whiteS = cv::countNonZero(maskedS);
          whiteT = cv::countNonZero(maskedT);
          
          if (abs(whiteS - whiteT) > 50) {
               adjustMask(maskedS, maskedT, binSE, binTE, setting.gapPix);
          }
          
          util->dbgSave(bigSExt, "bigSExt.tif", 0);
          util->dbgSave(bigTExt, "bigTExt.tif", 0);
          util->dbgSave(maskedS, "maskedS.tif", 0);
          util->dbgSave(maskedT, "maskedT.tif", 0);
          util->dbgSave(hikaku, "hikaku.tif", 0);
          
          // 差分をベースに、元画像をずらして比較
          
          bool isMatch = false;
          

          
          if (!isNoMove && isX) {
               for (int dx = -1*(setting.gapPix); dx <= (setting.gapPix); dx++) {
                    cv::Mat tmpHikaku;
                    cv::Mat tmpS, tmpMS;
                    moveImageWhite(bigSExt, tmpS, dx, 0, false);
                    makeShadeMask(tmpS, bigTExt, maskedS, maskedT, deltaThresh, tmpHikaku);
                    
//                    util->dbgSave(tmpHikaku, "tmpHikaku.tif", dx);
                    if (tmpHikaku.empty()) {
                         isMatch = true;
                         break;
                    }
                    cv::Mat chkDiff;
                    cv::bitwise_and(tmpHikaku, hikaku, chkDiff);
                    delMinAreaWhite(chkDiff, 4);
                    
                    if (!isExistsContour(chkDiff)) {
                         isMatch = true;
                         break;
                    }
               }
          }
          else if (!isNoMove && !isX) {
               for (int dy = -1*(setting.gapPix); dy <= (setting.gapPix); dy++) {
                    cv::Mat tmpHikaku;
                    cv::Mat tmpS, tmpMS;
                    moveImageWhite(bigSExt, tmpS, 0, dy, false);
                    makeShadeMask(tmpS, bigTExt, maskedS, maskedT, deltaThresh, tmpHikaku);
                    
                    if (tmpHikaku.empty()) {
                         isMatch = true;
                         break;
                    }
                    cv::Mat chkDiff;
                    cv::bitwise_and(tmpHikaku, hikaku, chkDiff);
                    delMinAreaWhite(chkDiff, 4);
                    
                    if (!isExistsContour(chkDiff)) {
                         isMatch = true;
                         break;
                    }
               }
          }

          if (!isMatch) {
               cv::Mat orMask;
               cv::bitwise_or(maskedS, maskedT, orMask);
               std::vector<cv::Mat> splitS, splitT;
               std::vector<cv::Rect> rows = getRowRects(orMask);
               std::vector<cv::Rect> cols = getColRects(orMask);
               if ((rows.size() != 1) || (cols.size() != 1)) {
                    if (rows.size() > cols.size()) {
                         splitS = splitComponent(maskedS, rows);
                         splitT = splitComponent(maskedT, rows);
                    }
                    else {
                         splitS = splitComponent(maskedS, cols);
                         splitT = splitComponent(maskedT, cols);
                    }
     
                    if (splitS.size() != splitT.size()) {
                         splitS.clear();
                         splitS.push_back(maskedS);
                         splitT.clear();
                         splitT.push_back(maskedT);
     
                    }
               }
               else {
                    splitS.push_back(maskedS);
                    splitT.push_back(maskedT);
               }
               if (splitS.size() == splitT.size()) {
                    
                    for (int i = 0; i < splitS.size(); i++) {
                         isMatch = false;
                         cv::Mat sOrg, tOrg;
                         bigSExt.copyTo(sOrg);
                         bigTExt.copyTo(tOrg);
                         cv::Mat pieceS, pieceT;
                         pieceS = splitS.at(i);
                         pieceT = splitT.at(i);
                         util->dbgSave(pieceS, "pieceS.tif", i);
                         util->dbgSave(pieceT, "pieceT.tif", i);
                         cv::Mat dfS, dfT;
                         cv::bitwise_and(pieceS, hikaku, dfS);
                         cv::bitwise_and(pieceT, hikaku, dfT);
                         if (!isExistsContour(dfS) && !isExistsContour(dfT)) continue;
                         cv::Mat absMat;
                         util->absDiffImg(pieceS, pieceT, absMat, false, false);
                         cropImageFromMask(pieceS, sOrg, cv::Scalar(255));
                         cropImageFromMask(pieceT, tOrg, cv::Scalar(255));
                         util->dbgSave(sOrg, "sOrg.tif", i);
                         util->dbgSave(tOrg, "tOrg.tif", i);
                         if (!isNoMove && isX) {
                              for (int dx = -1*(setting.gapPix); dx <= (setting.gapPix); dx++) {
                                   cv::Mat tmpHikaku;
                                   cv::Mat tmpS, tmpMS;
                                   moveImageWhite(sOrg, tmpS, dx, 0, false);
                                   makeShadeMask(tmpS, tOrg, pieceS, pieceT, deltaThresh, tmpHikaku);
                                   
                                   //                    util->dbgSave(tmpHikaku, "tmpHikaku.tif", dx);
                                   if (tmpHikaku.empty()) {
                                        isMatch = true;
                                        break;
                                   }
                                   cv::Mat chkDiff;
                                   cv::bitwise_and(tmpHikaku, hikaku, chkDiff);
                                   delMinAreaWhite(chkDiff, 4);
                                   
                                   if (!isExistsContour(chkDiff)) {
                                        isMatch = true;
                                        break;
                                   }
                              }
                         }
                         else if (!isNoMove && !isX) {
                              for (int dy = -1*(setting.gapPix); dy <= (setting.gapPix); dy++) {
                                   cv::Mat tmpHikaku;
                                   cv::Mat tmpS, tmpMS;
                                   moveImageWhite(sOrg, tmpS, 0, dy, false);
                                   makeShadeMask(tmpS, tOrg, pieceS, pieceT, deltaThresh, tmpHikaku);
                                   
                                   //                    util->dbgSave(tmpHikaku, "tmpHikaku.tif", dy);
                                   if (tmpHikaku.empty()) {
                                        isMatch = true;
                                        break;
                                   }
                                   cv::Mat chkDiff;
                                   cv::bitwise_and(tmpHikaku, hikaku, chkDiff);
                                   delMinAreaWhite(chkDiff, 4);
                                   
                                   if (!isExistsContour(chkDiff)) {
                                        isMatch = true;
                                        break;
                                   }
                              }
                         }
                         if (!isMatch) {
                              cv::Rect cropT = getContourRect(pieceT, cv::Rect());
                              cv::Mat tr;
                              util->cropSafe(pieceT, tr, cropT, false);
                              double similarity = cv::matchShapes(tr, pieceS, cv::CONTOURS_MATCH_I1, 0);    // huモーメントによるマッチング
                              if (similarity > 0.01) {
                                   getContours(pieceS, pieceT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
                                   diffprocess(diff_result, diff_cnt);
                              }
                         }
                    }
               }
               else {
                    for (int i = 0; i < splitS.size(); i++) {
                         util->dbgSave(splitS.at(i), "maskedS.tif", i);
                    }
                    for (int i = 0; i < splitT.size(); i++) {
                         util->dbgSave(splitT.at(i), "maskedT.tif", i);
                    }
               }
//               getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               diffprocess(diff_result, diff_cnt);
               return;
          }
          else {
               return;
          }
          getMaskImage(hikaku, maskedS, maskedS, roiS);
          getMaskImage(hikaku, maskedT, maskedT, roiT);
          
          if (abs(cv::countNonZero(maskedS) - cv::countNonZero(maskedT)) > 50) {
               cropImageFromMask(hikaku, maskedS, cv::Scalar::all(0));
               cropImageFromMask(hikaku, maskedT, cv::Scalar::all(0));
               util->dbgSave(maskedS, "maskedS.tif", 0);
               util->dbgSave(maskedT, "maskedT.tif", 0);
          }
          retAdjust = adjustMaskPosition(maskedS, maskedT, maskedS, bigSExt, binSE, true, shift);
          if (retAdjust == 0)
               return;
          else if (retAdjust == 1 || retAdjust == 2) {
               getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
               diffprocess(diff_result, diff_cnt);
               return;
          }
          util->dbgSave(hikaku, "hikaku.tif", 0);
          cv::Mat hikakuOrg;
          hikaku.copyTo(hikakuOrg);
          makeShadeMask(bigSExt, bigTExt, maskedS, maskedT, deltaThresh, hikaku);
          if (hikaku.empty()) return;

          util->dbgSave(bigSExt, "bigSExt.tif", 0);
          util->dbgSave(bigTExt, "bigTExt.tif", 0);
          util->dbgSave(maskedS, "maskedS.tif", 0);
          util->dbgSave(maskedT, "maskedT.tif", 0);
          util->dbgSave(hikaku, "hikaku.tif", 1);
          
          
          cropImageFromMask(hikaku, bigSExt, cv::Scalar::all(255));
          cropImageFromMask(hikaku, bigTExt, cv::Scalar::all(255));
//          util->dbgSave(bigSExt, "bigSExt.tif", 2);
//          util->dbgSave(bigTExt, "bigTExt.tif", 2);
//          cv::threshold(bigSExt, binSE, 190, 255, cv::THRESH_BINARY_INV);
//          cv::threshold(bigTExt, binTE, 190, 255, cv::THRESH_BINARY_INV);
//          cv::bitwise_xor(binSE, binTE, absMat);
//          delMinAreaWhite(absMat, 4);
//          absRect = getContourRect(absMat, roiRect);
//          cv::bitwise_and(binSE, absMat, binS);
//          cv::bitwise_and(binTE, absMat, binT);
//
//          util->cropSafe(binS, binS, absRect, false);
//          util->cropSafe(binT, binT, absRect, false);
//          toSize(binS, binS, cv::Size(crpSBE.cols,crpSBE.rows), absRect, cv::Scalar::all(0));
//          toSize(binT, binT, cv::Size(crpTBE.cols,crpTBE.rows), absRect, cv::Scalar::all(0));
//          getMaskImage(binS, binSE, maskedS, roiS);
//          getMaskImage(binT, binTE, maskedT, roiT);
//          util->dbgSave(maskedS, "maskedS.tif", 1);
//          util->dbgSave(maskedT, "maskedT.tif", 1);
//
//          defHikaku = makeShadeMask(bigSExt, bigTExt, maskedS, maskedT, deltaThresh, hikaku);
//          if (defHikaku) return;
//
//          util->dbgSave(maskedS, "maskedS.tif", 1);
//          util->dbgSave(maskedT, "maskedT.tif", 1);
//          util->dbgSave(hikaku, "hikaku.tif", 1);
//
//          // マスク更新
//          cropImageFromMask(hikaku, bigSExt, cv::Scalar::all(255));
//          cropImageFromMask(hikaku, bigTExt, cv::Scalar::all(255));
//          cv::Mat xorMask;
//          cv::bitwise_xor(maskedS, maskedT, xorMask);
//          cv::Rect xorArea = getContourRect(xorMask, cv::Rect());
//          util->cropSafe(maskedS, maskedS, xorArea, false);
//          util->cropSafe(maskedT, maskedT, xorArea, false);
//          toSize(maskedS, maskedS, bigSExt.size(), xorArea, cv::Scalar::all(0));
//          toSize(maskedT, maskedT, bigTExt.size(), xorArea, cv::Scalar::all(0));
//
//          retAdjust = adjustMaskPosition(maskedS, maskedT, maskedS, bigSExt, binSE, true, shift);
//          if (retAdjust == 0)
//               return;
//          else if (retAdjust == 1 || retAdjust == 2) {
//               getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               diffprocess(diff_result, diff_cnt);
//               return;
//          }
//          defHikaku = makeShadeMask(bigSExt, bigTExt, maskedS, maskedT, deltaThresh, hikaku);
//          if (defHikaku) return;
//          util->dbgSave(maskedS, "maskedS.tif", 2);
//          util->dbgSave(maskedT, "maskedT.tif", 2);
//          util->dbgSave(hikaku, "hikaku.tif", 2);
//
//          cv::Mat orMask, cropedS, cropedT;
//          cv::bitwise_or(maskedS, maskedT, orMask);
//          cv::Rect maskArea = getContourRect(orMask, cv::Rect());
//          util->cropSafe(bigSExt, cropedS, maskArea, false);
//          util->cropSafe(bigTExt, cropedT, maskArea, false);
//          toSize(cropedS, cropedS, bigSExt.size(), maskArea, cv::Scalar::all(255));
//          toSize(cropedT, cropedT, bigTExt.size(), maskArea, cv::Scalar::all(255));
//          retAdjust = adjustMaskPosition(cropedS, cropedT, maskedS, bigSExt, binSE, true, shift);
//          if (retAdjust == 0)
//               return;
//          else if (retAdjust == 1 || retAdjust == 2) {
//               getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               diffprocess(diff_result, diff_cnt);
//               return;
//          }
//          util->dbgSave(maskedS, "maskedS.tif", 2);
//          util->dbgSave(maskedT, "maskedT.tif", 2);
//
//          cv::Mat maskSorg, maskTorg;
//          maskedS.copyTo(maskSorg);
//          maskedT.copyTo(maskTorg);
//
//          defHikaku = makeShadeMask(cropedS, cropedT, maskedS, maskedT, 12.0, hikaku);
//          if (defHikaku) return;
//
//          // くっつき分離
//          util->dbgSave(maskedS, "maskedS.tif", 0);
//          util->dbgSave(maskedT, "maskedT.tif", 0);
//          util->dbgSave(hikaku, "hikaku.tif", 0);
//
//
//
//
//
//          cv::Rect crpArea = getContourRect(hikaku, cv::Rect());
//          // 差分エリア以外を消す
//          for (int r = 0; r < maskedS.rows; r++) {
//               uchar *sp = maskedS.ptr<uchar>(r);
//               uchar *tp = maskedT.ptr<uchar>(r);
//               for (int c = 0; c < maskedS.cols; c++) {
//                    cv::Point curP(c, r);
//                    if (!crpArea.contains(curP)) {
//                         sp[c] = 0;
//                         tp[c] = 0;
//                    }
//               }
//          }

          util->dbgSave(maskedS, "maskedS.tif", 1);
          util->dbgSave(maskedT, "maskedT.tif", 1);
          */
//          if (!isExistsContour(tmpMaskS) || !isExistsContour(tmpMaskT)) return true;
//          tmpMaskS.copyTo(maskS);
//          tmpMaskT.copyTo(maskT);
//
//          // 差分箇所を詳細に比較
//          cv::Mat orMask;
//          cv::bitwise_or(maskedS, maskedT, orMask);
//          std::vector<cv::Rect> rows = getRowRects(orMask);
//          std::vector<cv::Rect> cols = getColRects(orMask);
//          if ((rows.size() != 1) || (cols.size() != 1)) {
//               if (rows.size() > cols.size()) {
//                    splitS = splitComponent(maskedS, rows);
//                    splitT = splitComponent(maskedT, rows);
//               }
//               else {
//                    splitS = splitComponent(maskedS, cols);
//                    splitT = splitComponent(maskedT, cols);
//               }
//
//               if (splitS.size() != splitT.size()) {
//                    splitS.clear();
//                    splitS.push_back(maskedS);
//                    splitT.clear();
//                    splitT.push_back(maskedT);
//
//               }
//          }
//          else {
//               splitS.push_back(maskedS);
//               splitT.push_back(maskedT);
//          }
//
//          // xを-2~2の範囲で移動してチェック
//          for (int dx = -2; dx <= 2; dx++) {
//
//          }
//
//
//
//               cv::bitwise_or(maskedS, maskedT, orMask);
//               maskArea = getContourRect(orMask, cv::Rect());
//               util->cropSafe(bigSExt, cropedS, maskArea, false);
//               util->cropSafe(bigTExt, cropedT, maskArea, false);
//               toSize(cropedS, cropedS, bigSExt.size(), maskArea, cv::Scalar::all(255));
////               toSize(cropedT, cropedT, bigTExt.size(), maskArea, cv::Scalar::all(255));
//               double similarity = cv::matchShapes(maskSorg, maskTorg, cv::CONTOURS_MATCH_I1, 0);    // huモーメントによるマッチング
//               result = util->tmplateMatch(cropedT, cropedS, match_thresh, 1);
//
//               util->dbgSave(cropedT, "cropedT.tif", 1);
//               util->dbgSave(binSE, "binSE.tif", 1);
//               util->dbgSave(binTE, "binTE.tif", 1);
//               util->dbgSave(bigSExt, "bigSExt.tif", 1);
//               util->dbgSave(bigTExt, "bigTExt.tif", 1);
//
//
//               if ((similarity >= 0.004) && !result.isMatch) {
//                    getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    diffprocess(diff_result, diff_cnt);
//                    util->dbgSave(cropedS, "cropedS.tif", 1);
//                    return;
//               }
//               else if (poc_result < 0.9 && result.val < 0.9) {
//                    getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    diffprocess(diff_result, diff_cnt);
//               }
//
//
//
          
          
          
//
//
//
//          cv::Mat mS, mT;
//          maskedS.copyTo(mS);
//          maskedT.copyTo(mT);
//          cv::bitwise_xor(maskedS, maskedT, absMat);
//          if (!isExistsContour(absMat)) return;
//          getMaskImage(absMat, binSE, maskedS, roiS);
//          getMaskImage(absMat, binTE, maskedT, roiT);
//
//          whiteS = cv::countNonZero(maskedS);
//          whiteT = cv::countNonZero(maskedT);
//          absArea = abs(whiteS - whiteT);
//          if (absArea > 50) {
//               std::cout << "mask invalid" << std::endl;
//               mS.copyTo(maskedS);
//               mT.copyTo(maskedT);
//          }
//          getComponentFromRect(maskedS, roiRect, maskedS);
//          getComponentFromRect(maskedT, roiRect, maskedT);
//
//          util->dbgSave(maskedS, "maskedS.tif", 0);
//          util->dbgSave(maskedT, "maskedT.tif", 0);
//
//          if (!isExistsContour(maskedS) || !isExistsContour(maskedT)) {
//               // どっちかが無ならROIからはずれるため
//               return;
//          }
//
//          retAdjust = adjustMaskPosition(maskedS, maskedT, bigSExt, binSE, true);
//
//          if (retAdjust == 0)
//               return;
//          else if (retAdjust == 1 || retAdjust == 2) {
//               getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//               diffprocess(diff_result, diff_cnt);
//               return;
//          }
//
//          cv::bitwise_xor(maskedS, maskedT, absMat);
//          if (!isExistsContour(absMat)) return;
//
//          // 色差マスク作成
//          std::vector<cv::Mat> splitS, splitT;
//          if (!makeShadeMask(bigSExt, bigTExt, maskedS, maskedT, 13.0)) {
//               util->dbgSave(maskedS, "maskedS.tif", 1);
//               util->dbgSave(maskedT, "maskedT.tif", 1);
//
//               // 上下左右に移動しながら色差チェック
//               cv::Mat up,down,lft,rght;
//               cv::Mat mup,mdown,mlft,mrght;
//               cv::Mat mt;
//               maskedT.copyTo(mt);
//               moveImage(bigSExt, up, 0, -1, false);
//               moveImage(maskedS, mup, 0, -1, false);
//               moveImage(bigSExt, down, 0, 1, false);
//               moveImage(maskedS, mdown, 0, 1, false);
//               moveImage(bigSExt, lft, -1, 0, false);
//               moveImage(maskedS, mlft, -1, 0, false);
//               moveImage(bigSExt, rght, 1, 0, false);
//               moveImage(maskedS, mrght, 1, 0, false);
//
//               bool isUp = makeShadeMask(up, bigTExt, mup, mt, 13.0);
//               maskedT.copyTo(mt);
//               bool isDw = makeShadeMask(down, bigTExt, mdown, mt, 13.0);
//               maskedT.copyTo(mt);
//               bool isLf = makeShadeMask(lft, bigTExt, mlft, mt, 13.0);
//               maskedT.copyTo(mt);
//               bool isRg = makeShadeMask(rght, bigTExt, mrght, mt, 13.0);
//
//               if (isUp | isDw | isLf | isRg) return;
//
//               // 差分箇所を詳細に比較
//               cv::Mat orMask;
//               cv::bitwise_or(maskedS, maskedT, orMask);
//               std::vector<cv::Rect> rows = getRowRects(orMask);
//               std::vector<cv::Rect> cols = getColRects(orMask);
//               if ((rows.size() != 1) || (cols.size() != 1)) {
//                    if (rows.size() > cols.size()) {
//                         splitS = splitComponent(maskedS, rows);
//                         splitT = splitComponent(maskedT, rows);
//                    }
//                    else {
//                         splitS = splitComponent(maskedS, cols);
//                         splitT = splitComponent(maskedT, cols);
//                    }
//
//                    if (splitS.size() != splitT.size()) {
//                         splitS.clear();
//                         splitS.push_back(maskedS);
//                         splitT.clear();
//                         splitT.push_back(maskedT);
//
//                    }
//               }
//               else {
//                    splitS.push_back(maskedS);
//                    splitT.push_back(maskedT);
//               }
//               for (int i = 0; i < splitS.size(); i++) {
//                    cv::Mat theMaskS = splitS.at(i);
//                    cv::Mat theMaskT = splitT.at(i);
//
//                    retAdjust = adjustMaskPosition(theMaskS, theMaskT, bigSExt, binSE, false);
//                    if (retAdjust == 0) continue;
//                    else if (retAdjust == 1 || retAdjust == 2) {
//                         util->dbgSave(bigSExt, "bigSExt.tif", i);
//                         util->dbgSave(bigTExt, "bigTExt.tif", i);
//                         util->dbgSave(theMaskS, "theMaskS.tif", i);
//                         util->dbgSave(theMaskT, "theMaskT.tif", i);
//                         getContours(theMaskS, theMaskT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                         diffprocess(diff_result, diff_cnt);
//                         continue;
//                    }
//                    if (!makeShadeMask(bigSExt, bigTExt, theMaskS, theMaskT, 13.0)) {
//                         util->dbgSave(bigSExt, "bigSExt.tif", i);
//                         util->dbgSave(bigTExt, "bigTExt.tif", i);
//                         util->dbgSave(theMaskS, "theMaskS.tif", i);
//                         util->dbgSave(theMaskT, "theMaskT.tif", i);
//                         std::cout << "mask invalid" << std::endl;
//                    }
//               }
//          }
          
          
          
//
//          util->dbgSave(maskedS, "maskedS.tif", 1);
//          util->dbgSave(maskedT, "maskedT.tif", 1);
//
//          // 同じ位置の部品消去
//          removeSame(maskedS, maskedT);
//
//          util->dbgSave(maskedS, "maskedS.tif", 2);
//          util->dbgSave(maskedT, "maskedT.tif", 2);
//
//          removeAround(maskedS, 1);
//          removeAround(maskedT, 1);
//          delMinAreaWhite(maskedT, 10);
//          delMinAreaWhite(maskedS, 10);
//          if (!isExistsContour(maskedS) || !isExistsContour(maskedT)) {
//               maskSorg.copyTo(maskedS);
//               maskTorg.copyTo(maskedT);
//          }
//
//          absArea = abs(cv::countNonZero(maskedS) - cv::countNonZero(maskedT));
//
//          if (absArea > 200) {
//               // ほとんどイラスト差分か、文字の差分
//               maskSorg.copyTo(maskedS);
//               maskTorg.copyTo(maskedT);
//          }
//
//          util->dbgSave(maskedS, "maskedS.tif", 3);
//          util->dbgSave(maskedT, "maskedT.tif", 3);
//
//          whiteS = cv::countNonZero(maskedS);
//          whiteT = cv::countNonZero(maskedT);
//          absArea = abs(whiteS - whiteT);
//
//          if (absArea > 100) {
//               std::cout << "mask invalid" << std::endl;
//               // 多いエリアに合わせる
//               delOutComponent(maskedS, maskedT);
//               util->dbgSave(maskedS, "maskedS.tif", 4);
//               util->dbgSave(maskedT, "maskedT.tif", 4);
//          }
//
//
//
//          if (abs(shift.x) >= (setting.gapPix * VIEW_SCALE) || abs(shift.y) >= (setting.gapPix * VIEW_SCALE)) {
//               std::cout << "設定よりズレが大きい" << std::endl;
//               getContours(crpS, crpT, cropRect, diff_cnt);
//               diffprocess(diff_result, diff_cnt);
//               return;
//          }
          
//          roiS = getContourRect(maskedS, cv::Rect());
//          roiT = getContourRect(maskedT, cv::Rect());
//          cv::Rect mergeRect = roiS | roiT;
//          std::vector<cv::Mat> splitS, splitT;
//
//          if ((mergeRect.width * 2.5 <= mergeRect.height) || (mergeRect.height * 2.5 <= mergeRect.width)) {
//               cv::Mat orMask;
//               cv::bitwise_or(maskedS, maskedT, orMask);
//               std::vector<cv::Rect> rows = getRowRects(orMask);
//               std::vector<cv::Rect> cols = getColRects(orMask);
//
//               if ((rows.size() != 1) || (cols.size() != 1)) {
//                    std::cout << "部品分解" << std::endl;
//                    if (rows.size() > cols.size()) {
//                         splitS = splitComponent(maskedS, rows);
//                         splitT = splitComponent(maskedT, rows);
//                    }
//                    else {
//                         splitS = splitComponent(maskedS, cols);
//                         splitT = splitComponent(maskedT, cols);
//                    }
//
//                    if (splitS.size() != splitT.size()) {
//                         splitS.clear();
//                         splitS.push_back(maskedS);
//                         splitT.clear();
//                         splitT.push_back(maskedT);
//
//                    }
//               }
//          }
//          else {
//               splitS.push_back(maskedS);
//               splitT.push_back(maskedT);
//          }
//          bool isNG = false;
//          for (int i = 0; i < splitS.size(); i++) {
//               cv::Mat theMaskS = splitS.at(i);
//               cv::Mat theMaskT = splitT.at(i);
//               cv::Rect absExt;
//               util->dbgSave(theMaskS, "theMaskS.tif", 0);
//               util->dbgSave(theMaskT, "theMaskT.tif", 0);
//
//               // マスクで注目領域きりだし
//               cv::Mat diffS(theMaskS.rows, theMaskS.cols, CV_8UC1, cv::Scalar(255));
//               cv::Mat diffT(theMaskT.rows, theMaskT.cols, CV_8UC1, cv::Scalar(255));
//               crpSBE.copyTo(diffS, theMaskS);
//               crpTBE.copyTo(diffT, theMaskT);
//               cv::bitwise_xor(theMaskS, theMaskT, absMat);
//               absRect = getContourRect(absMat, cv::Rect());
//               absExt = cv::Rect(absRect.x - extCropSize,
//                                 absRect.y - extCropSize,
//                                 absRect.width + (extCropSize * 2),
//                                 absRect.height + (extCropSize * 2));
//               if (abs(cv::countNonZero(theMaskS) - cv::countNonZero(theMaskT) ) > 100 ) {
//                    std::cout << "mask invalid" << std::endl;
//
//
//                    util->cropSafe(crpTBE, crpT, absRect, false);
//                    util->dbgSave(crpSBE, "crpS.tif", 1);
//                    util->dbgSave(crpT, "crpT.tif", 1);
//                    result = util->tmplateMatch(crpSBE, crpT, match_thresh, 1);
//                    if (!result.isMatch) {
//                         getContours(diffS, diffT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                         diffprocess(diff_result, diff_cnt);
//                         isNG = true;
//                         continue;
//                    }
//                    if (!checkShade(crpSBE, crpTBE, maskedS, maskedT)) {
//                         std::cout << "濃度が違う" << std::endl;
//                         getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                         diffprocess(diff_result, diff_cnt);
//                         isNG = true;
//                         continue;
//                    }
//               }
//
//               shift_org = getPOCPos(theMaskS, theMaskT, &poc_result, setting.gapPix);
//               shift = normalizeShiftValue(shift_org);
//               if (abs(shift.x) >= (setting.gapPix * VIEW_SCALE) || abs(shift.y) >= (setting.gapPix * VIEW_SCALE)) {
//                    std::cout << "設定よりズレが大きい" << std::endl;
//                    getContours(diffS, diffT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    diffprocess(diff_result, diff_cnt);
//                    isNG = true;
//                    continue;
//               }
//
//               // 余分な領域カット
//               cv::Rect t;
//               cv::Mat crpSbin, crpTbin, move;
//               moveImage(theMaskT, move, shift.x, shift.y, true);
//               delMinAreaWhite(move, 12);
//               getMaskImage(move, theMaskS, theMaskS, t);
//               moveImage(theMaskS, move, shift.x, shift.y, false);
//               delMinAreaWhite(move, 12);
//               getMaskImage(move, theMaskT, theMaskT, t);
//
//               if (!isExistsContour(theMaskT) || !isExistsContour(theMaskS)) {
//                    continue;
//               }
//
//               cv::bitwise_xor(theMaskS, theMaskT, absMat);
//               absRect = getContourRect(absMat, cv::Rect());
//               absExt = cv::Rect(absRect.x - extCropSize,
//                                  absRect.y - extCropSize,
//                                  absRect.width + (extCropSize * 2),
//                                  absRect.height + (extCropSize * 2));
//               util->cropSafe(theMaskS, crpSbin, absExt, false);
//               util->cropSafe(theMaskT, crpTbin, absExt, false);
//               util->cropSafe(crpSBE, crpS, absExt, false);
//               util->cropSafe(crpTBE, crpT, absRect, false);
//
//               shift_org = getPOCPos(crpSbin, crpTbin, &poc_result, setting.gapPix);
//               double similarity = cv::matchShapes(crpSbin, crpTbin, cv::CONTOURS_MATCH_I1, 0);    // huモーメントによるマッチング
//
//               if (similarity == 0) continue;
//               else if (similarity > 0.01) {
//                    util->dbgSave(crpSBE, "crpS.tif", 1);
//                    util->dbgSave(crpT, "crpT.tif", 1);
//                    result = util->tmplateMatch(crpSBE, crpT, match_thresh, 1);
//                    if (!result.isMatch) {
//                         getContours(diffS, diffT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                         diffprocess(diff_result, diff_cnt);
//                         isNG = true;
//                         continue;
//                    }
//               }
//
//               /*if (!checkShade(crpSBE, crpTBE, theMaskS, theMaskT)) {
//                    std::cout << "濃度が違う" << std::endl;
//                    getContours(maskedS, maskedT, cropRect, diff_cnt, extCropSize, 1/VIEW_SCALE);
//                    diffprocess(diff_result, diff_cnt);
//                    isNG = true;
//                    continue;
//               }*/
//          }
//
//          if (isNG) return;
          
          
          
          
          
          
          
          
          
          
          
          
          
//          roiS = getContourRect(maskedS, cv::Rect());
//          roiT = getContourRect(maskedT, cv::Rect());
//          cv::Rect mergeRect = roiS | roiT;
//          if ((mergeRect.width * 1.6 <= mergeRect.height) || (mergeRect.height * 1.6 <= mergeRect.width)) {
//               // 部品別に分割
//               std::vector<cv::Rect> rowS = getRowRects(maskedS);
//               std::vector<cv::Rect> colS = getColRects(maskedS);
//               std::vector<cv::Rect> rowT = getRowRects(maskedT);
//               std::vector<cv::Rect> colT = getColRects(maskedT);
//               if (((rowS.size() != 1) || (colS.size() != 1)) &&
//                   ((rowT.size() != 1) || (colT.size() != 1)) ) {
//                    std::cout << "要分割" << std::endl;
//                    if (rowS.size() != rowT.size()) {
//                         std::cout << "行数違う" << std::endl;
//                    }
//                    if (colS.size() != colT.size()) {
//                         std::cout << "列数違う" << std::endl;
//                    }
//                    auto spS = splitComponent(maskedS);
//                    auto spT = splitComponent(maskedT);
//               }
//          }
          
          
          
          
          
          // matchTemplate前に判断
//          if ((cropRect.width > 500 || cropRect.height > 500)) {
//               std::cout << "差分領域がでかい" << std::endl;
//               getContours(crpS, crpT, cropRect.tl(), diff_cnt);
//               diffprocess(diff_result, diff_cnt);
//               return;
//          }
//          else {
//               removeSame(maskedS, maskedT);
//          }
//          util->dbgSave(maskedS, "maskedS.tif", 3);
//          util->dbgSave(maskedT, "maskedT.tif", 3);
//
//          absArea = abs(cv::countNonZero(maskedS) - cv::countNonZero(maskedT));
//          if (absArea > 200) {
//               std::cout << "dbg" << std::endl;
//          }
        // S と Tの 共通部分を削除
//        int retState = eraseSamePos(binS, binT, binSE, binTE, maskedS, maskedT);
//
//        if (retState == 1) {
//            // 両者が明らかに違う場合
//                getContours(crpS, crpT, cropRect.tl(), diff_cnt);
//                diffprocess(diff_result, diff_cnt);
//                return;
//        }
//        if (retState == 2) {
//            // ほぼ同じ画像
//            return;
//        }
//        cv::Mat test, test_e, test_m;
//        cv::bitwise_xor(maskedS, maskedT, test);
//        util->dbgSave(maskedS, "0_mS.tif", false);
//        util->dbgSave(maskedT, "0_mT.tif", false);
//        util->dbgSave(test, "0_test.tif", false);
//
//        int absWhiteArea = abs(cv::countNonZero(maskedS) - cv::countNonZero(maskedT));
//        if (absWhiteArea > 200) {
//            std::cout << "マスク画像差分" << std::endl;
//        }
//        double poc_result = 0;
//        cv::Point2d shift_org = getPOCPos(maskedS, maskedT, &poc_result);;
//
//        cv::Mat diffS(maskedS.rows, maskedS.cols, CV_8UC1, cv::Scalar(255));
//        cv::Mat diffT(maskedS.rows, maskedS.cols, CV_8UC1, cv::Scalar(255));
//        crpSBE.copyTo(diffS, maskedS);
//        crpTBE.copyTo(diffT, maskedT);
//        // 片方の余白を削除
//        cv::findContours(maskedT, diff_cnt, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
//
//        if (diff_cnt.size() == 0) {
//            getContours(crpS, crpT, cropRect.tl(), diff_cnt);
//            diffprocess(diff_result, diff_cnt);
//            return;
//        }
//
//        cv::Rect hanmen;
//        for (auto it = diff_cnt.begin(); it != diff_cnt.end(); it++) {
//            cv::Rect theRect = cv::boundingRect(*it);
//            hanmen |= theRect;
//        }
//        diff_cnt.clear();
//        cv::Mat tmplate;
//        util->cropSafe(diffT, tmplate, hanmen, false);
//        util->dbgSave(diffS, "1_rS.tif", false);
//        util->dbgSave(tmplate, "1_rT.tif", false);
//
//
//        result = util->tmplateMatch(diffS, tmplate, match_thresh, 1);
//        if (!result.isMatch) {
//
//            if (result.val < 0.93) {
//                std::cout << "微妙に違う" << std::endl;
//                getContours(crpS, crpT, cropRect.tl(), diff_cnt);
//                diffprocess(diff_result, diff_cnt);
//                return;
//            }
//
//            cv::Mat diffSbin, tempBin;
//            cv::threshold(diffS, diffSbin, thresh_bin, 255, cv::THRESH_BINARY_INV);
//            cv::threshold(tmplate, tempBin, thresh_bin, 255, cv::THRESH_BINARY_INV);
//
//            cv::findContours(diffSbin, diff_cnt, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
//            cv::Rect hanmen_S;
//            for (auto it = diff_cnt.begin(); it != diff_cnt.end(); it++) {
//                cv::Rect theRect = cv::boundingRect(*it);
//                hanmen_S |= theRect;
//            }
//            diff_cnt.clear();
//            cv::Mat roi = diffSbin(hanmen_S);
//            double similarity = cv::matchShapes(tempBin, roi, cv::CONTOURS_MATCH_I1, 0);    // huモーメントによるマッチング
//            if (similarity > 0.01) {
//                std::cout << "形が違う" << std::endl;
//                getContours(crpS, crpT, cropRect.tl(), diff_cnt);
//                diffprocess(diff_result, diff_cnt);
//                return;
//            }
//            else {
//                if (!checkShade(crpSBE, crpTBE, maskedS, maskedT)) {
//                    getContours(crpS, crpT, cropRect.tl(), diff_cnt);
//                    diffprocess(diff_result, diff_cnt);
//                    return;
//                }
//                return;
//            }
//        }
//
//        if (result.val >= 0.96)
//            return;
//
//        if (poc_result >= 0.97) {
//            return;
//        }
//

    
    
   
        
        
    }
    else {

         CvUtil::MatchingResult result;
        result = util->tmplateMatch(crpSBE, crpTBE, match_thresh, 1);
        if (!result.isMatch) {
            cv::Mat dfImg;
            cv::Mat tmp1,tmp2;
            
            
            cv::subtract(crpS, crpT, tmp1);
            cv::subtract(crpT, crpS, tmp2);
            cv::bitwise_or(tmp1, tmp2, dfImg);
            std::vector<std::vector<cv::Point>> vcnt, rvcnt;
            cv::findContours(dfImg, vcnt, cv::RETR_TREE, cv::CHAIN_APPROX_NONE);
            for (int i = 0; i < vcnt.size(); ++i) {
                std::vector<cv::Point> it = vcnt.at(i);
                std::vector<cv::Point> ttt;
                for (auto jt = it.begin(); jt != it.end(); ++jt) {
                    cv::Point p = *jt;
                    p.x += cropRect.x;
                    p.y += cropRect.y;
                    ttt.push_back(p);
                }
                rvcnt.push_back(ttt);
            }
            diffprocess(diff_result, rvcnt);
        }
         
         return;
    }
//
//    return;
}


#pragma mark -
#pragma mark Public Methods

//void DiffImgCore::rect_clustering(std::vector<cv::Rect> bounds, std::vector<cv::Rect>& out_bounds, double threshold)
//{
//     std::vector<dlib::sample_pair> edges;
//     std::vector<dlib::sample_pair> initial_centers;
//     for (auto it = bounds.begin(); it != bounds.end(); ++it) {
//          cv::Point2d center = (it->br() + it->tl()) * 0.5;
//          edges.push_back(dlib::sample_pair(center.x, center.y, 1));
//     }
//     
//     typedef dlib::radial_basis_kernel<dlib::sample_pair> kernel_type;
//     dlib::kcentroid<kernel_type> kc(kernel_type(0.1),0.01, 8);
//     dlib::kkmeans<kernel_type> test(kc);
//     test.set_number_of_centers(1000);
//     dlib::pick_initial_centers(1000, initial_centers, edges, test.get_kernel());
//     test.train(edges,initial_centers);
//     cout << "num dictionary vectors for center 0: " << test.get_kcentroid(0).dictionary_size() << endl;
//     cout << "num dictionary vectors for center 1: " << test.get_kcentroid(1).dictionary_size() << endl;
//     cout << "num dictionary vectors for center 2: " << test.get_kcentroid(2).dictionary_size() << endl;
//     for (unsigned long i = 0; i < edges.size()/1000; ++i)
//     {
//          cout << test(samples[i]) << " ";
//          cout << test(samples[i+num]) << " ";
//          cout << test(samples[i+2*num]) << "\n";
//     }
//     unsigned long num_clusters = chinese_whispers(edges, labels, 200, rnd);
//     
//     std::vector<int> labelsTable;
//     
//     cv::partition(bounds, labelsTable, [&](const cv::Rect& a, const cv::Rect& b){
//          double minDist = 9999999;
//          cv::Point2d aP[4], bP[4];
//          aP[0] = cv::Point2d(a.x,a.y);                   // tl
//          aP[1] = cv::Point2d(a.x+a.width,a.y);           // tr
//          aP[2] = cv::Point2d(a.x,a.y+a.height);          // bl
//          aP[3] = cv::Point2d(a.x+a.width,a.y+a.height);  // br
//          
//          bP[0] = cv::Point2d(b.x,b.y);
//          bP[1] = cv::Point2d(b.x+b.width,b.y);
//          bP[2] = cv::Point2d(b.x,b.y+b.height);
//          bP[3] = cv::Point2d(b.x+b.width,b.y+b.height);
//          
//          for (int i = 0; i < 4; i++) {
//               cv::Point2d curP = aP[i];
//               for (int j = 0; j < 4; j++) {
//                    minDist = std::min(minDist,sqrt(pow(curP.x-bP[j].x,2) + pow(curP.y-bP[j].y,2)));
//               }
//          }
//          
//          return minDist <= threshold;
//     });
//     
//     if (labelsTable.size() != 0) {
//          int C = *std::max_element(labelsTable.begin(), labelsTable.end());
//          
//          for (int i = 0; i <= C; i++){
//               out_bounds.push_back(cv::Rect(0,0,0,0));
//          }
//          
//          for (int i = 0; i < labelsTable.size(); i++) {
//               int label=labelsTable[i];
//               out_bounds.at(label) |= bounds.at(i);
//          }
//     }
//}

//NSData* DiffImgCore::getRawDataFromCV(cv::Mat img)
//{
//    Halide::Buffer<uint8_t> tmp;
//    tmp = Halide::Buffer<uint8_t>(img.ptr<uchar>(0), img.cols, img.rows, img.channels());
//    std::vector<uchar> buf;
//    CvUtil::convertHalide2Vector(tmp, buf);
//    
//    NSData *retData = [[NSData alloc] initWithBytes:buf.data() length:buf.size()];
//    
//    return retData;
//}
void DiffImgCore::drawDiffContours(cv::Mat& diffAdd, DiffResult res)
{
    if(!strcmp(setting.diffDispMode.c_str(), [NSLocalizedStringFromTable(@"DiffModeRect", @"Preference", nil) UTF8String])){
        writeContourMain(rectContour, diffAdd, res);
    }else if(!strcmp(setting.diffDispMode.c_str() ,[NSLocalizedStringFromTable(@"DiffModeArround", @"Preference", nil) UTF8String])){
        writeContourMain(writeContour, diffAdd, res);
    }
}

void DiffImgCore::resizeImage(cv::Mat src, cv::Mat& dst, double scale)
{
    util->resizeImage(src, dst, scale);
}

void DiffImgCore::cvtGrayIfColor(cv::Mat in, cv::Mat &out)
{
    util->cvtGrayIfColor(in, out);
}

std::vector<cv::Rect> DiffImgCore::getDiffRects(cv::Mat imgS, cv::Mat imgT, NSMutableDictionary** info, std::vector<cv::Rect> &illustAreas, std::vector<cv::Rect> &txtAreas)
{
     std::vector<cv::Rect> diff_rects;
     cv::Mat grayS,grayT,subMat;
     cv::Mat sikisa;
     util->cvtGrayIfColor(imgS, grayS);
     util->cvtGrayIfColor(imgT, grayT);
//     cv::subtract(grayS, grayT, subMat);
//     cv::threshold(subMat, sikisa, 0, 255, cv::THRESH_OTSU);
     makeShadeMask(grayS, grayT, cv::Mat(), cv::Mat(), 4.0, sikisa);

     if (sikisa.empty()) {
          [*info setObject:@[] forKey:@"addPos"];
          [*info setObject:@[] forKey:@"delPos"];
          [*info setObject:@[] forKey:@"diffPos"];
          return diff_rects;
     }
     
     // ノイズ除去
     if (setting.noizeReduction != 0) {
          for (int i = 0; i < setting.noizeReduction; i++) {
               util->deleteMinimumArea(sikisa, 1);
          }
     }
     // 周囲2px塗りつぶす
     cv::rectangle(sikisa, cv::Point(0,0), cv::Point(sikisa.cols, sikisa.rows), cv::Scalar(0), 2);
     std::vector<std::vector<cv::Point>> vctContours;
//     util->dbgSave(sikisa, "sikisa.tif", 0);
     if (illustAreas.size() != 0) {
          // イラストエリアの塗りつぶし
          // 消す部分を白にする
          cv::Mat maskIllust(grayS.size(), grayS.type(), cv::Scalar::all(0));
          
          for (auto it = illustAreas.begin(); it != illustAreas.end(); ++it) {
               cv::Rect rc = *it;
               extractRect(rc, 2, imgS);
               cv::rectangle(maskIllust, rc.tl(), rc.br(), cv::Scalar::all(255), cv::FILLED);
          }
          for (auto it = txtAreas.begin(); it != txtAreas.end(); ++it) {
               cv::Rect rc = *it;
               extractRect(rc, 2, imgS);
               cv::rectangle(maskIllust, rc.tl(), rc.br(), cv::Scalar::all(0), cv::FILLED);
          }
          // 差分のあるイラストエリア抽出
//          cv::Mat iLLustDiff(grayS.size(), grayS.type(), cv::Scalar::all(0));
//          for (int r = 0; r < sikisa.rows; r++) {
//               uchar* m = maskIllust.ptr<uchar>(r);
//               uchar* s = sikisa.ptr<uchar>(r);
//               uchar* i = iLLustDiff.ptr<uchar>(r);
//               for (int c = 0; c < sikisa.cols; c++) {
//                    if ((m[c] == 255) && (s[c] == 255)) {
//                         i[c] = 255;
//                    }
//               }
//          }
//          util->dbgSave(iLLustDiff, "iLLustDiff.tif", 0);
//
          // マスクの黒部分の差分を残す
          for (int r = 0; r < maskIllust.rows; r++) {
               uchar* m = maskIllust.ptr<uchar>(r);
               uchar* p = sikisa.ptr<uchar>(r);
               for (int c = 0; c < maskIllust.cols; c++) {
                    if (m[c] == 255) {
                         p[c] = 0;
                    }
               }
          }
//          util->dbgSave(sikisa, "sikisa.tif", 1);
          
          // イラストの差分エリア
//          std::vector<cv::Rect> tmpIll;
//          cv::findContours(iLLustDiff, vctContours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
//          std::vector<cv::Rect> ill_rects;
//          for (auto it = vctContours.begin(); it != vctContours.end(); ++it) {
//               cv::Rect rc = cv::boundingRect(*it);
//               ill_rects.push_back(rc);
//          }
//
//          for (auto it = illustAreas.begin(); it != illustAreas.end(); ++it) {
//               cv::Rect rc = *it;
//               cv::Rect imgDiff;
//               for (auto jt = ill_rects.begin(); jt != ill_rects.end(); ++jt) {
//                    if ((*jt & rc).area() > 0) {
//                         imgDiff |= *jt;
//                    }
//               }
//               if (imgDiff != cv::Rect())
//                    tmpIll.push_back(imgDiff);
//          }
//          illustAreas = std::vector<cv::Rect>(tmpIll);
          
//          // 色差からイラスト差分を消す
//          for (auto it = illustAreas.begin(); it != illustAreas.end(); ++it) {
//               cv::rectangle(sikisa, it->tl(), it->br(), cv::Scalar::all(0), cv::FILLED);
//          }
     }
     vctContours.clear();
     sikisa.copyTo(bitDiffImg);
     sikisa.copyTo(bitDiffImgL);
     util->dbgSave(sikisa, "bitDiffImg.tif", 0);

     cv::findContours(bitDiffImg, vctContours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);

     if (vctContours.size() == 0) {
         // 差分無しの時は何も保存しないで終わる
         [*info setObject:@[] forKey:@"addPos"];
         [*info setObject:@[] forKey:@"delPos"];
         [*info setObject:@[] forKey:@"diffPos"];
         return diff_rects;
     }
    
     std::vector<cv::Rect> dbs_rects;
     for (auto it = vctContours.begin(); it != vctContours.end(); ++it) {
          cv::Rect rc = cv::boundingRect(*it);
          dbs_rects.push_back(rc);
     }

     cout << "allDiffAreas: " << (int)dbs_rects.size() << endl;

//    if (dbs_rects.size() >= 12000)
//         return dbs_rects;

//    util->rect_clustering(dbs_rects, diff_rects, 4);

    return dbs_rects;
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

NSData* DiffImgCore::encodeMatToData(cv::Mat img, const cv::String type)
{
    std::vector<uchar> buf;
    cv::Mat diffColor;
    if (!setting.isSaveColor) {
        util->cvtGrayIfColor(img, diffColor);
    }
    else {
        img.copyTo(diffColor);
    }
//    cv::imwrite("/tmp/test.png", diffColor);
    cv::imencode(type, diffColor, buf);
    NSData *retData = [[NSData alloc] initWithBytes:buf.data() length:buf.size()];
    
    return retData;
}

void DiffImgCore::convertBlueRedImg(cv::Mat& imgBlue, cv::Mat& imgRed)
{
    if (!strcmp(setting.aoAkaMode.c_str(), [NSLocalizedStringFromTable(@"AoAkaModeRB", @"Preference", nil) UTF8String])) {
        util->conv2Blue(imgBlue);
        util->conv2Red(imgRed);
    }
    else if (!strcmp(setting.aoAkaMode.c_str(), [NSLocalizedStringFromTable(@"AoAkaModeCM", @"Preference", nil) UTF8String])) {
        util->conv2Cyan(imgBlue);
        util->conv2Magenta(imgRed);
    }
}

bool DiffImgCore::adjustSize(cv::Mat& src, cv::Mat& dst, int mode)
{
    bool ret = false;
    if (mode == 0) // POC
        ret = util->adjustSize(src, dst, cv::Scalar::all(255), CvUtil::ADJUST_POC);
    else if (mode == 1) // FEATURE
        ret = util->adjustSize(src, dst, cv::Scalar::all(255), CvUtil::ADJUST_FEATURE);
    
    return ret;
}

cv::Mat DiffImgCore::openImg(NSData* img)
{
    cv::Mat deced;
    size_t size = img.length;
    std::vector<uint8_t> buff((uint8_t*)img.bytes, (uint8_t*)img.bytes + size);
    
    if (!setting.isSaveColor) {
        deced = cv::imdecode(cv::Mat(buff), cv::IMREAD_GRAYSCALE);
    }
    else {
        deced = cv::imdecode(cv::Mat(buff), cv::IMREAD_COLOR);
    }

    if (deced.empty()) {
//        [img writeToFile:@"/tmp/ng_img.tif" atomically:YES];
        return deced;
    }
    return deced;
}

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
                    else if(!strcmp(key,"matchThresh")){
                        setting.matchThresh = (float)json_integer_value(value);
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
                    else if(!strcmp(key,"adjustMode")){
                        setting.adjustMode = (int)json_integer_value(value);
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
                    else if (!strcmp(key,"isForceResize")){
                        setting.isForceResize = true;
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
                    else if (!strcmp(key,"isForceResize")){
                        setting.isForceResize = false;
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
    //util->dbgSave(cntImg, "cntImg.tif", false);
}


