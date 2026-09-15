import AtmosphereCore;
import ScatteringIntegration;

[[vk::binding(4, 0)]]
RWTexture2D<float4> gMultiScatteringLUTOut;

static const uint  SQRT_SAMPLE_COUNT = 8;     // 8x8 = 64 sample directions over the sphere.
static const float SAMPLE_COUNT_INI  = 20.0f; // Ray-march steps per direction; a minimum is
                                               // needed for accuracy, per the source's comment.

groupshared float3 gMultiScatAs1Shared[64];
groupshared float3 gLShared[64];

[[shader("compute")]]
[numthreads(1, 1, 64)]
void main(uint3 dispatchThreadID : SV_DispatchThreadID, uint3 groupThreadID : SV_GroupThreadID)
{
    AtmosphereParameters atmosphere = gAtmosphere;
    float lutRes = gAtmosphere.MultiScatteringLUTRes;

    float2 pixPos = float2(dispatchThreadID.xy) + 0.5f;
    float2 uv = pixPos / lutRes;
    uv = float2(fromSubUvsToUnit(uv.x, lutRes), fromSubUvsToUnit(uv.y, lutRes));

    float cosSunZenithAngle = uv.x * 2.0f - 1.0f;
    float3 sunDir = float3(0.0f, sqrt(saturate(1.0f - cosSunZenithAngle * cosSunZenithAngle)), cosSunZenithAngle);
    float viewHeight = atmosphere.BottomRadius
        + saturate(uv.y + PLANET_RADIUS_OFFSET) * (atmosphere.TopRadius - atmosphere.BottomRadius - PLANET_RADIUS_OFFSET);

    float3 worldPos = float3(0.0f, 0.0f, viewHeight);

    const float sphereSolidAngle = 4.0f * PI;
    const float isotropicPhase = 1.0f / sphereSolidAngle;
    const float sqrtSample = float(SQRT_SAMPLE_COUNT);

    uint z = groupThreadID.z;
    float i = 0.5f + float(z / SQRT_SAMPLE_COUNT);
    float j = 0.5f + float(z - (z / SQRT_SAMPLE_COUNT) * SQRT_SAMPLE_COUNT);
    float randA = i / sqrtSample;
    float randB = j / sqrtSample;
    float theta = 2.0f * PI * randA;
    float phi = acos(1.0f - 2.0f * randB); // Uniform sphere sample
    float cosPhi = cos(phi), sinPhi = sin(phi);
    float cosTheta = cos(theta), sinTheta = sin(theta);
    float3 worldDir = float3(cosTheta * sinPhi, sinTheta * sinPhi, cosPhi);

    // ground = true: the multi-scattering estimate must include the single bounce off
    // the planet's surface, same as the source's call site.
    ScatterIntegrationResult r = IntegrateScatteredLuminance(atmosphere, worldPos, worldDir, sunDir, true, SAMPLE_COUNT_INI);

    gMultiScatAs1Shared[z] = r.MultiScatAs1 * sphereSolidAngle / (sqrtSample * sqrtSample);
    gLShared[z]            = r.L            * sphereSolidAngle / (sqrtSample * sqrtSample);

    GroupMemoryBarrierWithGroupSync();

    // Parallel reduction 64 -> 1,.
    [unroll]
    for (uint stride = 32; stride > 0; stride >>= 1)
    {
        if (z < stride)
        {
            gMultiScatAs1Shared[z] += gMultiScatAs1Shared[z + stride];
            gLShared[z]            += gLShared[z + stride];
        }
        GroupMemoryBarrierWithGroupSync();
    }

    if (z > 0) return;

    float3 multiScatAs1          = gMultiScatAs1Shared[0] * isotropicPhase; // Equation 7, f_ms
    float3 inScatteredLuminance  = gLShared[0]            * isotropicPhase; // Equation 5, L_2ndOrder

    // Geometric series over all scattering orders: 1 + r + r^2 + ... = 1 / (1 - r).
    float3 sumOfAllOrders = 1.0f / (1.0f - multiScatAs1); // Equation 10, Psi_ms
    float3 L = inScatteredLuminance * sumOfAllOrders;

    gMultiScatteringLUTOut[dispatchThreadID.xy] = float4(gAtmosphere.MultipleScatteringFactor * L, 1.0f);
}
