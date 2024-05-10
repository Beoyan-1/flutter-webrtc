//
//  FlutterRTCWatermarkingVideoCapturer.h
//  flutter_webrtc_haoxin
//
//  Created by 孙海平 on 2023/3/6.
//

#import <WebRTC/WebRTC.h>

#import "MFPixelBufferHelper.h"

NS_ASSUME_NONNULL_BEGIN
@interface FlutterRTCBeautyideoCapturer : RTCCameraVideoCapturer
///是否美颜
@property (nonatomic, assign) BOOL isBeauty;


///水印图片名称
@property (nonatomic, strong) NSString * watermarkName;

///转格式
@property (nonatomic, strong) MFPixelBufferHelper * helper;
@end

NS_ASSUME_NONNULL_END
