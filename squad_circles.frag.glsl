#version 430
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in DataVS {
    flat vec4 v_color;
    smooth float v_dist;
};

out vec4 fragColor;

void main() {
    float t = 1.0 - v_dist;
    float alpha = v_color.a * t;
    // Premultiplied alpha for MAX blending
    fragColor = vec4(v_color.rgb * alpha, alpha);
}
