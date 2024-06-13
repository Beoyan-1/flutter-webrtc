package com.cloudwebrtc.webrtc.audio;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.Context;
import android.content.pm.PackageManager;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.os.Handler;
import android.os.Looper;
import android.telephony.TelephonyManager;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;

import com.cloudwebrtc.webrtc.utils.PermissionUtils;
import com.twilio.audioswitch.AudioDevice;
import com.twilio.audioswitch.AudioSwitch;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;

import kotlin.Unit;
import kotlin.jvm.functions.Function2;

public class AudioSwitchManager {
    @SuppressLint("StaticFieldLeak")
    public static AudioSwitchManager instance;
    @NonNull
    private final Context context;
    @NonNull
    private final AudioManager audioManager;

    public boolean loggingEnabled;
    private boolean isActive = false;
    private boolean isEnableSpeakerphone = false;
    @NonNull
    public Function2<
            ? super List<? extends AudioDevice>,
            ? super AudioDevice,
            Unit> audioDeviceChangeListener = (devices, currentDevice) -> null;

    @NonNull
    public AudioManager.OnAudioFocusChangeListener audioFocusChangeListener = (i -> {
        Log.e("miki","audioFocusChangeListener");
    });

    public boolean isPhone(){
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) {
            TelephonyManager telephonyManager = (TelephonyManager)context.getSystemService(Context.TELEPHONY_SERVICE);
            int callState = telephonyManager.getCallState();

// 判断当前通话状态
            if (callState == TelephonyManager.CALL_STATE_OFFHOOK) {
                // 设备当前没有处于通话状态

                Log.d("miki", "Device is not in call state");
                return true;
            } else  {
                // 设备当前处于通话状态
                Log.d("miki", "Device is in call state");
                return false;
            }
        }
        return false;
    }


    @NonNull
    public List<Class<? extends AudioDevice>> preferredDeviceList;

    // AudioSwitch is not threadsafe, so all calls should be done on the main thread.
    private final Handler handler = new Handler(Looper.getMainLooper());

    @Nullable
    private AudioSwitch audioSwitch;

    public AudioSwitchManager(@NonNull Context context) {
        this.context = context;
        this.audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);

        preferredDeviceList = new ArrayList<>();
        preferredDeviceList.add(AudioDevice.BluetoothHeadset.class);
        preferredDeviceList.add(AudioDevice.WiredHeadset.class);
        preferredDeviceList.add(AudioDevice.Speakerphone.class);
        preferredDeviceList.add(AudioDevice.Earpiece.class);
        isEnableSpeakerphone = audioManager.isMicrophoneMute();
        initAudioSwitch();
    }

    private void initAudioSwitch() {
        if (audioSwitch == null) {
            handler.removeCallbacksAndMessages(null);
            handler.postAtFrontOfQueue(() -> {
                audioSwitch = new AudioSwitch(
                        context,
                        loggingEnabled,
                        audioFocusChangeListener,
                        preferredDeviceList
                );
                audioSwitch.start(audioDeviceChangeListener);
            });

        }
    }

    public void start() {
        if (audioSwitch != null) {
            handler.removeCallbacksAndMessages(null);
            handler.postAtFrontOfQueue(() -> {
                if (!isActive) {
                    Objects.requireNonNull(audioSwitch).activate();
                    isActive = true;
                }
            });
        }
    }

    public void stop() {
        if (audioSwitch != null) {
            handler.removeCallbacksAndMessages(null);
            handler.postAtFrontOfQueue(() -> {
                if (isActive) {
                    Objects.requireNonNull(audioSwitch).deactivate();
                    isActive = false;
                }
            });
        }
    }

    public void setMicrophoneMute(boolean mute){
        Log.e("miki","==========setMicrophoneMute="+mute);
        audioManager.setMicrophoneMute(mute);
    }

    public boolean isMicrophoneMute(){
       return audioManager.isMicrophoneMute();
    }

    @Nullable
    public AudioDevice selectedAudioDevice() {
        return Objects.requireNonNull(audioSwitch).getSelectedAudioDevice();
    }

    @NonNull
    public List<AudioDevice> availableAudioDevices() {
        return Objects.requireNonNull(audioSwitch).getAvailableAudioDevices();
    }

    public void selectAudioOutput(@NonNull Class<? extends AudioDevice> audioDeviceClass) {
        handler.post(() -> {
            List<AudioDevice> devices = availableAudioDevices();
            AudioDevice audioDevice = null;
            for (AudioDevice device : devices) {
                Log.e("miki","当前设备列表："+device.getName());
                if (device.getClass().equals(audioDeviceClass)) {
                    audioDevice = device;
                    break;
                }
            }
            if (audioDevice != null) {
                Objects.requireNonNull(audioSwitch).selectDevice(audioDevice);
            }
        });
    }
    public void selectAudioOutput2() {
        Objects.requireNonNull(audioSwitch).selectDevice(null);
    }
    public void enableSpeakerphone(boolean enable) {
        Log.e("miki","是否开启麦克风："+enable);
        if(enable){
            audioManager.setSpeakerphoneOn(true);
        selectAudioOutput(AudioDeviceKind.fromTypeName("speaker"));
        }else{
            audioManager.setSpeakerphoneOn(false);
            selectAudioOutput(AudioDeviceKind.fromTypeName("earpiece"));
        }

        Log.e("miki","是否开启麦克风-----："+audioManager.isSpeakerphoneOn());
        isEnableSpeakerphone = enable;
    }

    public boolean isEnableSpeakerphone() {
        return isEnableSpeakerphone;
    }
    
    public void selectAudioOutput(@Nullable AudioDeviceKind kind) {
        if (kind != null) {
            selectAudioOutput(kind.audioDeviceClass);
        }
    }
}
