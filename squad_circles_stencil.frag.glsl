#version 430
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in DataVS {
    flat vec4 v_color;
};

out vec4 fragColor;

void main() {
    fragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
