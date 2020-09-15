
/*
    Nyctalopia, by CopingMechanism
    Gaussian Blur by SleepKiller's shaderpatch
    
    Process:
    Pass 1. Threshold and downscale to 256x256 -> t_LOD_9
    Pass 2. t_LOD_9 prepates and outputs the last LOD level -> t_BlurH
    Pass 3. Horizontally blur t_BlurH -> t_BlurV
    Pass 4. Vertically blur t_BlurV -> t_Image
    Pass 5. t_Image composites the result, stretches to screen, and BlendOp
*/

#include "ReShade.fxh"

#define size 256.0
#define rcp_size 1.0/pSize
#define mirror AddressU = MIRROR; AddressV = MIRROR; AddressW = MIRROR

// [ Textures and Samplers ]

sampler s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };

texture t_LOD_9 < pooled = true; > { Width = size; Height = size; MipLevels = 9; Format = RGBA16F; };
texture t_BlurH < pooled = true; > { Width = size/16; Height = size/16; Format = RGB10A2; };
texture t_BlurV < pooled = true; > { Width = size/16; Height = size/16; Format = RGB10A2; };
texture t_Image < pooled = true; > { Width = size/16; Height = size/16; Format = RGB10A2; };

sampler s_LOD_9 { Texture = t_LOD_9; mirror; };
sampler s_BlurH { Texture = t_BlurH; mirror; };
sampler s_BlurV { Texture = t_BlurV; mirror; };
sampler s_Image { Texture = t_Image; mirror; };

// [ Pixel Shaders -> Techniques ]

struct vs_out { float4 vpos : SV_POSITION; float2 uv : TEXCOORD; };

float3 PS_Blur(vs_out o, sampler src, float2 pSize) : SV_TARGET
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

float4 PS_Light(vs_out o) : COLOR { float3 c = tex2D(s_Linear, o.uv).rgb; return float4(lerp(c-1.0, dot(c, c), c*c), 1.0); }
float4 PS_LOD_9(vs_out o) : COLOR { return float4(tex2D(s_LOD_9, o.uv).rgb, 1.0); }
float4 PS_BlurH(vs_out o) : COLOR { return float4(PS_Blur(o, s_BlurH, float2(rcp_size * 16, 0.0)), 1.0); }
float4 PS_BlurV(vs_out o) : COLOR { return float4(PS_Blur(o, s_BlurV, float2(0.0, rcp_size * 16)), 1.0); }
float4 PS_Image(vs_out o) : COLOR { return float4(tex2D(s_Image, o.uv).rgb, 1.0); }

technique CBloom
{
    pass { VertexShader = PostProcessVS; PixelShader = PS_Light; RenderTarget = t_LOD_9; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_LOD_9; RenderTarget = t_BlurH; SRGBWriteEnable = true; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_BlurH; RenderTarget = t_BlurV; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_BlurV; RenderTarget = t_Image; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_Image; BlendEnable = true; DestBlend = INVSRCColor; }
}
