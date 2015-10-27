//
//  AliUploadHandler.h
//  TFOSSAssistant
//
//  Created by Melvin on 10/27/15.
//  Copyright © 2015 TimeFace. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TFOSSAssistant.h"

@interface TFOSSUploadHandler : NSObject

@property (nonatomic, strong) NSString                *token;
@property (nonatomic, strong) UploadProgressBlock     progressBlock;
@property (nonatomic, strong) UploadCompletionBlock   completionBlock;
@property (nonatomic, assign) NSInteger               tag;
@property (nonatomic, assign) id<TFOSSAssistantDelegate> delegate;

+ (TFOSSUploadHandler*) uploadHandlerWithToken:(NSString *)token
                               progressBlock:(UploadProgressBlock)progressBlock
                             completionBlock:(UploadCompletionBlock)completionBlock
                                         tag:(NSInteger)tag;

+ (TFOSSUploadHandler*) uploadHandlerWithToken:(NSString *)token
                                    delegate:(id<TFOSSAssistantDelegate>)delegate;

@end
