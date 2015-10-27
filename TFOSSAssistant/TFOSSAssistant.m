//
//  TFOSSAssistant.m
//  TFOSSAssistant
//
//  Created by Melvin on 10/27/15.
//  Copyright © 2015 TimeFace. All rights reserved.
//

#import "TFOSSAssistant.h"
#import <EGOCache/EGOCache.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AliyunOSSiOS/OSSService.h>
#import <AliyunOSSiOS/OSSCompat.h>
#import <Photos/Photos.h>
#import "TFOSSLibraryManager.h"
#import "TFOSSUploadHandler.h"
#import "TFOSSAssistantTools.h"
#import "ALAssetRepresentation+TFOSSMD5.h"

typedef void (^ActionCompletionBlock)(BOOL result, id response);

@implementation UploadModel

@end

const static CGFloat kCompressionQuality = 0.99;
const static NSString  *kCachePath       = @"kCachePath";
const static NSString  *kSizeList        = @"kSizeList";
const static NSString  *kMD5List         = @"kMD5List";

@interface TFOSSAssistant()<NSURLSessionDelegate>
@property (nonatomic ,copy) NSString *authSTS;
@property (nonatomic ,copy) NSString *bucket;
@property (nonatomic ,copy) NSString *endPoint;
@property (nonatomic ,copy) NSString *hostId;

@property (nonatomic, strong) NSString              *diskCachePath;
@property (nonatomic, strong) NSMutableDictionary   *uploadOperations;
@property (nonatomic, strong) NSMutableDictionary   *uploadFailure;
@property (nonatomic, strong) NSMutableDictionary   *uploadHandlers;
@property (nonatomic, strong) PHCachingImageManager *imageManager;

@property (nonatomic) float totalCount;
@property (nonatomic) float currentCount;



@end

@implementation TFOSSAssistant{
    OSSClient                   *_client;
    float                       _totalBytesExpectedToWrite;
    float                       _totalBytesWritten;
}

- (id)init {
    self = [super init];
    if (self) {
        [self initOSSService];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >=  __IPHONE_8_0
            self.imageManager = [[PHCachingImageManager alloc] init];
#endif
        _authSTS = @"https://auth.timeface.cn/aliyun/sts";
        self.uploadOperations      = [NSMutableDictionary dictionary];
        self.uploadHandlers        = [NSMutableDictionary dictionary];
        _totalBytesExpectedToWrite = 0;
        _totalBytesWritten         = 0;
        _totalCount                = 0;
        _currentCount              = 0;
        _diskCachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"cn.timeface.upload.cache"];
       dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            if ([[EGOCache globalCache] hasCacheForKey:@"kUploadQueue"]) {
                //                self.uploadOperations = (NSMutableDictionary *)[[EGOCache globalCache] objectForKey:kUploadQueue];
                if (self.uploadOperations) {
                    //启动上次未完成上传任务
                    //                    [self startAllTask];
                }
            }
        });
        //监听APP进入后台通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        //监听APP恢复通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)progressUpdate:(NSDictionary *)change {
    NSLog(@"%s, change:%@",__func__,change);
}

- (void)progressUpdateWithToken:(NSString *)token {
    float progress = _currentCount / _totalCount;
    NSLog(@"_currentCount:%@ _totalCount:%@  progress:%.2f",@(_currentCount),@(_totalCount),progress);
    GlobalProgressBlock(progress,token,self);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_uploadOperations removeAllObjects];
    _uploadOperations = nil;
    [_uploadHandlers removeAllObjects];
    _uploadHandlers = nil;
    _client      = nil;
    NSLog(@"%s",__func__);
}


#pragma mark -
#pragma mark Global Blocks

void (^GlobalProgressBlock)(float progress, NSString *token, TFOSSAssistant* self) =
^(float progress, NSString *token, TFOSSAssistant* self)
{
    NSMutableArray *handlers = [self.uploadHandlers objectForKey:token];
    //Inform the handlers
    [handlers enumerateObjectsUsingBlock:^(TFOSSUploadHandler *handler, NSUInteger idx, BOOL *stop) {
        if(handler.progressBlock)
            handler.progressBlock(progress, token);
        if([handler.delegate respondsToSelector:@selector(uploadAssistantDidProgress:token:)])
            [handler.delegate uploadAssistantDidProgress:progress token:token];
    }];
};
void (^GlobalCompletionBlock)(BOOL success, id response, NSString *token, TFOSSAssistant* self) =
^(BOOL success, id response, NSString *token, TFOSSAssistant* self)
{
    NSMutableArray *handlers = [self.uploadHandlers objectForKey:token];
    //Inform the handlers
    [handlers enumerateObjectsUsingBlock:^(TFOSSUploadHandler *handler, NSUInteger idx, BOOL *stop) {
        if(handler.completionBlock)
            handler.completionBlock(success, response);
        
        if([handler.delegate respondsToSelector:@selector(uploadAssistantDidFinish:response:)])
            [handler.delegate uploadAssistantDidFinish:success response:response];
        
    }];
    
    //Remove the upload handlers
    [self.uploadHandlers removeObjectForKey:token];
    
    //Remove the upload operation
    [self.uploadHandlers removeObjectForKey:token];
};



#pragma mark -
#pragma mark Public
+ (instancetype)sharedWithBucket:(NSString *)bucket endPoint:(NSString *)endPoint hostId:(NSString *)hostId {
    static TFOSSAssistant* uploadAssistant = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!uploadAssistant) {
            uploadAssistant = [[self alloc] init];
            uploadAssistant.bucket = bucket;
            uploadAssistant.endPoint = endPoint;
            uploadAssistant.hostId = hostId;
        }
    });
    return uploadAssistant;
}


- (void) attachListener:(id<TFOSSAssistantDelegate>)listener token:(NSString *)token {
    [self removeHandlerWithListener:listener];
    NSMutableArray *handlers = [self.uploadHandlers objectForKey:token];
    if (!handlers)
        handlers = [NSMutableArray new];
    
    TFOSSUploadHandler *handler = [TFOSSUploadHandler uploadHandlerWithToken:token delegate:listener];
    [handlers addObject:handler];
    [self.uploadHandlers setObject:handlers forKey:token];
}

- (void) detachListener:(id<TFOSSAssistantDelegate>)listener {
    [self removeHandlerWithListener:listener];
}


- (void)uploadFiles2AliOSS:(NSArray *)modelList
                     token:(NSString *)token
             progressBlock:(UploadProgressBlock)progressBlock {
    
    if([self isUploadingWithToken:token])
        return;
    //缓存到任务队列
    [self.uploadOperations setObject:modelList forKey:token];
    [[EGOCache globalCache] setObject:self.uploadOperations forKey:token];
    _totalCount = [modelList count];
    __weak __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        void(^uploadImageDataToAliyun)(NSData * _Nullable imageData ,NSString * _Nullable objectKey) = ^(NSData * _Nullable imageData,NSString * _Nullable objectKey) {
            //update nsdata
            [weakSelf objectExist:objectKey
                  completionBlock:^(BOOL result, id response)
             {
                 if (!result) {
                     //不存在
                     OSSPutObjectRequest * put = [OSSPutObjectRequest new];
                     // required fields
                     put.contentType = [[TFOSSAssistantTools sharedTools] getMimeType:@"jpg"];
                     put.bucketName = self.bucket;
                     put.objectKey = objectKey;
                     put.uploadingData = imageData;
                     // optional fields
                     put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
                         
                     };
                     OSSTask *putTask = [_client putObject:put];
                     [putTask continueWithBlock:^id(OSSTask *task) {
                         if (!task.error) {
                             NSLog(@"upload object success!");
                             _currentCount +=1;
                             [weakSelf progressUpdateWithToken:token];
                         } else {
                             NSLog(@"upload object failed, error: %@" , task.error);
                         }
                         dispatch_semaphore_signal(semaphore);
                         return nil;
                     }];
                 }
                 else {
                     NSLog(@"object already Exist!");
                     _currentCount +=1;
                     [weakSelf progressUpdateWithToken:token];
                     dispatch_semaphore_signal(semaphore);
                 }
             }];
        };
        __block NSString *objectKey = nil;
        void(^uploadDataToAliyun)(UploadModel *model) = ^(UploadModel *model) {
            //update nsdata
            [weakSelf objectExist:objectKey
                  completionBlock:^(BOOL result, id response)
             {
                 if (!result) {
                     //不存在
                     OSSPutObjectRequest * put = [OSSPutObjectRequest new];
                     // required fields
                     put.contentType = [[TFOSSAssistantTools sharedTools] getMimeType:model.extension];
                     put.bucketName = self.bucket;
                     put.objectKey = objectKey;
                     put.uploadingFileURL = [NSURL URLWithString:model.cachePath];
                     // optional fields
                     put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
                     };
                     OSSTask *putTask = [_client putObject:put];
                     [putTask continueWithBlock:^id(OSSTask *task) {
                         if (!task.error) {
                             NSLog(@"upload object success!");
                             _currentCount +=1;
                             [weakSelf progressUpdateWithToken:token];
                             //remove file from disk
                             [[NSFileManager defaultManager] removeItemAtPath:model.cachePath
                                                                        error:NULL];
                         } else {
                             NSLog(@"upload object failed, error: %@" , task.error);
                         }
                         dispatch_semaphore_signal(semaphore);
                         return nil;
                     }];
                 }
                 else {
                     NSLog(@"object already Exist!");
                     _currentCount +=1;
                     [weakSelf progressUpdateWithToken:token];
                     dispatch_semaphore_signal(semaphore);
                 }
             }];
        };
        for (UploadModel *model in modelList) {
            
            if (model.localIdentifier.length) {
                //Photos
                @autoreleasepool {
                    PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[model.localIdentifier]
                                                                                        options:nil];
                    objectKey = [NSString stringWithFormat:@"%@/%@.%@",@"melvin",model.md5,model.extension];
                    model.objectKey = objectKey;
                    if ([assetsFetchResult count] > 0) {
                        PHAsset *asset                      = [assetsFetchResult objectAtIndex:0];
                        PHImageRequestOptions *imageOptions = [[PHImageRequestOptions alloc] init];
                        imageOptions.deliveryMode           = PHImageRequestOptionsDeliveryModeHighQualityFormat;
                        imageOptions.resizeMode             = PHImageRequestOptionsResizeModeNone;
                        imageOptions.synchronous            = YES;
                        imageOptions.networkAccessAllowed   = YES;
                        imageOptions.progressHandler =  ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
                            NSLog(@"%f", progress);
                        };
                        model.width = asset.pixelWidth;
                        model.height = asset.pixelHeight;
                        
                        [[PHImageManager defaultManager] requestImageDataForAsset:asset options:imageOptions resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
                            NSLog(@"info2:%@",info);
                            if (imageData) {
                                uploadImageDataToAliyun(imageData,objectKey);
                            }
                            dispatch_semaphore_signal(semaphore);
                        }];
                    }
                }
            }
            else {
                if (!model.URL) {
                    //无URL情况
                    dispatch_semaphore_signal(semaphore);
                }
                else {
                    if ([[[model.URL scheme] lowercaseString] isEqualToString:@"assets-library"]) {
                        //本地相册,copy至临时目录
                        [[TFOSSLibraryManager sharedInstance] fixAssetForURL:model.URL
                                                              resultBlock:^(ALAsset *asset)
                         {
                             if (asset) {
                                 model.md5 = [[asset defaultRepresentation] getMD5String];
                                 model.extension = [[[[asset defaultRepresentation] filename] pathExtension] lowercaseString];
                                 objectKey = [NSString stringWithFormat:@"%@/%@.%@",@"melvin",model.md5,model.extension];
                                 model.objectKey = objectKey;
                                 model.width      = asset.defaultRepresentation.dimensions.width;
                                 model.height     = asset.defaultRepresentation.dimensions.height;
                                 NSLog(@"objectKey:%@ ",objectKey);
                                 [weakSelf copyImageToDisk:weakSelf.diskCachePath
                                                     asset:asset
                                                  fileName:[NSString stringWithFormat:@"%@.%@",model.md5,model.extension]
                                                 completed:^(NSUInteger fileSize, NSString *md5, NSString *filePath)
                                  {
                                      _totalBytesExpectedToWrite += fileSize;
                                      model.cachePath = filePath;
                                      uploadDataToAliyun(model);
                                  }];
                                 
                             }
                         }
                                                             failureBlock:^(NSError *error)
                         {
                             dispatch_semaphore_signal(semaphore);
                         }];
                    }
                    if ([model.URL isFileReferenceURL]) {
                        //本地磁盘文件
                        model.cachePath = [model.URL absoluteString];
                        model.md5 = [[TFOSSAssistantTools sharedTools] getFileMD5WithPath:[model.URL absoluteString]];
                        model.extension = [[[model.URL absoluteString] pathExtension] lowercaseString];
                        objectKey = [NSString stringWithFormat:@"%@/%@.%@",@"melvin",model.md5,model.extension];
                        uploadDataToAliyun(model);
                        dispatch_semaphore_signal(semaphore);
                    }
                }
            }
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        }
        NSLog(@"upload over -------------");
        //通知上传完成
        GlobalCompletionBlock(YES,[self.uploadOperations objectForKey:token],token,self);
        [self cleanOperations:token];
    });
}



- (void)uploadData2AliOSS:(NSData *)data
                    token:(NSString *)token
                objectKey:(NSString *)objectKey
            progressBlock:(UploadProgressBlock)progressBlock
          completionBlock:(UploadCompletionBlock)completionBlock {
    __weak __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [weakSelf objectExist:objectKey
              completionBlock:^(BOOL result, id response)
         {
             if (!result) {
                 //不存在
                 OSSPutObjectRequest * put = [OSSPutObjectRequest new];
                 // required fields
                 put.contentType = [[TFOSSAssistantTools sharedTools] getMimeType:[objectKey pathExtension]];
                 put.bucketName = self.bucket;
                 put.objectKey = objectKey;
                 put.uploadingData = data;
                 // optional fields
                 put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
                     progressBlock(bytesSent/totalByteSent,token);
                 };
                 OSSTask *putTask = [_client putObject:put];
                 [putTask continueWithBlock:^id(OSSTask *task) {
                     if (!task.error) {
                         NSLog(@"upload object success!");
                         completionBlock(YES,nil);
                     } else {
                         completionBlock(NO,task.error);
                         NSLog(@"upload object failed, error: %@" , task.error);
                     }
                     return nil;
                 }];
             }
             else {
                 completionBlock(YES,nil);
                 NSLog(@"object already Exist!");
             }
         }];
    });
}

#pragma mark -
#pragma mark Privates

- (void)cleanOperations:(NSString *)token {
    [self.uploadOperations removeObjectForKey:token];
    [[EGOCache globalCache] setObject:self.uploadOperations forKey:token];
}

- (BOOL)isUploadingWithToken:(NSString *)token {
    return [self.uploadOperations objectForKey:token] != nil;
}

- (void)removeHandlerWithListener:(id)listener {
    for (NSInteger i = self.uploadHandlers.allKeys.count - 1; i >= 0; i-- ) {
        id key = self.uploadHandlers.allKeys[i];
        NSMutableArray *array = [self.uploadHandlers objectForKey:key];
        
        for (NSInteger j = array.count - 1; j >= 0; j-- ) {
            TFOSSUploadHandler *handler = array[j];
            if (handler.delegate == listener) {
                [array removeObject:handler];
            }
        }
    }
}

- (BOOL)objectExist:(NSString *)objectKey
    completionBlock:(ActionCompletionBlock)completionBlock{
    NSString *url = [NSString stringWithFormat:@"http://%@.%@/%@",self.bucket,self.hostId,objectKey];
    NSLog(@"check file by url:%@",url);
    __block BOOL result = NO;
    // HEAD 请求
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = @"HEAD";
    NSURLSessionConfiguration  *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession * session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    NSURLSessionTask * sessionTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
    {
        if(error) {
            completionBlock(NO,nil);
        }
        else {
            result = YES;
            completionBlock(YES,url);
        }
    }];
    [sessionTask resume];
  
    return result;
}

/**
 *  从相册写入本地临时文件夹
 *
 *  @param path     本地目录
 *  @param asset    相册ALAsset模型
 *  @param completedBlock
 *
 *  @return BOOL
 */
- (BOOL)copyImageToDisk:(NSString *)path
                  asset:(ALAsset *)asset
               fileName:(NSString *)fileName
              completed:(void (^)(NSUInteger fileSize,NSString *md5,NSString *filePath))completedBlock {
    BOOL isDir = YES;
    NSError *error = nil;
    BOOL directoryExists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    if (!directoryExists) {
        [[NSFileManager defaultManager] createDirectoryAtURL:[NSURL fileURLWithPath:path]
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:&error];
    }
    ALAssetRepresentation *rep = [asset defaultRepresentation];
    NSString *filePath = [path stringByAppendingPathComponent:fileName];
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    
    @autoreleasepool {
        CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:filePath];
        CFMutableDictionaryRef properties = CFDictionaryCreateMutable(nil, 0,
                                                                      &kCFTypeDictionaryKeyCallBacks,  &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(properties, kCGImageDestinationLossyCompressionQuality,
                             (__bridge const void *)([NSNumber numberWithFloat:kCompressionQuality]));
        NSDictionary *metadata = rep.metadata;
        for (NSString *key in metadata) {
            CFDictionarySetValue(properties, (__bridge const void *)key,
                                 (__bridge const void *)[metadata objectForKey:key]);
        }
        CGImageRef imageRef = [rep fullResolutionImage];
        CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypeJPEG, 1, NULL);
        if (!destination) {
            NSLog(@"Failed to create CGImageDestination for %@", path);
            return NO;
        }
        
        CGImageDestinationAddImage(destination, imageRef, properties);
        
        if (!CGImageDestinationFinalize(destination)) {
            NSLog(@"Failed to write image to %@", path);
            CFRelease(destination);
            return NO;
        }
        
        CFRelease(destination);
        CFRelease(properties);
        
        NSError *readFileError;
        NSDictionary *fileAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&readFileError];
        NSString *md5 = [[TFOSSAssistantTools sharedTools] getFileMD5WithPath:filePath];
        NSNumber *fileSizeNumber = fileAttr[NSFileSize];
        if (completedBlock) {
            completedBlock([fileSizeNumber integerValue],md5,filePath);
        }
    }
    
    return YES;
}

/**
 *  初始化阿里云oss服务
 */
- (void)initOSSService {
    id<OSSCredentialProvider> credential = [[OSSFederationCredentialProvider alloc] initWithFederationTokenGetter:^OSSFederationToken * {
        NSURL * url = [NSURL URLWithString:_authSTS];
        NSURLRequest * request = [NSURLRequest requestWithURL:url];
        BFTaskCompletionSource * tcs = [BFTaskCompletionSource taskCompletionSource];
        NSURLSessionConfiguration  *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession * session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
        NSURLSessionTask * sessionTask = [session dataTaskWithRequest:request
                                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                        if (error) {
                                                            [tcs setError:error];
                                                            return;
                                                        }
                                                        [tcs setResult:data];
                                                    }];
        [sessionTask resume];
        [tcs.task waitUntilFinished];
        if (tcs.task.error) {
            return nil;
        } else {
            NSDictionary *object = [NSJSONSerialization JSONObjectWithData:tcs.task.result
                                                                   options:kNilOptions
                                                                     error:nil];
            OSSFederationToken *token         = [OSSFederationToken new];
            token.tAccessKey                  = [object objectForKey:@"tempAK"];
            token.tSecretKey                  = [object objectForKey:@"tempSK"];
            token.tToken                      = [object objectForKey:@"token"];
            token.expirationTimeInMilliSecond = [[object objectForKey:@"expiration"] longLongValue]*1000;
            return token;
        }
    }];
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount                   = 3;
    conf.enableBackgroundTransmitService = YES;// 是否开启后台传输服务
    conf.timeoutIntervalForRequest       = 15;
    conf.timeoutIntervalForResource      = 24 * 60 * 60;
    _client = [[OSSClient alloc] initWithEndpoint:self.endPoint
                               credentialProvider:credential
                              clientConfiguration:conf];
}

- (void)startAllTask {
    for (NSString *key in [self.uploadOperations keyEnumerator]) {
        NSLog(@"%s key:%@",__func__,key);
        [self uploadFiles2AliOSS:[self.uploadOperations objectForKey:key]
                           token:key
                   progressBlock:NULL];
    }
}

#pragma mark - Notice

- (void)applicationDidEnterBackground:(NSNotification *)notice {
    //缓存所有任务
    [[EGOCache globalCache] setObject:self.uploadOperations forKey:@"kUploadQueue"];
    //
    NSLog(@"%s",__func__);
}

- (void)applicationDidBecomeActive:(NSNotification *)notice {
    NSLog(@"%s",__func__);
}



@end
