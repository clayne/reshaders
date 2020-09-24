
/*
    Nyctalopia, by CopingMechanism
    This bloom's [--]ed up, as expected from an amatuer. Help is welcome! :)

    PS_Blur() Function by SleepKiller's shaderpatch (MIT License)
    aces_main_bakinglab() by MJP and David Neubelt (MIT License)
*/

#include "ReShade.fxh"

#define size 512.0
#define rcp_size 1.0/size

sampler s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };

texture t_LOD_6 < pooled = true; > { Width = size; Height = size; MipLevels = 6; Format = RGBA16F; };
texture t_BlurH < pooled = true; > { Width = size/32; Height = size/32; Format = RGBA16F; };
texture t_BlurV < pooled = true; > { Width = size/32; Height = size/32; Format = RGBA16F; };

sampler s_LOD_6 { Texture = t_LOD_6; };
sampler s_BlurH { Texture = t_BlurH; };
sampler s_BlurV { Texture = t_BlurV; };

struct vs_out { float4 vpos : SV_POSITION; float2 uv : TEXCOORD; };

// [ Pixel Shaders -> Techniques ]

float4 PS_Light(vs_out o) : SV_Target
{
    float3 m = tex2D(s_Linear, o.uv).rgb;
    return float4((saturate(lerp(-dot(m,m), m, m)))*dot( m, m), 1.0);
}

float3 PS_Blur(vs_out o, sampler src, float2 pSize)
{
    const int steps = 6;
    const float weights[steps] = { 0.16501, 0.17507, 0.10112, 0.04268, 0.01316, 0.002960 };
    const float offsets[steps] = { 0.65772, 2.45017, 4.41096, 6.37285, 8.33626, 10.30153 };

    float3 result;
    for (int i = 0; i < steps; ++i) {
        const float2 uv_offset = offsets[i] * pSize;
        const float3 samples = tex2D(src,o.uv + uv_offset).rgb + tex2D(src, o.uv - uv_offset).rgb;
        result += weights[i] * samples;
    }

    return result;
}

// sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
static const float3x3 ACESInputMat = float3x3(
    0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
static const float3x3 ACESOutputMat = float3x3(
     1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602
);

float3 RRTAndODTFit(float3 v)
{
    float3 a = v * (v + 0.0245786f) - 0.000090537f;
    float3 b = v * (0.983729f * v + 0.4329510f) + 0.238081f;
    return a / b;
}

float3 aces_main_bakinglab(float3 texColor)
{
    texColor = mul(ACESInputMat, texColor);
    texColor = RRTAndODTFit(texColor);
    return mul(ACESOutputMat, texColor);
}

/*
   The following code is licensed under the MIT license: https://gist.github.com/TheRealMJP/bc503b0b87b643d3505d41eab8b332ae
   Samples a texture with Catmull-Rom filtering, using 9 texture fetches instead of 16.
   See http://vec3.ca/bicubic-filtering-in-fewer-taps/ for more details
*/

float4 SampleTextureCatmullRom(vs_out o) : SV_Target
{
    /*
        We're going to sample a a 4x4 grid of texels surrounding the target UV coordinate. We'll do this by rounding
        down the sample location to get the exact center of our "starting" texel. The starting texel will be at
        location [1, 1] in the grid, where [0, 0] is the top left corner.
    */

    const float2 texSize = tex2Dsize(s_BlurV, 0.0);
    float2 samplePos = o.uv * texSize;
    float2 texPos1 = floor(samplePos - 0.5f) + 0.5f;

    /*
        Compute the fractional offset from our starting texel to our original sample location, which we'll
        feed into the Catmull-Rom spline function to get our filter weights.
    */

    float2 f = samplePos - texPos1;

    /*
        Compute the Catmull-Rom weights using the fractional offset that we calculated earlier.
        These equations are pre-expanded based on our knowledge of where the texels will be located,
        which lets us avoid having to evaluate a piece-wise function.
    */

    float2 w0 = f * (-0.5f + f * (1.0f - 0.5f * f));
    float2 w1 = 1.0f + f * f * (-2.5f + 1.5f * f);
    float2 w2 = f * (0.5f + f * (2.0f - 1.5f * f));
    float2 w3 = f * f * (-0.5f + 0.5f * f);

    /*
        Work out weighting factors and sampling offsets that will let us use bilinear filtering to
        simultaneously evaluate the middle 2 samples from the 4x4 grid.
    */

    float2 w12 = w1 + w2;
    float2 offset12 = w2 / (w1 + w2);

    // Compute the final UV coordinates we'll use for sampling the texture

    float2 texPos0 = texPos1 - 1;
    float2 texPos3 = texPos1 + 2;
    float2 texPos12 = texPos1 + offset12;

    texPos0 /= texSize;
    texPos3 /= texSize;
    texPos12 /= texSize;

    float4 result;
    result += tex2D(s_BlurV, float2(texPos0.x,  texPos0.y)) * w0.x  * w0.y;
    result += tex2D(s_BlurV, float2(texPos12.x, texPos0.y)) * w12.x * w0.y;
    result += tex2D(s_BlurV, float2(texPos3.x,  texPos0.y)) * w3.x  * w0.y;

    result += tex2D(s_BlurV, float2(texPos0.x,  texPos12.y)) * w0.x  * w12.y;
    result += tex2D(s_BlurV, float2(texPos12.x, texPos12.y)) * w12.x * w12.y;
    result += tex2D(s_BlurV, float2(texPos3.x,  texPos12.y)) * w3.x  * w12.y;

    result += tex2D(s_BlurV, float2(texPos0.x,  texPos3.y)) * w0.x  * w3.y;
    result += tex2D(s_BlurV, float2(texPos12.x, texPos3.y)) * w12.x * w3.y;
    result += tex2D(s_BlurV, float2(texPos3.x,  texPos3.y)) * w3.x  * w3.y;

    return float4(aces_main_bakinglab(result.rgb), 1.0);
}

float4 PS_BlurH(vs_out o) : SV_Target { return float4(PS_Blur(o, s_LOD_6, float2(rcp_size * 32, 0.0)), 1.0); }
float4 PS_BlurV(vs_out o) : SV_Target { return float4(PS_Blur(o, s_BlurH, float2(0.0, rcp_size * 32)), 1.0); }

technique CBloom2
{
    pass { VertexShader = PostProcessVS; PixelShader = PS_Light; RenderTarget = t_LOD_6; } // Generate 6 Mipmaps from a 512x512 texture
    pass { VertexShader = PostProcessVS; PixelShader = PS_BlurH; RenderTarget = t_BlurH; } // Horizontal Blur
    pass { VertexShader = PostProcessVS; PixelShader = PS_BlurV; RenderTarget = t_BlurV; } // Vertical Blur - Write Back to t_BlurH
    pass { VertexShader = PostProcessVS; PixelShader = SampleTextureCatmullRom; SRGBWriteEnable = true; BlendEnable = true; DestBlend = INVSRCColor; } // Catmull-Rom Upsample
}
