import AtmosphereCore;

[[vk::binding(3, 0)]]
RWTexture2D<float4> gTransmittanceLUTOut;

static const float SAMPLE_COUNT = 40.0f;

[shader("compute")]
[numthreads(8, 8, 1)]
void csMain(uint3 dispatchThreadID : SV_DispatchThreadID)
{
    uint width  = uint(gAtmosphere.TRANSMITTANCE_TEXTURE_WIDTH);
    uint height = uint(gAtmosphere.TRANSMITTANCE_TEXTURE_HEIGHT);
    if (dispatchThreadID.x >= width || dispatchThreadID.y >= height)
        return;

    AtmosphereParameters atmosphere = gAtmosphere;

    float2 pixPos = float2(dispatchThreadID.xy) + 0.5f;
    float2 uv = pixPos / float2(width, height);

    float viewHeight, viewZenithCosAngle;
    UvToLutTransmittanceParams(atmosphere, viewHeight, viewZenithCosAngle, uv);

    float3 worldPos = float3(0.0f, 0.0f, viewHeight);
    float3 worldDir = float3(0.0f, sqrt(1.0f - viewZenithCosAngle * viewZenithCosAngle), viewZenithCosAngle);

    float3 opticalDepth = IntegrateOpticalDepth(atmosphere, worldPos, worldDir, SAMPLE_COUNT);
    float3 transmittance = exp(-opticalDepth);

    gTransmittanceLUTOut[dispatchThreadID.xy] = float4(transmittance, 1.0f);
}