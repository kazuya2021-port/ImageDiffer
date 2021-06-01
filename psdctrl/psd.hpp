//
//  psd.hpp
//  psdctrl
//
//  Created by uchiyama_Macmini on 2019/08/15.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef psd_hpp
#define psd_hpp

#include <stdio.h>
#include <iostream>
#include <sstream>
#include <vector>
#include <queue>
#include <string>

#ifdef DEBUG
std::queue<std::string> argment_contents;
void set_args_con() {}
template<class First, class... Rest>
void set_args_con(const First& first, const Rest&... rest) {
    std::stringstream ss;
    ss<<first;
    argment_contents.push(ss.str());
    set_args_con(rest...);
}
std::string gen_string(std::string s) {
    s+=',';
    std::string ret="";
    int par=0;
    for(int i=0; i<(int)s.size(); i++) {
        if(s[i]=='(' || s[i]=='<' || s[i]=='{') par++;
        else if(s[i]==')' || s[i]=='>' || s[i]=='}') par--;
        if(par==0 && s[i]==',') {
            ret+="="+argment_contents.front();
            argment_contents.pop();
            if(i!=(int)s.size()-1) {
                ret+=",";
            }
        }
        else ret+=s[i];
    }
    return ret;
}
#define dump(...) {set_args_con(__VA_ARGS__);std::cerr<<gen_string(#__VA_ARGS__)<<std::endl;}
#define log_err(message, ...) {std::cerr<<message<<std::endl;set_args_con(__VA_ARGS__);std::cerr<<gen_string(#__VA_ARGS__)<<std::endl;}
#else
#define dump(...)
#define log_err(message, ...) std::cerr<<message<<std::endl;
#endif


namespace psd {
#pragma mark -
#pragma mark PSD Util
    namespace util {
        using namespace psd;
        template<class T>
        inline void reverse_endian(T* value)
        {
            char *first = reinterpret_cast<char*>(&value);
            char *last = first + sizeof(T);
            std::reverse(first, last);
        }
        template <>
        inline void reverse_endian<uint8_t>(uint8_t* value) {
            // do nothing;
        }
    }
    
#pragma mark -
#pragma mark PSD File Type
    namespace type {
        using namespace psd::util;
        template <typename T>
        struct bigE {
            T x;
            bigE() : x(0) {}
            bigE(T x) : x(x) { reverse_endian(&(this->x)); }
            bigE(const bigE& y) : x(y.x) {}
            
            operator T() const {
                T y = x;
                reverse_endian(&y);
                return y;
            }
            
            bigE& operator = (bigE y) {
                x = y.x;
                return *this;
            }
            
            bigE& operator = (T y) {
                x = y;
                reverse_endian(&x);
                return *this;
            }
            
            T operator += (T y) {
                reverse_endian(&x);
                x += y;
                T xx = x;
                reverse_endian(&x);
                return xx;
            }
            
            T operator -= (T y) {
                reverse_endian(&x);
                x -= y;
                T xx = x;
                reverse_endian(&x);
                return xx;
            }
            
            T operator *= (T y) {
                reverse_endian(&x);
                x *= y;
                T xx = x;
                reverse_endian(&x);
                return xx;
            }
            
            T operator /= (T y) {
                reverse_endian(&x);
                x /= y;
                T xx = x;
                reverse_endian(&x);
                return xx;
            }
        };
        
        typedef uint8_t psd_uint8_t;
        typedef uint16_t psd_uint16_t;
        typedef uint32_t psd_uint32_t;
        typedef uint64_t psd_uint64_t;
        
        typedef bigE<psd_uint8_t> psd_uint8_B;
        typedef bigE<psd_uint16_t> psd_uint16_B;
        typedef bigE<psd_uint32_t> psd_uint32_B;
        typedef bigE<psd_uint64_t> psd_uint64_B;
    }
    
#pragma mark -
#pragma mark PSD File Structure
    
    namespace file_struct {
        using namespace psd::util;
        using namespace psd::type;
        struct PSDSignature
        {
            psd_uint32_t sig;
            
            PSDSignature() : sig(0) {}
            PSDSignature(psd_uint32_t sig) : sig(sig) {}
            PSDSignature(const std::string& str) {
                if(str.size() != 4) {
                    log_err("not get signature", str)
                }
                else {
                    sig = *(uint32_t*)str.data();
                }
            }
            operator std::string() {
                return std::string((char*)&sig, (char*)&sig+4);
            }
        };
        
        struct PSDHeader
        {
            PSDHeader() : reserve1(0), reserve2(0) {}
            PSDSignature signature;
            psd_uint16_B version;
            psd_uint16_t reserve1;
            psd_uint32_t reserve2;
            psd_uint16_B num_channels;
            psd_uint32_B height;
            psd_uint32_B width;
            psd_uint16_B bit_depth;
            psd_uint16_B c_mode;
        };
    }
    
    using namespace psd::type;
    using namespace psd::file_struct;
    using namespace psd::util;
    
#pragma mark -
#pragma mark Public Class
    class PSD {
    public:
        bool open(const char *path) {
            log_err("read file error!", path);
            FILE* f = fopen(path, "rb");
            if (f) {
                return open(f);
            }
            else {
                log_err("read file error!", path);
                return false;
            }
            return true;
        }
        bool open(FILE *f) {
            return true;
        }
    private:
        std::vector<char> psd_buffer;
    };
}
#endif /* psd_hpp */
