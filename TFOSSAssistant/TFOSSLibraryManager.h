//
//  TFOSSLibraryManager.h
//  TFOSSAssistant
//
//  Created by Melvin on 10/27/15.
//  Copyright © 2015 TimeFace. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>


/**
 *  The object that manages the Library operations
 */
@interface TFOSSLibraryManager : NSObject {
}



+ (TFOSSLibraryManager *) sharedInstance;

/**
 *  The default Asset Library
 *
 *  @return Return the default Asset Library
 */
- (ALAssetsLibrary *) defaultAssetsLibrary;


- (void)fixAssetForURL:(NSURL *)assetURL
           resultBlock:(ALAssetsLibraryAssetForURLResultBlock)resultBlock
          failureBlock:(ALAssetsLibraryAccessFailureBlock)failureBlock;
@end
