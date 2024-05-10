//
//  FlutterRTCCustomCaprurer.m
//  flutter_webrtc_haoxin
//
//  Created by 孙海平 on 2023/6/7.
//

#import "FlutterRTCCustomCaprurer.h"

#include <mach/mach_time.h>


@interface FlutterRTCCustomCaprurer ()

@property (nonatomic, assign) mach_timebase_info_data_t timebaseInfo;

@property (nonatomic, assign) int64_t startTimeStampNs;


@property (nonatomic, strong) RTCCVPixelBuffer * pixelBuffer;

@property (nonatomic, strong) RTCVideoSource * source;

@end

@implementation FlutterRTCCustomCaprurer


- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate{
    
    self = [super initWithDelegate:delegate];
    if (self) {
        mach_timebase_info(&_timebaseInfo);
//        _path = path;
        self.source = delegate;
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
    
    __weak __typeof(self)wself = self;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//        NSLog(@"接到通知 ......");
        
        
        
        if (nfc.object && [nfc.object isKindOfClass:[UIImage class]]){
//            NSLog(@"开始转换 ......");
            UIImage * image = (UIImage *)nfc.object;
            
            CVPixelBufferRef newBuffer = [self imageToRGBPixelBuffer:image];

            wself.pixelBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:newBuffer];

            CVPixelBufferRelease(newBuffer);
//            NSLog(@" 结束转换 ......");
//            NSLog(@"使用新的 videoFrame");
        }else{
//            NSLog(@"使用缓存的 videoFrame");
        }
        
        
        if (wself.pixelBuffer && wself.delegate && [wself.delegate respondsToSelector:@selector(capturer:didCaptureVideoFrame:)]){
            int64_t currentTime = mach_absolute_time();
            int64_t currentTimeStampNs = currentTime * wself.timebaseInfo.numer / wself.timebaseInfo.denom;

            if (wself.startTimeStampNs < 0) {
                wself.startTimeStampNs = currentTimeStampNs;
            }

            int64_t frameTimeStampNs = currentTimeStampNs - wself.startTimeStampNs;

        //    NSLog(@"当前时间戳 = %lld",frameTimeStampNs);
            
            RTC_OBJC_TYPE(RTCVideoFrame) * videoFrame =
                [[RTCVideoFrame alloc] initWithBuffer:wself.pixelBuffer rotation:RTCVideoRotation_0 timeStampNs:frameTimeStampNs];
            

            [wself.delegate capturer:wself didCaptureVideoFrame:videoFrame];
                
        }
    });
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
