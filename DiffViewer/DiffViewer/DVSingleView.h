//
//  DVSingleView.h
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/08/01.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DVToolBarController.h"

@class DVToolBarController;
@interface DVSingleView : NSViewController <DVToolBarControllerDelegate>
@property(nonatomic, retain) OpenedFile *curFile;
@property(nonatomic, assign) BOOL isSingle;
@end
