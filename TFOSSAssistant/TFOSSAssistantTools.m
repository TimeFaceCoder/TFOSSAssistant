//
//  TFOSSAssistantTools.m
//  TFOSSAssistant
//
//  Created by Melvin on 10/27/15.
//  Copyright © 2015 TimeFace. All rights reserved.
//

#import "TFOSSAssistantTools.h"
#import <CommonCrypto/CommonDigest.h>
#import <MobileCoreServices/MobileCoreServices.h>

#define FileHashDefaultChunkSizeForReadingData 1024*8
@implementation TFOSSAssistantTools

+ (instancetype)sharedTools
{
    static TFOSSAssistantTools* utility = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        if (!utility) {
            utility = [[self alloc] init];
        }
    });
    return utility;
}

- (NSString *)getMimeType:(NSString *)fileType {
    
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                            (__bridge CFStringRef)fileType, NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    
    NSString *mimeType = (__bridge NSString *)MIMEType;
    CFRelease(MIMEType);
    return mimeType;
}

- (NSString *)getMD5StringFromNSString:(NSString *)string {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
    CC_MD5([data bytes], (CC_LONG)[data length], digest);
    NSMutableString *result = [NSMutableString string];
    for (i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat: @"%02x", (int)(digest[i])];
    }
    return [result copy];
}

- (NSString *)getMD5StringFromNSData:(NSData *)data {
    unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
    CC_MD5([data bytes], (CC_LONG)[data length], digest);
    NSMutableString *result = [NSMutableString string];
    for (i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat: @"%02x", (int)(digest[i])];
    }
    return [result copy];
}

- (NSString*)getFileMD5WithPath:(NSString*)path {
    return (__bridge_transfer NSString *)TFOSSFileMD5HashCreateWithPath((__bridge CFStringRef)path,
                                                                   FileHashDefaultChunkSizeForReadingData);
}

CFStringRef TFOSSFileMD5HashCreateWithPath(CFStringRef filePath,size_t chunkSizeForReadingData) {
    // Declare needed variables
    CFStringRef result = NULL;
    CFReadStreamRef readStream = NULL;
    // Get the file URL
    CFURLRef fileURL =
    CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                  (CFStringRef)filePath,
                                  kCFURLPOSIXPathStyle,
                                  (Boolean)false);
    if (!fileURL) goto done;
    // Create and open the read stream
    readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault,
                                            (CFURLRef)fileURL);
    if (!readStream) goto done;
    bool didSucceed = (bool)CFReadStreamOpen(readStream);
    if (!didSucceed) goto done;
    // Initialize the hash object
    CC_MD5_CTX hashObject;
    CC_MD5_Init(&hashObject);
    // Make sure chunkSizeForReadingData is valid
    if (!chunkSizeForReadingData) {
        chunkSizeForReadingData = FileHashDefaultChunkSizeForReadingData;
    }
    // Feed the data to the hash object
    bool hasMoreData = true;
    while (hasMoreData) {
        uint8_t buffer[chunkSizeForReadingData];
        CFIndex readBytesCount = CFReadStreamRead(readStream,(UInt8 *)buffer,(CFIndex)sizeof(buffer));
        if (readBytesCount == -1) break;
        if (readBytesCount == 0) {
            hasMoreData = false;
            continue;
        }
        CC_MD5_Update(&hashObject,(const void *)buffer,(CC_LONG)readBytesCount);
    }
    // Check if the read operation succeeded
    didSucceed = !hasMoreData;
    // Compute the hash digest
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &hashObject);
    // Abort if the read operation failed
    if (!didSucceed) goto done;
    // Compute the string result
    char hash[2 * sizeof(digest) + 1];
    for (size_t i = 0; i < sizeof(digest); ++i) {
        snprintf(hash + (2 * i), 3, "%02x", (int)(digest[i]));
    }
    result = CFStringCreateWithCString(kCFAllocatorDefault,(const char *)hash,kCFStringEncodingUTF8);
    
done:
    if (readStream) {
        CFReadStreamClose(readStream);
        CFRelease(readStream);
    }
    if (fileURL) {
        CFRelease(fileURL);
    }
    return result;
}


@end
