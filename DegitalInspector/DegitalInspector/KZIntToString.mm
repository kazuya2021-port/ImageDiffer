//
//  KZIntToString.m
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/05.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import "KZIntToString.h"

@implementation KZIntToString
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
    // ビュー→モデル変換は行う
    
    return YES;
}

//
// 値変換メソッド
//
// モデル→ビュー変換メソッド（コメント有無による表示色制御）
- (id)transformedValue:(id)value
{
    NSNumber *num = (NSNumber*)value;
    return [NSString stringWithFormat:@"%d", [num intValue]];
}

- (id)reverseTransformedValue:(id)value
{
    return [NSNumber numberWithInt:[(NSString*)value intValue]];
}
@end
