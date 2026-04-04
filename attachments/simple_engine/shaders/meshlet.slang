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

struct MeshDrawCommand
{
    uint drawId;

    // VkDrawIndexedIndirectCommand
    uint indexCount;
    uint instanceCount;
    uint firstIndex;
    uint vertexOffset;
    uint firstInstance;

    // VkDrawMeshTasksIndirectCommandNV
    uint taskCount;
    uint firstTask;
};

struct VisibleMeshCount {
    uint opaque_mesh_visible_count;
    uint opaque_mesh_culled_count;
    uint transparent_mesh_visible_count;
    uint transparent_mesh_culled_count;

    uint total_count;
    uint depth_pyramid_texture_index;
    uint late_flag;
    uint meshlet_index_count;

    uint dispatch_task_x;
    uint dispatch_task_y;
    uint dispatch_task_z;
    uint meshlet_instances_count;
};

struct GpuInstanceData {
    float4x4 model;
}

[[vk::binding(1, 0)]] StructuredBuffer<Meshlet> meshlets;
[[vk::binding(6, 0)]] StructuredBuffer<MeshDrawCommand> draw_commands;
[[vk::binding(7, 0)]] ConstantBuffer<VisibleMeshCount> counters;

struct TaskPayload {
    uint meshletIndices[32];
};

[shader("amplification")]
[numthreads(32, 1, 1)]
void taskMain(uint3 threadIdInGroup: SV_GroupThreadID, uint3 groupId: SV_GroupID, out payload TaskPayload payload)
{
    // Porting variables:
    uint thread_index = threadIdInGroup.x;
    uint group_index = groupId.x;
    uint global_meshlet_index = group_index * 32 + thread_index;

    uint mesh_instance_index = draw_commands[groupId.x].drawId;
    //TODO:Get meshlet instance data and implement cone cull and frustrum logic.

}

[shader("mesh")]
[numthreads(16, 16, 1)]
float4 meshMain(uint tig: SV_Target) {
    return float4(1, 1, 1, 1);
}