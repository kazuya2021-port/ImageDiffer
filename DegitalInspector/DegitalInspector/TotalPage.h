//
//  Header.h
//  DigitalInspector
//
//  Created by uchiyama_Macmini on 2019/02/25.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TotalPage : NSValueTransformer
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

