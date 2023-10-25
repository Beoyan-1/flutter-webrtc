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
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.util.Log;
import android.view.Surface;

import org.webrtc.CapturerObserver;
import org.webrtc.SurfaceTextureHelper;
import org.webrtc.VideoCapturer;
import org.webrtc.VideoFrame;
import org.webrtc.VideoSink;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Date;
import java.util.Map;


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
                    // System.out.println("添加帧");
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
            if(mWorkerThread!=null){
                mWorkerThread.exit();
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
    private WorkerThread mWorkerThread = new WorkerThread();
    int index=0;
    private class WorkerThread extends Thread {
        protected static final String TAG = "WorkerThread";
        private Handler mHandler;
        private Looper mLooper;
        public WorkerThread() {
            start();
        }
        public void run() {
            Looper.prepare();
            mLooper = Looper.myLooper();
            mHandler = new Handler(mLooper) {
                @Override
                public void handleMessage(Message msg) {
                    tick((byte[]) msg.obj);

                }
            };
            Looper.loop();
        }

        public void exit() {
            if (mLooper != null) {
                mLooper.quit();
                mLooper = null;
            }
        }

        public void executeTask(byte[] data) {
            Message msg = Message.obtain();
            msg.obj = data;
            mHandler.sendMessage(msg);
        }
    }



    class ShareImageReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            byte[] data = intent.getByteArrayExtra("data");
            // Bitmap bt= intent.getParcelableExtra("data");
            mWorkerThread.executeTask(data);
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