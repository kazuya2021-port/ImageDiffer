//
//  DBScan.h
//  DiffImgCV
//
//  Created by uchiyama_Macmini on 2019/05/30.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef DBScan_h
#define DBScan_h

#include "opencv2/opencv.hpp"
#include <map>
#include <sstream>

class DbScan
{
public:
    std::map<int, int> labels;
    std::vector<cv::Rect>& data;
    int C;
    double eps;
    int mnpts;
    double* dp;
    //memoization table in case of complex dist functions
    #define DP(i,j) dp[(data.size()*i)+j]
    DbScan(std::vector<cv::Rect>& _data,double _eps,int _mnpts):data(_data)
    {
        C=-1;
        for(int i=0;i<data.size();i++)
        {
            labels[i]=-99;
        }
        eps=_eps;
        mnpts=_mnpts;
    }
    void run()
    {
        dp = new double[data.size()*data.size()];
        for(int i=0;i<data.size();i++)
        {
            for(int j=0;j<data.size();j++)
            {
                if(i==j)
                    DP(i,j)=0;
                else
                    DP(i,j)=-1;
            }
        }
        for(int i=0;i<data.size();i++)
        {
            if(!isVisited(i))
            {
                std::vector<int> neighbours = regionQuery(i);
                if(neighbours.size()<mnpts)
                {
                    labels[i]=-1;//noise
                }else
                {
                    C++;
                    expandCluster(i,neighbours);
                }
            }
        }
        delete [] dp;
    }
    void expandCluster(int p,std::vector<int> neighbours)
    {
        labels[p]=C;
        for(int i=0;i<neighbours.size();i++)
        {
            if(!isVisited(neighbours[i]))
            {
                labels[neighbours[i]]=C;
                std::vector<int> neighbours_p = regionQuery(neighbours[i]);
                if (neighbours_p.size() >= mnpts)
                {
                    expandCluster(neighbours[i],neighbours_p);
                }
            }
        }
    }
    
    bool isVisited(int i)
    {
        return labels[i]!=-99;
    }
    
    std::vector<int> regionQuery(int p)
    {
        std::vector<int> res;
        for(int i=0;i<data.size();i++)
        {
            if(distanceFunc(p,i)<=eps)
            {
                res.push_back(i);
            }
        }
        return res;
    }
    
    double dist2d(cv::Point2d a,cv::Point2d b)
    {
        return sqrt(pow(a.x-b.x,2) + pow(a.y-b.y,2));
    }
    
    double distanceFunc(int ai,int bi)
    {
        if(DP(ai,bi)!=-1)
            return DP(ai,bi);
        
        try {
            cv::Rect a,b;
            a = data.at(ai);
            b = data.at(bi);
            
            cv::Point2d tla =cv::Point2d(a.x,a.y);
            cv::Point2d tra =cv::Point2d(a.x+a.width,a.y);
            cv::Point2d bla =cv::Point2d(a.x,a.y+a.height);
            cv::Point2d bra =cv::Point2d(a.x+a.width,a.y+a.height);
            
            cv::Point2d tlb =cv::Point2d(b.x,b.y);
            cv::Point2d trb =cv::Point2d(b.x+b.width,b.y);
            cv::Point2d blb =cv::Point2d(b.x,b.y+b.height);
            cv::Point2d brb =cv::Point2d(b.x+b.width,b.y+b.height);
            
            double minDist = 9999999;
            
            minDist = cv::min(minDist,dist2d(tla,tlb));
            minDist = cv::min(minDist,dist2d(tla,trb));
            minDist = cv::min(minDist,dist2d(tla,blb));
            minDist = cv::min(minDist,dist2d(tla,brb));
            
            minDist = cv::min(minDist,dist2d(tra,tlb));
            minDist = cv::min(minDist,dist2d(tra,trb));
            minDist = cv::min(minDist,dist2d(tra,blb));
            minDist = cv::min(minDist,dist2d(tra,brb));
            
            minDist = cv::min(minDist,dist2d(bla,tlb));
            minDist = cv::min(minDist,dist2d(bla,trb));
            minDist = cv::min(minDist,dist2d(bla,blb));
            minDist = cv::min(minDist,dist2d(bla,brb));
            
            minDist = cv::min(minDist,dist2d(bra,tlb));
            minDist = cv::min(minDist,dist2d(bra,trb));
            minDist = cv::min(minDist,dist2d(bra,blb));
            minDist = cv::min(minDist,dist2d(bra,brb));
            DP(ai,bi)=minDist;
            DP(bi,ai)=minDist;
            return DP(ai,bi);
        }
        catch(cv::Exception ex) {
            return DP(ai,bi);
        }
    }
    
    std::vector<std::vector<cv::Rect> > getGroups()
    {
        std::vector<std::vector<cv::Rect> > ret;
        for(int i=0;i<=C;i++)
        {
            ret.push_back(std::vector<cv::Rect>());
            for(int j=0;j<data.size();j++)
            {
                if(labels[j]==i)
                {
                    ret[ret.size()-1].push_back(data[j]);
                }
            }
        }
        return ret;
    }
};
#endif /* DBScan_h */
