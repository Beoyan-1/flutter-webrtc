package com.cloudwebrtc.webrtc;


import android.app.Activity;

import android.content.BroadcastReceiver;

import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Rect;

import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;

import android.util.Log;
import android.view.PixelCopy;
import android.view.Surface;

import org.webrtc.CapturerObserver;
import org.webrtc.SurfaceTextureHelper;
import org.webrtc.VideoCapturer;
import org.webrtc.VideoFrame;
import org.webrtc.VideoSink;

import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
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

            try{
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
            }catch (Exception e){
                Log.e("miki","报错---"+e.getMessage());
            }
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
        Bitmap bitmapTmp = null;
        @Override
        public void onReceive(Context context, Intent intent) {
            Bundle bundle = intent.getExtras();
            boolean isCaptureBySelf = bundle.getBoolean("isCaptureBySelf");
            if(isCaptureBySelf){
                //高版本，直接由webrtc自己截图
                //Log.e("miki","高版本，直接由webrtc自己截图");
                boolean isCaptrue = bundle.getBoolean("isCaptrue");

                if(isCaptrue){
                    int left = bundle.getInt("left");
                    int right = bundle.getInt("right");
                    int top = bundle.getInt("top");
                    int bottom = bundle.getInt("bottom");
                    int width = bundle.getInt("width");
                    int height = bundle.getInt("height");
                    Bitmap screenshotBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
                    //截图方法
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Rect rect = new Rect(left,top,right,bottom);
                      try{
                          PixelCopy.request(getActivity().getWindow() , rect,screenshotBitmap, new PixelCopy.OnPixelCopyFinishedListener() {
                              @Override
                              public void onPixelCopyFinished(int copyResult) {

                              }
                          }, new Handler(Looper.getMainLooper()));
                          bitmapTmp = screenshotBitmap.copy(Bitmap.Config.ARGB_8888,true);
                          pushBitmap(screenshotBitmap,0);
                      }catch (Exception e){

                      }

                    }
                }else{
                    pushBitmap(bitmapTmp,0);
                }
            }else {
                //低版本，获取由webview拿到的截图
               // Log.e("miki","高版本，获取由webview拿到的截图");
                byte[] data = bundle.getByteArray("data");
                mWorkerThread.executeTask(data);
            }
        }
    }



    public static Activity getActivity() {
        Class activityThreadClass = null;
        try {
            activityThreadClass = Class.forName("android.app.ActivityThread");
            Object activityThread = activityThreadClass.getMethod("currentActivityThread").invoke(null);
            Field activitiesField = activityThreadClass.getDeclaredField("mActivities");
            activitiesField.setAccessible(true);
            Map activities = (Map) activitiesField.get(activityThread);
            for (Object activityRecord : activities.values()) {
                Class activityRecordClass = activityRecord.getClass();

                Field pausedField = activityRecordClass.getDeclaredField("paused");
                pausedField.setAccessible(true);
                if (!pausedField.getBoolean(activityRecord)) {
                    Field activityField = activityRecordClass.getDeclaredField("activity");
                    activityField.setAccessible(true);
                    Activity activity = (Activity) activityField.get(activityRecord);
                    return activity;
                }
            }
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
        } catch (NoSuchMethodException e) {
            e.printStackTrace();
        } catch (IllegalAccessException e) {
            e.printStackTrace();
        } catch (InvocationTargetException e) {
            e.printStackTrace();
        } catch (NoSuchFieldException e) {
            e.printStackTrace();
        }
        return null;
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
            pushBitmap(bitmap,0);
        }

    }
}

