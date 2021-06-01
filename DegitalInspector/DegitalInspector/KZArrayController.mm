//
//  KZArrayController.m
//  DigitalInspector
//
//  Created by uchiyama_Macmini on 2018/12/19.
//  Copyright © 2018年 uchiyama_Macmini. All rights reserved.
//

#import "KZArrayController.h"
#import "KZKeyHookTable.h"

@interface KZArrayController()
@property (nonatomic, weak) IBOutlet KZKeyHookTable *dataTable;
@property (nonatomic) BOOL skipFlag;
@end

@implementation KZArrayController
#pragma mark -
#pragma mark Init/Dealloc/Finalize

- (id) init
{
    self = [super init];
    if (self != nil) {
        self.modified = NO;
    }
    return self;
}

#pragma mark -
#pragma mark Private utilities

- (void)_setArrangedObject:(id)object value:(id)value forKeyPath:(NSString*)keyPath
{
    // "<null>" -> NSNull
    [object setValue:value forKeyPath:keyPath];
}

#pragma mark -
#pragma mark KVO callback
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    self.modified = YES;
    if (change) {
        //NSLog(@"keyPath: %@, change: %@", keyPath, change);
        id value = [change objectForKey:NSKeyValueChangeOldKey];
        if (value == [NSNull null]) {
            value = nil;
        }
    }
}

#pragma mark -
#pragma mark Overridden methods

- (void)_addObserverFor:(NSArray*)objects
{
    // TODO checking dup addition
    //NSLog(@"add Observe ArrayController");
    for (id object in objects) {
        NSArray* ks = _keys;
        
        if (!ks) {
            return;
        }
        for (NSString* key in ks) {
            [object addObserver:self
                     forKeyPath:key
                        options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
                        context:nil];
        }
    }
}

- (void)_removeObserverFor:(NSArray*)objects
{
    //NSLog(@"remove Observe ArrayController");
    for (id object in objects) {
        NSArray* ks = _keys;
        if (!ks) {
            return;
        }
        for (NSString* key in ks) {
            [object removeObserver:self
                        forKeyPath:key];
        }
    }
}

- (void)insertObject:(id)object atArrangedObjectIndex:(NSUInteger)index
{
    //NSLog(@"%@", [self content]);
    if (!_skipFlag) {
        [self _addObserverFor:[NSArray arrayWithObject:object]];
        //NSLog(@"info: %@", [object observationInfo]);
    }
    [super insertObject:object atArrangedObjectIndex:index];
    self.modified = YES;
}

- (void)insertObjects:(NSArray *)objects atArrangedObjectIndexes:(NSIndexSet *)indexes
{
    [self _addObserverFor:objects];
    
    _skipFlag = YES;
    [super insertObjects:objects atArrangedObjectIndexes:indexes];
    _skipFlag = NO;
    self.modified = YES;
}

- (void)removeObjectAtArrangedObjectIndex:(NSUInteger)index
{
    NSPredicate* oldPredicate = self.filterPredicate;
    self.filterPredicate = nil;
    if (!_skipFlag) {
        
        NSArray* arrangedObjects = [self arrangedObjects];
        id object = [arrangedObjects objectAtIndex:index];
        
        [self _removeObserverFor:[NSArray arrayWithObject:object]];
    }
    [super removeObjectAtArrangedObjectIndex:index];
    self.filterPredicate = oldPredicate;
    self.modified = YES;
}

- (void)removeObjectsAtArrangedObjectIndexes:(NSIndexSet *)indexes
{
    NSPredicate* oldPredicate = self.filterPredicate;
    self.filterPredicate = nil;
    NSArray* arrangedObjects = [self arrangedObjects];
    NSMutableArray* insertObjects = [NSMutableArray arrayWithCapacity:[indexes count]];
    
    [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        id object = [arrangedObjects objectAtIndex:idx];
        [insertObjects addObject:object];
    }];
    [self _removeObserverFor:insertObjects];
    
    _skipFlag = YES;
    [super removeObjectsAtArrangedObjectIndexes:indexes];
    _skipFlag = NO;
    self.filterPredicate = oldPredicate;
    self.modified = YES;
}

- (void)setContent:(id)content
{
    NSPredicate* oldPredicate = self.filterPredicate;
    self.filterPredicate = nil;
    [self _addObserverFor:content];
    [super setContent:content];
    self.filterPredicate = oldPredicate;
}

- (void)addObjects:(NSArray *)objects
{
    NSPredicate* oldPredicate = self.filterPredicate;
    self.filterPredicate = nil;
    [super addObjects:objects];
    [self _addObserverFor:objects];
    self.filterPredicate = oldPredicate;
    self.modified = YES;
}

- (void)addObject:(id)object
{
    NSPredicate* oldPredicate = self.filterPredicate;
    self.filterPredicate = nil;
    [super addObject:object];
    [self _addObserverFor:object];
    self.filterPredicate = oldPredicate;
    self.modified = YES;
}

#pragma mark -
#pragma mark Filtering Content
- (void)setSortDescriptors:(NSArray *)sortDescriptors
{
    //NSLog(@"%s|%@", __PRETTY_FUNCTION__, sortDescriptors);
    [super setSortDescriptors:sortDescriptors];
    self.modified = YES;
}



@end
