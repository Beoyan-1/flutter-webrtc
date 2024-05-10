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

@property(nonatomic, strong) GPUImageUIElement * uiElement;

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
    
    [self setupUiElement:format];
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
    
    
    //添加水印
//    CVPixelBufferRef newBuffer = [self shuiyinByGPUImage:pixelBuffer VideoRotation:videoRotation];
//    rtcPixelBuffer =
//        [[RTC_OBJC_TYPE(RTCCVPixelBuffer) alloc] initWithPixelBuffer:newBuffer];
//    CVPixelBufferRelease(newBuffer);
    
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

/***************** 水印 *****************/
- (void)setupUiElement:(AVCaptureDeviceFormat *)format
{
    CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
    CGSize size = CGSizeMake(dimension.width, dimension.height);

    //添加时间戳水印和图片水印
//    AVCaptureVideoDataOutput * dataOutput = [self valueForKey:@"_videoDataOutput"];

    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, dimension.width, dimension.height)];
    contentView.clipsToBounds = YES;
    contentView.backgroundColor = [[UIColor alloc] initWithRed:1 green:0 blue:0 alpha:0.5];
//
//
    UIImageView *imageV = [[UIImageView alloc] initWithFrame:contentView.bounds];
    imageV.image = [UIImage imageNamed:@"launch_icon11"];
    imageV.backgroundColor = [[UIColor alloc] initWithRed:1 green:0 blue:1 alpha:0.5];
    imageV.contentMode = UIViewContentModeScaleAspectFit;
    //        imageV.backgroundColor = [UIColor cyanColor];
//    imageV.image = [UIImage imageNamed:@"shishi"];
    [contentView addSubview:imageV];



    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

    [formatter setDateFormat:@"yyyy年MM月dd日hh:mm:ss"];

    NSDate *currentDate = [NSDate date];

    NSString *timeString = [formatter stringFromDate:currentDate];

    UILabel *timestampLabel = [[UILabel alloc] initWithFrame:CGRectMake(contentView.frame.size.width * 0.5 - 80, 200, 160, 60)];

    timestampLabel.text = timeString;

    timestampLabel.textColor = [UIColor redColor];

    [contentView addSubview:timestampLabel];


    //创建水印图形

    self.uiElement = [[GPUImageUIElement alloc] initWithView:contentView];
}


////  采集拿到的数据进行处理
- (CVPixelBufferRef)shuiyinByGPUImage:(CVPixelBufferRef)pixelBuffer VideoRotation:(RTCVideoRotation)videoRotation{
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

       //水印内容滤镜
       GPUImageUIElement *uiElement = self.uiElement;
       if (uiElement.targets > 0){
           [uiElement removeAllTargets];
       }

       //亮度滤镜（GPUImageAlphaBlendFilter 需要用它来过渡,如果不使用，视频流黑屏）
       GPUImageBrightnessFilter *filter = [[GPUImageBrightnessFilter alloc] init];
       filter.brightness = 0.00;

       [filter setFrameProcessingCompletionBlock:^(GPUImageOutput * imageOutput, CMTime time) {
//           //如果不调用更新 视频流为黑屏
           [uiElement update];
       }];

       //透明滤镜
       GPUImageAlphaBlendFilter * blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
       blendFilter.mix = 1.0;

       //旋转滤镜
       GPUImageTransformFilter *transformFilter = [[GPUImageTransformFilter alloc] init];
       // [transformFilter forceProcessingAtSize:?????];

       CGFloat temp = 0.0;

       CGFloat tx = 0.0;
       CGFloat ty = 0.0;
       if (videoRotation == RTCVideoRotation_0){
           temp = 0.0;
           tx = 0.7;
           ty = 0.5;
       }else if (videoRotation == RTCVideoRotation_90){
           temp = -M_PI_2;
           tx = 0.5;
           ty = 0.8;
       }else if (videoRotation == RTCVideoRotation_180){
           temp = M_PI;
           tx = 0.7;
           ty = 0.5;
       }else if (videoRotation == RTCVideoRotation_270){
           temp = M_PI_2;
           tx = -0.5;
           ty = -0.8;
       }

       CGAffineTransform transform = CGAffineTransformMakeRotation(temp);
       transform = CGAffineTransformTranslate(transform, tx, ty);
       transform = CGAffineTransformScale(transform, 0.2, 0.2);
       transformFilter.affineTransform = transform;

       //添加全部滤镜
       [textureInput addTarget:filter];
       [filter addTarget:blendFilter];

       [uiElement addTarget:transformFilter];
       [transformFilter addTarget:blendFilter];

       GPUImageTextureOutput *textureOutput = [[GPUImageTextureOutput alloc] init];
       [blendFilter addTarget:textureOutput];


       [textureInput processTextureWithFrameTime:kCMTimeZero];
       //       3. 处理后的纹理转pixelBuffer BGRA
       output = [self.helper convertTextureToPixelBuffer:textureOutput.texture
                                                        textureSize:size];
       [textureOutput doneWithTexture];
       glDeleteTextures(1, &textureID);

   });
   CVPixelBufferRelease(pixelBuffer);
   return output;
}


- (RTCVideoFrame *)addWatermarkToFrame:(RTCVideoFrame *)frame watermark:(UIImage *)watermarkImage {
    // 获取图像数据
    RTCCVPixelBuffer *pixelBuffer = (RTCCVPixelBuffer *)frame.buffer;
    CVPixelBufferRef pixelBufferRef = [pixelBuffer pixelBuffer];

    // 将水印图像叠加到图像上
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(CVPixelBufferGetWidth(pixelBufferRef), CVPixelBufferGetHeight(pixelBufferRef)), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0, CVPixelBufferGetHeight(pixelBufferRef));
    CGContextScaleCTM(context, 1.0, -1.0);

    CGRect imageRect = CGRectMake(0, 0, CVPixelBufferGetWidth(pixelBufferRef), CVPixelBufferGetHeight(pixelBufferRef));
    CGContextDrawImage(context, imageRect, [self convertCVPixelBufferToCGImage:pixelBufferRef]);

    CGRect watermarkRect = CGRectMake(10, 10, watermarkImage.size.width, watermarkImage.size.height);
    [watermarkImage drawInRect:watermarkRect];

    UIImage *watermarkedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    // 将带有水印的图像重新放回帧中
    RTCVideoFrame *watermarkedFrame = [[RTCVideoFrame alloc] initWithBuffer:[self convertCGImageToCVPixelBuffer:watermarkedImage.CGImage] rotation:frame.rotation timeStampNs:frame.timeStampNs];

    return watermarkedFrame;
}



- (CVPixelBufferRef)convertCGImageToCVPixelBuffer:(CGImageRef)image {
    // 实现将CGImage转换为CVPixelBuffer的逻辑
    // 这里需要注意图像格式和颜色空间的处理
    
    CGSize frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));

        NSDictionary *options = @{
            (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
            (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
        };

        CVPixelBufferRef pixelBuffer = NULL;
        CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                              frameSize.width,
                                              frameSize.height,
                                              kCVPixelFormatType_32ARGB,
                                              (__bridge CFDictionaryRef)options,
                                              &pixelBuffer);

        if (status != kCVReturnSuccess) {
            return NULL;
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);

        CGContextRef context = CGBitmapContextCreate(baseAddress,
                                                     frameSize.width,
                                                     frameSize.height,
                                                     8,
                                                     CVPixelBufferGetBytesPerRow(pixelBuffer),
                                                     CGImageGetColorSpace(image),
                                                     kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

        CGContextDrawImage(context, CGRectMake(0, 0, frameSize.width, frameSize.height), image);

        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        CGContextRelease(context);

        return pixelBuffer;
}

- (CGImageRef)convertCVPixelBufferToCGImage:(CVPixelBufferRef)pixelBuffer {
    // 实现将CVPixelBuffer转换为CGImage的逻辑
    // 这里需要注意图像格式和颜色空间的处理
    // 获取图像属性
        size_t width = CVPixelBufferGetWidth(pixelBuffer);
        size_t height = CVPixelBufferGetHeight(pixelBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
        void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        // 创建 Core Graphics 上下文
        CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

        // 创建 CGImage
        CGImageRef image = CGBitmapContextCreateImage(context);

        // 释放资源
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);

        return image;
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
