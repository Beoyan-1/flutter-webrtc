package com.cloudwebrtc.webrtc.effector.filter;

import android.content.Context;

import com.cloudwebrtc.webrtc.effector.utils.EffectorOpenGLUtils;

/**
 * 美颜用的高斯模糊
 */
class GLImageBeautyBlurFilter extends GLImageGaussianBlurFilter {

    public GLImageBeautyBlurFilter(Context context) {
        this(context, EffectorOpenGLUtils.getShaderFromAssets(context, "shader/beauty/vertex_beauty_blur.glsl"),
                EffectorOpenGLUtils.getShaderFromAssets(context, "shader/beauty/fragment_beauty_blur.glsl"));
    }

    public GLImageBeautyBlurFilter(Context context, String vertexShader, String fragmentShader) {
        super(context, vertexShader, fragmentShader);
    }

}
