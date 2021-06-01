//
//  psd_utils.hpp
//  KZPSDParser
//
//  Created by uchiyama_Macmini on 2019/08/13.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef psd_utils_hpp
#define psd_utils_hpp

#include <stdio.h>
#include <cassert>
#include <string>
#include <vector>
#include <map>
#include <iostream>

namespace psd
{
    template <typename T> bool read_file(FILE* f, T* data) {
        size_t ret = fread((T*)data, sizeof(T), 1, f);
        return (ret == 0)? false : true;
    }
    
    template <uint32_t padding>
    uint32_t padded_size(uint32_t size) {
        return (size + padding-1)/padding*padding;
    }
    
    template <typename T> void BEtoLE(T& x);
    template <> inline void BEtoLE<uint8_t>(uint8_t& x) {
        // do nothing;
    }
    template <> inline void BEtoLE<uint64_t>(uint64_t& x) {
        uint8_t t;
        uint8_t* p = reinterpret_cast<uint8_t*>(&x);
        t = p[0]; p[0] = p[7]; p[7] = t;
        t = p[1]; p[1] = p[6]; p[6] = t;
        t = p[2]; p[2] = p[5]; p[5] = t;
        t = p[3]; p[3] = p[4]; p[4] = t;
    }
    template <> inline void BEtoLE<uint32_t>(uint32_t& x) {
        uint8_t t;
        uint8_t* p = reinterpret_cast<uint8_t*>(&x);
        t = p[0]; p[0] = p[3]; p[3] = t;
        t = p[1]; p[1] = p[2]; p[2] = t;
    }
    template <> inline void BEtoLE<uint16_t>(uint16_t& x) {
        uint8_t t;
        uint8_t* p = reinterpret_cast<uint8_t*>(&x);
        t = p[0]; p[0] = p[1]; p[1] = t;
    }
    template <> inline void BEtoLE<int64_t>(int64_t& x) {
        BEtoLE(*(uint64_t*)&x);
    }
    template <> inline void BEtoLE<int32_t>(int32_t& x) {
        BEtoLE(*(uint32_t*)&x);
    }
    template <> inline void BEtoLE<int16_t>(int16_t& x) {
        BEtoLE(*(uint16_t*)&x);
    }

    template <typename T> struct be {
        T x;
        
        be() : x(0) {}
        
        be(T x) : x(x) {
            BEtoLE(this->x);
        }
        
        be(const be& y) : x(y.x) {
        }
        
        operator T() const {
            T y = x;
            BEtoLE(y);
            return y;
        }
        
        be& operator = (be y) {
            x = y.x;
            return *this;
        }
        
        be& operator = (T y) {
            x = y;
            BEtoLE(x);
            return *this;
        }
        
        T operator += (T y) {
            BEtoLE(x);
            x += y;
            T xx = x;
            BEtoLE(x);
            return xx;
        }
        
        T operator -= (T y) {
            BEtoLE(x);
            x -= y;
            T xx = x;
            BEtoLE(x);
            return xx;
        }
    };

    struct Signature
    {
        uint32_t sig;
        
        Signature() : sig(0) {
        }
        
        Signature(uint32_t sig) : sig(sig) {
        }
        
        Signature(const std::string& str) {
            assert(str.size() == 4);
            sig = *(uint32_t*)str.data();
        }
        
        operator std::string() {
            return std::string((char*)&sig, (char*)&sig+4);
        }
    };

    inline bool operator == (const Signature& sig, const std::string& str) {
        return sig.sig == Signature(str).sig;
    }

    inline bool operator == (const std::string& str, const Signature& sig) {
        return sig.sig == Signature(str).sig;
    }

    inline bool operator != (const Signature& sig, const std::string& str) {
        return sig.sig != Signature(str).sig;
    }

    inline bool operator != (const std::string& str, const Signature& sig) {
        return sig.sig != Signature(str).sig;
    }
    
    template <typename T> T read_vector(std::vector<char> buffer, uint32_t start, uint32_t end) {
        std::string tmp(buffer.begin()+start, buffer.begin()+end);
        const char* buf = tmp.c_str();
        
        T retData = 0;
        memcpy(&retData, buf, sizeof(T));

        return retData;
    }
}

#endif /* psd_utils_hpp */
