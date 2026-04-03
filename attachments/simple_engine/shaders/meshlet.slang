import culling;

// Common data
struct VertexExtraData
{
    uint8_t nx, ny, nz, nw; // normal
    uint8_t tx, ty, tz, tw; // tangent
    float16_t tu, tv;       // tex coords
    float padding;
};

struct VertexPosition
{
    float3 v;
    float padding;
};

struct Meshlet
{
    float3 center;
    float radius;

    int8_t cone_axis[3];
    int8_t cone_cutoff;

    uint data_offset;
    uint mesh_index;
    uint8_t vertex_count;
    uint8_t triangle_count;
};

ParameterBlock<TSOutput> input {

};

    // Input from vertex buffer
    struct TSInput {
    uint test;
};

// Output from vertex shader / Input to fragment shader
struct TSOutput {
    uint meshletIndices[32];
};

[shader("amplification")]
[numthreads(32, 1, 1)]
void taskMain(uint3 DTid: SV_DispatchThreadID)
{
    uint3 threadId : SV_GroupThreadID;
    uint3 groupId : SV_GroupID;
}

[shader("mesh")]
[numthreads(16, 16, 1)]
float4 meshMain(uint tig: SV_Target) {
    return float4(1, 1, 1, 1);
}