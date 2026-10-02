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

// TODO: PASS camera and sun direction to shader
public static const float PI = 3.14159265358979323846f;

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
[[vk::binding(2, 0)]] Sampler2D skyViewLUT; // Set 0 binding 2 for skyViewLUT values
[[vk::binding(3, 0)]]
cbuffer SkyViewParams
{
    float4x4 gInvViewProj;
    float3 gCameraWorldPos; // kilometers, planet-space
    float gViewHeight;
    float3 gSunDirection;
    float _pad;
};

struct Push {
    float exposure;
    float gamma;
    int outputIsSRGB;     // 1 when the color attachment is SRGB; 0 otherwise
    float BotttomRadius;         // pad to 16 bytes for push constant layout
};
[[vk::push_constant]] Push pushConsts;



float2 WorldDirToSkyViewUv(float3 dir, float3 sunDir, float viewHeight, float gBotttomRadius)
{
    // Inverse of SkyViewLUT.slang's UvToSkyViewLutParams
    float viewZenithCosAngle = dir.z;
    float lightViewCosAngle = dot(normalize(float2(dir.x, dir.y)), normalize(float2(sunDir.x, sunDir.y)));

    float Vhorizon = sqrt(viewHeight * viewHeight - gBotttomRadius * gBotttomRadius);
    float CosBeta = Vhorizon / viewHeight;
    float Beta = acos(CosBeta);
    float ZenithHorizonAngle = PI - Beta;

    float coordY;
    if (viewZenithCosAngle > cos(ZenithHorizonAngle))
    {
        float coord = acos(viewZenithCosAngle) / ZenithHorizonAngle;
        coordY = 0.5f - 0.5f * sqrt(1.0f - coord);
    }
    else
    {
        float coord = (acos(viewZenithCosAngle) - ZenithHorizonAngle) / Beta;
        coordY = 0.5f + 0.5f * sqrt(coord);
    }

    float coordX = sqrt(saturate((1.0f - lightViewCosAngle) * 0.5f));
    return float2(coordX, coordY);
}

// Export entrypoint for fragment stage
[shader("fragment")] float4 PSMain(VSOut i) : SV_TARGET
{
    // NOTE: Which depth convention?
    //ANSWER: Camera_component.h	
    // Common parameters
   // float nearPlane = 0.1f;
   // float farPlane = 100.0f;
    float depth = sceneDepth.Sample(i.UV).r;

    float4 c = sceneColor.Sample(i.UV);
    //float3 color = c.rgb;


    float3 color;
    // NOTE: adjust this comparison to match the depth convention 
    // (non-reversed) Z clears to 1.0 at the far plane; reversed-Z clears to 0.0.
    bool isBackground = pushConsts.BotttomRadius > 0.0f && depth >= 0.9999f;

    if (isBackground)
    {
        // Reconstruct the view ray from screen UV via the far plane - no need to
        // interpret the depth value itself, only whether this pixel is background.
        float2 ndc = i.UV * 2.0f - 1.0f;
        float4 farClip = float4(ndc, 1.0f, 1.0f);
        float4 farWorld = mul(gInvViewProj, farClip);
        farWorld /= farWorld.w;
        float3 dirEngine = normalize(farWorld.xyz - gCameraWorldPos);
        float3 worldDir = float3(dirEngine.x, -dirEngine.z, dirEngine.y); // Y-up -> Z-up 

        
        float2 uv = WorldDirToSkyViewUv(worldDir, normalize(gSunDirection), gViewHeight, gBotttomRadius);
        color = skyViewLUT.Sample(uv).rgb;
    }
    else
    {
        color = sceneColor.Sample(i.UV).rgb;
    }

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
