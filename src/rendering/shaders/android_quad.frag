#version 450

layout(location = 0) in vec2 fragTexCoord;

layout(location = 0) out vec4 outColor;

layout(binding = 0) uniform sampler2D texSampler;

layout(push_constant) uniform PushConstants {
    float pos_x;
    float pos_y;
    float size_x;
    float size_y;
    float extent_x;
    float extent_y;
    float opacity;
    float _pad;
    float content_rect_x;
    float content_rect_y;
    float content_rect_w;
    float content_rect_h;
} pc;

void main() {
    outColor = texture(texSampler, fragTexCoord) * pc.opacity;
}
