#version 430
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

uniform sampler2D stencilTex;

in DataVS {
    flat vec4 v_color;
};

out vec4 fragColor;

void main() {
    vec2 stencilUV = gl_FragCoord.xy * vec2(1.0 / VSX, 1.0 / VSY);
    float stencilValue = texture(stencilTex, stencilUV).r;
    float visibility = 1.0 - smoothstep(0.49, 0.51, stencilValue);
    fragColor = vec4(v_color.rgb, v_color.a * visibility);
}
