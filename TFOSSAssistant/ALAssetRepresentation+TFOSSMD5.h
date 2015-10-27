//
//  ALAssetRepresentation+TFOSSMD5.h
//  TFOSSAssistant
//
//  Created by Melvin on 10/27/15.
//  Copyright © 2015 TimeFace. All rights reserved.
//


#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface ALAssetRepresentation (TFOSSMD5)

- (NSString *)hashString;
- (NSString *)getMD5String;

@end
