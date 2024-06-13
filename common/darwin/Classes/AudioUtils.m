#if TARGET_OS_IPHONE
#import "AudioUtils.h"
#import <AVFoundation/AVFoundation.h>

@implementation AudioUtils

+ (void)ensureAudioSessionWithRecording:(BOOL)recording {
  RTCAudioSession* session = [RTCAudioSession sharedInstance];
  // we also need to set default WebRTC audio configuration, since it may be activated after
  // this method is called
  RTCAudioSessionConfiguration* config = [RTCAudioSessionConfiguration webRTCConfiguration];
    
    if (session.category != AVAudioSessionCategoryPlayAndRecord ||
        (session.categoryOptions & AVAudioSessionCategoryOptionAllowAirPlay) != AVAudioSessionCategoryOptionAllowAirPlay ||
        (session.categoryOptions & AVAudioSessionCategoryOptionAllowBluetooth) != AVAudioSessionCategoryOptionAllowBluetooth ||
        (session.categoryOptions & AVAudioSessionCategoryOptionAllowBluetoothA2DP) != AVAudioSessionCategoryOptionAllowBluetoothA2DP){
        config.category = AVAudioSessionCategoryPlayAndRecord;
        config.categoryOptions = AVAudioSessionCategoryOptionAllowAirPlay | AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionAllowBluetoothA2DP ;
        
        config.mode = AVAudioSessionModeVoiceChat;

        // upgrade from ambient if needed
        [session lockForConfiguration];
        [session setCategory:config.category withOptions:config.categoryOptions error:nil];
        [session setMode:config.mode error:nil];
        [session unlockForConfiguration];
    }
    
}

+ (BOOL)selectAudioInput:(AVAudioSessionPort)type {
  RTCAudioSession* rtcSession = [RTCAudioSession sharedInstance];
  AVAudioSessionPortDescription* inputPort = nil;
  for (AVAudioSessionPortDescription* port in rtcSession.session.availableInputs) {
    if ([port.portType isEqualToString:type]) {
      inputPort = port;
      break;
    }
  }
  if (inputPort != nil) {
    NSError* errOut = nil;
    [rtcSession lockForConfiguration];
    [rtcSession setPreferredInput:inputPort error:&errOut];
    [rtcSession unlockForConfiguration];
    if (errOut != nil) {
      return NO;
    }
    return YES;
  }
  return NO;
}

+ (void)setSpeakerphoneOn:(BOOL)enable {
  RTCAudioSession* session = [RTCAudioSession sharedInstance];
  RTCAudioSessionConfiguration* config = [RTCAudioSessionConfiguration webRTCConfiguration];
  [session lockForConfiguration];
  NSError* error = nil;
  if (!enable) {
      
    BOOL success = [session setCategory:config.category
                            withOptions:AVAudioSessionCategoryOptionAllowAirPlay |
                                        AVAudioSessionCategoryOptionAllowBluetoothA2DP |
                                        AVAudioSessionCategoryOptionAllowBluetooth
                                  error:&error];

    success = [session.session overrideOutputAudioPort:kAudioSessionOverrideAudioRoute_None
                                                 error:&error];
    if (!success)
      NSLog(@"Port override failed due to: %@", error);
  } else {
      
      BOOL success = [session setCategory:config.category
                              withOptions:AVAudioSessionCategoryOptionAllowAirPlay |
                      AVAudioSessionCategoryOptionAllowBluetoothA2DP |
                      AVAudioSessionCategoryOptionAllowBluetooth| AVAudioSessionCategoryOptionDefaultToSpeaker
                                    error:&error];

       success = [session overrideOutputAudioPort:kAudioSessionOverrideAudioRoute_Speaker
                                         error:&error];
    if (!success)
      NSLog(@"Port override failed due to: %@", error);
  }
  [session unlockForConfiguration];
}

+ (void)deactiveRtcAudioSession {
  NSError* error = nil;
  RTCAudioSession* session = [RTCAudioSession sharedInstance];
  [session lockForConfiguration];
  if ([session isActive]) {
    BOOL success = [session setActive:NO error:&error];
    if (!success)
      NSLog(@"RTC Audio session deactive failed: %@", error);
    else
      NSLog(@"RTC AudioSession deactive is successful ");
  }
  [session unlockForConfiguration];
}

@end
#endif
