package com.cloudwebrtc.webrtc.effector;

import android.content.Context;

import com.cloudwebrtc.webrtc.effector.filter.GLImageBeautyFilter;
import com.cloudwebrtc.webrtc.effector.filter.bean.BeautyParam;
import com.cloudwebrtc.webrtc.effector.format.LibYuvBridge;
import com.cloudwebrtc.webrtc.effector.format.YuvByteBufferDumper;
import com.cloudwebrtc.webrtc.effector.format.YuvByteBufferReader;
import com.cloudwebrtc.webrtc.effector.utils.EffectorOpenGLUtils;
import com.cloudwebrtc.webrtc.effector.utils.TextureRotationUtils;

import org.webrtc.GlUtil;
import org.webrtc.SurfaceTextureHelper;
import org.webrtc.VideoFrame;

import java.nio.FloatBuffer;

public class RTCVideoEffector {

    public static final String TAG = RTCVideoEffector.class.getSimpleName();

    private Runnable mPendingRunnable;
    private boolean isFrist = true;
    private LibYuvBridge libYuvBridge;
    private GLImageBeautyFilter beautyFilter;

    private Context mcontext;


    public RTCVideoEffector(Context applicationConte) {
        this.mcontext = applicationConte;

    }

    private VideoEffectorContext context = new VideoEffectorContext();

    private boolean enabled = true;

    private YuvByteBufferReader yuvBytesReader;
    private YuvByteBufferDumper yuvBytesDumper;

    private SurfaceTextureHelper helper;
    private FloatBuffer mVertexBuffer;
    private FloatBuffer mTextureBuffer;

    public void init(SurfaceTextureHelper helper) {

        VideoEffectorLogger.d(TAG, "init");

        this.helper = helper;

        libYuvBridge = new LibYuvBridge();
        beautyFilter = new GLImageBeautyFilter(this.mcontext);
        yuvBytesReader = new YuvByteBufferReader();
        yuvBytesReader.init();

        yuvBytesDumper = new YuvByteBufferDumper();
        yuvBytesDumper.init();
        mVertexBuffer = EffectorOpenGLUtils.createFloatBuffer(TextureRotationUtils.CubeVertices);
        mTextureBuffer = EffectorOpenGLUtils.createFloatBuffer(TextureRotationUtils.TextureVertices);

        GlUtil.checkNoGLES2Error("RTCVideoEffector.init");
    }

    public boolean isEnabled() {
        return enabled;
    }

    public void enable() {
        enabled = true;
    }

    public void disable() {
        enabled = false;
    }

    public VideoFrame.I420Buffer processByteBufferFrame(VideoFrame.I420Buffer i420Buffer,
                                                        int rotation, long timestamp) {

        if (!isEnabled()) {
            return i420Buffer;
        }

        // Direct buffer ではない場合スルーする
        // TODO: direct に変換してあげる手もある
        if (!i420Buffer.getDataY().isDirect()
                || !i420Buffer.getDataU().isDirect()
                || !i420Buffer.getDataV().isDirect()) {
            return i420Buffer;
        }

        int width = i420Buffer.getWidth();
        int height = i420Buffer.getHeight();
        int strideY = i420Buffer.getStrideY();
        int strideU = i420Buffer.getStrideU();
        int strideV = i420Buffer.getStrideV();

        context.updateFrameInfo(width, height, rotation, timestamp);

//        if (mShaderGroup != null) {
//            filterWrapper.updateShader(mShaderGroup, width, height);
//            mShaderGroup = null;
//        }

        int stepTextureId = yuvBytesReader.read(i420Buffer);

        // ビデオフレームの画像は回転された状態で来ることがある
        // グレースケールやセピアフィルタなど、画像全体に均質にかけるエフェクトでは問題にならないが
        // 座標を指定する必要のあるエフェクトでは、使いにくいものとなる。
        // 비디오 프레임의 이미지는 회전 된 상태로 올 수 있는
        // 그레이 스케일과 세피아 필터 등 이미지 전체에 균일하게 적용되는 효과는 문제가 되지 않지만
        // 좌표를 지정해야 하는 효과는 사용하기 어려울 수 있습니다

        // そのため、場合によっては、フィルタをかける前後で回転の補正を行う必要がある
        // ただし、そのためのtexture間のコピーが二度発生することになる
        // 必要のないときはこの機能は使わないようにon/offできるようにしておきたい
        // 따라서, 경우에 따라 필터링 전후로 회전 보정을 해야 할 수 있습니다
        // 추가로 텍스쳐간 복사가 두번 발생하게 되는 기능이 필요하지 않을 때에를 위해, 관련 기능을 토글처리를 구현해야 할 수 있습니다

        if (context.getFrameInfo().isRotated()) {
            // TODO
        }
//
        if (isEnabled()) {
            VideoEffectorContext.FrameInfo info = context.getFrameInfo();
            beautyFilter.initFrameBuffer(info.getWidth(), info.getHeight());
            BeautyParam beautyParam = new BeautyParam();
            beautyParam.beautyIntensity = 0.7f;
            beautyParam.complexionIntensity = 0.7f;
            beautyParam.faceLift = 1.0f;
            beautyParam.faceShave = 1.0f;
            beautyParam.chinIntensity = 1.0f;
            beautyFilter.onBeauty(beautyParam);
            stepTextureId = beautyFilter.drawFrameBuffer(stepTextureId, mVertexBuffer, mTextureBuffer);
        }

        if (context.getFrameInfo().isRotated()) {
            // TODO
        }

        return yuvBytesDumper.dump(stepTextureId, width, height, strideY, strideU, strideV);
//        return  i420Buffer;
    }


//    public boolean needToProcessFrame() {
//        if (!enabled) {
//            return false;
//        }

//        if (filterWrapper != null) {
//            if (filterWrapper.isEnabled()) {
//                return true;
//            } else {
//                return false;
//            }
//        } else {
//            return false;
//        }

//    }

    public void dispose() {
        disposeInternal();
//        if (helper != null) {
//            // This effector is not initialized
//            return;
//        }
//        ThreadUtils.invokeAtFrontUninterruptibly(this.helper.getHandler(), new Runnable() {
//            @Override
//            public void run() {
//                disposeInternal();
//            }
//        });
    }

    private void disposeInternal() {


        yuvBytesReader.dispose();
        yuvBytesDumper.dispose();
    }

//    public void updateShader(final GPUImageFilter group) {
//        mShaderGroup = group;
//    }
}
