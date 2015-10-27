//
//  TFOSSLibraryManager.m
//  TFOSSAssistant
//
//  Created by Melvin on 10/27/15.
//  Copyright © 2015 TimeFace. All rights reserved.
//

#import "TFOSSLibraryManager.h"
@interface TFOSSLibraryManager () {
}
@end
@implementation TFOSSLibraryManager

+ (TFOSSLibraryManager *) sharedInstance
{
    static TFOSSLibraryManager * sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[TFOSSLibraryManager alloc] init];
    });
    return sharedInstance;
}

- (ALAssetsLibrary *) defaultAssetsLibrary
{
    static dispatch_once_t pred = 0;
    static ALAssetsLibrary *library = nil;
    dispatch_once(&pred, ^{
        library = [[ALAssetsLibrary alloc] init];
    });
    return library;
}
- (void)fixAssetForURL:(NSURL *)assetURL resultBlock:(ALAssetsLibraryAssetForURLResultBlock)resultBlock failureBlock:(ALAssetsLibraryAccessFailureBlock)failureBlock {
    [[self defaultAssetsLibrary] assetForURL:assetURL resultBlock:^(ALAsset *asset) {
        if (asset) {
            resultBlock(asset);
        }
        else {
            [[self defaultAssetsLibrary] enumerateGroupsWithTypes:ALAssetsGroupPhotoStream usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                    if ([result.defaultRepresentation.url isEqual:assetURL]) {
                        *stop = YES;
                        resultBlock(result);
                    }
                }];
            } failureBlock:^(NSError *error) {
                failureBlock(error);
            }];
        }
    } failureBlock:^(NSError *error) {
        [[self defaultAssetsLibrary] enumerateGroupsWithTypes:ALAssetsGroupPhotoStream usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                if ([result.defaultRepresentation.url isEqual:assetURL]) {
                    *stop = YES;
                    resultBlock(result);
                }
            }];
        } failureBlock:^(NSError *error) {
            failureBlock(error);
        }];
    }];
}

@end
