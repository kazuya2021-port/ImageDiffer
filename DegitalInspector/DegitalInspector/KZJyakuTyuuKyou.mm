//
//  KZJyakuTyuuKyou.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/02.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZJyakuTyuuKyou.h"

@implementation KZJyakuTyuuKyou
//
// 実装必須なクラスメソッド
//
// 変換後の値のクラス
+ (Class)transformedValueClass
{
    // 表示色の制御なのでNSColorのクラスを返す
    return [NSString class];
}

// 逆変換の有無
+ (BOOL)allowsReverseTransformation
{
    // ビュー→モデル変換は行わない
    
    return NO;
}

//
// 値変換メソッド
//
// モデル→ビュー変換メソッド（コメント有無による表示色制御）
- (id)transformedValue:(id)value
{
    NSNumber *num = (NSNumber*)value;
    switch ([num intValue]) {
        case 0:
            return NSLocalizedStringFromTable(@"NoizeReductionNone", @"Preference", nil);
            
        case 1:
            return NSLocalizedStringFromTable(@"NoizeReductionLow", @"Preference", nil);;
            
        case 2:
            return NSLocalizedStringFromTable(@"NoizeReductionMid", @"Preference", nil);;
            
        case 3:
            return NSLocalizedStringFromTable(@"NoizeReductionHigh", @"Preference", nil);;
            
        default:
            break;
    }
    return nil;
}

@end
