/* Copyright (c) 2025 Holochip Corporation
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 the "License";
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Fullscreen composite pass: samples the off-screen opaque color and writes to swapchain

import tonemapping_utils;
//import AtmosphereCore;

struct VSOut {
    float4 Position : SV_POSITION;
    float2 UV       : TEXCOORD0;
};

// Export entrypoint for vertex stage
[shader("vertex")] VSOut VSMain(uint vid : SV_VertexID)
{
    // Fullscreen triangle (no vertex buffer)
    float2 pos = float2( (vid == 2) ? 3.0 : -1.0,
                         (vid == 1) ? 3.0 : -1.0 );
    float2 uv  = float2( (vid == 2) ? 2.0 : 0.0,
                         (vid == 1) ? 2.0 : 0.0 );
    VSOut o;
    o.Position = float4(pos, 0.0, 1.0);
    o.UV = uv;
    return o;
}

// Set 0, binding 0: combined image sampler for the off-screen scene color
[[vk::binding(0, 0)]] Sampler2D sceneColor;
[[vk::binding(1, 0)]] Sampler2D sceneDepth; //Set 0 binding 1 for scene depth values
[[vk::binding(2, 0)]] Sampler2D skyViewLUT; //Set 0 binding 2 for skyViewLUT values

struct Push {
    float exposure;
    float gamma;
    int   outputIsSRGB; // 1 when the color attachment is SRGB; 0 otherwise
    float _pad;         // pad to 16 bytes for push constant layout
};
[[vk::push_constant]] Push pushConsts;

//[[vk::binding(3, 0)]]
//cbuffer SkyViewParams
//{
//    float4x4 gInvViewProj;
//    float3 gCameraWorldPos; // kilometers, planet-space 
//    float gViewHeight;
//    float3 gSunDirection;
//    float _pad0;
//};

//float2 WorldDirToSkyViewUv(float3 dir, float3 sunDir, float viewHeight, AtmosphereParameters atmosphere)
//{
//    // Inverse of SkyViewLUT.slang's UvToSkyViewLutParams
//    float viewZenithCosAngle = dir.z;
//    float lightViewCosAngle = dot(normalize(float2(dir.x, dir.y)), normalize(float2(sunDir.x, sunDir.y)));

//    float Vhorizon = sqrt(viewHeight * viewHeight - atmosphere.BottomRadius * atmosphere.BottomRadius);
//    float CosBeta = Vhorizon / viewHeight;
//    float Beta = acos(CosBeta);
//    float ZenithHorizonAngle = PI - Beta;

//    float coordY;
//    if (viewZenithCosAngle > cos(ZenithHorizonAngle))
//    {
//        float coord = acos(viewZenithCosAngle) / ZenithHorizonAngle;
//        coordY = 0.5f - 0.5f * sqrt(1.0f - coord);
//    }
//    else
//    {
//        float coord = (acos(viewZenithCosAngle) - ZenithHorizonAngle) / Beta;
//        coordY = 0.5f + 0.5f * sqrt(coord);
//    }

//    float coordX = sqrt(saturate((1.0f - lightViewCosAngle) * 0.5f));
//    return float2(coordX, coordY);
//}

// Export entrypoint for fragment stage
[shader("fragment")] float4 PSMain(VSOut i) : SV_TARGET
{
    float4 c = sceneColor.Sample(i.UV);
    float3 color = c.rgb;

    // Apply exposure and filmic tonemapping
    color *= pushConsts.exposure;

    // Uncharted2 / Hable filmic tonemap, canonical form
    float3 t = Hable_Filmic_Tonemapping::Uncharted2Tonemap(color);
    float3 w = Hable_Filmic_Tonemapping::Uncharted2Tonemap(float3(1,1,1) * Hable_Filmic_Tonemapping::W);
    color = t / max(w, float3(1e-6, 1e-6, 1e-6));

    // If the attachment is NOT SRGB, encode gamma here. When it is SRGB,
    // the hardware will encode at store so we keep color in linear space.
    if (pushConsts.outputIsSRGB == 0) {
        color = pow(max(color, 0.0), float3(1.0 / pushConsts.gamma));
    } else {
        color = saturate(color);
    }
    return float4(color, 1.0);
}
