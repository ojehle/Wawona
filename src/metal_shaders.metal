#include <metal_stdlib>
using namespace metal;

// Simple vertex shader for compositing Wayland surfaces
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    // Position is already in normalized device coordinates (-1 to 1)
    out.position = float4(in.position.x, in.position.y, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

// Simple fragment shader for texture sampling
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               texture2d<float> texture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    return texture.sample(textureSampler, in.texCoord);
}

