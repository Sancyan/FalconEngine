import AtmosphereCore;
import ScatteringIntegration;

[[vk::binding(5, 0)]]
Texture2D<float4> gMultiScatteringLUT;

[[vk::binding(6, 0)]]
RWTexture2D<float4> gSkyViewLUTOut;

[[vk::push_constant]]
cbuffer SkyViewPushConstants
{
    float3 gSunDirection;
    float  gViewHeight;
};

static const uint2 SKY_VIEW_LUT_RES = uint2(192, 108);
static const float SAMPLE_COUNT = 30.0f;

// Hillaire's non-linear UV mapping: puts more texel density near the horizon,
// where the sky has the most visible detail. Cross-check the exact constants
// here against your reference source before trusting this bit-for-bit.
void UvToSkyViewLutParams(AtmosphereParameters atmosphere, out float viewZenithCosAngle, out float lightViewCosAngle, float viewHeight, float2 uv)
{
    float Vhorizon = sqrt(viewHeight * viewHeight - atmosphere.BottomRadius * atmosphere.BottomRadius);
    float CosBeta = Vhorizon / viewHeight;
    float Beta = acos(CosBeta);
    float ZenithHorizonAngle = PI - Beta;

    if (uv.y < 0.5f)
    {
        float coord = 1.0f - 2.0f * uv.y;
        coord *= coord;
        coord = 1.0f - coord;
        viewZenithCosAngle = cos(ZenithHorizonAngle * coord);
    }
    else
    {
        float coord = uv.y * 2.0f - 1.0f;
        coord *= coord;
        viewZenithCosAngle = cos(ZenithHorizonAngle + Beta * coord);
    }

    float coord = uv.x;
    coord *= coord;
    lightViewCosAngle = -(coord * 2.0f - 1.0f);
}

[[shader("compute")]]
[numthreads(8, 8, 1)]
void main(uint3 dispatchThreadID : SV_DispatchThreadID)
{
    if (dispatchThreadID.x >= SKY_VIEW_LUT_RES.x || dispatchThreadID.y >= SKY_VIEW_LUT_RES.y)
        return;

    AtmosphereParameters atmosphere = gAtmosphere;

    float2 pixPos = float2(dispatchThreadID.xy) + 0.5f;
    float2 uv = pixPos / float2(SKY_VIEW_LUT_RES);

    float viewZenithCosAngle, lightViewCosAngle;
    UvToSkyViewLutParams(atmosphere, viewZenithCosAngle, lightViewCosAngle, gViewHeight, uv);

    float viewZenithSinAngle = sqrt(saturate(1.0f - viewZenithCosAngle * viewZenithCosAngle));
    float3 worldPos = float3(0.0f, 0.0f, gViewHeight);
    float3 worldDir = float3(
        viewZenithSinAngle * lightViewCosAngle,
        viewZenithSinAngle * sqrt(saturate(1.0f - lightViewCosAngle * lightViewCosAngle)),
        viewZenithCosAngle);

    ScatterIntegrationResult r = IntegrateScatteredLuminance(atmosphere, worldPos, worldDir, normalize(gSunDirection), false, SAMPLE_COUNT);

    gSkyViewLUTOut[dispatchThreadID.xy] = float4(r.L, 1.0f);
}