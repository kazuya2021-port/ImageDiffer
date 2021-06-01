//
//  psd_types.hpp
//  KZMagick
//
//  Created by uchiyama_Macmini on 2019/08/19.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#ifndef psd_types_hpp
#define psd_types_hpp
#include "psd_def.h"
#include <vector>

namespace Psd{
    namespace Type {
        
        template<class T>
        void reverse_endian(T* value)
        {
            if (sizeof(T)== 1) return;
            char *first = reinterpret_cast<char*>(value);
            if (first == NULL) return;
            std::reverse(first, first+sizeof(T));
        }
        
        template <class T>
        struct BigE {
            T x;
            BigE() : x(0) {}
            BigE(T x) : x(x) { reverse_endian<T>(&(this->x)); }
            BigE(const BigE& y) : x(y.x) {}
            
            operator T() const {
                T y = x;
                reverse_endian<T>(&y);
                return y;
            }
            
            BigE& operator = (BigE y) {
                x = y.x;
                return *this;
            }
            
            BigE& operator = (T y) {
                x = y; reverse_endian<T>(&x);
                return *this;
            }
            
            T operator += (T y) {
                reverse_endian<T>(&x); x += y;
                T xx = x; reverse_endian<T>(&x);
                return xx;
            }
            
            T operator -= (T y) {
                reverse_endian<T>(&x); x -= y;
                T xx = x; reverse_endian<T>(&x);
                return xx;
            }
            
            T operator *= (T y) {
                reverse_endian<T>(&x); x *= y;
                T xx = x; reverse_endian<T>(&x);
                return xx;
            }
            
            T operator /= (T y) {
                reverse_endian<T>(&x); x /= y;
                T xx = x; reverse_endian<T>(&x);
                return xx;
            }
        } __attribute__((packed));
        
        template <class T>
        struct PsdRect {
            T x; T y; T w; T h;
            PsdRect() : x(0), y(0), w(0), h(0){}
            PsdRect(T top, T left, T bottom, T right) : x(0), y(0), w(0), h(0){
                this->x = top; this->y = left;
                this->w = right-left; this->h = bottom-top;
            }
        };

        typedef BigE<psd_uint8_t> psd_uint8_B;
        typedef BigE<psd_uint16_t> psd_uint16_B;
        typedef BigE<psd_uint32_t> psd_uint32_B;
        typedef BigE<psd_uint64_t> psd_uint64_B;
        typedef BigE<psd_int8_t> psd_int8_B;
        typedef BigE<psd_int16_t> psd_int16_B;
        typedef BigE<psd_int32_t> psd_int32_B;
        typedef BigE<psd_int64_t> psd_int64_B;
        
        
    }
}

#endif /* psd_types_hpp */
