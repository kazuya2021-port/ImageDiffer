//
//  TotalPage.m
//  DigitalInspector
//
//  Created by uchiyama_Macmini on 2019/02/25.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "TotalPage.h"

@implementation TotalPage
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
    return [NSString stringWithFormat:@"%@ P",value];
}
@end
