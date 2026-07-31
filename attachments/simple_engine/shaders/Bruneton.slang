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