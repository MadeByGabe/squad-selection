#version 430 core

//__DEFINES__

uniform sampler2D stencilTex;

in vec2 v_uv;
out vec4 fragColor;

void main() {
    vec4 stencil = texture(stencilTex, v_uv);
    float val = stencil.r;

    if (val <= 0.001) {
        discard;
    }

    vec3 color = stencil.gba;

#if DEBUG_SHADER == 1
    fragColor = vec4(val, val, val, 1.0);
#elif DEBUG_SHADER == 2
    float outer = cos(val * 8.28);
    fragColor = vec4(1.0, 1.0, 1.0, outer);
#else
    float outer = cos(val * 8.28);
    fragColor = vec4(color, CIRCLE_OPACITY * outer);
#endif
}
