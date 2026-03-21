#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 10000

layout (location = 0) in vec4 circlepointposition;
layout (location = 1) in vec4 radius_color; // x=radius (negative=air), yzw=rgb
layout (location = 2) in uvec4 instData;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

uniform sampler2D heightmapTex;

struct SUniformsBuffer {
    uint composite;
    uint unused2;
    uint unused3;
    uint unused4;

    float maxHealth;
    float health;
    float unused5;
    float unused6;

    vec4 drawPos;
    vec4 speed;
    vec4[4] userDefined;
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
    SUniformsBuffer uni[];
};

out DataVS {
    flat vec4 v_color;
    smooth float v_dist; // 0 at center, 1 at edge
};

void main() {
    vec4 center = vec4(uni[instData.y].drawPos.xyz, 1.0);
    float circleRadius = abs(radius_color.x);
    bool isAir = radius_color.x < 0.0;

    // Frustum culling
    if (SphereInViewSignedDistance(center.xyz, circleRadius) > 0.0) {
        gl_Position = vec4(2.0, 0.0, 0.0, 1.0);
        return;
    }

    // Expand circle vertices in XZ plane
    vec4 vertex = vec4(center.xyz, 1.0);
    vertex.xz += circlepointposition.xy * circleRadius;

    if (isAir) {
        // Air units: flat circle at flight altitude
        vertex.y = max(0.0, center.y + 6.0);
    } else {
        // Ground/naval units: project each vertex to heightmap
        vec2 uvhm = heightmapUVatWorldPos(vertex.xz);
        vertex.y = textureLod(heightmapTex, uvhm, 0.0).x + 6.0;
    }

    gl_Position = cameraViewProj * vertex;
    v_color = vec4(radius_color.yzw, CIRCLE_OPACITY);
    v_dist = length(circlepointposition.xy); // 0 for center vertex, 1 for edge
}
