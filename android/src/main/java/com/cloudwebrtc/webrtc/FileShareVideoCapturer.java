package com.cloudwebrtc.webrtc;


import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.os.Build;
import android.view.Surface;

import org.webrtc.CapturerObserver;
import org.webrtc.SurfaceTextureHelper;
import org.webrtc.VideoCapturer;
import org.webrtc.VideoFrame;
import org.webrtc.VideoSink;



public class FileShareVideoCapturer implements VideoCapturer {

    private final static String TAG = "FileVideoCapturer";
    private CapturerObserver capturerObserver;

    private SurfaceTextureHelper surTexture;

    private Context appContext;

    private Surface surface;

    private String stateLock = "";

    private boolean disposed = false;
    private int rotation = 0;

    private int width = 0;
    private int height = 0;

    private ShareImageReceiver shareImageReceiver;

    public FileShareVideoCapturer() {
    }

    @Override
    public void initialize(SurfaceTextureHelper surfaceTextureHelper, Context applicationContext,
                           CapturerObserver capturerObserver) {
        synchronized (stateLock) {
            this.capturerObserver = capturerObserver;
            this.surTexture = surfaceTextureHelper;
            this.appContext = applicationContext;
            surface = new Surface(surfaceTextureHelper.getSurfaceTexture());
        }
    }

    @Override
    public void startCapture(int width, int height, int framerate) {
        shareImageReceiver = new ShareImageReceiver();
        IntentFilter filter = new IntentFilter("inAppWebViewScreenCapture");
        appContext.registerReceiver(shareImageReceiver,filter);
        capturerObserver.onCapturerStarted(true);
        synchronized (stateLock) {
            surTexture.startListening(new VideoSink() {
                @Override
                public void onFrame(VideoFrame videoFrame) {
                    System.out.println("添加帧");
                    capturerObserver.onFrameCaptured(videoFrame);
                }
            });
        }


    }



    @Override
    public void stopCapture() {
        synchronized (stateLock) {
            surTexture.stopListening();
            capturerObserver.onCapturerStopped();
            try{
                appContext.unregisterReceiver(shareImageReceiver);
            }catch (Exception e){}
        }
    }


    @Override
    public void changeCaptureFormat(int width, int height, int framerate) {
    }

    @Override
    public void dispose() {

        synchronized (stateLock) {
            if (disposed) {
                return;
            }
            disposed = true;
            stopCapture();
            surface.release();
        }

    }

    @Override
    public boolean isScreencast() {
        return false;
    }

    public void pushBitmap(Bitmap bitmap, int rotationDegrees) {
        synchronized (stateLock) {

            if (disposed) {
                return;
            }
            if (this.rotation != rotationDegrees) {
                surTexture.setFrameRotation(rotationDegrees);
                this.rotation = rotationDegrees;
            }
            if (this.width != bitmap.getWidth() || this.height != bitmap.getHeight()) {
                surTexture.setTextureSize(bitmap.getWidth(), bitmap.getHeight());
                this.width = bitmap.getWidth();
                this.height = bitmap.getHeight();
            }
            surTexture.getHandler().post(() -> {
                Canvas canvas;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    canvas = surface.lockHardwareCanvas();
                } else {
                    canvas = surface.lockCanvas(null);
                }
                if (canvas != null) {
                    canvas.drawBitmap(bitmap, new Matrix(), new Paint());
                    surface.unlockCanvasAndPost(canvas);
                }
            });
        }
    }

   class ShareImageReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            byte[] data = intent.getByteArrayExtra("data");
            tick(data);
        }
    }
    public Bitmap Bytes2Bimap(byte[] b) {
        if (b.length != 0) {
            return BitmapFactory.decodeByteArray(b, 0, b.length);
        } else {
            return null;
        }
    }
    public void tick(byte[] data) {
        Bitmap bitmap = Bytes2Bimap(data);
        if (bitmap != null) {
            pushBitmap(bitmap, 0);
        }

    }
}

