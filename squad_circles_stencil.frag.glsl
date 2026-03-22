#version 430
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in DataVS {
    flat vec4 v_color;
    vec2 v_localPos;
};

out vec4 fragColor;

void main() {
    float dist = length(v_localPos);
    fragColor = vec4(1.0 - dist, v_color.rgb);
}
