//
//  TFOSSAssistantTools.h
//  TFOSSAssistant
//
//  Created by Melvin on 10/27/15.
//  Copyright © 2015 TimeFace. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TFOSSAssistantTools : NSObject

+ (instancetype)sharedTools;

- (NSString *)getMimeType:(NSString *)fileType;
- (NSString *)getMD5StringFromNSString:(NSString *)string;
- (NSString *)getMD5StringFromNSData:(NSData *)data;
- (NSString*)getFileMD5WithPath:(NSString*)path;
@end
