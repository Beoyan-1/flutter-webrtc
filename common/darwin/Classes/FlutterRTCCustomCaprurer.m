//
//  FlutterRTCCustomCaprurer.m
//  flutter_webrtc_haoxin
//
//  Created by 孙海平 on 2023/6/7.
//

#import "FlutterRTCCustomCaprurer.h"

#include <mach/mach_time.h>


@interface FlutterRTCCustomCaprurer ()

@end

@implementation FlutterRTCCustomCaprurer{
//    NSString * _path;
    mach_timebase_info_data_t _timebaseInfo;
    int64_t _startTimeStampNs;
    
    RTCVideoSource* _source;
}


- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate{
    
    self = [super initWithDelegate:delegate];
    if (self) {
        mach_timebase_info(&_timebaseInfo);
//        _path = path;
        _source = delegate;
    }
    
    return self;
}


- (void)startCapture{
    //监听通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inAppWebViewScreenCaptureAticon:) name:@"inAppWebViewScreenCapture" object:NULL];
}



- (void)stopCapture{
    //注销通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)stopCaptureWithCompletionHandler:(nullable void (^)(void))completionHandler {
    [self stopCapture];
    if (completionHandler != nil) {
        completionHandler();
    }
}

- (void)inAppWebViewScreenCaptureAticon:(NSNotification *)nfc{
//    NSLog(@"接收到截屏通知 %f",[[NSDate date] timeIntervalSince1970]);
    if (nfc.object && [nfc.object isKindOfClass:[UIImage class]]){
        UIImage * image = (UIImage *)nfc.object;
        //3.图片转成buffer
        CVPixelBufferRef newBuffer = [self imageToRGBPixelBuffer:image];

        RTCCVPixelBuffer* rtcPixelBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:newBuffer];

        CVPixelBufferRelease(newBuffer);

        //生成videoFrame

        int64_t currentTime = mach_absolute_time();
        int64_t currentTimeStampNs = currentTime * _timebaseInfo.numer / _timebaseInfo.denom;

        if (_startTimeStampNs < 0) {
          _startTimeStampNs = currentTimeStampNs;
        }

        int64_t frameTimeStampNs = currentTimeStampNs - _startTimeStampNs;

    //    NSLog(@"当前时间戳 = %lld",frameTimeStampNs);
        
        RTC_OBJC_TYPE(RTCVideoFrame) * videoFrame =
            [[RTCVideoFrame alloc] initWithBuffer:rtcPixelBuffer rotation:RTCVideoRotation_0 timeStampNs:frameTimeStampNs];

        if (self.delegate && [self.delegate respondsToSelector:@selector(capturer:didCaptureVideoFrame:)]){
            [self.delegate capturer:self didCaptureVideoFrame:videoFrame];
        }
//        NSLog(@"发送给编码器 %f",[[NSDate date] timeIntervalSince1970]);
    }
    
}


- (CVPixelBufferRef)imageToRGBPixelBuffer:(UIImage *)image {
    

    CGSize frameSize = CGSizeMake(CGImageGetWidth(image.CGImage),CGImageGetHeight(image.CGImage));

    NSDictionary *options =
    [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],kCVPixelBufferCGImageCompatibilityKey,[NSNumber numberWithBool:YES],kCVPixelBufferCGBitmapContextCompatibilityKey,nil];
    

    CVPixelBufferRef pxbuffer = NULL;

    CVReturn status =
    CVPixelBufferCreate(kCFAllocatorDefault, frameSize.width, frameSize.height,kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)options, &pxbuffer);
    

    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

    CVPixelBufferLockBaseAddress(pxbuffer, 0);

    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();

    CGContextRef context = CGBitmapContextCreate(pxdata, frameSize.width, frameSize.height,8, CVPixelBufferGetBytesPerRow(pxbuffer),rgbColorSpace,(CGBitmapInfo)kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image.CGImage),CGImageGetHeight(image.CGImage)), image.CGImage);

    CGColorSpaceRelease(rgbColorSpace);

    CGContextRelease(context);

    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);

    return pxbuffer;
}

@end
