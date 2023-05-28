#include <metal_stdlib>

using namespace metal;

struct Vertex
{
    float2 dst_position;
    float2 mask_position;
    float2 src_position;
};

struct RasterizerData
{
    float4 position [[position]];
    float2 dst_position;
    float2 mask_position;
    float2 src_position;
};

vertex RasterizerData vertex_main(const device Vertex *vertices [[buffer(0)]],
                                  uint vertexID [[vertex_id]])
{
    RasterizerData out_vertex;
    Vertex in_vertex = vertices[vertexID];

    out_vertex.position =
        float4((in_vertex.dst_position - float2(0.5, 0.5)) * float2(2.0, -2.0), 0.0, 1.0);
    out_vertex.dst_position = in_vertex.dst_position;
    out_vertex.mask_position = in_vertex.mask_position;
    out_vertex.src_position = in_vertex.src_position;

    return out_vertex;
}

fragment float4 fragment_main(RasterizerData data [[stage_in]],
                              texture2d<float, access::sample> frame_texture [[texture(0)]],
                              sampler frame_sampler [[sampler(0)]],
                              texture2d<float, access::sample> face_texture [[texture(1)]],
                              sampler face_sampler [[sampler(1)]],
                              texture2d<float, access::sample> mask_texture [[texture(2)]],
                              sampler mask_sampler [[sampler(2)]])
{
    float alpha = data.mask_position.x < .33 || data.mask_position.x > .67 ||
                          data.mask_position.y < .33 || data.mask_position.y > .67
                      ? 0.0
                      : mask_texture.sample(mask_sampler, data.mask_position).r;
    float4 dst = frame_texture.sample(frame_sampler, data.dst_position) * (1.0 - alpha);
    float4 src = face_texture.sample(face_sampler, data.src_position) * alpha;

    return dst + src;
}
