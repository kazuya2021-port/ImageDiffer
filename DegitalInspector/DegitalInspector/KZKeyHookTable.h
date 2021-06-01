//
//  BAKeyHookTable.h
//  DigitalInspector
//
//  Created by uchiyama_Macmini on 2018/12/19.
//  Copyright © 2018年 uchiyama_Macmini. All rights reserved.
//

#import <Foundation/Foundation.h>

@class KZKeyHookTable;

@protocol KZKeyHookTableDelegate
@optional
- (void)tableViewDeleteKeyPressedOnRows:(KZKeyHookTable *)table index:(NSIndexSet *)idx;
- (void)tableViewEnterKeyPressedOnRows:(KZKeyHookTable *)table index:(NSIndexSet *)idx;
- (void)tableViewShiftEnterKeyPressedOnRows:(KZKeyHookTable *)table index:(NSIndexSet *)idx;
@end

@interface KZKeyHookTable : NSTableView
@property(nonatomic, assign) id <KZKeyHookTableDelegate> delegateKey;
@end


