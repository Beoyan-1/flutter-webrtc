/*
 * @Author: Beoyan
 * @Date: 2022-11-14 09:43:41
 * @LastEditTime: 2022-11-14 09:43:42
 * @LastEditors: Beoyan
 * @Description: 
 */
package com.cloudwebrtc.webrtc;

import android.content.Context;
import android.os.Handler;
import android.util.Log;

import androidx.annotation.Nullable;

import com.cloudwebrtc.webrtc.effector.RTCVideoEffector;

import org.json.JSONException;
import org.webrtc.SurfaceTextureHelper;
import org.webrtc.ThreadUtils;
import org.webrtc.VideoFrame;
import org.webrtc.VideoProcessor;
import org.webrtc.VideoSink;

import java.io.IOException;


public class FilterProcessor implements VideoProcessor {
    VideoSink sink;
    private final Context applicationContext;
    private final RTCVideoEffector effector;

    public FilterProcessor(Context applicationContext, SurfaceTextureHelper surfaceTextureHelper) {

        this.applicationContext = applicationContext;
        effector = new RTCVideoEffector(applicationContext);
        final Handler handler = surfaceTextureHelper.getHandler();
        ThreadUtils.invokeAtFrontUninterruptibly(handler, () ->
                {
                    try {
                        effector.init(surfaceTextureHelper);
                    } catch (JSONException e) {
                        throw new RuntimeException(e);
                    } catch (IOException e) {
                        throw new RuntimeException(e);
                    }
                }
        );
    }

    //启用滤镜
    public void enable() {
        if (effector != null) {
            effector.enable();
        }
    }

    //禁用滤镜
    public void disable() {
        if (effector != null) {
            effector.disable();
        }
    }


    @Override
    public void setSink(@Nullable VideoSink videoSink) {
        sink = videoSink;
    }

    @Override
    public void onCapturerStarted(boolean b) {

    }

    @Override
    public void onCapturerStopped() {

    }

    @Override
    public void onFrameCaptured(VideoFrame videoFrame) {
        if (effector != null && effector.isEnabled()) {
            VideoFrame.I420Buffer originalI420Buffer = videoFrame.getBuffer().toI420();
            VideoFrame.I420Buffer effectedI420Buffer = this.effector.processByteBufferFrame(originalI420Buffer, videoFrame.getRotation(), videoFrame.getTimestampNs());
            VideoFrame effectedVideoFrame = new VideoFrame(
                    effectedI420Buffer, videoFrame.getRotation(), videoFrame.getTimestampNs());
            sink.onFrame(effectedVideoFrame);
            Log.e("miki","onFrame--1----------------");
            originalI420Buffer.release();
//            videoFrame.release();
        } else {
            Log.e("miki","onFrame--2----------------");
            sink.onFrame(videoFrame);
        }
    }
}
