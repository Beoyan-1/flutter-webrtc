package com.cloudwebrtc.webrtc.effector.filter;

import android.content.Context;
import android.opengl.GLES30;

import com.cloudwebrtc.webrtc.effector.utils.EffectorOpenGLUtils;

/**
 * 高通滤波器
 */
class GLImageBeautyHighPassFilter extends GLImageFilter {

    private int mBlurTextureHandle;
    private int mBlurTexture;

    public GLImageBeautyHighPassFilter(Context context) {
        this(context, VERTEX_SHADER, EffectorOpenGLUtils.getShaderFromAssets(context,
                "shader/beauty/fragment_beauty_highpass.glsl"));
    }

    public GLImageBeautyHighPassFilter(Context context, String vertexShader, String fragmentShader) {
        super(context, vertexShader, fragmentShader);
    }

    @Override
    public void initProgramHandle() {
        super.initProgramHandle();
        mBlurTextureHandle = GLES30.glGetUniformLocation(mProgramHandle, "blurTexture");
    }

    @Override
    public void onDrawFrameBegin() {
        super.onDrawFrameBegin();
        EffectorOpenGLUtils.bindTexture(mBlurTextureHandle, mBlurTexture, 1);
    }

    /**
     * 设置经过高斯模糊的滤镜
     * @param texture
     */
    public void setBlurTexture(int texture) {
        mBlurTexture = texture;
    }

}
