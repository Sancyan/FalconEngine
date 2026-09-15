// AtmosphereCore.slang
//

public static const float PI = 3.14159265358979323846f;
public static const float PLANET_RADIUS_OFFSET = 0.01f;

// Atmosphere parameters


public struct AtmosphereParameters
{
    public float3 RayleighScattering;
    public float  RayleighDensityExpScale;

    public float3 MieScattering;
    public float  MieDensityExpScale;

    public float3 MieExtinction;
    public float  MiePhaseG;

    public float3 MieAbsorption;
    public float  BottomRadius;

    public float3 AbsorptionExtinction;
    public float  TopRadius;

    public float3 GroundAlbedo;
    public float  MultipleScatteringFactor;

    public float AbsorptionDensity0LayerWidth;
    public float AbsorptionDensity0ConstantTerm;
    public float AbsorptionDensity0LinearTerm;
    public float AbsorptionDensity1ConstantTerm;

    public float AbsorptionDensity1LinearTerm;
    public float MultiScatteringLUTRes;
    public int   TRANSMITTANCE_TEXTURE_WIDTH;
    public int   TRANSMITTANCE_TEXTURE_HEIGHT;
};

[[vk::binding(0, 0)]]
public ConstantBuffer<AtmosphereParameters> gAtmosphere;

// ---------------------------------------------------------------------------
// Geometry helpers
// ---------------------------------------------------------------------------

public float raySphereIntersectNearest(float3 r0, float3 rd, float3 s0, float sR)
{
    float3 s0_r0 = r0 - s0;
    float a = dot(rd, rd);
    float b = 2.0f * dot(rd, s0_r0);
    float c = dot(s0_r0, s0_r0) - sR * sR;
    float delta = b * b - 4.0f * a * c;
    if (delta < 0.0f || a == 0.0f) return -1.0f;
    float sol0 = (-b - sqrt(delta)) / (2.0f * a);
    float sol1 = (-b + sqrt(delta)) / (2.0f * a);
    if (sol0 < 0.0f && sol1 < 0.0f) return -1.0f;
    if (sol0 < 0.0f) return max(0.0f, sol1);
    if (sol1 < 0.0f) return max(0.0f, sol0);
    return max(0.0f, min(sol0, sol1));
}

// ---------------------------------------------------------------------------
// Participating medium (Rayleigh + Mie + ozone-style absorption layer)
// ---------------------------------------------------------------------------

public struct MediumSampleRGB
{
    public float3 scattering; // Rayleigh + Mie scattering (what actually feeds the phase function)
    public float3 extinction; // scattering + absorption across all three components
};

public MediumSampleRGB sampleMediumRGB(float3 WorldPos, AtmosphereParameters Atmosphere)
{
    float viewHeight = length(WorldPos) - Atmosphere.BottomRadius;

    float densityMie = exp(Atmosphere.MieDensityExpScale * viewHeight);
    float densityRay = exp(Atmosphere.RayleighDensityExpScale * viewHeight);
    float densityOzo = saturate(viewHeight < Atmosphere.AbsorptionDensity0LayerWidth
        ? Atmosphere.AbsorptionDensity0LinearTerm * viewHeight + Atmosphere.AbsorptionDensity0ConstantTerm
        : Atmosphere.AbsorptionDensity1LinearTerm * viewHeight + Atmosphere.AbsorptionDensity1ConstantTerm);

    float3 scatteringMie = densityMie * Atmosphere.MieScattering;
    float3 extinctionMie = densityMie * Atmosphere.MieExtinction;
    float3 scatteringRay = densityRay * Atmosphere.RayleighScattering; // Rayleigh absorption is 0 in the source
    float3 extinctionOzo = densityOzo * Atmosphere.AbsorptionExtinction; // ozone only absorbs, never scatters

    MediumSampleRGB s;
    s.scattering = scatteringMie + scatteringRay;
    s.extinction = extinctionMie + scatteringRay + extinctionOzo;
    return s;
}

public float uniformPhase()
{
    return 1.0f / (4.0f * PI);
}

// ---------------------------------------------------------------------------
// LUT parameterization (Bruneton 2017 height/angle mapping -- unchanged from source)
// ---------------------------------------------------------------------------

public float fromUnitToSubUvs(float u, float resolution) { return (u + 0.5f / resolution) * (resolution / (resolution + 1.0f)); }
public float fromSubUvsToUnit(float u, float resolution) { return (u - 0.5f / resolution) * (resolution / (resolution - 1.0f)); }

// uv -> (viewHeight, viewZenithCosAngle). Used when generating the transmittance LUT
// (each compute thread maps its texel to the (height, angle) pair it needs to evaluate).
public void UvToLutTransmittanceParams(AtmosphereParameters Atmosphere, out float viewHeight, out float viewZenithCosAngle, float2 uv)
{
    float x_mu = uv.x;
    float x_r  = uv.y;

    float H   = sqrt(Atmosphere.TopRadius * Atmosphere.TopRadius - Atmosphere.BottomRadius * Atmosphere.BottomRadius);
    float rho = H * x_r;
    viewHeight = sqrt(rho * rho + Atmosphere.BottomRadius * Atmosphere.BottomRadius);

    float d_min = Atmosphere.TopRadius - viewHeight;
    float d_max = rho + H;
    float d = d_min + x_mu * (d_max - d_min);
    viewZenithCosAngle = (d == 0.0f) ? 1.0f : (H * H - rho * rho - d * d) / (2.0f * viewHeight * d);
    viewZenithCosAngle = clamp(viewZenithCosAngle, -1.0f, 1.0f);
}

// (viewHeight, viewZenithCosAngle) -> uv. The inverse mapping, used whenever a later pass
// (multi-scattering, sky-view, aerial perspective, final composite) needs to *sample* the
// already-built transmittance LUT for an arbitrary point/direction.
public void LutTransmittanceParamsToUv(AtmosphereParameters Atmosphere, float viewHeight, float viewZenithCosAngle, out float2 uv)
{
    float H   = sqrt(max(0.0f, Atmosphere.TopRadius * Atmosphere.TopRadius - Atmosphere.BottomRadius * Atmosphere.BottomRadius));
    float rho = sqrt(max(0.0f, viewHeight * viewHeight - Atmosphere.BottomRadius * Atmosphere.BottomRadius));

    float discriminant = viewHeight * viewHeight * (viewZenithCosAngle * viewZenithCosAngle - 1.0f) + Atmosphere.TopRadius * Atmosphere.TopRadius;
    float d = max(0.0f, -viewHeight * viewZenithCosAngle + sqrt(discriminant));

    float d_min = Atmosphere.TopRadius - viewHeight;
    float d_max = rho + H;
    float x_mu = (d - d_min) / (d_max - d_min);
    float x_r  = rho / H;

    uv = float2(x_mu, x_r);
}

// ---------------------------------------------------------------------------
// Optical-depth-only integration -- used EXCLUSIVELY by the transmittance LUT.
//
// The source's general-purpose IntegrateScatteredLuminance also samples the
// transmittance LUT and evaluates phase functions while computing this, even though
// none of that affects the optical depth it returns (transmittance along a straight
// path depends only on the medium's extinction, never on sun direction or scattering).
// This function does only the work that actually contributes to the output, which is
// why it needs no sun direction, no phase function, and no texture bindings at all.
// ---------------------------------------------------------------------------

public float3 IntegrateOpticalDepth(AtmosphereParameters Atmosphere, float3 WorldPos, float3 WorldDir, float sampleCount)
{
    float3 earthO = float3(0.0f, 0.0f, 0.0f);
    float tBottom = raySphereIntersectNearest(WorldPos, WorldDir, earthO, Atmosphere.BottomRadius);
    float tTop    = raySphereIntersectNearest(WorldPos, WorldDir, earthO, Atmosphere.TopRadius);

    float tMax;
    if (tBottom < 0.0f)
    {
        if (tTop < 0.0f) return float3(0.0f, 0.0f, 0.0f); // Ray misses the atmosphere entirely.
        tMax = tTop;
    }
    else
    {
        tMax = (tTop > 0.0f) ? min(tTop, tBottom) : tBottom;
    }

    float3 opticalDepth = float3(0.0f, 0.0f, 0.0f);
    float t = 0.0f;
    const float sampleSegmentT = 0.3f; // Matches the source's fixed-step sample placement.

    for (float s = 0.0f; s < sampleCount; s += 1.0f)
    {
        float newT = tMax * (s + sampleSegmentT) / sampleCount;
        float dt = newT - t;
        t = newT;

        float3 P = WorldPos + t * WorldDir;
        MediumSampleRGB medium = sampleMediumRGB(P, Atmosphere);
        opticalDepth += medium.extinction * dt;
    }
    return opticalDepth;
}
