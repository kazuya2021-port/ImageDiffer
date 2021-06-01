//
//  nms.hpp
//  DiffImgCV
//
//  Created by uchiyama_Macmini on 2019/07/04.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef nms_hpp
#define nms_hpp

#include <vector>
#include <numeric>
#include <opencv2/opencv.hpp>

enum PointInRectangle {XMIN, YMIN, XMAX, YMAX};

std::vector<cv::Rect> nms(const std::vector<std::vector<float>> &,
                          const float &);

std::vector<float> GetPointFromRect(const std::vector<std::vector<float>> &,
                                    const PointInRectangle &);

std::vector<float> ComputeArea(const std::vector<float> &,
                               const std::vector<float> &,
                               const std::vector<float> &,
                               const std::vector<float> &);

template <typename T>
std::vector<int> argsort(const std::vector<T> & v);

std::vector<float> Maximum(const float &,
                           const std::vector<float> &);

std::vector<float> Minimum(const float &,
                           const std::vector<float> &);

std::vector<float> CopyByIndexes(const std::vector<float> &,
                                 const std::vector<int> &);

std::vector<int> RemoveLast(const std::vector<int> &);

std::vector<float> Subtract(const std::vector<float> &,
                            const std::vector<float> &);

std::vector<float> Multiply(const std::vector<float> &,
                            const std::vector<float> &);

std::vector<float> Divide(const std::vector<float> &,
                          const std::vector<float> &);

std::vector<int> WhereLarger(const std::vector<float> &,
                             const float &);

std::vector<int> RemoveByIndexes(const std::vector<int> &,
                                 const std::vector<int> &);

std::vector<cv::Rect> BoxesToRectangles(const std::vector<std::vector<float>> &);

template <typename T>
std::vector<T> FilterVector(const std::vector<T> &,
                            const std::vector<int> &);

#endif /* nms_hpp */
