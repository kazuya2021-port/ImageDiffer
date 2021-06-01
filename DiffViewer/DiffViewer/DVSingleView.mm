//
//  DVSingleView.m
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/08/01.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "DVSingleView.h"
#import "DVWholeImageView.h"
#import "DVArrayController.h"
#import "DVChangeSingle.h"
#import "DVChangeDouble.h"

@interface DVSingleView () <NSTableViewDataSource, NSTableViewDelegate, DVWholeImageViewDelegate, DVChangeSingleDelegate>

@property (nonatomic, weak) IBOutlet DVWholeImageView *wholeImage;
@property (nonatomic, weak) IBOutlet NSTableView *diffList;
@property (nonatomic, weak) IBOutlet DVArrayController *diffListData;
@property (nonatomic, weak) IBOutlet DVChangeSingle *singleView;
@property (nonatomic, weak) IBOutlet DVChangeDouble *doubleView;
@property (nonatomic, weak) IBOutlet NSView *replaceView;
@property (nonatomic, strong) NSMutableArray *diffDataSource;
@property (nonatomic, assign) NSPoint lastMovedLoupe;
@end

@implementation DVSingleView

- (void)awakeFromNib
{
    _diffDataSource = [NSMutableArray array];
    _lastMovedLoupe = NSZeroPoint;
    
    
}

- (void)loadView
{
    [super loadView];
    if (!_curFile)
        return;
    
    NSSortDescriptor *descripter = [[NSSortDescriptor alloc] initWithKey:@"No" ascending:YES selector:@selector(compare:)];
    NSSortDescriptor *descripterType = [[NSSortDescriptor alloc] initWithKey:@"Type" ascending:YES selector:@selector(compare:)];
    NSSortDescriptor *descripterArea = [[NSSortDescriptor alloc] initWithKey:@"Area" ascending:YES comparator:^NSComparisonResult(id obj1, id obj2) {
        NSArray *pos1 = [[(NSString*)obj1 stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]
                          componentsSeparatedByString:@","];
        NSArray *pos2 = [[(NSString*)obj2 stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]
                          componentsSeparatedByString:@","];
        
        // order by RectArea
        NSRect r1 = NSMakeRect([pos1[0] doubleValue], [pos1[1] doubleValue], [pos1[2] doubleValue], [pos1[3] doubleValue]);
        NSRect r2 = NSMakeRect([pos2[0] doubleValue], [pos2[1] doubleValue], [pos2[2] doubleValue], [pos2[3] doubleValue]);
        
        double r1Area = r1.size.width * r1.size.height;
        double r2Area = r2.size.width * r2.size.height;
        
        if (r1Area > r2Area) return NSOrderedDescending;
        else if (r1Area < r2Area) return NSOrderedAscending;
        else return NSOrderedSame;
    }];
    for (NSTableColumn *col in _diffList.tableColumns) {
        if (EQ_STR(col.identifier, @"Area")) {
            col.sortDescriptorPrototype = descripterArea;
        }
    }
    [_diffList setSortDescriptors:@[descripter,descripterType]];
    [_diffListData bind:NSContentArrayBinding toObject:self withKeyPath:@"self.diffDataSource" options:nil];
    _diffListData.keys = @[@"No", @"Type", @"Area"];
    
    _diffList.delegate = self;
    _diffList.dataSource = self;
    _wholeImage.image = [[NSImage alloc] initWithContentsOfFile:_curFile.path];
    _wholeImage.delegate = self;
    _wholeImage.file = _curFile;
    
    
    if (_isSingle) {
        [self changeToView:_singleView];
        _singleView.imagePath = _curFile.path;
    }
    else {
        [self changeToView:_doubleView];
        _doubleView.imagePath = _curFile.path;
    }
    
}

#pragma mark -
#pragma mark Local Funcs
- (void)changeToView:(__strong id)view
{
    _replaceView.subviews = @[];
    [_replaceView addSubview:view];
    [view setDelegate:self];
    NSArray* arConst = [self getConstraintFill:(NSView*)view];
    [view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[view superview] addConstraints:arConst];
}

- (NSArray*)getConstraintFill:(NSView*)trgView
{
    NSLayoutConstraint *layTop = [NSLayoutConstraint constraintWithItem:[trgView superview]
                                                              attribute:NSLayoutAttributeTop
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:trgView
                                                              attribute:NSLayoutAttributeTop
                                                             multiplier:1.0
                                                               constant:0.0];
    NSLayoutConstraint *layBotom = [NSLayoutConstraint constraintWithItem:[trgView superview]
                                                                attribute:NSLayoutAttributeBottom
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:trgView
                                                                attribute:NSLayoutAttributeBottom
                                                               multiplier:1.0
                                                                 constant:0.0];
    NSLayoutConstraint *layLead = [NSLayoutConstraint constraintWithItem:[trgView superview]
                                                               attribute:NSLayoutAttributeLeading
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:trgView
                                                               attribute:NSLayoutAttributeLeading
                                                              multiplier:1.0
                                                                constant:0.0];
    NSLayoutConstraint *layTrail = [NSLayoutConstraint constraintWithItem:[trgView superview]
                                                                attribute:NSLayoutAttributeTrailing
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:trgView
                                                                attribute:NSLayoutAttributeTrailing
                                                               multiplier:1.0
                                                                 constant:0.0];
    return @[layTop,layBotom,layLead,layTrail];
}
         
- (BOOL)isContainsPos:(NSNumber*)diffNo
{
    NSMutableSet *set = [[NSMutableSet alloc] init];
    const NSUInteger count = [_diffListData.arrangedObjects count];
    BOOL isDup = NO;
    for(NSUInteger i = 0; i < count; i++)
    {
        NSDictionary *tbl = _diffListData.arrangedObjects[i];
        
        if([set containsObject:diffNo])
        {
            isDup = YES;
            break;
        }
        else
        {
            [set addObject:tbl[@"No"]];
        }
    }
    if([set containsObject:diffNo])
    {
        isDup = YES;
    }
    return isDup;
}

#pragma mark -
#pragma mark Delegate From SingleView
- (void)changeImageViewSize:(NSSize)frameSize
{
    _wholeImage.loupeSizeBase = frameSize;
    [_wholeImage eraseFocusedLayer];
}

#pragma mark -
#pragma mark Delegate From WholeImage
- (void)mouseEnteredArea:(NSUInteger)areaNo
{
    NSLog(@"Mouse entered : %d", (int)areaNo);
}

- (void)mouseExitted
{
    if (_isSingle) {
        [_singleView mouseExitted];
    }
    else {
        [_doubleView mouseExitted];
    }
}

- (void)mouseEnteredAt:(NSPoint)realPos
{
    _lastMovedLoupe = realPos;
    
    if (_isSingle) {
        [_singleView mouseEnteredAt:realPos wholeImage:_wholeImage];
    }
    else {
        [_doubleView mouseEnteredAt:realPos wholeImage:_wholeImage];
    }
}

- (void)mouseMovedAt:(NSPoint)realPos
{
    NSPoint diffMove = NSMakePoint(realPos.x - _lastMovedLoupe.x, realPos.y - _lastMovedLoupe.y);
    _lastMovedLoupe = realPos;
    if (_isSingle) {
        [_singleView mouseMovedAt:diffMove];
    }
    else {
        [_doubleView mouseMovedAt:diffMove];
    }
}


- (void)decideEnteredArea
{
    NSLog(@"decide Area!");
}

- (void)addedTrackInfo:(NSUInteger)areaNo type:(NSString*)type area:(NSRect)rect
{
    NSDictionary *rowInfo = @{@"No" : [NSNumber numberWithUnsignedInteger:areaNo],
                              @"Type" : type,
                              @"Area" : [NSString stringWithFormat:@"%d, %d, %d, %d",
                                         (int)rect.origin.x,(int)rect.origin.y,(int)rect.size.width,(int)rect.size.height],
                              };
    if (![self isContainsPos:[NSNumber numberWithUnsignedInteger:areaNo]]) {
        [_diffListData addObject:rowInfo];
    }
}

#pragma mark -
#pragma mark DataSource From Table
- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    [_diffList setSortDescriptors:tableView.sortDescriptors];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    NSUInteger theCount = [_diffListData.arrangedObjects count];
    return theCount;
}

#pragma mark -
#pragma mark Delegate From Table

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *identifier = tableColumn.identifier;
    NSTableCellView *cell = nil;
    cell = [tableView makeViewWithIdentifier:identifier owner:self];
    cell.identifier = [NSString stringWithFormat:@"%lu",row];
    
    NSArray *arFileInfo = _diffListData.arrangedObjects;
    NSDictionary *theFileInfo = arFileInfo[row];
    cell.textField.stringValue = theFileInfo[tableColumn.identifier];
    
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSTableView *table = notification.object;
    NSIndexSet *rowIndexes = table.selectedRowIndexes;
    NSUInteger row = rowIndexes.lastIndex;
    
    if (row == NSNotFound) return;

    if (row + 1 > table.numberOfRows) {
        [table deselectAll:table.selectedRowIndexes];
    }
    else {
        NSArray *arFileInfo = _diffListData.arrangedObjects;
        NSDictionary *theFileInfo = arFileInfo[row];
        NSArray *arRectStr = [theFileInfo[@"Area"] componentsSeparatedByString:@","];
        NSRect focusRect = NSMakeRect([arRectStr[0] floatValue], [arRectStr[1] floatValue], [arRectStr[2] floatValue], [arRectStr[3] floatValue]);
        [_wholeImage focusArea:focusRect no:[NSString stringWithFormat:@"Focus%d", [theFileInfo[@"Count"] intValue]]];
        
        if (_isSingle) {
            [_singleView focusAt:focusRect wholeImage:_wholeImage];
        }
        else {
            [_doubleView focusAt:focusRect wholeImage:_wholeImage];
        }
    }
}

#pragma mark -
#pragma mark Delegate From DVToolBarController
- (void)appearSingleView
{
    NSLog(@"single!");
    _isSingle = YES;
    [self changeToView:_singleView];
}

- (void)appearDoubleView
{
    NSLog(@"double!");
    _isSingle = NO;
    [self changeToView:_doubleView];
}
@end
