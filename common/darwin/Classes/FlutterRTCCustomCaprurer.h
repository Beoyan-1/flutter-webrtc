//
//  FlutterRTCCustomCaprurer.h
//  flutter_webrtc_haoxin
//
//  Created by 孙海平 on 2023/6/7.
//

#import <WebRTC/WebRTC.h>

NS_ASSUME_NONNULL_BEGIN

@interface FlutterRTCCustomCaprurer : RTCVideoCapturer

- (instancetype)initWithDelegate:(__weak id<RTCVideoCapturerDelegate>)delegate;
- (void)startCapture;
- (void)stopCapture;
- (void)stopCaptureWithCompletionHandler:(nullable void (^)(void))completionHandler;
@end

NS_ASSUME_NONNULL_END
