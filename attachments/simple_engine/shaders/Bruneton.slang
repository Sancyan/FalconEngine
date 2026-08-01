module atmosphere_definitions;



typedef float Length;
typedef float Wavelength;
typedef float Angle;
typedef float SolidAngle;
typedef float Power;
typedef float LuminousPower;



/*
<p>From this we "derive" the irradiance, radiance, spectral irradiance,
spectral radiance, luminance, etc, as well pure numbers, area, volume, etc (the
actual derivation is done in the <a href="reference/definitions.h.html">C++
equivalent</a> of this file).
*/

typedef float Number;
typedef float InverseLength;
typedef float Area;
typedef float Volume;
typedef float NumberDensity;
typedef float Irradiance;
typedef float Radiance;
typedef float SpectralPower;
typedef float SpectralIrradiance;
typedef float SpectralRadiance;
typedef float SpectralRadianceDensity;
typedef float ScatteringCoefficient;
typedef float InverseSolidAngle;
typedef float LuminousIntensity;
typedef float Luminance;
typedef float Illuminace;

/*
<p>We  also need vectors of physical quantities, mostly to represent functions
depending on the wavelength. In this case the vector elements correspond to
values of a function at some predefined wavelengths. Again, in GLSL we can't
define custom vector types to enforce the homogeneity of expressions at compile
time, so we define these vector types as <code>vec3</code>, with preprocessor
macros. The full definitions are given in the
<a href="reference/definitions.h.html">C++ equivalent</a> of this file).
*/

// A generic function from Wavelength to some other type.
typedef float3 AbstractSpectrum;
// A function from Wavelength to Number.
typedef float3 DimensionlessSpectrum;
// A function from Wavelength to SpectralPower.
typedef float3 PowerSpectrum;
// A function from Wavelength to SpectralIrradiance.
typedef float3 IrradianceSpectrum;
// A function from Wavelength to SpectralRadiance.
typedef float3 RadianceSpectrum;
// A function from Wavelength to SpectralRadianceDensity.
typedef float3 RadianceDensitySpectrum;
// A function from Wavelength to ScaterringCoefficient.
typedef float3 ScatteringSpectrum;

// A position in 3D (3 length values).
typedef float3 Position;
// A unit direction vector in 3D (3 unitless values).
typedef float3 Direction;
// A vector of 3 luminance values.
typedef float3 Luminance3;
// A vector of 3 illuminance values.
typedef float3 Illuminance3;

/*
<p>Finally, we also need precomputed textures containing physical quantities in
each texel. Since we can't define custom sampler types to enforce the
homogeneity of expressions at compile time in GLSL, we define these texture
types as <code>sampler2D</code> and <code>sampler3D</code>, with preprocessor
macros. The full definitions are given in the
<a href="reference/definitions.h.html">C++ equivalent</a> of this file).
*/

typedef Sampler2D TransmittanceTexture         ;
typedef Sampler3D AbstractScatteringTexture    ;
typedef Sampler3D ReducedScatteringTexture 	   ;
typedef Sampler3D ScatteringTexture 		   ;
typedef Sampler3D ScatteringDensityTexture 	   ;
typedef Sampler2D IrradianceTexture 		   ;

#ifdef D_UNREAL_ENGINE_4

float PI = 3.1415926535897932384626433832795f;
                                                                   ;
float m = 1.0f                                                     ;
float nm = 1.0f                                                    ;
float rad = 1.0f                                                   ;
float sr = 1.0f                                                    ;
float watt = 1.0f                                                  ;
float lm  =1.0f                                                    ;
float                                                              ;
float km  =(1000.0 * m)                                            ;
float m2  =(m * m)                                                 ;
float m3  =(m * m * m)                                             ;
float pi  = (PI * rad)                                             ;
float deg  = (pi / 180.0f)                                         ;
float watt_per_square_meter  = (watt / m2)                         ;
float watt_per_square_meter_per_sr  = (watt / (m2 * sr))           ;
float watt_per_square_meter_per_nm = (watt / (m2 * nm))            ;
float watt_per_square_meter_per_sr_per_nm = (watt / (m2 * sr * nm));
float watt_per_cubic_meter_per_sr_per_nm = (watt / (m3 * sr * nm));
float cd = (lm / sr)                                              ;
float kcd = (1000.0 * cd)                                         ;
float cd_per_square_meter = (cd / m2)                             ;
float kcd_per_square_meter  = (kcd / m2)                          ;
                                                                  
#else

/*
<h3>Physical units</h3>

<p>We can then define the units for our six base physical quantities:
meter (m), nanometer (nm), radian (rad), steradian (sr), watt (watt) and lumen
(lm):
*/

static const Length m = 1.0;
static const Wavelength nm = 1.0;
static const Angle rad = 1.0;
static const SolidAngle sr = 1.0;
static const Power watt = 1.0;
static const LuminousPower lm = 1.0;

/*
<p>From which we can derive the units for some derived physical quantities,
as well as some derived units (kilometer km, kilocandela kcd, degree deg):
*/

static const float ATMO_PI = 3.1415926535897932384626433832795f;

static const Length km = 1000.0 * m;
static const Area m2 = m * m;
static const Volume m3 = m * m * m;
static const Angle pi = ATMO_PI * rad;
static const Angle deg = pi / 180.0f;
static const Irradiance watt_per_square_meter = watt / m2;
static const Radiance watt_per_square_meter_per_sr = watt / (m2 * sr);
static const SpectralIrradiance watt_per_square_meter_per_nm = watt / (m2 * nm);
static const SpectralRadiance watt_per_square_meter_per_sr_per_nm =
    watt / (m2 * sr * nm);
static const SpectralRadianceDensity watt_per_cubic_meter_per_sr_per_nm =
    watt / (m3 * sr * nm);
static const LuminousIntensity cd = lm / sr;
static const LuminousIntensity kcd = 1000.0 * cd;
static const Luminance cd_per_square_meter = cd / m2;
static const Luminance kcd_per_square_meter = kcd / m2;

#endif

/*
<h3>Atmosphere parameters</h3>

<p>Using the above types, we can now define the parameters of our atmosphere
model. We start with the definition of density profiles, which are needed for
parameters that depend on the altitude:
*/

// An atmosphere layer of width 'width', and whose density is defined as
//   'exp_term' * exp('exp_scale' * h) + 'linear_term' * h + 'constant_term',
// clamped to [0,1], and where h is the altitude.
struct DensityProfileLayer {
    Length width;
    Number exp_term;
    InverseLength exp_scale;
    InverseLength linear_term;
    Number constant_term;
};

// An atmosphere density profile made of several layers on top of each other
// (from bottom to top). The width of the last layer is ignored, i.e. it always
// extend to the top atmosphere boundary. The profile values vary between 0
// (null density) to 1 (maximum density).
struct DensityProfile {
    DensityProfileLayer layers[2];
};

/*
The atmosphere parameters are then defined by the following struct:
*/

struct AtmosphereParameters {
    // The solar irradiance at the top of the atmosphere.
    IrradianceSpectrum solar_irradiance;
    // The sun's angular radius. Warning: the implementation uses approximations
    // that are valid only if this angle is smaller than 0.1 radians.
    Angle sun_angular_radius;
    // The distance between the planet center and the bottom of the atmosphere.
    Length bottom_radius;
    // The distance between the planet center and the top of the atmosphere.
    Length top_radius;
    // The density profile of air molecules, i.e. a function from altitude to
    // dimensionless values between 0 (null density) and 1 (maximum density).
    DensityProfile rayleigh_density;
    // The scattering coefficient of air molecules at the altitude where their
    // density is maximum (usually the bottom of the atmosphere), as a function of
    // wavelength. The scattering coefficient at altitude h is equal to
    // 'rayleigh_scattering' times 'rayleigh_density' at this altitude.
    ScatteringSpectrum rayleigh_scattering;
    // The density profile of aerosols, i.e. a function from altitude to
    // dimensionless values between 0 (null density) and 1 (maximum density).
    DensityProfile mie_density;
    // The scattering coefficient of aerosols at the altitude where their density
    // is maximum (usually the bottom of the atmosphere), as a function of
    // wavelength. The scattering coefficient at altitude h is equal to
    // 'mie_scattering' times 'mie_density' at this altitude.
    ScatteringSpectrum mie_scattering;
    // The extinction coefficient of aerosols at the altitude where their density
    // is maximum (usually the bottom of the atmosphere), as a function of
    // wavelength. The extinction coefficient at altitude h is equal to
    // 'mie_extinction' times 'mie_density' at this altitude.
    ScatteringSpectrum mie_extinction;
    // The asymetry parameter for the Cornette-Shanks phase function for the
    // aerosols.
    Number mie_phase_function_g;
    // The density profile of air molecules that absorb light (e.g. ozone), i.e.
    // a function from altitude to dimensionless values between 0 (null density)
    // and 1 (maximum density).
    DensityProfile absorption_density;
    // The extinction coefficient of molecules that absorb light (e.g. ozone) at
    // the altitude where their density is maximum, as a function of wavelength.
    // The extinction coefficient at altitude h is equal to
    // 'absorption_extinction' times 'absorption_density' at this altitude.
    ScatteringSpectrum absorption_extinction;
    // The average albedo of the ground.
    DimensionlessSpectrum ground_albedo;
    // The cosine of the maximum Sun zenith angle for which atmospheric scattering
    // must be precomputed (for maximum precision, use the smallest Sun zenith
    // angle yielding negligible sky light radiance values. For instance, for the
    // Earth case, 102 degrees is a good choice - yielding mu_s_min = -0.2).
    Number mu_s_min;
};

/*<h2>atmosphere/functions.glsl</h2>

<p>This GLSL file contains the core functions that implement our atmosphere
model. It provides functions to compute the transmittance, the single scattering
and the second and higher orders of scattering, the ground irradiance, as well
as functions to store these in textures and to read them back. It uses physical
types and constants which are provided in two versions: a
<a href="definitions.glsl.html">GLSL version</a> and a
<a href="reference/definitions.h.html">C++ version</a>. This allows this file to
be compiled either with a GLSL compiler or with a C++ compiler (see the
<a href="../index.html">Introduction</a>).

<p>The functions provided in this file are organized as follows:
<ul>
<li><a href="#transmittance">Transmittance</a>
<ul>
<li><a href="#transmittance_computation">Computation</a></li>
<li><a href="#transmittance_precomputation">Precomputation</a></li>
<li><a href="#transmittance_lookup">Lookup</a></li>
</ul>
</li>
<li><a href="#single_scattering">Single scattering</a>
<ul>
<li><a href="#single_scattering_computation">Computation</a></li>
<li><a href="#single_scattering_precomputation">Precomputation</a></li>
<li><a href="#single_scattering_lookup">Lookup</a></li>
</ul>
</li>
<li><a href="#multiple_scattering">Multiple scattering</a>
<ul>
<li><a href="#multiple_scattering_computation">Computation</a></li>
<li><a href="#multiple_scattering_precomputation">Precomputation</a></li>
<li><a href="#multiple_scattering_lookup">Lookup</a></li>
</ul>
</li>
<li><a href="#irradiance">Ground irradiance</a>
<ul>
<li><a href="#irradiance_computation">Computation</a></li>
<li><a href="#irradiance_precomputation">Precomputation</a></li>
<li><a href="#irradiance_lookup">Lookup</a></li>
</ul>
</li>
<li><a href="#rendering">Rendering</a>
<ul>
<li><a href="#rendering_sky">Sky</a></li>
<li><a href="#rendering_aerial_perspective">Aerial perspective</a></li>
<li><a href="#rendering_ground">Ground</a></li>
</ul>
</li>
</ul>

<p>They use the following utility functions to avoid NaNs due to floating point
values slightly outside their theoretical bounds:
*/

Number ClampCosine(Number mu) {
    return clamp(mu, Number(-1.0), Number(1.0));
}

Length ClampDistance(Length d) {
    return max(d, 0.0 * m);
}

Length ClampRadius(in AtmosphereParameters atmosphere, Length r) {
    return clamp(r, atmosphere.bottom_radius, atmosphere.top_radius);
}

Length SafeSqrt(Area a) {
    return sqrt(max(a, 0.0 * m2));
}

/*
<h3 id="transmittance">Transmittance</h3>
*/

Length DistanceToTopAtmosphereBoundary(in AtmosphereParameters atmosphere,
    Length r, Number mu) {
    static_assert(r <= atmosphere.top_radius, "Radius is not Smaller than atmosphere top radius!");
    static_assert(mu >= -1.0 && mu <= 1.0, "mu not in Valid Range!");
    Area discriminant = r * r * (mu * mu - 1.0) +
      atmosphere.top_radius * atmosphere.top_radius;
    return ClampDistance(-r * mu + SafeSqrt(discriminant));
}

/*
<p>We will also need, in the other sections, the distance to the bottom
atmosphere boundary, which can be computed in a similar way (this code assumes
that $[\bp,\bi)$ intersects the ground):
*/

Length DistanceToBottomAtmosphereBoundary(in AtmosphereParameters atmosphere,
    Length r, Number mu) {
    static_assert(r >= atmosphere.bottom_radius, "r is not greater than bottom radius");
    static_assert(mu >= -1.0 && mu <= 1.0, "mu is not in range -1,1");
    Area discriminant = r * r * (mu * mu - 1.0) +
      atmosphere.bottom_radius * atmosphere.bottom_radius;
    return ClampDistance(-r * mu - SafeSqrt(discriminant));
}

/*
<h5>Intersections with the ground</h5>

<p>The segment $[\bp,\bi]$ intersects the ground when
$d^2+2r\mu d+r^2=r_{\mathrm{bottom}}^2$ has a solution with $d \ge 0$. This
requires the discriminant $r^2(\mu^2-1)+r_{\mathrm{bottom}}^2$ to be positive,
from which we deduce the following function:
*/

bool RayIntersectsGround(in AtmosphereParameters atmosphere,
    Length r, Number mu) {
    static_assert(r >= atmosphere.bottom_radius, "r is not greater than bottom radius!");
    static_assert(mu >= -1.0 && mu <= 1.0, "mu is not in range");
    return mu < 0.0 && r * r * (mu * mu - 1.0) +
      atmosphere.bottom_radius * atmosphere.bottom_radius >= 0.0 * m2;
}

/*
<h5>Transmittance to the top atmosphere boundary</h5>

<p>We can now compute the transmittance between $\bp$ and $\bi$. From its
definition and the
<a href="https://en.wikipedia.org/wiki/Beer-Lambert_law">Beer-Lambert law</a>,
this involves the integral of the number density of air molecules along the
segment $[\bp,\bi]$, as well as the integral of the number density of aerosols
and the integral of the number density of air molecules that absorb light
(e.g. ozone) - along the same segment. These 3 integrals have the same form and,
when the segment $[\bp,\bi]$ does not intersect the ground, they can be computed
numerically with the help of the following auxilliary function (using the <a
href="https://en.wikipedia.org/wiki/Trapezoidal_rule">trapezoidal rule</a>):
*/

Number GetLayerDensity(in DensityProfileLayer layer, Length altitude) {
    Number density = layer.exp_term * exp(layer.exp_scale * altitude) +
      layer.linear_term * altitude + layer.constant_term;
    return clamp(density, Number(0.0), Number(1.0));
}

Number GetProfileDensity(in DensityProfile profile, Length altitude) {
    return altitude < profile.layers[0].width ?
      GetLayerDensity(profile.layers[0], altitude) :
      GetLayerDensity(profile.layers[1], altitude);
}

Length ComputeOpticalLengthToTopAtmosphereBoundary(
    in AtmosphereParameters atmosphere, in DensityProfile profile,
                                                   Length r, Number mu) {
    static_assert(r >= atmosphere.bottom_radius && r <= atmosphere.top_radius, "r not in range!");
    static_assert(mu >= -1.0 && mu <= 1.0, "mu not in range!");
    // Number of intervals for the numerical integration.
    const int SAMPLE_COUNT = 500;
    // The integration step, i.e. the length of each integration interval.
    Length dx =
      DistanceToTopAtmosphereBoundary(atmosphere, r, mu) / Number(SAMPLE_COUNT);
    // Integration loop.
    Length result = 0.0 * m;
    for (int i = 0; i <= SAMPLE_COUNT; ++i) {
        Length d_i = Number(i) * dx;
        // Distance between the current sample point and the planet center.
        Length r_i = sqrt(d_i * d_i + 2.0 * r * mu * d_i + r * r);
        // Number density at the current sample point (divided by the number density
        // at the bottom of the atmosphere, yielding a dimensionless number).
        Number y_i = GetProfileDensity(profile, r_i - atmosphere.bottom_radius);
        // Sample weight (from the trapezoidal rule).
        Number weight_i = i == 0 || i == SAMPLE_COUNT ? 0.5 : 1.0;
        result += y_i * weight_i * dx;
    }
    return result;
}

/*
<p>With this function the transmittance between $\bp$ and $\bi$ is now easy to
compute (we continue to assume that the segment does not intersect the ground):
*/

DimensionlessSpectrum ComputeTransmittanceToTopAtmosphereBoundary(
    in AtmosphereParameters atmosphere, Length r, Number mu) {
    static_assert(r >= atmosphere.bottom_radius && r <= atmosphere.top_radius,"r is not atmosphere range!" );
    static_assert(mu >= -1.0 && mu <= 1.0, "mu is not in range!");
    return exp(-(
      atmosphere.rayleigh_scattering *
                     ComputeOpticalLengthToTopAtmosphereBoundary(
              atmosphere, atmosphere.rayleigh_density, r, mu) +
                 atmosphere.mie_extinction *
                     ComputeOpticalLengthToTopAtmosphereBoundary(
              atmosphere, atmosphere.mie_density, r, mu) +
                 atmosphere.absorption_extinction *
                     ComputeOpticalLengthToTopAtmosphereBoundary(
              atmosphere, atmosphere.absorption_density, r, mu)));
}

/*
<h4 id="transmittance_precomputation">Precomputation</h4>

<p>The above function is quite costly to evaluate, and a lot of evaluations are
needed to compute single and multiple scattering. Fortunately this function
depends on only two parameters and is quite smooth, so we can precompute it in a
small 2D texture to optimize its evaluation.

<p>For this we need a mapping between the function parameters $(r,\mu)$ and the
texture coordinates $(u,v)$, and vice-versa, because these parameters do not
have the same units and range of values. And even if it was the case, storing a
function $f$ from the $[0,1]$ interval in a texture of size $n$ would sample the
function at $0.5/n$, $1.5/n$, ... $(n-0.5)/n$, because texture samples are at
the center of texels. Therefore, this texture would only give us extrapolated
function values at the domain boundaries ($0$ and $1$). To avoid this we need
to store $f(0)$ at the center of texel 0 and $f(1)$ at the center of texel
$n-1$. This can be done with the following mapping from values $x$ in $[0,1]$ to
texture coordinates $u$ in $[0.5/n,1-0.5/n]$ - and its inverse:
*/

Number GetTextureCoordFromUnitRange(Number x, int texture_size) {
    return 0.5 / Number(texture_size) + x * (1.0 - 1.0 / Number(texture_size));
}

Number GetUnitRangeFromTextureCoord(Number u, int texture_size) {
    return (u - 0.5 / Number(texture_size)) / (1.0 - 1.0 / Number(texture_size));
}

/*
<p>Using these functions, we can now define a mapping between $(r,\mu)$ and the
texture coordinates $(u,v)$, and its inverse, which avoid any extrapolation
during texture lookups. In the <a href=



<p>With these definitions, the mapping from $(r,\mu)$ to the texture coordinates
$(u,v)$ can be implemented as follows:
*/

float2 GetTransmittanceTextureUvFromRMu(in AtmosphereParameters atmosphere,
    Length r, Number mu) {
    static_assert(r >= atmosphere.bottom_radius && r <= atmosphere.top_radius, "r is not in valid range");
    static_assert(mu >= -1.0 && mu <= 1.0, "mu is not in valid range");
    // Distance to top atmosphere boundary for a horizontal ray at ground level.
    Length H = sqrt(atmosphere.top_radius * atmosphere.top_radius -
      atmosphere.bottom_radius * atmosphere.bottom_radius);
    // Distance to the horizon.
    Length rho =
      SafeSqrt(r * r - atmosphere.bottom_radius * atmosphere.bottom_radius);
    // Distance to the top atmosphere boundary for the ray (r,mu), and its minimum
    // and maximum values over all mu - obtained for (r,1) and (r,mu_horizon).
    Length d = DistanceToTopAtmosphereBoundary(atmosphere, r, mu);
    Length d_min = atmosphere.top_radius - r;
    Length d_max = rho + H;
    Number x_mu = (d - d_min) / (d_max - d_min);
    Number x_r = rho / H;
    return float2(GetTextureCoordFromUnitRange(x_mu, TRANSMITTANCE_TEXTURE_WIDTH),
                GetTextureCoordFromUnitRange(x_r, TRANSMITTANCE_TEXTURE_HEIGHT));
}

/*
<p>and the inverse mapping follows immediately:
*/

void GetRMuFromTransmittanceTextureUv(in AtmosphereParameters atmosphere,
    in float2 uv, out Length r, out Number mu) {
    static_assert(uv.x >= 0.0 && uv.x <= 1.0, "uv x not in 0,1 range");
    static_assert(uv.y >= 0.0 && uv.y <= 1.0, "uv y not in 0,1 range");
    Number x_mu = GetUnitRangeFromTextureCoord(uv.x, TRANSMITTANCE_TEXTURE_WIDTH);
    Number x_r = GetUnitRangeFromTextureCoord(uv.y, TRANSMITTANCE_TEXTURE_HEIGHT);
    // Distance to top atmosphere boundary for a horizontal ray at ground level.
    Length H = sqrt(atmosphere.top_radius * atmosphere.top_radius -
      atmosphere.bottom_radius * atmosphere.bottom_radius);
    // Distance to the horizon, from which we can compute r:
    Length rho = H * x_r;
    r = sqrt(rho * rho + atmosphere.bottom_radius * atmosphere.bottom_radius);
    // Distance to the top atmosphere boundary for the ray (r,mu), and its minimum
    // and maximum values over all mu - obtained for (r,1) and (r,mu_horizon) -
    // from which we can recover mu:
    Length d_min = atmosphere.top_radius - r;
    Length d_max = rho + H;
    Length d = d_min + x_mu * (d_max - d_min);
    mu = d == 0.0 * m ? Number(1.0) : (H * H - rho * rho - d * d) / (2.0 * r * d);
    mu = ClampCosine(mu);
}

/*
<p>It is now easy to define a fragment shader function to precompute a texel of
the transmittance texture:
*/

DimensionlessSpectrum ComputeTransmittanceToTopAtmosphereBoundaryTexture(
    in AtmosphereParameters atmosphere, in float2 frag_coord) {
    const float2 TRANSMITTANCE_TEXTURE_SIZE =
      float2(TRANSMITTANCE_TEXTURE_WIDTH, TRANSMITTANCE_TEXTURE_HEIGHT);
    Length r;
    Number mu;
    GetRMuFromTransmittanceTextureUv(
      atmosphere, frag_coord / TRANSMITTANCE_TEXTURE_SIZE, r, mu);
    return ComputeTransmittanceToTopAtmosphereBoundary(atmosphere, r, mu);
}



DimensionlessSpectrum GetTransmittanceToTopAtmosphereBoundary(
    in AtmosphereParameters atmosphere,
                                                              in TransmittanceTexture transmittance_texture,
    Length r, Number mu) {
    static_assert(r >= atmosphere.bottom_radius && r <= atmosphere.top_radius, "r not in valid atmosphere range");
    float2 uv = GetTransmittanceTextureUvFromRMu(atmosphere, r, mu);
    return DimensionlessSpectrum(texture(transmittance_texture, uv).rgb);
}



DimensionlessSpectrum GetTransmittance(
    IN(AtmosphereParameters) atmosphere,
                                       IN(TransmittanceTexture) transmittance_texture,
    Length r, Number mu, Length d, bool ray_r_mu_intersects_ground) {
    assert(r >= atmosphere.bottom_radius && r <= atmosphere.top_radius);
    assert(mu >= -1.0 && mu <= 1.0);
    assert(d >= 0.0 * m);

    Length r_d = ClampRadius(atmosphere, sqrt(d * d + 2.0 * r * mu * d + r * r));
    Number mu_d = ClampCosine((r * mu + d) / r_d);

    if (ray_r_mu_intersects_ground) {
        return min(
        GetTransmittanceToTopAtmosphereBoundary(
            atmosphere, transmittance_texture, r_d, -mu_d) /
                       GetTransmittanceToTopAtmosphereBoundary(
            atmosphere, transmittance_texture, r, -mu),
                   DimensionlessSpectrum(1.0, 1.0, 1.0));
    } else {
        return min(
        GetTransmittanceToTopAtmosphereBoundary(
            atmosphere, transmittance_texture, r, mu) /
                       GetTransmittanceToTopAtmosphereBoundary(
            atmosphere, transmittance_texture, r_d, mu_d),
                   DimensionlessSpectrum(1.0, 1.0, 1.0));
    }
}

/*
<p>where <code>ray_r_mu_intersects_ground</code> should be true iif the ray
defined by $r$ and $\mu$ intersects the ground. We don't compute it here with
<code>RayIntersectsGround</code> because the result could be wrong for rays
very close to the horizon, due to the finite precision and rounding errors of
floating point operations. And also because the caller generally has more robust
ways to know whether a ray intersects the ground or not (see below).

<p>Finally, we will also need the transmittance between a point in the
atmosphere and the Sun. The Sun is not a point light source, so this is an
integral of the transmittance over the Sun disc. Here we consider that the
transmittance is constant over this disc, except below the horizon, where the
transmittance is 0. As a consequence, the transmittance to the Sun can be
computed with <code>GetTransmittanceToTopAtmosphereBoundary</code>, times the
fraction of the Sun disc which is above the horizon.

<p>This fraction varies from 0 when the Sun zenith angle $\theta_s$ is larger
than the horizon zenith angle $\theta_h$ plus the Sun angular radius $\alpha_s$,
to 1 when $\theta_s$ is smaller than $\theta_h-\alpha_s$. Equivalently, it
varies from 0 when $\mu_s=\cos\theta_s$ is smaller than
$\cos(\theta_h+\alpha_s)\approx\cos\theta_h-\alpha_s\sin\theta_h$ to 1 when
$\mu_s$ is larger than
$\cos(\theta_h-\alpha_s)\approx\cos\theta_h+\alpha_s\sin\theta_h$. In between,
the visible Sun disc fraction varies approximately like a smoothstep (this can
be verified by plotting the area of <a
href="https://en.wikipedia.org/wiki/Circular_segment">circular segment</a> as a
function of its <a href="https://en.wikipedia.org/wiki/Sagitta_(geometry)"
>sagitta</a>). Therefore, since $\sin\theta_h=r_{\mathrm{bottom}}/r$, we can
approximate the transmittance to the Sun with the following function:
*/

DimensionlessSpectrum GetTransmittanceToSun(
    IN(AtmosphereParameters) atmosphere,
                                            IN(TransmittanceTexture) transmittance_texture,
    Length r, Number mu_s) {
    Number sin_theta_h = atmosphere.bottom_radius / r;
    Number cos_theta_h = -sqrt(max(1.0 - sin_theta_h * sin_theta_h, 0.0));
    return GetTransmittanceToTopAtmosphereBoundary(
          atmosphere, transmittance_texture, r, mu_s) *
           smoothstep(-sin_theta_h * atmosphere.sun_angular_radius / rad,
                      sin_theta_h * atmosphere.sun_angular_radius / rad,
                 mu_s - cos_theta_h);
}

/*
<h3 id="single_scattering">Single scattering</h3>

<p>The single scattered radiance is the light arriving from the Sun at some
point after exactly one scattering event inside the atmosphere (which can be due
to air molecules or aerosol particles; we exclude reflections from the ground,
computed <a href="#irradiance">separately</a>). The following sections describe
how we compute it, how we store it in a precomputed texture, and how we read it
back.

<h4 id="single_scattering_computation">Computation</h4>

<p>Consider the Sun light scattered at a point $\bq$ by air molecules before
arriving at another point $\bp$ (for aerosols, replace "Rayleigh" with "Mie"
below):

<svg height="190px" width="340px">
  <style type="text/css"><![CDATA[
    circle { fill: #000000; stroke: none; }
    path { fill: none; stroke: #000000; }
    text { font-size: 16px; font-style: normal; font-family: Sans; }
    .vector { font-weight: bold; }
  ]]></style>
  <path d="m 0,66 a 600,600 0 0 1 340,0"/>
  <path d="m 0,150 a 520,520 0 0 1 340,0"/>
  <path d="m 170,180 0,-165"/>
  <path d="m 250,180 30,-165"/>
  <path d="m 170,90 -30,-60"/>
  <path d="m 155,70 0,-10 8,6" />
  <path d="m 270,70 -20,-40" style="stroke-width:2;"/>
  <path d="m 170,90 100,-20" style="stroke-width:2;"/>
  <path d="m 270,70 75,-15" />
  <path d="m 170,65 a 25,25 0 0 1 25,20" style="stroke-dasharray:4,2;"/>
  <path d="m 170,30 a 60,60 1 0 0 -26.8,6.3" style="stroke-dasharray:4,2;"/>
  <path d="m 255,40 a 35,35 0 0 1 21,-3.2" style="stroke-dasharray:4,2;"/>
  <path d="m 258,45 a 30,30 0 0 1 41,19" style="stroke-dasharray:4,2;"/>
  <circle cx="170" cy="90" r="2.5"/>
  <circle cx="270" cy="70" r="2.5"/>
  <text x="155" y="105" class="vector">p</text>
  <text x="275" y="85" class="vector">q</text>
  <text x="130" y="70" class="vector">?<tspan
      dy="2" style="font-size:10px;font-weight:normal;">s</tspan></text>
  <text x="155" y="164">r</text>
  <text x="265" y="165">r<tspan dy="2" style="font-size:10px">d</tspan></text>
  <text x="220" y="95">d</text>
  <text x="190" y="65">?</text>
  <text x="145" y="25">?<tspan dy="2" style="font-size:10px">s</tspan></text>
  <text x="290" y="45">?</text>
  <text x="250" y="20">?<tspan dy="2" style="font-size:10px">s,d</tspan></text>
</svg>

<p>The radiance arriving at $\bp$ is the product of:
<ul>
<li>the solar irradiance at the top of the atmosphere,</li>
<li>the transmittance between the Sun and $\bq$ (i.e. the fraction of the Sun
light at the top of the atmosphere that reaches $\bq$),</li>
<li>the Rayleigh scattering coefficient at $\bq$ (i.e. the fraction of the
light arriving at $\bq$ which is scattered, in any direction),</li>
<li>the Rayleigh phase function (i.e. the fraction of the scattered light at
$\bq$ which is actually scattered towards $\bp$),</li>
<li>the transmittance between $\bq$ and $\bp$ (i.e. the fraction of the light
scattered at $\bq$ towards $\bp$ that reaches $\bp$).</li>
</ul>

<p>Thus, by noting $\bw_s$ the unit direction vector towards the Sun, and with
the following definitions:
<ul>
<li>$r=\Vert\bo\bp\Vert$,</li>
<li>$d=\Vert\bp\bq\Vert$,</li>
<li>$\mu=(\bo\bp\cdot\bp\bq)/rd$,</li>
<li>$\mu_s=(\bo\bp\cdot\bw_s)/r$,</li>
<li>$\nu=(\bp\bq\cdot\bw_s)/d$</li>
</ul>
the values of $r$ and $\mu_s$ for $\bq$ are
<ul>
<li>$r_d=\Vert\bo\bq\Vert=\sqrt{d^2+2r\mu d +r^2}$,</li>
<li>$\mu_{s,d}=(\bo\bq\cdot\bw_s)/r_d=((\bo\bp+\bp\bq)\cdot\bw_s)/r_d=
(r\mu_s + d\nu)/r_d$</li>
</ul>
and the Rayleigh and Mie single scattering components can be computed as follows
(note that we omit the solar irradiance and the phase function terms, as well as
the scattering coefficients at the bottom of the atmosphere - we add them later
on for efficiency reasons):
*/

void ComputeSingleScatteringIntegrand(
    IN(AtmosphereParameters) atmosphere,
                                      IN(TransmittanceTexture) transmittance_texture,
    Length r, Number mu, Number mu_s, Number nu, Length d,
    bool ray_r_mu_intersects_ground,
                                      OUT(DimensionlessSpectrum) rayleigh, OUT(DimensionlessSpectrum) mie) {
    Length r_d = ClampRadius(atmosphere, sqrt(d * d + 2.0 * r * mu * d + r * r));
    Number mu_s_d = ClampCosine((r * mu_s + d * nu) / r_d);
    DimensionlessSpectrum transmittance =
        GetTransmittance(
          atmosphere, transmittance_texture, r, mu, d,
          ray_r_mu_intersects_ground) *
        GetTransmittanceToSun(
          atmosphere, transmittance_texture, r_d, mu_s_d);
    rayleigh = transmittance * GetProfileDensity(
      atmosphere.rayleigh_density, r_d - atmosphere.bottom_radius);
    mie = transmittance * GetProfileDensity(
      atmosphere.mie_density, r_d - atmosphere.bottom_radius);
}

/*
<p>Consider now the Sun light arriving at $\bp$ from a given direction $\bw$,
after exactly one scattering event. The scattering event can occur at any point
$\bq$ between $\bp$ and the intersection $\bi$ of the half-line $[\bp,\bw)$ with
the nearest atmosphere boundary. Thus, the single scattered radiance at $\bp$
from direction $\bw$ is the integral of the single scattered radiance from $\bq$
to $\bp$ for all points $\bq$ between $\bp$ and $\bi$. To compute it, we first
need the length $\Vert\bp\bi\Vert$:
*/

Length DistanceToNearestAtmosphereBoundary(IN(AtmosphereParameters) atmosphere,
    Length r, Number mu, bool ray_r_mu_intersects_ground) {
    if (ray_r_mu_intersects_ground) {
        return DistanceToBottomAtmosphereBoundary(atmosphere, r, mu);
    } else {
        return DistanceToTopAtmosphereBoundary(atmosphere, r, mu);
    }
}

/*
<p>The single scattering integral can then be computed as follows (using
the <a href="https://en.wikipedia.org/wiki/Trapezoidal_rule">trapezoidal
rule</a>):
*/

void ComputeSingleScattering(
    IN(AtmosphereParameters) atmosphere,
    IN(TransmittanceTexture) transmittance_texture,
                             Length r, Number mu, Number mu_s, Number nu,
    bool ray_r_mu_intersects_ground,
                             OUT(IrradianceSpectrum) rayleigh, OUT(IrradianceSpectrum) mie) {
    assert(r >= atmosphere.bottom_radius && r <= atmosphere.top_radius);
    assert(mu >= -1.0 && mu <= 1.0);
    assert(mu_s >= -1.0 && mu_s <= 1.0);
    assert(nu >= -1.0 && nu <= 1.0);

    // Number of intervals for the numerical integration.
    const int SAMPLE_COUNT = 50;
    // The integration step, i.e. the length of each integration interval.
    Length dx =
        DistanceToNearestAtmosphereBoundary(atmosphere, r, mu,
          ray_r_mu_intersects_ground) / Number(SAMPLE_COUNT);
    // Integration loop.
    DimensionlessSpectrum rayleigh_sum = DimensionlessSpectrum(0.0, 0.0, 0.0);
    DimensionlessSpectrum mie_sum = DimensionlessSpectrum(0.0, 0.0, 0.0);
    for (int i = 0; i <= SAMPLE_COUNT; ++i) {
        Length d_i = Number(i) * dx;
        // The Rayleigh and Mie single scattering at the current sample point.
        DimensionlessSpectrum rayleigh_i;
        DimensionlessSpectrum mie_i;
        ComputeSingleScatteringIntegrand(atmosphere, transmittance_texture,
        r, mu, mu_s, nu, d_i, ray_r_mu_intersects_ground, rayleigh_i, mie_i);
        // Sample weight (from the trapezoidal rule).
        Number weight_i = (i == 0 || i == SAMPLE_COUNT) ? 0.5 : 1.0;
        rayleigh_sum += rayleigh_i * weight_i;
        mie_sum += mie_i * weight_i;
    }
    rayleigh = rayleigh_sum * dx * atmosphere.solar_irradiance *
      atmosphere.rayleigh_scattering;
    mie = mie_sum * dx * atmosphere.solar_irradiance * atmosphere.mie_scattering;
}

