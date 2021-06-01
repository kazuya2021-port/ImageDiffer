//
//  KZJyakuTyuuKyou.h
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/02.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KZJyakuTyuuKyou : NSValueTransformer
//
// 実装必須なクラスメソッド
//
// 変換後の値のクラス
+ (Class)transformedValueClass;

// 逆変換の有無
+ (BOOL)allowsReverseTransformation;

//
// 値変換メソッド
//
// モデル→ビュー変換メソッド（コメント有無による表示色制御）
- (id)transformedValue:(id)value;
@end
