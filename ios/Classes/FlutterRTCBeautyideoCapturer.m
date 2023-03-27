//
//  FlutterRTCWatermarkingVideoCapturer.m
//  flutter_webrtc_haoxin
//
//  Created by 孙海平 on 2023/3/6.
//

#import "FlutterRTCBeautyideoCapturer.h"

#import <GPUImage/GPUImage.h>

#import "LFGPUImageBeautyFilter.h"

// See: https://developer.apple.com/videos/play/wwdc2017/606/


BOOL CFStringContainsString(CFStringRef theString, CFStringRef stringToFind) {
  return CFStringFindWithOptions(theString,
                                 stringToFind,
                                 CFRangeMake(0, CFStringGetLength(theString)),
                                 kCFCompareCaseInsensitive,
                                 nil);
}


const int64_t kNanosecondsPerSecond = 1000000000;


@interface FlutterRTCBeautyideoCapturer ()


@end



@implementation FlutterRTCBeautyideoCapturer {
    RTCVideoSource* source;
}


- (instancetype)initWithDelegate:(id<RTCVideoCapturerDelegate>)delegate{
    self = [super initWithDelegate:delegate];
    return self;
}


- (void)startCaptureWithDevice:(AVCaptureDevice *)device
                        format:(AVCaptureDeviceFormat *)format
                           fps:(NSInteger)fps {
    
    [self startCaptureWithDevice:device format:format fps:fps completionHandler:nil];
}


- (void)startCaptureWithDevice:(AVCaptureDevice *)device
                        format:(AVCaptureDeviceFormat *)format
                           fps:(NSInteger)fps
             completionHandler:(nullable void (^)(NSError *_Nullable error))completionHandler {
    
//    [self setupUiElement:format];
    [super startCaptureWithDevice:device format:format fps:fps completionHandler:completionHandler];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    

    id tempOutput = [self valueForKey:@"_videoDataOutput"];
    if (tempOutput && [tempOutput isKindOfClass:[AVCaptureVideoDataOutput class]]){
        AVCaptureVideoDataOutput * currentOutput = (AVCaptureVideoDataOutput*)tempOutput;
        NSParameterAssert(captureOutput == currentOutput);
    }
 
    if (CMSampleBufferGetNumSamples(sampleBuffer) != 1 || !CMSampleBufferIsValid(sampleBuffer) ||
        !CMSampleBufferDataIsReady(sampleBuffer)) {
      return;
    }

    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (pixelBuffer == nil) {
      return;
    }

  #if TARGET_OS_IPHONE
    // Default to portrait orientation on iPhone.
    BOOL usingFrontCamera = NO;
    // Check the image's EXIF for the camera the image came from as the image could have been
    // delayed as we set alwaysDiscardsLateVideoFrames to NO.
    AVCaptureDevicePosition cameraPosition =
        [self devicePositionForSampleBuffer:sampleBuffer];

    if (cameraPosition != AVCaptureDevicePositionUnspecified) {
      usingFrontCamera = AVCaptureDevicePositionFront == cameraPosition;
    } else {
      AVCaptureDeviceInput *deviceInput =
          (AVCaptureDeviceInput *)((AVCaptureInputPort *)connection.inputPorts.firstObject).input;
      usingFrontCamera = AVCaptureDevicePositionFront == deviceInput.device.position;
    }
    
    
    RTCVideoRotation videoRotation = RTCVideoRotation_0;
    NSNumber * number = [self valueForKey:@"_rotation"];
    if (number){
        videoRotation = number.integerValue;
    }
    
    
    UIDeviceOrientation _orientation = [UIDevice currentDevice].orientation;
    
    switch (_orientation) {
      case UIDeviceOrientationPortrait:
            videoRotation = RTCVideoRotation_90;
        break;
      case UIDeviceOrientationPortraitUpsideDown:
            videoRotation = RTCVideoRotation_270;
        break;
      case UIDeviceOrientationLandscapeLeft:
            videoRotation = usingFrontCamera ? RTCVideoRotation_180 : RTCVideoRotation_0;
        break;
      case UIDeviceOrientationLandscapeRight:
            videoRotation = usingFrontCamera ? RTCVideoRotation_0 : RTCVideoRotation_180;
        break;
      case UIDeviceOrientationFaceUp:
      case UIDeviceOrientationFaceDown:
      case UIDeviceOrientationUnknown:
        // Ignore.
        break;
    }
  #else
    // No rotation on Mac.
    videoRotation = RTCVideoRotation_0;
  #endif
    
    [self setValue:[NSNumber numberWithInteger:videoRotation] forKey:@"_rotation"];
    
    RTC_OBJC_TYPE(RTCCVPixelBuffer) *rtcPixelBuffer;
    if (self.isBeauty){
       //处理美颜数据
        CVPixelBufferRef newBuffer = [self renderByGPUImage:pixelBuffer];
           rtcPixelBuffer =
               [[RTC_OBJC_TYPE(RTCCVPixelBuffer) alloc] initWithPixelBuffer:newBuffer];
        CVPixelBufferRelease(newBuffer);
    }else{
        CVPixelBufferRetain(pixelBuffer);
        rtcPixelBuffer =
            [[RTC_OBJC_TYPE(RTCCVPixelBuffer) alloc] initWithPixelBuffer:pixelBuffer];
        CVPixelBufferRelease(pixelBuffer);
    }
    
    //生成videoFrame
    int64_t timeStampNs = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * kNanosecondsPerSecond;
    
    
    RTC_OBJC_TYPE(RTCVideoFrame) * videoFrame =
        [[RTCVideoFrame alloc] initWithBuffer:rtcPixelBuffer rotation:videoRotation timeStampNs:timeStampNs];
    
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(capturer:didCaptureVideoFrame:)]){
        [self.delegate capturer:self didCaptureVideoFrame:videoFrame];
    }
}


////  采集拿到的数据进行处理
- (CVPixelBufferRef)renderByGPUImage:(CVPixelBufferRef)pixelBuffer {
   CVPixelBufferRetain(pixelBuffer);
   __block CVPixelBufferRef output = nil;
   runSynchronouslyOnVideoProcessingQueue(^{
       
       [GPUImageContext useImageProcessingContext];
       //        1.取到采集数据i420 CVPixelBufferRef->纹理
       GLuint textureID = [self.helper convertYUVPixelBufferToTexture:pixelBuffer];
       CGSize size = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer),
                                CVPixelBufferGetHeight(pixelBuffer));


       //        2.GPUImage滤镜处理
       [GPUImageContext setActiveShaderProgram:nil];
       GPUImageTextureInput *textureInput = [[GPUImageTextureInput alloc] initWithTexture:textureID size:size];
       
       //美颜
       LFGPUImageBeautyFilter * fliter = [[LFGPUImageBeautyFilter alloc] init];
       fliter.beautyLevel = 0.7;
       fliter.toneLevel = 1;
       fliter.brightLevel = 0.5;
       [textureInput addTarget:fliter];

       GPUImageTextureOutput *textureOutput = [[GPUImageTextureOutput alloc] init];
       
       [fliter addTarget:textureOutput];
       
       [textureInput processTextureWithFrameTime:kCMTimeZero];
       output = [self.helper convertTextureToPixelBuffer:textureOutput.texture
                                                        textureSize:size];
       [textureOutput doneWithTexture];
       glDeleteTextures(1, &textureID);
   });
   CVPixelBufferRelease(pixelBuffer);
   return output;
}

- (AVCaptureDevicePosition)devicePositionForSampleBuffer:(CMSampleBufferRef)sampleBuffer {
  // Check the image's EXIF for the camera the image came from.
  AVCaptureDevicePosition cameraPosition = AVCaptureDevicePositionUnspecified;
  CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(
      kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
  if (attachments) {
    int size = CFDictionaryGetCount(attachments);
    if (size > 0) {
      CFDictionaryRef cfExifDictVal = nil;
      if (CFDictionaryGetValueIfPresent(
              attachments, (const void *)CFSTR("{Exif}"), (const void **)&cfExifDictVal)) {
        CFStringRef cfLensModelStrVal;
        if (CFDictionaryGetValueIfPresent(cfExifDictVal,
                                          (const void *)CFSTR("LensModel"),
                                          (const void **)&cfLensModelStrVal)) {
          if (CFStringContainsString(cfLensModelStrVal, CFSTR("front"))) {
            cameraPosition = AVCaptureDevicePositionFront;
          } else if (CFStringContainsString(cfLensModelStrVal, CFSTR("back"))) {
            cameraPosition = AVCaptureDevicePositionBack;
          }
        }
      }
    }
    CFRelease(attachments);
  }
  return cameraPosition;
}

- (MFPixelBufferHelper *)helper
{
    if (!_helper){
        EAGLContext *context = [[GPUImageContext sharedImageProcessingContext] context];
        _helper = [[MFPixelBufferHelper alloc] initWithContext:context];
    }
    return _helper;
}

@end
