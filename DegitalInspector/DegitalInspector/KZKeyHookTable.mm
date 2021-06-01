//
//  BAKeyHookTable.m
//  DigitalInspector
//
//  Created by uchiyama_Macmini on 2018/12/19.
//  Copyright © 2018年 uchiyama_Macmini. All rights reserved.
//

#import "KZKeyHookTable.h"

@implementation KZKeyHookTable

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    // Drawing code here.
}



- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)awakeFromNib
{
    
}

- (BOOL)validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event
{
    return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
    NSIndexSet *selectedIndexes = [self selectedRowIndexes];
    NSString *keyCharacters = [theEvent characters];
    
    if([selectedIndexes count]>0) {
        if([keyCharacters length]>0) {
            unichar firstKey = [keyCharacters characterAtIndex:0];
            NSUInteger modifierFlags = [theEvent modifierFlags];
            
            if(firstKey==NSDeleteCharacter||firstKey==NSBackspaceCharacter||firstKey==0xf728) {
                // デリートキー
                [_delegateKey tableViewDeleteKeyPressedOnRows:self index:selectedIndexes];
                return;
            }
            
            else if (firstKey==NSEnterCharacter || firstKey==NSCarriageReturnCharacter) {

                if(modifierFlags & NSShiftKeyMask) {
                    // シフト+エンター
                    [_delegateKey tableViewShiftEnterKeyPressedOnRows:self index:selectedIndexes];
                }
                else {
                    // Enter
                    [_delegateKey tableViewEnterKeyPressedOnRows:self index:selectedIndexes];
                }
                    
            }
            
            
        }
    }
    
    //We don't care about it
    [super keyDown:theEvent];
}
@end
