import AtmosphereCore;

[[vk::binding(1, 0)]] public Texture2D<float4> gTransmittanceLUT;
[[vk::binding(2, 0)]] public SamplerState       gLinearClampSampler;

public struct ScatterIntegrationResult
{
    public float3 L;            // In-scattered luminance along the ray (single scattering order).
    public float3 MultiScatAs1; // "If every sample scattered isotropically with albedo 1, how much
                                 // luminance would arrive" -- the geometric-series r term consumed
                                 // by the multi-scattering LUT pass.
};

// Ray march used by the multi-scattering LUT. This is a trimmed port of the source's
// IntegrateScatteredLuminance: dropped are the depth-buffer intersection branch, the
// variable-sample-count branch, the shadow-map lookup, and the debug-line hooks -- none
// of the LUT passes ever exercise those branches (they're only meaningful for the
// full-resolution ray-marched render).
public ScatterIntegrationResult IntegrateScatteredLuminance(
    AtmosphereParameters Atmosphere, float3 WorldPos, float3 WorldDir, float3 SunDir,
    bool ground, float sampleCount)
{
    ScatterIntegrationResult result;
    result.L = float3(0.0f, 0.0f, 0.0f);
    result.MultiScatAs1 = float3(0.0f, 0.0f, 0.0f);

    float3 earthO = float3(0.0f, 0.0f, 0.0f);
    float tBottom = raySphereIntersectNearest(WorldPos, WorldDir, earthO, Atmosphere.BottomRadius);
    float tTop    = raySphereIntersectNearest(WorldPos, WorldDir, earthO, Atmosphere.TopRadius);

    float tMax;
    if (tBottom < 0.0f)
    {
        if (tTop < 0.0f) return result; // Ray misses the atmosphere entirely.
        tMax = tTop;
    }
    else
    {
        tMax = (tTop > 0.0f) ? min(tTop, tBottom) : tBottom;
    }

    const float uniformPhaseValue = uniformPhase();
    float3 throughput = float3(1.0f, 1.0f, 1.0f);
    float t = 0.0f;
    const float sampleSegmentT = 0.3f;

    for (float s = 0.0f; s < sampleCount; s += 1.0f)
    {
        float newT = tMax * (s + sampleSegmentT) / sampleCount;
        float dt = newT - t;
        t = newT;

        float3 P = WorldPos + t * WorldDir;
        MediumSampleRGB medium = sampleMediumRGB(P, Atmosphere);
        float3 sampleOpticalDepth = medium.extinction * dt;
        float3 sampleTransmittance = exp(-sampleOpticalDepth);

        float pHeight = length(P);
        float3 upVector = P / pHeight;
        float sunZenithCosAngle = dot(SunDir, upVector);
        float2 uv;
        LutTransmittanceParamsToUv(Atmosphere, pHeight, sunZenithCosAngle, uv);
        float3 transmittanceToSun = gTransmittanceLUT.SampleLevel(gLinearClampSampler, uv, 0).rgb;

        // The multi-scattering LUT always integrates with a uniform (isotropic) phase
        // function -- MieRayPhase is false at this call site in the source, so the
        // Cornette-Shanks / Rayleigh phase evaluation never actually runs there.
        float3 phaseTimesScattering = medium.scattering * uniformPhaseValue;

        float tEarth = raySphereIntersectNearest(P, SunDir, earthO + PLANET_RADIUS_OFFSET * upVector, Atmosphere.BottomRadius);
        float earthShadow = (tEarth >= 0.0f) ? 0.0f : 1.0f;

        float3 S = earthShadow * transmittanceToSun * phaseTimesScattering;

        // Power-series multi-scatter factor (MULTI_SCATTERING_POWER_SERIE path in the
        // source -- the non-power-series branch is dead code there and isn't ported).
        float3 MS = medium.scattering;
        float3 MSint = (MS - MS * sampleTransmittance) / medium.extinction;
        result.MultiScatAs1 += throughput * MSint;

        float3 Sint = (S - S * sampleTransmittance) / medium.extinction;
        result.L += throughput * Sint;
        throughput *= sampleTransmittance;
    }

    if (ground && tMax == tBottom && tBottom > 0.0f)
    {
        float3 P = WorldPos + tBottom * WorldDir;
        float pHeight = length(P);
        float3 upVector = P / pHeight;
        float sunZenithCosAngle = dot(SunDir, upVector);
        float2 uv;
        LutTransmittanceParamsToUv(Atmosphere, pHeight, sunZenithCosAngle, uv);
        float3 transmittanceToSun = gTransmittanceLUT.SampleLevel(gLinearClampSampler, uv, 0).rgb;

        float NdotL = saturate(dot(upVector, SunDir));
        result.L += transmittanceToSun * throughput * NdotL * Atmosphere.GroundAlbedo / PI;
    }

    return result;
}
