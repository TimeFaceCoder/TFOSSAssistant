//
//  TFOSSAssistant.h
//  TFOSSAssistant
//
//  Created by Melvin on 10/27/15.
//  Copyright © 2015 TimeFace. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UploadModel : NSObject
/**
 *  路径
 */
@property (nonatomic ,strong) NSURL              *URL;
/**
 *  iOS 8 +
 */
@property (nonatomic ,copy  ) NSString           *localIdentifier;
/**
 *  扩展名
 */
@property (nonatomic ,copy  ) NSString           *extension;
/**
 *  文件MD5
 */
@property (nonatomic ,copy  ) NSString           *md5;
/**
 * 临时文件地址
 */
@property (nonatomic ,copy  ) NSString           *cachePath;

@property (nonatomic ,copy  ) NSString           *objectKey;

@property (nonatomic ,assign) CGFloat width;

@property (nonatomic ,assign) CGFloat height;

@end

typedef void(^UploadProgressBlock)(float progress,NSString *token);
typedef void (^UploadCompletionBlock)(BOOL success, id response);

@protocol TFOSSAssistantDelegate <NSObject>
- (void) uploadAssistantDidProgress:(float)progress token:(NSString *)token;
- (void) uploadAssistantDidFinish:(BOOL)success response:(id)response;
@end

@interface TFOSSAssistant : NSObject

+ (instancetype)sharedWithBucket:(NSString *)bucket
                        endPoint:(NSString *)endPoint
                          hostId:(NSString *)hostId;

/**
 *  上传文件至阿里云服务器
 *
 *  @param modelList     文件列表
 *  @param token         业务系统token
 *  @param progressBlock 回调
 */
- (void)uploadFiles2AliOSS:(NSArray *)modelList
                     token:(NSString *)token
             progressBlock:(UploadProgressBlock)progressBlock;
/**
 *  上传数据至阿里云服务器
 *
 *  @param data      NSData
 *  @param objectKey objectKey
 */
- (void)uploadData2AliOSS:(NSData *)data
                    token:(NSString *)token
                objectKey:(NSString *)objectKey
            progressBlock:(UploadProgressBlock)progressBlock
          completionBlock:(UploadCompletionBlock)completionBlock;


- (void) attachListener:(id<TFOSSAssistantDelegate>)listener token:(NSString *)token;
- (void) detachListener:(id<TFOSSAssistantDelegate>)listener;


@end
