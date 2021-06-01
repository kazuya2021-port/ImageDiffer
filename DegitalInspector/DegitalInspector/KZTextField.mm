//
//  KZTextField.m
//  DegitalInspector
//
//  Created by uchiyama_Macmini on 2019/07/11.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "KZTextField.h"

@implementation KZTextField

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (BOOL)becomeFirstResponder
{
    BOOL returnValue = [super becomeFirstResponder];
    if (returnValue) {
        //do something here when this becomes first responder
    }
    
    return returnValue;
}

- (BOOL)resignFirstResponder
{
    BOOL returnValue = [super resignFirstResponder];
    if(returnValue){
        //do something when resigns first responder
        
    }
    return returnValue;
}
@end
