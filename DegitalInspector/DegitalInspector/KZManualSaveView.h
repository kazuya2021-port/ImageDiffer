//
//  KZManualSaveView.h
//  DegitalInspector
//
//  Created by 内山和也 on 2019/04/10.
//  Copyright (c) 2019年 内山和也. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KZTextField.h"
@interface KZManualSaveView : NSObject
@property (nonatomic, weak) IBOutlet KZTextField *saveFolderField;
- (void)appearView;
- (void)hideView;
@end
