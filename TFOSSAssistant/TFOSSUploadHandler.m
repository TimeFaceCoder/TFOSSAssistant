//
//  AliUploadHandler.m
//  TFOSSAssistant
//
//  Created by Melvin on 10/27/15.
//  Copyright © 2015 TimeFace. All rights reserved.
//

#import "TFOSSUploadHandler.h"

@implementation TFOSSUploadHandler

+ (TFOSSUploadHandler*) uploadHandlerWithToken:(NSString *)token
                               progressBlock:(UploadProgressBlock)progressBlock
                             completionBlock:(UploadCompletionBlock)completionBlock
                                         tag:(NSInteger)tag {
    TFOSSUploadHandler *handler = [TFOSSUploadHandler new];
    handler.token = token;
    handler.tag = tag;
    handler.progressBlock = progressBlock;
    handler.completionBlock = completionBlock;
    
    return handler;
}

+ (TFOSSUploadHandler*) uploadHandlerWithToken:(NSString *)token
                                    delegate:(id<TFOSSAssistantDelegate>)delegate {
    TFOSSUploadHandler *handler = [TFOSSUploadHandler new];
    
    handler.token = token;
    handler.delegate = delegate;
    
    return handler;
}

@end
