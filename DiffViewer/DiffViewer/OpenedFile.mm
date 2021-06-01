//
//  OpenFile.m
//  DiffViewer
//
//  Created by uchiyama_Macmini on 2019/07/31.
//  Copyright © 2019年 uchiyama_Macmini. All rights reserved.
//

#import "NSDataExt.h"
#import "OpenedFile.h"
#import <XMPTool/XMPTool.h>

@implementation OpenedFile

#define DiffViewDomain @"org.kaz.diffviewer.mac"

#pragma mark -
#pragma mark Initialize

- (id)init
{
    self = [super init];
    if(self){
        _addContours = [NSArray array];
        _delContours = [NSArray array];
        _diffContours = [NSArray array];
        _path = @"";
        _fileName = @"";
        _fileType = @"";
    }
    return self;
}

+ (id)initWithPath:(NSString*)path error:(NSError**)error
{
    OpenedFile *file = [[OpenedFile alloc] init];
    if (!file) {
        *error = [NSError errorWithDomain:DiffViewDomain code:-1 userInfo:@{@"message": [NSString stringWithFormat:@"%@ : %@", NSLocalizedStringFromTable(@"OpenInitialize", @"Error", nil), [KZLibs getFileName:path]]}];
        return nil;
    }
    
    file.path = path;
    file.fileName = [KZLibs getFileName:path];
    if ([KZImage isSupported:path]) {
        file.fileType = [[KZLibs getFileExt:path] lowercaseString];
        
        NSArray* arIn = [XmpSDK getXmpInfo:path error:nil];
        NSString* pre_keyPath = @"xsdkEdit:";
        BOOL isNoTag = YES;
        
        for (NSDictionary* d in arIn) {
            NSData *tmp;
            if (EQ_STR([pre_keyPath stringByAppendingString:@"addContours"], d[@"Path"])) {
                isNoTag = NO;
                tmp = [[NSData alloc] initWithBase64EncodedString:d[@"Value"] options:NSDataBase64DecodingIgnoreUnknownCharacters];
                
                @try {
                    file.addContours = [NSKeyedUnarchiver unarchiveObjectWithData:tmp];
                }
                @catch (NSException* ex) {
                    tmp = [tmp inflate];
                    file.addContours = [NSKeyedUnarchiver unarchiveObjectWithData:tmp];
                }
                
            }
            else if (EQ_STR([pre_keyPath stringByAppendingString:@"delContours"], d[@"Path"])) {
                isNoTag = NO;
                tmp = [[NSData alloc] initWithBase64EncodedString:d[@"Value"] options:NSDataBase64DecodingIgnoreUnknownCharacters];

                @try {
                    file.delContours = [NSKeyedUnarchiver unarchiveObjectWithData:tmp];
                }
                @catch (NSException* ex) {
                    tmp = [tmp inflate];
                    file.delContours = [NSKeyedUnarchiver unarchiveObjectWithData:tmp];
                }
            }
            else if (EQ_STR([pre_keyPath stringByAppendingString:@"diffContours"], d[@"Path"])) {
                isNoTag = NO;
                tmp = [[NSData alloc] initWithBase64EncodedString:d[@"Value"] options:NSDataBase64DecodingIgnoreUnknownCharacters];
                @try {
                    file.diffContours = [NSKeyedUnarchiver unarchiveObjectWithData:tmp];
                }
                @catch (NSException* ex) {
                    tmp = [tmp inflate];
                    file.diffContours = [NSKeyedUnarchiver unarchiveObjectWithData:tmp];
                }
            }
        }
        if (isNoTag) {
            *error = [NSError errorWithDomain:DiffViewDomain code:-2 userInfo:@{@"message": [NSString stringWithFormat:@"%@ : %@", NSLocalizedStringFromTable(@"OpenNoTag", @"Error", nil), file.fileName]}];
            return nil;
        }
        
    }
    else {
        *error = [NSError errorWithDomain:DiffViewDomain code:-3 userInfo:@{@"message": [NSString stringWithFormat:@"%@ : %@", NSLocalizedStringFromTable(@"OpenNotSupport", @"Error", nil), [KZLibs getFileName:path]]}];
        return nil;
    }
    return file;
}

@end
