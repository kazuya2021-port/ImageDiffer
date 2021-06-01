//
//  CvUtil.cpp
//  DiffImgCV
//
//  Created by 内山和也 on 2019/04/16.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#include "CvUtil.hpp"

using namespace std;
//using namespace Halide;

CvUtil::CvUtil(){
}

CvUtil::~CvUtil(){
}

//#ifndef DEBUG

void CvUtil::dbgInfo(const cv::Mat& mat)
{
    using namespace std;
    
    // 高さと幅
    cout << "size(w x h): " << mat.cols << " x " << mat.rows << endl;
    
    // 要素の型とチャンネル数の組み合わせ。
    cout << "type: " << (
                         mat.type() == CV_8UC1 ? "CV_8UC1" :
                         mat.type() == CV_8UC2 ? "CV_8UC2" :
                         mat.type() == CV_8UC3 ? "CV_8UC3" :
                         mat.type() == CV_8UC4 ? "CV_8UC4" :
                         mat.type() == CV_16SC1 ? "CV_16SC1" :
                         mat.type() == CV_64FC2 ? "CV_64FC2" :
                         "other"
                         ) << endl;
    
    // 要素の型
    cout << "depth: " << (
                          mat.depth() == CV_8U ? "CV_8U" :
                          mat.depth() == CV_16S ? "CV_16S" :
                          mat.depth() == CV_64F ? "CV_64F" :
                          "other"
                          ) << endl;
    
    // チャンネル数
    cout << "channels: " << mat.channels() << endl;
    
    // バイト列が連続しているか
    cout << "continuous: " <<
    (mat.isContinuous() ? "true" : "false")<< endl;
    
    cout << "------------------------" << endl;
}

// 画像を表示
void CvUtil::dbgShow(cv::Mat img, string window_title, bool isDestroiWindow){
    imshow(window_title, img);
    while (cv::waitKey(1) == -1);
    if(isDestroiWindow)
        cv::destroyWindow(window_title);
}

// 文字を付加して保存
void CvUtil::dbgSave(cv::Mat img, std::string file_name, std::string header)
{
    if(img.empty()) return;
    std::string sp = DBG_SAVE_PATH + header + "_" + file_name;
    cv::imwrite(sp, img);
}
// 画像保存
/*void CvUtil::dbgSave(cv::Mat img, string file_name, bool iscmyk)
{
    string sp = DBG_SAVE_PATH + file_name;
    if(img.empty()) return;
    if(iscmyk){
        cmyk2rgb(img);
    }
    cv::imwrite(sp, img);
}*/

// 数字を付加して保存
void CvUtil::dbgSave(cv::Mat img, std::string file_name, int num)
{
    if(img.empty()) return;
    std::string numStr = std::to_string(num);
    std::string sp = DBG_SAVE_PATH + numStr + "_" + file_name;
    cv::imwrite(sp, img);
}



void CvUtil::dbgRemove(std::string file_name, int num){
    std::string numStr = std::to_string(num);
    std::string sp = DBG_SAVE_PATH + numStr + "_" + file_name;
    remove(sp.c_str());
}
/*
#else

void CvUtil::print_info(const cv::Mat& mat){
}

// 画像を表示
void CvUtil::dbgShow(cv::Mat img, string window_title, bool isDestroiWindow){
}

// 画像保存
void CvUtil::dbgSave(cv::Mat img, string file_name, bool iscmyk){
}
void CvUtil::dbgSave(cv::Mat img, std::string file_name, int num){
}
#endif
*/

#pragma mark -
#pragma mark Construct/Destruct

CvUtil::FoundImage::FoundImage(){
}
CvUtil::LabelItem::LabelItem() {
}
CvUtil::RotateInfo::RotateInfo(){
}

CvUtil::LabelItem::LabelItem(const cv::Rect rect, const cv::Point2f p, double area) {
    this->rect = rect;
    this->center = p;
    this->area = area;
}
CvUtil::MatchingResult::MatchingResult(){
}

#pragma mark -
#pragma mark Public Methods
void CvUtil::rect_clustering(std::vector<cv::Rect> bounds, std::vector<cv::Rect>& out_bounds, double threshold)
{
    std::vector<int> labelsTable;
    
    {
        cv::partition(bounds, labelsTable, [&](const cv::Rect& a, const cv::Rect& b){
            double minDist = 9999999;
            cv::Point2d aP[4], bP[4];
            aP[0] = cv::Point2d(a.x,a.y);                   // tl
            aP[1] = cv::Point2d(a.x+a.width,a.y);           // tr
            aP[2] = cv::Point2d(a.x,a.y+a.height);          // bl
            aP[3] = cv::Point2d(a.x+a.width,a.y+a.height);  // br
            
            bP[0] = cv::Point2d(b.x,b.y);
            bP[1] = cv::Point2d(b.x+b.width,b.y);
            bP[2] = cv::Point2d(b.x,b.y+b.height);
            bP[3] = cv::Point2d(b.x+b.width,b.y+b.height);
            
#pragma omp parallel for
            for (int i = 0; i < 4; i++) {
                cv::Point2d curP = aP[i];
                for (int j = 0; j < 4; j++) {
                    minDist = std::min(minDist,sqrt(pow(curP.x-bP[j].x,2) + pow(curP.y-bP[j].y,2)));
                }
            }
            
            return minDist <= threshold;
        });
    }
    
    if (labelsTable.size() != 0) {
        int C = *std::max_element(labelsTable.begin(), labelsTable.end());
        
        for (int i = 0; i <= C; i++){
            out_bounds.push_back(cv::Rect(0,0,0,0));
        }
        
        for (int i = 0; i < labelsTable.size(); i++) {
            int label=labelsTable[i];
            out_bounds.at(label) |= bounds.at(i);
        }
    }
}

bool DoesRectangleContainPoint(cv::RotatedRect rectangle, cv::Point2f point){
    //Get the corner points.
    cv::Point2f corners[4];
    rectangle.points(corners);
    
    //Convert the point array to a vector.
    cv::Point2f* lastItemPointer = (corners + sizeof corners / sizeof corners[0]);
    vector<cv::Point2f> contour(corners, lastItemPointer);
    
    //Check if the point is within the rectangle.
    double indicator = cv::pointPolygonTest(contour, point, false);
    bool rectangleContainsPoint = (indicator >= 0);
    return rectangleContainsPoint;
}

void CvUtil::moveSafe(cv::Mat in, cv::Mat& out, cv::Point2d movePoint, cv::Scalar bgColor){
    
    //CV_Assert(in.channels() == 1);
    
    cv::Mat mat = (cv::Mat_<double>(2,3)<<1.0, 0.0, movePoint.x, 0.0, 1.0, movePoint.y);
    cv::warpAffine(in, out, mat, in.size(), cv::INTER_CUBIC, cv::BORDER_TRANSPARENT, bgColor);
    
}

void CvUtil::resizeImage(cv::Mat src, cv::Mat& dst, double scale)
{
    if(src.empty()) return;
    cv::Mat dst_img((int)(scale*src.rows),(int)(scale*src.cols), src.type());
    if (scale != 1.0f) {
        cv::InterpolationFlags flg = cv::INTER_LINEAR_EXACT;
        if (scale < 1.0) {
            flg = cv::INTER_AREA;
        }
        cv::resize(src, dst_img, cv::Size(scale*src.cols, scale*src.rows), flg);
    }
    dst_img.copyTo(dst);
}

// 画像の分割アルゴリズム
void CvUtil::divide(cv::Mat base, vector<cv::Mat> & chars, vector<cv::Mat>& masks, vector<cv::Rect>& rects) {
    
    cv::Mat bw,gray,labelImg;
    
    cvtGrayIfColor(base, gray);
    
    cv::threshold(gray, bw, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
    
    
    auto nLab = getLabel(bw, labelImg);
    
    for(int i = 0; i < nLab.size(); i++){
        cv::Mat cntImg(gray.rows, gray.cols, gray.type(), cv::Scalar::all(255));
        cv::Mat mask(gray.rows, gray.cols, gray.type(), cv::Scalar(0));
        for(int r = 0; r < labelImg.rows; r++){
            int* label = labelImg.ptr<int>(r);
            uchar* retPtr = cntImg.ptr<uchar>(r);
            uchar* srcPtr = gray.ptr<uchar>(r);
            uchar* maskPtr = mask.ptr<uchar>(r);
            
            for(int c = 0; c < labelImg.cols; c++){
                if(label[c] == i+1){
                    retPtr[c] = srcPtr[c];
                    maskPtr[c] = 255;
                }
            }
        }
        chars.push_back(cntImg);
        vector<vector<cv::Point>> c;
        cv::findContours(mask, c, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
        cv::drawContours(mask, c, -1, cv::Scalar::all(255), cv::FILLED);
        masks.push_back(mask);
        rects.push_back(nLab.at(i).rect);
    }
    /*
     for(int i = 0; i < nLab.size(); i++){
     cv::Mat empt = cv::Mat(base.rows, base.cols, base.type(), cv::Scalar::all(255));
     cv::Mat labelArea = cv::Mat(gray,nLab.at(i).rect);
     chars.push_back(labelArea);
     }
     */
    return;
}

cv::Point CvUtil::minPoint(std::vector<cv::Point> contours){
    // 原点に近い点を抽出
    cv::Point minDis;
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
cv::Point CvUtil::maxPoint(std::vector<cv::Point> contours){
    // 距離が遠いモノを抽出
    cv::Point maxDis;
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

cv::Rect CvUtil::cropSafe(cv::Mat in, cv::Mat& out, cv::Rect cropSize, bool isFill){
    int fillx = 0;
    int filly = 0;
    int fillw = 0;
    int fillh = 0;
    int result_width, result_height;
    int result_x, result_y;

    cv::Rect ret;
    
    result_x = cropSize.tl().x;
    result_y = cropSize.tl().y;
    result_width = cropSize.width;
    result_height = cropSize.height;
    
    if (result_x < 0){
        if(isFill){
            fillx = abs(result_x);
            result_width+=fillx;
        }
        result_x = 0;
    }
    if (result_y < 0){
        if(isFill){
            filly = abs(result_y);
            result_height+=filly;
        }
        result_y = 0;
    }
    if((result_y + result_height) > in.rows){
        if(isFill){
            fillh = abs(in.rows - (result_y + result_height));
            if(filly == 0){
                filly = fillh;
            }
        }else{
            result_height = (in.rows - result_y);
        }
        
    }
    if((result_x + result_width) > in.cols){
        if(isFill){
            fillw = abs(in.cols - (result_x + result_width));
            if(fillx == 0){
                fillx = fillw;
            }
        }else{
            result_width = (in.cols - result_x);
        }
    }
    if(isFill){
        cv::Mat makeIn;
        in.copyTo(makeIn);
        if(fillx != 0 || filly != 0){
            translateImageExt(makeIn, fillx, filly, true);
        }
        ret = cv::Rect(result_x, result_y, result_width, result_height);
        out = cv::Mat(makeIn, ret);
    }
    else{
        ret = cv::Rect(result_x, result_y, result_width, result_height);
        out = cv::Mat(in, ret);
    }
    
    return ret;
}

void CvUtil::cvtBGR(cv::Mat in, cv::Mat &out){
    if(checkImg(in)){
        if(in.channels() == 3){
            out = in;
        }
        else if (in.channels() == 4){
            CvUtil::cmyk2rgb(in);
            out = in;
        }
        else if (in.channels() == 1){
            try{
                cvtColor(in, out, cv::COLOR_GRAY2BGR);
            }catch(const std::exception e){
                std::cout << "error: invalid color mode!" << std::endl;
                return;
            }
        }
        else{
            std::cout << "error: invalid channels!" << std::endl;
            return;
        }
    }
}

void CvUtil::cvtGrayIfColor(cv::Mat in, cv::Mat &out) {
    if(checkImg(in)){
        if(in.channels() == 3){
            try{
                cvtColor(in, out, cv::COLOR_BGR2GRAY);
            }catch(const std::exception e){
                std::cout << "error: invalid color mode!" << std::endl;
                return;
            }
        }
        else if (in.channels() == 4){
            CvUtil::cmyk2rgb(in);
            cv::cvtColor(in, out, cv::COLOR_BGR2GRAY);
        }
        else if (in.channels() == 1){
            out = in;
        }
        else{
            std::cout << "error: invalid channels!" << std::endl;
            return;
        }
    }
}

void CvUtil::conv2Blue(cv::Mat& img){
    cvtGrayIfColor(img, img);
    cv::Mat invImg;
    cv::bitwise_not(img, invImg);
    vector<cv::Mat> rgb;
    for(int i = 0; i < 3; i++){
        rgb.push_back(cv::Mat(img.rows, img.cols, img.type(), cv::Scalar(0)));
    }
    rgb.at(0) = invImg;
    
    cv::Mat colorImage;
    cv::merge(rgb, colorImage);
    
    cv::cvtColor(img, img, cv::COLOR_GRAY2BGR);
    cv::add(colorImage, img, img);
}

void CvUtil::conv2Red(cv::Mat& img){
    cvtGrayIfColor(img, img);
    cv::Mat invImg;
    cv::bitwise_not(img, invImg);
    vector<cv::Mat> rgb;
    for(int i = 0; i < 3; i++){
        rgb.push_back(cv::Mat(img.rows, img.cols, img.type(), cv::Scalar(0)));
    }
    rgb.at(2) = invImg;
    
    cv::Mat colorImage;
    cv::merge(rgb, colorImage);
    
    cv::cvtColor(img, img, cv::COLOR_GRAY2BGR);
    cv::add(colorImage, img, img);
}

void CvUtil::conv2Cyan(cv::Mat& img){
    cvtGrayIfColor(img, img);
    cv::bitwise_not(img, img);
    
    vector<cv::Mat> ymck;
    for (int i = 0; i < 4; i++) {
        ymck.push_back(cv::Mat::zeros(img.size(), CV_8UC1));
    }
    ymck[2] = img;
    cv::Mat cmykImg;
    cv::merge(ymck, cmykImg);
    cmyk2rgb(cmykImg);
    img = cmykImg.clone();
}

void CvUtil::conv2Magenta(cv::Mat& img){
    cvtGrayIfColor(img, img);
    cv::bitwise_not(img, img);
    
    vector<cv::Mat> ymck;
    for (int i = 0; i < 4; i++) {
        ymck.push_back(cv::Mat::zeros(img.size(), CV_8UC1));
    }
    ymck[1] = img;
    cv::Mat cmykImg;
    cv::merge(ymck, cmykImg);
    cmyk2rgb(cmykImg);
    img = cmykImg.clone();
}

// コンターから四角を取得
cv::Rect CvUtil::getRect(std::vector<cv::Point> cnt){
    cv::RotatedRect rt = cv::minAreaRect(cnt);
    return rt.boundingRect();
}

// イメージの2値化
void CvUtil::binalize(cv::Mat src, cv::Mat& out, bool inv){
    cv::Mat src_tmp;
    cvtGrayIfColor(src, src_tmp);
    if(inv)
        threshold(src_tmp,out, 128, 255, cv::THRESH_BINARY_INV); // THRESH_OTSU = 8; THRESH_TRIANGLE = 16;
    else
        threshold(src_tmp,out, 128, 255, cv::THRESH_BINARY); // THRESH_OTSU = 8; THRESH_TRIANGLE = 16;
}

// 差の絶対値
void CvUtil::absDiffImg(cv::Mat src, cv::Mat targ, cv::Mat& out, bool isMorphology, bool isGray){
    cv::Mat S2, T2;
    cv::Mat matDiff;
    
    if(isGray){
        cv::Mat tmp1,tmp2;
        cvtGrayIfColor(src, S2);
        cvtGrayIfColor(targ, T2);
        
        cv::subtract(S2, T2, tmp1);
        cv::subtract(T2, S2, tmp2);
        cv::bitwise_or(tmp1, tmp2, out);
    }
    else{
        binalize(src, S2, false);
        binalize(targ, T2, false);
        
        
        cv::absdiff(S2, T2, matDiff);
        
        if(isMorphology){
            cv::morphologyEx(matDiff, out, cv::MORPH_CLOSE, cv::Mat());
        }else{
            out = matDiff;
        }
    }
    
}

// 狭小領域の削除(入力画像は2値データ)
void CvUtil::deleteMinimumArea(cv::Mat& img, int strong){
    cv::Mat img_tmp, labels;
    
    vector<vector<cv::Point>> contours;

    cv::findContours(img, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
    int width_start = 0;
    int width_end = strong;
    int height_start = 0;
    int height_end = strong;
    int max_area = 40 * strong;
    
    for(int i = 0; i < contours.size(); ++i){
        auto rc = cv::boundingRect(contours.at(i));
        if((rc.width <= width_end) && (rc.height <= height_end)) {
            float area = cv::contourArea(contours.at(i));
            if (area <= max_area) {
                cv::drawContours(img, contours, i, cv::Scalar::all(0), cv::FILLED);
            }
        }
    }
}

// 2値画像から差分文字の切り出し
void CvUtil::scanCharactors(cv::Mat upImg, vector<cv::Rect>& position){
    bool isTate;
    cv::Mat croppedImg;
    cv::Mat binImg;
    //vector<cv::Mat> targetChar;
    vector<cv::Range> colRange;
    vector<cv::Range> rowRange;
    
    colRange.clear();
    rowRange.clear();
    
    //dbgSave(upImg, "upImg.tif", false);
    
    // 出力画像
    cv::Mat result;
    cv::Mat grayS,grayT;
    
    cvtGrayIfColor(upImg, grayS);
    
    cv::threshold(grayS, binImg, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
    
    // 余分な空白削除
    cv::Rect crop = getNotWhiteSpace(grayS);
    
    croppedImg = cv::Mat(grayS,crop);
    //dbgSave(croppedImg, "croppedImg.tif", false);
    
    int gcdSize = Gcd(crop.width, crop.height);
    int aspectX = (crop.width / gcdSize);
    int aspectY = (crop.height / gcdSize);
    if(aspectX * 2 <= aspectY){
        isTate = true;
    }
    else if (aspectY * 2 <= aspectX){
        isTate = false;
    }
    else{
        cv::Mat src;
        getInteglal(binImg, src);
        colRange = searchColumns(src); // 白領域を抽出
        rowRange = searchRows(src); // 白領域を抽出
        
        // 縦横判別
        float total = 0;
        float aveColSpace, aveRowSpace;
        
        if(colRange.size() == 0){
            aveColSpace = 0;
        }else{
            for(int i = 0; i < colRange.size(); i++){
                total += abs(colRange.at(i).end - colRange.at(i).start);
            }
            aveColSpace = total / colRange.size();
            total = 0;
        }
        
        if(rowRange.size() == 0){
            aveRowSpace = 0;
        }else{
            for(int i = 0; i < rowRange.size(); i++){
                total += abs(rowRange.at(i).end - rowRange.at(i).start);
            }
            aveRowSpace = total / rowRange.size();
        }
        
        
        if(aveColSpace < aveRowSpace) isTate = false;
        else isTate = true;
    }
    
    
    
#ifdef DEBUG
    if(isTate){
        //cout << "縦書き" << endl;
    }else{
        //cout << "横書き" << endl;
    }
#endif
    
    binImg = cv::Mat(binImg,crop);
    
    vector<cv::Mat> gyou;
    vector<cv::Rect> gyouPos;
    splitGyou(croppedImg, binImg, isTate, gyouPos, gyou);
    //std::cout << "gyou.size() = " << gyou.size() << std::endl;
    for(int i = 0; i < gyou.size(); i++){
        vector<cv::Rect> mojiPos;
        vector<cv::Mat> retsu;
        splitChar(gyou.at(i), cv::Mat(binImg,gyouPos.at(i)), isTate, mojiPos, retsu);
        //std::cout << "retsu.size() = " << retsu.size() << std::endl;
        //dbgSave(gyou.at(i), "gyou.tif", false);
        for(int j = 0; j < retsu.size(); j++){
            cv::Point topLeft,bottomRight;
            if(isTate){
                // 切り抜き分を加える
                topLeft = cv::Point(gyouPos.at(i).tl().x + crop.tl().x,
                                    mojiPos.at(j).tl().y + crop.tl().y);
                bottomRight = cv::Point(topLeft.x + gyouPos.at(i).width,
                                        topLeft.y + mojiPos.at(j).height);
            }else{
                // 切り抜き分を加える
                topLeft = cv::Point(mojiPos.at(j).tl().x + crop.tl().x,
                                    gyouPos.at(i).tl().y + crop.tl().y);
                bottomRight = cv::Point(topLeft.x + mojiPos.at(j).width,
                                        topLeft.y + gyouPos.at(i).height);
            }
            cv::Rect theMojiPos(topLeft,bottomRight);
            
            position.push_back(theMojiPos);
        }
        mojiPos.clear();
    }
    
    if(position.size() == 0){
        return;
    }//else{
    //for(int i = 0; i < position.size(); i++){
    /*ostringstream ss;
     ss << i;
     string savename = "char(" + ss.str() + ").tif";
     dbgSave(cv::Mat(upImg,position.at(i)), savename, false);*/
    //targetChar.push_back(cv::Mat(upImg,position.at(i)));
    //}
    //}
    return;
}

// 2値画像のラベリング
vector<CvUtil::LabelItem> CvUtil::getLabel(cv::Mat img, cv::Mat& labelImg, bool isGetRRect){
    
    vector<CvUtil::LabelItem> items;
    cv::Mat stats;
    cv::Mat centroids;
    vector<cv::Mat> labels;
    int nLab = cv::connectedComponentsWithStats(img, labelImg, stats, centroids, 8, CV_32S);
    for(int i = 1; i < nLab; ++i){
        int *param = stats.ptr<int>(i);
        int x = param[cv::ConnectedComponentsTypes::CC_STAT_LEFT];
        int y = param[cv::ConnectedComponentsTypes::CC_STAT_TOP];
        int w = param[cv::ConnectedComponentsTypes::CC_STAT_WIDTH];
        int h = param[cv::ConnectedComponentsTypes::CC_STAT_HEIGHT];
        int a = param[cv::ConnectedComponentsTypes::CC_STAT_AREA];
        cv::Rect rc(x,y,w,h);
        cv::Point2f c = (rc.tl()+rc.br())*0.5;
        CvUtil::LabelItem li(rc,c,a);
        items.push_back(li);
        if(isGetRRect){
            cv::Mat blackImg = cv::Mat::zeros(img.rows, img.cols, CV_8UC1);
            labels.push_back(blackImg);
        }
    }
    
    if(isGetRRect){
        for(int r = 0; r < labelImg.rows; r++){
            uchar* labelp = labelImg.ptr<uchar>(r);
            for(int c = 0; c < labelImg.cols; c++){
                if(labelp[c] != 0){
                    labels.at(labelp[c] - 1).at<uchar>(r,c) = 255;
                }
            }
        }
        vector<vector<cv::Point>> vctContours;
        for(int i = 1; i < nLab; ++i){
            cv::findContours(labels.at(i), vctContours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
            items.at(i).rect_r = cv::minAreaRect(vctContours);
        }
    }
    
    return items;
}

// 領域を拡張して切り出す
void CvUtil::cropExtra(cv::Mat in, cv::Mat& out, cv::Rect cropSize, int aroundSize){
    int result_width, result_height;
    int result_x, result_y;
    result_x = cropSize.tl().x - aroundSize;
    result_y = cropSize.tl().y - aroundSize;
    result_width = cropSize.width + ( aroundSize * 2 );
    result_height = cropSize.height + ( aroundSize * 2 );
    
    if (result_x < 0){
        result_x = 0;
    }
    if (result_y < 0){
        result_y = 0;
    }
    if((result_x + result_width) > in.cols){
        result_width = (in.cols - result_x);
    }else if((result_x + result_width) < in.cols){
        
    }
    if((result_y + result_height) > in.rows){
        result_height = (in.rows - result_y);
    }
    out = cv::Mat(in, cv::Rect(result_x, result_y, result_width, result_height));
}

// 空白以外のエリアを取得
cv::Rect CvUtil::getNotWhiteSpace(cv::Mat in){
    cv::Mat ret,binImg,tmp;
    tmp = in.clone();
    vector<vector<cv::Point>> vctContours;
    vector<int> x1,y1,x2,y2;
    cvtGrayIfColor(tmp, binImg);
    cv::threshold(binImg, binImg, 0, 255, cv::THRESH_OTSU | cv::THRESH_BINARY_INV);
    cv::findContours(binImg, vctContours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_NONE);
    
    for(int i = 0; i < vctContours.size(); i++){
        cv::Rect bound = cv::boundingRect(vctContours.at(i));
        x1.push_back(bound.tl().x);
        y1.push_back(bound.tl().y);
        x2.push_back(bound.br().x);
        y2.push_back(bound.br().y);
    }
    if(x1.size() == 0 || y1.size() == 0 ||
       x2.size() == 0 || y2.size() == 0){
        return cv::Rect(0,0,0,0);
    }
    else{
        cv::Rect crop(cv::Point(*min_element(x1.begin(), x1.end()), *min_element(y1.begin(), y1.end())),
                      cv::Point(*max_element(x2.begin(), x2.end()), *max_element(y2.begin(), y2.end())));
        return crop;
    }
}

CvUtil::FoundImage CvUtil::searchNearImg(vector<LabelItem> labels,
                                         cv::Mat labelImg,          // 元画像のラベルイメージ
                                         cv::Mat input,             // 元画像
                                         cv::Mat search             // 検索するContour
)
{
    FoundImage ret;
    ret.area = 0;
    if(1 > labels.size()) return ret;
    if(search.rows != labelImg.rows && search.cols != labelImg.cols) return ret;
    
    //cv::Mat retImg(labelImg.rows, labelImg.cols, CV_8UC1, cv::Scalar(255));
    // 検査対象のContourにどのラベルがあるのか検索
    set<int> foundIdx{};;
    for(int r = 0; r < labelImg.rows; r++){
        int* label = labelImg.ptr<int>(r);
        uchar* s = search.ptr<uchar>(r);
        bool isTarget = false;
        for(int c = 0; c < labelImg.cols; c++){
            if(s[c] == 255) isTarget = true;
            else isTarget = false;
            
            if(isTarget){
                if(label[c] != 0){
                    foundIdx.insert(label[c]);
                }
            }
        }
    }
    if(foundIdx.empty()){
        return ret;
    }
    
    ret.isFound = true;
    cv::Rect rcArea;
    for(auto i = foundIdx.begin(); i != foundIdx.end(); i++){
        rcArea = rcArea | labels.at(*i-1).rect;
    }
    for(auto i = foundIdx.begin(); i != foundIdx.end(); i++){
        //cout << "found label:" << *i << endl;
        for(int r = 0; r < labelImg.rows; r++){
            int* label = labelImg.ptr<int>(r);
            //uchar* retPtr = retImg.ptr<uchar>(r);
            //uchar* inPtr = input.ptr<uchar>(r);
            for(int c = 0; c < labelImg.cols; c++){
                if(label[c] == *i){
                    ret.area++;
                    //retPtr[c] = inPtr[c];
                }
            }
        }
    }
    ret.rect = rcArea;
    ret.img = cv::Mat(input,rcArea);
    return ret;
    
}

// RGB to CMYK conversion
void CvUtil::rgb2cmyk(cv::Mat& img) {
    std::vector<cv::Mat> ymck;
    assert(img.type() == CV_8UC3 && "input image must be CV_8UC3");
    
    // Allocate cmyk to store 4 componets
    for (int i = 0; i < 4; i++) {
        ymck.push_back(cv::Mat(img.size(), CV_8UC1));
    }
    
    // Get rgb
    std::vector<cv::Mat> rgb;
    cv::split(img, rgb);
    
    // rgb to ymck
    for (int i = 0; i < img.rows; i++) {
        for (int j = 0; j < img.cols; j++) {
            float r = (int)rgb[2].at<uchar>(i,j) / 255.;
            float g = (int)rgb[1].at<uchar>(i,j) / 255.;
            float b = (int)rgb[0].at<uchar>(i,j) / 255.;
            float k = std::min(std::min(1- r, 1- g), 1- b);
            
            float y = (1 - b - k) / (1 - k) * 255.;
            float m = (1 - g - k) / (1 - k) * 255.;
            float c = (1 - r - k) / (1 - k) * 255.;
            k = k * 255.;
            ymck[0].at<uchar>(i, j) = y;
            ymck[1].at<uchar>(i, j) = m;
            ymck[2].at<uchar>(i, j) = c;
            ymck[3].at<uchar>(i, j) = k;
        }
    }
    cv::merge(ymck, img);
}

// CMYK to RGB conversion
void CvUtil::cmyk2rgb(cv::Mat& img) {
    std::vector<cv::Mat> bgr;
    assert(img.type() == CV_8UC4 && "input image must be CV_8UC4");
    
    // Allocate cmyk to store 4 componets
    for (int i = 0; i < 3; i++) {
        bgr.push_back(cv::Mat(img.size(), CV_8UC1));
    }
    
    // Get cmyk
    std::vector<cv::Mat> ymck;
    cv::split(img, ymck);
    
    for (int i = 0; i < 3; i++) {
        dbgSave(ymck.at(i), "ymck.tif", i);
    }
    
    // cmyk to rgb
    for (int i = 0; i < img.rows; i++) {
        for (int j = 0; j < img.cols; j++) {
            /*std::cout << "y = " << ymck[0].at<uchar>(i,j) << std::endl;
            std::cout << "m = " << ymck[1].at<uchar>(i,j) << std::endl;
            std::cout << "c = " << ymck[2].at<uchar>(i,j) << std::endl;
            std::cout << "k = " << ymck[3].at<uchar>(i,j) << std::endl;*/
            float y = (int)ymck[0].at<uchar>(i,j) / 255.;
            float m = (int)ymck[1].at<uchar>(i,j) / 255.;
            float c = (int)ymck[2].at<uchar>(i,j) / 255.;
            float k = (int)ymck[3].at<uchar>(i,j) / 255.;
            
            float r = 255. * (1 - c) * (1 - k);
            float g = 255. * (1 - m) * (1 - k);
            float b = 255. * (1 - y) * (1 - k);
            
            bgr[2].at<uchar>(i, j) = r;
            bgr[1].at<uchar>(i, j) = g;
            bgr[0].at<uchar>(i, j) = b;
        }
    }
    cv::merge(bgr, img);
}

bool CvUtil::isWhiteImage(cv::Mat img){
    if(img.empty()) return true;
    int whiteCount;
    cv::Mat cnv;
    cvtGrayIfColor(img, cnv);
    cv::adaptiveThreshold(cnv, cnv, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY, 11, 6);
    int imgSize = (cnv.rows * cnv.cols);
    whiteCount = cv::countNonZero(cnv);
    
    return (whiteCount == imgSize);
}


void CvUtil::fillMat(cv::Mat& src, cv::Mat& dst, cv::Scalar nuri, bool istl){
    if(istl){
        if((src.rows > dst.rows || src.rows < dst.rows) ||
           (src.cols > dst.cols || src.cols < dst.cols)){
            cv::Mat smallImg, largeImg;
            if(src.rows == dst.rows){
                smallImg = (src.cols > dst.cols)? dst:src;
                largeImg = (src.cols > dst.cols)? src:dst;
            }
            else if(src.cols == dst.cols){
                smallImg = (src.rows > dst.rows)? dst:src;
                largeImg = (src.rows > dst.rows)? src:dst;
            }
            else{
                smallImg = (src.rows > dst.rows)? dst:src;
                largeImg = (src.rows > dst.rows)? src:dst;
            }
            
            cv::Mat makeImg(cv::Size(largeImg.cols,largeImg.rows), largeImg.type(), nuri);
            cv::Mat remakeROI(makeImg, cv::Rect(0,0,smallImg.cols,smallImg.rows));
            smallImg.copyTo(remakeROI);
            cv::rectangle(makeImg, cv::Point(0,smallImg.rows), cv::Point(makeImg.cols,makeImg.rows), nuri, cv::FILLED);
            cv::rectangle(makeImg, cv::Point(smallImg.cols,0), cv::Point(makeImg.cols,makeImg.rows), nuri, cv::FILLED);
            
            if(src.rows == dst.rows){
                if((src.cols > dst.cols)) {
                    src = largeImg;
                    dst = makeImg;
                }else{
                    src = makeImg;
                    dst = largeImg;
                }
            }
            else if(src.cols == dst.cols){
                if((src.rows > dst.rows)) {
                    src = largeImg;
                    dst = makeImg;
                }else{
                    src = makeImg;
                    dst = largeImg;
                }
            }
            else if((src.rows > dst.rows) || (src.cols > dst.cols)) {
                src = largeImg;
                dst = makeImg;
            }
            else{
                src = makeImg;
                dst = largeImg;
            }
        }
    }
    else{
        // 高さのサイズ
        if(src.rows > dst.rows || src.rows < dst.rows){
            cv::Mat smallImg, largeImg;
            smallImg = (src.rows > dst.rows)? dst:src;
            largeImg = (src.rows > dst.rows)? src:dst;
            
            int diffHeight = largeImg.rows - smallImg.rows;
            cv::Mat restored;
            
            restored = cv::Mat(cv::Size(smallImg.cols,largeImg.rows), largeImg.type(), nuri);
            
            cv::Mat remakeROI(restored, cv::Rect(0,diffHeight/2,smallImg.cols,smallImg.rows));
            smallImg.copyTo(remakeROI);
            //cv::rectangle(restored, cv::Point(0,0), cv::Point(smallImg.cols,diffHeight/2), nuri, cv::FILLED);
            //cv::rectangle(restored, cv::Point(0,smallImg.rows+(diffHeight/2)), cv::Point(smallImg.cols,restored.rows), nuri, cv::FILLED);

            if(src.rows > dst.rows) {
                src = largeImg;
                dst = restored;
            }
            else{
                src = restored;
                dst = largeImg;
            }
        }
        
        // 幅のサイズ
        if(src.cols < dst.cols || src.cols > dst.cols){
            cv::Mat smallImg, largeImg;
            smallImg = (src.cols > dst.cols)? dst:src;
            largeImg = (src.cols > dst.cols)? src:dst;
            
            int diffWidth = largeImg.cols - smallImg.cols;
            
            cv::Mat restored;
            restored = cv::Mat(cv::Size(largeImg.cols,largeImg.rows), largeImg.type(), nuri);
            
            cv::Mat remakeROI(restored, cv::Rect(diffWidth/2,0,smallImg.cols,smallImg.rows));
            smallImg.copyTo(remakeROI);
            
            if(src.cols > dst.cols) {
                src = largeImg;
                dst = restored;
            }else{
                src = restored;
                dst = largeImg;
            }
        }
    }
    
}
// 画像サイズ調整
bool CvUtil::adjustSize(cv::Mat& src, cv::Mat& dst, cv::Scalar nuri, AdjustMode mode){
    
    if (!checkImg(src) || !checkImg(dst)) {
        cout << "adjustSize() error: image is empty!" << endl;
        return false;
    }
    
    if (( src.rows == dst.rows )&&( src.cols == dst.cols ) ) {
        // 同じサイズの画像は調整しない
        return true;
    }
    
    if(mode != ADJUST_FILL &&
       mode != ADJUST_CROP &&
       mode != ADJUST_FEATURE &&
       mode != ADJUST_REGISTMARK &&
       mode != ADJUST_POC){
        cout << "adjustSize() error: invalid mode!" << endl;
        return false;
    }
    // 平行移動のズレに対応
    if(mode == ADJUST_POC){
        cv::Mat imgS,imgT;
        bool isSrcLarge = false;
        if(src.rows > dst.rows || src.cols > dst.cols) isSrcLarge = true;
        imgS = src.clone();
        imgT = dst.clone();
        if(!( (src.rows == dst.rows) && (src.cols == dst.cols) )){
            // 同じサイズに調整
            //fillMat(imgS, imgT, cv::Scalar::all(255), false);
            cropMat(imgS,imgT);
        }
        
        imgS.copyTo(src);
        imgT.copyTo(dst);
        
        cvtGrayIfColor(imgS, imgS);
        cvtGrayIfColor(imgT, imgT);
        
        double resl;
        cv::Mat hann;
        cv::createHanningWindow(hann, imgS.size(), CV_32F);
        imgS.convertTo(imgS, CV_32F);
        imgT.convertTo(imgT, CV_32F);
        cv::Point2d shift = cv::phaseCorrelate(imgS, imgT, hann, &resl);
        if(round(resl) == 0) return true;
        if(shift.x < 1.1 && shift.y < 1.1) return true;
        
        cout << "x:" << shift.x << endl;
        cout << "y:" << shift.y << endl;
        cv::Rect roiCrop;
        cv::Mat cropped;
        
        if(isSrcLarge){
            // shiftの数字だけsrcを移動
            moveSafe(src, cropped, shift, cv::Scalar(255));
            src.release();
            roiCrop = cv::Rect(0,0,dst.cols,dst.rows);
            cv::Mat resultImg(cropped, roiCrop);
            src = resultImg.clone();
            resultImg.release();
        }
        else{
            // shiftの数字だけdstを移動
            moveSafe(dst, cropped, -1 * shift, cv::Scalar(255));
            dst.release();
            roiCrop = cv::Rect(0,0,src.cols,src.rows);
            cv::Mat resultImg(cropped, roiCrop);
            dst = resultImg.clone();
            resultImg.release();
        }
        return true;
    }
    else if(mode == ADJUST_REGISTMARK){
        
        cv::Mat cropImg;
        int split = 4;
        cv::Size orgSize;
        bool isSrc = false;
        if(src.rows > dst.rows && src.cols > dst.cols){
            orgSize = cv::Size(dst.cols, dst.rows);
            cropImg = src.clone();
            isSrc = true;
        }else if (src.rows < dst.rows && src.cols < dst.cols){
            orgSize = cv::Size(src.cols, src.rows);
            cropImg = dst.clone();
        }
        else{
            CV_Assert((src.rows < dst.rows && src.cols > dst.cols) || (src.rows > dst.rows && src.cols > dst.cols));
            return false;
        }
        cv::Rect tlRect(0,0,cropImg.cols / split, cropImg.rows / split);
        cv::Rect brRect(cropImg.cols - (cropImg.cols / split),
                        cropImg.rows - (cropImg.rows / split),cropImg.cols / split, cropImg.rows / split);
        cv::Mat iii, ret;
        cv::cvtColor(cropImg, iii, cv::COLOR_BGR2GRAY);
        
        cv::Mat tlIm(iii, tlRect);
        cv::Mat brIm(iii, brRect);
        
        vector<cv::Point2f> corners;
        cv::goodFeaturesToTrack(tlIm, corners, 4, 0.01, 20);
        
        auto minP = minPointf(corners);
        corners.clear();
        
        cv::goodFeaturesToTrack(brIm, corners, 4, 0.01, 20);
        auto maxP = maxPointf(corners);
        maxP.x += brRect.x;
        maxP.y += brRect.y;
        
        cv::Rect cropArea(minP,maxP);
        if(cropArea.width > orgSize.width || cropArea.width < orgSize.width){
            bool isLargerCrop = (cropArea.width > orgSize.width);
            int diffwidth = abs(orgSize.width - cropArea.width);
            if(isLargerCrop) {
                cropArea.width -= diffwidth;
            }else{
                cropArea.width += diffwidth;
            }
        }
        if(cropArea.height > orgSize.height || cropArea.height < orgSize.height){
            bool isLargerCrop = (cropArea.height > orgSize.height);
            int diffheight = abs(orgSize.height - cropArea.height);
            if(isLargerCrop) {
                cropArea.height -= diffheight;
            }else{
                cropArea.height += diffheight;
            }
        }
        cv::Mat result(cropImg, cropArea);
        
        if(isSrc) src = result.clone();
        else dst = result.clone();
        return true;
    }
    else if(mode == ADJUST_FEATURE){
        return featureDetect(src, dst);
        /*
        cropMat(src,ret);
        
        dst = ret.clone();
        
        cv::Mat cdst;
        cv::Mat bT;
        cv::pyrDown(dst, bT);
        cv::pyrDown(bT, bT);
        binalize(bT, bT, true);
        cv::dilate(bT, bT, cv::Mat());
        cv::dilate(bT, bT, cv::Mat());
        vector<vector<cv::Point>> vctContoursT;
        cv::findContours(bT, vctContoursT, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
        vector<cv::RotatedRect> rcTs;
        
        for (int i = 0; i < vctContoursT.size(); i++){
            auto conts = vctContoursT.at(i);
            cv::RotatedRect rt = cv::minAreaRect(conts);
            rcTs.push_back(rt);
        }
        
        sort(rcTs.begin(), rcTs.end(), byAreaR());
        auto tr = *rcTs.begin();
        float agl = 0.0f;
        if(tr.angle < -45) agl = 90 + tr.angle;
        else agl = tr.angle;
        cout << "T:angle = " << agl << endl;
        if(agl != 0){
            auto rot = cv::getRotationMatrix2D(cv::Point2f(dst.cols/2,dst.rows/2), agl, 1.0);
            cv::warpAffine(dst, dst, rot, cv::Size(src.cols,src.rows));
        }*/
        //dbgSave(dst, "dst.png");
        /*
         float k = 3.0f;
         float kernelData[] = {
         -k/9.0f, -k/9.0f,           -k/9.0f,
         -k/9.0f, 1 + (8 * k)/9.0f,  -k/9.0f,
         -k/9.0f, -k/9.0f,           -k/9.0f,
         };
         cv::Mat kernel(3,3,CV_32F,kernelData);
         cv::filter2D(dst, dst, -1, kernel);
         */
        //dbgSave(dst, "dst.png");
    }
    else if(mode == ADJUST_FILL){
        
        fillMat(src,dst,nuri, false);
    }
    else if (mode == ADJUST_CROP){
        
        cropMat(src,dst);
    }
    return true;
}

CvUtil::MatchingResult CvUtil::tmplateMatch(cv::Mat rS, cv::Mat rT, double threshold, int scale){
    auto result = MatchingResult();
    
    /*
    cv::Mat extTrg(cv::Size(rT.size().width + 40,rT.size().height + 40), rT.type(), cv::Scalar(255));
    cv::Rect roi(20, 20, rT.cols, rT.rows);
    cv::Mat roi_img, tmp_img;
    cropSafe(extTrg, roi_img, roi, false);
    rT.copyTo(roi_img);
    
    if(rS.rows > extTrg.rows || rS.cols > extTrg.cols){
        fillMat(rS, rT, cv::Scalar(255), false);
        //dbgSave(rS, "rS.tif", false);
        //dbgSave(rT, "rT.tif", false);
    }
    cv::Mat BigS,BigT;
    cv::resize(rS, BigS, cv::Size(rS.cols * scale, rS.rows * scale));
    cv::resize(extTrg, BigT, cv::Size(extTrg.cols * scale, extTrg.rows * scale));
    */
    
    
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
    
//    cvtGrayIfColor(BigS,BigS);
//    cvtGrayIfColor(BigT,BigT);
    cvtGrayIfColor(rS,rS);
    cvtGrayIfColor(rT,rT);
    cv::UMat uSrc, uTmp;
    rS.copyTo(uSrc);
    rT.copyTo(uTmp);
//    cv::matchTemplate(BigS, BigT, result_img, cv::TM_CCOEFF_NORMED);
    cv::matchTemplate(uSrc, uTmp, result_img, cv::TM_CCOEFF_NORMED);
    cv::minMaxLoc(result_img, &minVal, &maxVal, &min_pt, &max_pt);
    max_pt = max_pt / scale;
//    cv::Rect roi_rect(max_pt, cv::Point(max_pt.x+ extTrg.cols, max_pt.y+extTrg.rows));
    cv::Rect roi_rect(max_pt, cv::Point(max_pt.x+ rT.cols, max_pt.y+rT.rows));
    
    cout << "MaxVal: " << maxVal << endl;
    if(maxVal < threshold) {
#ifdef DEBUG
//        cout << "MinVal: " << minVal << endl;
//        cout << "MinRect : x = " << min_pt.x << " y = " << min_pt.y << " w = " << extTrg.cols << " h = " << extTrg.rows << endl;
        
//        cout << "MaxRect : x = " << max_pt.x << " y = " << max_pt.y << " w = " << extTrg.cols << " h = " << extTrg.rows << endl;
//        cout << "----------------------------" << endl;
#endif
        result.isMatch = false;
    }
    else {
        result.isMatch = true;
    }
    
    result.ROI.push_back(roi_rect);
    result.val = maxVal;
    
    return result;
}

cv::Scalar CvUtil::HSVtoRGBcvScalar(int H, int S, int V) {
    
    int bH = H; // H component
    int bS = S; // S component
    int bV = V; // V component
    double fH, fS, fV;
    double fR, fG, fB;
    const double double_TO_BYTE = 255.0f;
    const double BYTE_TO_double = 1.0f / double_TO_BYTE;
    
    // Convert from 8-bit integers to doubles
    fH = (double)bH * BYTE_TO_double;
    fS = (double)bS * BYTE_TO_double;
    fV = (double)bV * BYTE_TO_double;
    
    // Convert from HSV to RGB, using double ranges 0.0 to 1.0
    int iI;
    double fI, fF, p, q, t;
    
    if( bS == 0 ) {
        // achromatic (grey)
        fR = fG = fB = fV;
    }
    else {
        // If Hue == 1.0, then wrap it around the circle to 0.0
        if (fH>= 1.0f)
            fH = 0.0f;
        
        fH *= 6.0; // sector 0 to 5
        fI = floor( fH ); // integer part of h (0,1,2,3,4,5 or 6)
        iI = (int) fH; // " " " "
        fF = fH - fI; // factorial part of h (0 to 1)
        
        p = fV * ( 1.0f - fS );
        q = fV * ( 1.0f - fS * fF );
        t = fV * ( 1.0f - fS * ( 1.0f - fF ) );
        
        switch( iI ) {
            case 0:
                fR = fV;
                fG = t;
                fB = p;
                break;
            case 1:
                fR = q;
                fG = fV;
                fB = p;
                break;
            case 2:
                fR = p;
                fG = fV;
                fB = t;
                break;
            case 3:
                fR = p;
                fG = q;
                fB = fV;
                break;
            case 4:
                fR = t;
                fG = p;
                fB = fV;
                break;
            default: // case 5 (or 6):
                fR = fV;
                fG = p;
                fB = q;
                break;
        }
    }
    
    // Convert from doubles to 8-bit integers
    int bR = (int)(fR * double_TO_BYTE);
    int bG = (int)(fG * double_TO_BYTE);
    int bB = (int)(fB * double_TO_BYTE);
    
    // Clip the values to make sure it fits within the 8bits.
    if (bR > 255)
        bR = 255;
    if (bR < 0)
        bR = 0;
    if (bG >255)
        bG = 255;
    if (bG < 0)
        bG = 0;
    if (bB > 255)
        bB = 255;
    if (bB < 0)
        bB = 0;
    
    // Set the RGB cvScalar with G B R, you can use this values as you want too..
    return cv::Scalar(bB,bG,bR); // R component
}

bool getKeyPoints(cv::Mat rS, cv::Mat rT, std::vector<cv::KeyPoint>& kp_q, std::vector<cv::KeyPoint>& kp_t, std::vector<cv::DMatch>& matches)
{
    cv::Ptr<cv::Feature2D> feature = cv::AKAZE::create();
    cv::Mat descriptor1,descriptor2;
    feature->detectAndCompute(rS, cv::noArray(), kp_q, descriptor1);
    feature->detectAndCompute(rT, cv::noArray(), kp_t, descriptor2);
    
    if(kp_q.size()==0 || kp_t.size()==0){
        cout << "no features!!!" << endl;
        return false;
    }
    cv::BFMatcher matcher(cv::NORM_HAMMING, true);
    
    std::vector<cv::DMatch> tmp_matches;
    matcher.match(descriptor1, descriptor2, tmp_matches);
    for (auto m : tmp_matches) {
        if (m.distance < 6) {
            matches.push_back(m);
        }
    }
    return true;
}

// 似た領域を抽出
bool CvUtil::featureDetect(cv::Mat& rS, cv::Mat& rT){
    cv::Mat dst;
    cv::Mat imgS,imgT;

    dbgSave(rS, "rS.tif", false);
    dbgSave(rT, "rT.tif", false);
    std::vector<cv::KeyPoint> keypoints1,keypoints2;
    std::vector<cv::DMatch> matches;
    std::vector<FeatureInfo> matchPoints;
    
    if(!getKeyPoints(rS,rT,keypoints1, keypoints2, matches)) {
        cout << "no features!!!" << endl;
        return false;
    }
    
    for (auto m : matches) {
        FeatureInfo p;
        p.query_pt = keypoints1.at(m.queryIdx).pt;
        p.train_pt = keypoints2.at(m.trainIdx).pt;
        p.distance = m.distance;
        matchPoints.push_back(p);
    }
    
    if (matchPoints.size() <= 2) {
        cout << "no match!!!" << endl;
        return false;
    }
    
    sort(matchPoints.begin(), matchPoints.end(), byOrgDistanceQuery());
    
    // 回転
    cv::Point2f centerRT(rT.cols / 2.0f, rT.rows / 2.0f); // 元のセンター座標
    FeatureInfo best_match1 = matchPoints.at(0);
    FeatureInfo best_match2 = matchPoints.at(matchPoints.size() - 1);
    
    double q_deg = atan2(best_match2.query_pt.y - best_match1.query_pt.y, best_match2.query_pt.x - best_match1.query_pt.x)*180/CV_PI;
    double t_deg = atan2(best_match2.train_pt.y - best_match1.train_pt.y, best_match2.train_pt.x - best_match1.train_pt.x)*180/CV_PI;
    double angle = round(q_deg - t_deg);
    
    if (angle != 0) {
        if (abs(angle) == 90) {
            if (angle < 0) {
                angle = -1 * angle;
            }
        }
        else {
            angle = -1 * angle;
        }
        
        auto rot = cv::getRotationMatrix2D(centerRT, angle, 1.0);
        
        
        cv::warpAffine(rT, rT, rot, cv::Size(rT.cols, rT.rows));
        dbgSave(rT, "rT.tif", false);
        keypoints1.clear();
        keypoints2.clear();
        matches.clear();
        matchPoints.clear();
        getKeyPoints(rS,rT,keypoints1, keypoints2, matches);
        for (auto m : matches) {
            FeatureInfo p;
            p.query_pt = keypoints1.at(m.queryIdx).pt;
            p.train_pt = keypoints2.at(m.trainIdx).pt;
            p.distance = m.distance;
            matchPoints.push_back(p);
        }
    }
    
    // 元画像からの移動量計算
    float ave_x = 0.0;
    float ave_y = 0.0;
    for (auto m : matchPoints) {
        int dx = round(m.train_pt.x - m.query_pt.x);
        int dy = round(m.train_pt.y - m.query_pt.y);
        ave_x += dx;
        ave_y += dy;
    }
    ave_x /= matchPoints.size();
    ave_y /= matchPoints.size();

    int dX = round(ave_x);
    int dY = round(ave_y);
    cv::Rect crpS, crpT;
    if (dX < 0 && dY < 0) {
        crpS = cv::Rect(abs(dX), abs(dY), rS.cols - abs(dX), rS.rows - abs(dY));
        crpT = cv::Rect(0, 0, rS.cols - abs(dX), rS.rows - abs(dY));
    }
    else if (dX < 0 && dY >= 0) {
        crpS = cv::Rect(abs(dX), 0, rS.cols - abs(dX), rS.rows);
        crpT = cv::Rect(0, abs(dY), rS.cols - abs(dX), rS.rows);
    }
    else if (dX >= 0 && dY < 0) {
        crpS = cv::Rect(0, abs(dY), rS.cols, rS.rows - abs(dY));
        crpT = cv::Rect(abs(dX), 0, rS.cols, rS.rows - abs(dY));
    }
    else {
        crpS = cv::Rect(0, 0, rS.cols, rS.rows);
        crpT = cv::Rect(abs(dX), abs(dY), rS.cols, rS.rows);
    }
    
    cropSafe(rS, rS, crpS, true);
    cropSafe(rT, rT, crpT, true);
  
    return true;
    
}

//#pragma mark -
//#pragma mark Halide
//
//// ２画像の差分
//Func CvUtil::diff_img(Buffer<uint8_t>& src, Buffer<uint8_t>& trg){
//    Var x{"x"}, y{"y"}, c{"c"};
//    Func output{"output"};
//    output(x,y,c) = saturating_cast<uint8_t>(cast<int16_t>(trg(x,y,c)) - cast<int16_t>(src(x,y,c))) |
//    saturating_cast<uint8_t>(cast<int16_t>(src(x,y,c)) - cast<int16_t>(trg(x,y,c)));
//    return output;
//}
//
//// 閾値で2値化
//Func CvUtil::thresh(Func src, int thresh){
//    Var x{"x"}, y{"y"}, c{"c"};
//    Func output{"output"};
//    output(x,y,c) = select(src(x,y,c) >= thresh, cast<uint8_t>(255), cast<uint8_t>(0));
//    return output;
//}
//
//// 閾値で2値化
//Func CvUtil::threshBuf(Buffer<uint8_t>& src, int thresh){
//    Var x{"x"}, y{"y"}, c{"c"};
//    Func output{"output"};
//    
//    output(x,y,c) = select(src(x,y,c) >= thresh, cast<uint8_t>(255), cast<uint8_t>(0));
//    return output;
//}

