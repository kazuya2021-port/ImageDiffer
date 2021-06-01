//
//  DVTabViewController.m
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/07/31.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "DVTabViewController.h"
#import "PSMTabBarControl/PSMTabBarControl.h"
#import "PSMTabBarControl/PSMTabStyle.h"
#import "DVSingleView.h"
#import "DVToolBarController.h"

@interface DVTabViewController()<NSTabViewDelegate>
@property (nonatomic, weak) IBOutlet NSTabView *mainTab;
@property (nonatomic, weak) IBOutlet DVToolBarController *toolBar;
@property (nonatomic, weak) IBOutlet PSMTabBarControl *tabBarView;
@property (nonatomic, retain) NSMutableDictionary *tblDiffViewController;
@property (nonatomic, assign) NSUInteger tabCount;
@end

@implementation DVTabViewController
#pragma mark -
#pragma mark Local Funcs
- (void)setConstraintTabBar
{
    NSLayoutConstraint *layTop = [NSLayoutConstraint constraintWithItem:_tabBarView
                                                              attribute:NSLayoutAttributeTop
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:[_tabBarView superview]
                                                              attribute:NSLayoutAttributeTop
                                                             multiplier:1.0
                                                               constant:0.0];
    NSLayoutConstraint *layBotom = [NSLayoutConstraint constraintWithItem:_tabBarView
                                                                attribute:NSLayoutAttributeBottom
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_mainTab
                                                                attribute:NSLayoutAttributeTop
                                                               multiplier:1.0
                                                                 constant:0.0];
    NSLayoutConstraint *layLead = [NSLayoutConstraint constraintWithItem:[_tabBarView superview]
                                                               attribute:NSLayoutAttributeLeading
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:_tabBarView
                                                               attribute:NSLayoutAttributeLeading
                                                              multiplier:1.0
                                                                constant:0.0];
    NSLayoutConstraint *layTrail = [NSLayoutConstraint constraintWithItem:[_tabBarView superview]
                                                                attribute:NSLayoutAttributeTrailing
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_tabBarView
                                                                attribute:NSLayoutAttributeTrailing
                                                               multiplier:1.0
                                                                 constant:0.0];
    NSArray *constraints = @[layTop,layBotom,layLead,layTrail];
    [_mainTab setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[_mainTab superview] addConstraints:constraints];
}

- (void)setConstraintTab
{
    NSLayoutConstraint *layTop = [NSLayoutConstraint constraintWithItem:_mainTab
                                                              attribute:NSLayoutAttributeTop
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:_tabBarView
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1.0
                                                               constant:0.0];
    NSLayoutConstraint *layBotom = [NSLayoutConstraint constraintWithItem:_mainTab
                                                                attribute:NSLayoutAttributeBottom
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:[_mainTab superview]
                                                                attribute:NSLayoutAttributeBottom
                                                               multiplier:1.0
                                                                 constant:0.0];
    NSLayoutConstraint *layLead = [NSLayoutConstraint constraintWithItem:[_mainTab superview]
                                                               attribute:NSLayoutAttributeLeading
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:_mainTab
                                                               attribute:NSLayoutAttributeLeading
                                                              multiplier:1.0
                                                                constant:0.0];
    NSLayoutConstraint *layTrail = [NSLayoutConstraint constraintWithItem:[_mainTab superview]
                                                                attribute:NSLayoutAttributeTrailing
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:_mainTab
                                                                attribute:NSLayoutAttributeTrailing
                                                               multiplier:1.0
                                                                 constant:0.0];
    NSArray *constraints = @[layTop,layBotom,layLead,layTrail];
    [_mainTab setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[_mainTab superview] addConstraints:constraints];
}


- (void)setConstraint:(NSView**)trgView
{
    NSLayoutConstraint *layTop = [NSLayoutConstraint constraintWithItem:[*trgView superview]
                                                              attribute:NSLayoutAttributeTop
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:*trgView
                                                              attribute:NSLayoutAttributeTop
                                                             multiplier:1.0
                                                               constant:0.0];
    NSLayoutConstraint *layBotom = [NSLayoutConstraint constraintWithItem:[*trgView superview]
                                                                attribute:NSLayoutAttributeBottom
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:*trgView
                                                                attribute:NSLayoutAttributeBottom
                                                               multiplier:1.0
                                                                 constant:0.0];
    NSLayoutConstraint *layLead = [NSLayoutConstraint constraintWithItem:[*trgView superview]
                                                               attribute:NSLayoutAttributeLeading
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:*trgView
                                                               attribute:NSLayoutAttributeLeading
                                                              multiplier:1.0
                                                                constant:0.0];
    NSLayoutConstraint *layTrail = [NSLayoutConstraint constraintWithItem:[*trgView superview]
                                                                attribute:NSLayoutAttributeTrailing
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:*trgView
                                                                attribute:NSLayoutAttributeTrailing
                                                               multiplier:1.0
                                                                 constant:0.0];
    NSArray *constraints = @[layTop,layBotom,layLead,layTrail];
    [*trgView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[*trgView superview] addConstraints:constraints];
}

#pragma mark -
#pragma mark Initialize

- (id)init
{
    self = [super init];
    if(self){
        _tblDiffViewController = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark -
#pragma mark Public Func
- (void)loadView
{
    _mainTab.drawsBackground = NO;
    _mainTab.tabViewType = NSNoTabsNoBorder;
    
    
    //[(NSButton*)_tabBarView.addTabButton setTarget:self];
    //[(NSButton*)_tabBarView.addTabButton setAction:@selector(addNewDiff:)];
    _tabBarView.canCloseOnlyTab = YES;
    [_tabBarView setStyleNamed:@"Metal"];
    
    _tabBarView.showAddTabButton = NO;
    _tabBarView.allowsBackgroundTabClosing = YES;
    _tabBarView.hideForSingleTab = NO;
    _tabBarView.cellMinWidth = 60;
    _tabBarView.orientation = PSMTabBarHorizontalOrientation;
    _tabBarView.sizeCellsToFit = NO;
    _tabBarView.useOverflowMenu = YES;
    
    
    [_mainTab setDelegate:_tabBarView];
    
    [_tabBarView setDelegate:self];
    
    [_window.contentView addSubview:_mainTab];
    [_window.contentView addSubview:_tabBarView];

}

#pragma mark -
#pragma mark Delegate
- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    AppDelegate *del = NSApplication.sharedApplication.delegate;
    del.currentFile =  tabViewItem.identifier;
}

- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
    AppDelegate *del = NSApplication.sharedApplication.delegate;
    [del.arOpenFiles removeObject:tabViewItem.identifier];
    return YES;
}

- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
    AppDelegate *del = NSApplication.sharedApplication.delegate;
    _tabCount = del.arOpenFiles.count;
}

- (NSArray *)allowedDraggedTypesForTabView:(NSTabView *)aTabView
{
    return [NSArray arrayWithObjects:NSStringPboardType, nil];
}

- (void)tabView:(NSTabView *)aTabView acceptedDraggingInfo:(id <NSDraggingInfo>)draggingInfo onTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSLog(@"acceptedDraggingInfo: %@ onTabViewItem: %@", [[draggingInfo draggingPasteboard] stringForType:[[[draggingInfo draggingPasteboard] types] objectAtIndex:0]], [tabViewItem label]);
}

- (NSMenu *)tabView:(NSTabView *)aTabView menuForTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSLog(@"menuForTabViewItem: %@", [tabViewItem label]);
    return nil;
}

- (BOOL)tabView:(NSTabView*)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem fromTabBar:(PSMTabBarControl *)tabBarControl
{
    return YES;
}

- (BOOL)tabView:(NSTabView*)aTabView shouldDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)tabBarControl
{
    return YES;
}

- (void)tabView:(NSTabView*)aTabView didDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)tabBarControl
{
    NSLog(@"didDropTabViewItem: %@ inTabBar: %@", [tabViewItem label], tabBarControl);
}


- (NSImage *)tabView:(NSTabView *)aTabView imageForTabViewItem:(NSTabViewItem *)tabViewItem offset:(NSSize *)offset styleMask:(NSUInteger *)styleMask
{
    NSLog(@"imageForTabViewItem: %@", [tabViewItem label]);
    // grabs whole window image
    NSImage *viewImage = [[NSImage alloc] init];
    NSRect contentFrame = [_window.contentView frame];
    [_window.contentView lockFocus];
    NSBitmapImageRep *viewRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:contentFrame];
    [viewImage addRepresentation:viewRep];
    [_window.contentView unlockFocus];
    
    // grabs snapshot of dragged tabViewItem's view (represents content being dragged)
    NSView *viewForImage = [tabViewItem view];
    NSRect viewRect = [viewForImage frame];
    NSImage *tabViewImage = [[NSImage alloc] initWithSize:viewRect.size];
    [tabViewImage lockFocus];
    [viewForImage drawRect:[viewForImage bounds]];
    [tabViewImage unlockFocus];
    
    [viewImage lockFocus];
    NSPoint tabOrigin = [_mainTab frame].origin;
    tabOrigin.x += 10;
    tabOrigin.y += 13;
    [tabViewImage drawAtPoint:tabOrigin fromRect:[_mainTab frame] operation:NSCompositeSourceOver fraction:1.0];
    
    [viewImage unlockFocus];
    
    /*
     
     //draw over where the tab bar would usually be
     NSRect tabFrame = [_tabBarView frame];
     [viewImage lockFocus];
     [[NSColor windowBackgroundColor] set];
     NSRectFill(tabFrame);
     //draw the background flipped, which is actually the right way up
     NSAffineTransform *transform = [NSAffineTransform transform];
     [transform scaleXBy:1.0 yBy:-1.0];
     [transform concat];
     tabFrame.origin.y = -tabFrame.origin.y - tabFrame.size.height;
     [(id <PSMTabStyle>)[(PSMTabBarControl *)[aTabView delegate] style] drawBackgroundInRect:tabFrame];
     [transform invert];
     [transform concat];
     
     [viewImage unlockFocus];
     
     
     */
    return viewImage;
}

- (void)tabView:(NSTabView *)aTabView closeWindowForLastTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSLog(@"closeWindowForLastTabViewItem: %@", [tabViewItem label]);
}

- (void)tabView:(NSTabView *)aTabView tabBarDidHide:(PSMTabBarControl *)tabBarControl
{
    NSLog(@"tabBarDidHide: %@", tabBarControl);
}

- (void)tabView:(NSTabView *)aTabView tabBarDidUnhide:(PSMTabBarControl *)tabBarControl
{
    NSLog(@"tabBarDidUnhide: %@", tabBarControl);
}

- (NSString *)tabView:(NSTabView *)aTabView toolTipForTabViewItem:(NSTabViewItem *)tabViewItem
{
    return [tabViewItem label];
}

- (NSString *)accessibilityStringForTabView:(NSTabView *)aTabView objectCount:(NSInteger)objectCount
{
    return (objectCount == 1) ? @"item" : @"items";
}

#pragma mark -
#pragma mark Action
- (void)addNewDiff:(OpenedFile*)file
{
    if (!file) return;
    
    NSString *label = file.fileName;
    NSTabViewItem *mainTabItem = [[NSTabViewItem alloc] initWithIdentifier:file];
    
    mainTabItem.label = label;
    NSView *theView = nil;
    DVSingleView *dv = [[DVSingleView alloc] initWithNibName:@"DVSingleView" bundle:nil];
    
    if (EQ_STR(file.fileType, @"psd") || EQ_STR(file.fileType, @"gif")) {
        // psdかgifならレイヤー情報あり
        dv.isSingle = NO;
    }
    else {
        // レイヤー情報なし
        dv.isSingle = YES;
    }
    dv.curFile = file;
    [dv loadView];
    theView = [dv view];
    _toolBar.delegate = dv;
    [mainTabItem.view addSubview:theView];
    [_mainTab addTabViewItem:mainTabItem];
    [_mainTab selectTabViewItem :mainTabItem];
    
    [self setConstraint:&theView];
    [self setConstraintTabBar];
    [self setConstraintTab];
    //[tblDiffViewController setObject:dv forKey:countStr];
    //[dv setFocus];
}
@end
