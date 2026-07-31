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
typedef float SpectralRadianceDenisty;
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

static const float ATMO_PI = 3.1415926535897932384626433832795f;

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
