#version 430
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

uniform sampler2D stencilTex;

in DataVS {
    flat vec4 v_color;
    vec2 v_localPos;
};

out vec4 fragColor;

void main() {
    vec2 stencilUV = gl_FragCoord.xy * vec2(1.0 / VSX, 1.0 / VSY);
    float val = texture(stencilTex, stencilUV).r;

#if DEBUG_SHADER == 1
    // Visualize raw stencil gradient
    fragColor = vec4(val, val, val, 1.0);
#elif DEBUG_SHADER == 2
    // Visualize border band only (white)
    float outer = sin(val*31.4);
    float inner = sin(val*20);
    float border = outer - inner;
    fragColor = vec4(1.0, 1.0, 1.0, border);
#else
    // Normal: colored border
    float outer = sin(val*31.4);
    float inner = sin(val*20);
    float border = outer - inner;
    fragColor = vec4(v_color.rgb, v_color.a * border);
#endif
}
