
/*
    Nyctalopia, by CopingMechanism
    This bloom's [--]ed up, as expected from an amatuer. Help is welcome! :)

    Process:
        Pass 1. Threshold in linear and downscale to 256x256 -> t_LOD_9
        Pass 2. t_LOD_9 prepates and outputs the last LOD level -> t_BlurH
        Pass 3. Horizontally blur t_BlurH -> t_BlurV
        Pass 4. Vertically blur t_BlurV -> t_Image
        Pass 5. t_Image composites the result, stretches to screen, and BlendOp
*/

#include "ReShade.fxh"

#define size 256.0
#define rcp_size 1.0/size

sampler s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };

texture t_LOD_9 < pooled = true; > { Width = size; Height = size; MipLevels = 9; Format = RGBA16F; };
texture t_BlurH < pooled = true; > { Width = size/16; Height = size/16; Format = RGB10A2; };
texture t_BlurV < pooled = true; > { Width = size/16; Height = size/16; Format = RGB10A2; };
texture t_Image < pooled = true; > { Width = size/16; Height = size/16; Format = RGB10A2; };

sampler s_LOD_9 { Texture = t_LOD_9; };
sampler s_BlurH { Texture = t_BlurH; };
sampler s_BlurV { Texture = t_BlurV; };
sampler s_Image { Texture = t_Image; };

// [ Pixel Shaders -> Techniques ]

/*
    [ Pixel Shaders -> Techniques ]
    [ Gaussian Blur Function by SleepKiller's shaderpatch ]
    [ PS_LOD_9 techniques by Keijiro Takahashi ]
*/

float4 PS_Light(vs_out o) : SV_Target
{
    float3 x = tex2D(s_Linear, o.uv).rgb;
    return float4((-0.1*x)/(x-1.1)*dot(x,x), 1.0);
}

float Brightness(float3 c) { return max(max(c.r, c.g), c.b); }

float4 PS_LOD_9(vs_out o) : SV_Target
{
    float4 d = (rcp_size * 8) * float4(-1, -1, +1, +1);

    float3 s1 = tex2D(s_LOD_9, o.uv + d.xy).rgb;
    float3 s2 = tex2D(s_LOD_9, o.uv + d.zy).rgb;
    float3 s3 = tex2D(s_LOD_9, o.uv + d.xw).rgb;
    float3 s4 = tex2D(s_LOD_9, o.uv + d.zw).rgb;

    // Karis's luma weighted average (using brightness instead of luma)
    float s1w = 1 / (Brightness(s1) + 1);
    float s2w = 1 / (Brightness(s2) + 1);
    float s3w = 1 / (Brightness(s3) + 1);
    float s4w = 1 / (Brightness(s4) + 1);
    float one_div_wsum = 1 / (s1w + s2w + s3w + s4w);

    return float4((s1 * s1w + s2 * s2w + s3 * s3w + s4 * s4w) * one_div_wsum, 1.0);
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

float4 PS_BlurV(vs_out o) : SV_Target { return float4(PS_Blur(o, s_BlurH, float2(rcp_size * 16, 0.0)), 1.0); }
float4 PS_BlurH(vs_out o) : SV_Target { return float4(PS_Blur(o, s_BlurV, float2(0.0, rcp_size * 16)), 1.0); }
float4 PS_Image(vs_out o) : SV_Target { return float4(tex2D(s_Image, o.uv).rgb, 1.0); }

technique CBloom2
{
    pass { VertexShader = PostProcessVS; PixelShader = PS_Light; RenderTarget = t_LOD_9; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_LOD_9; RenderTarget = t_BlurH; SRGBWriteEnable = true; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_BlurH; RenderTarget = t_BlurV; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_BlurV; RenderTarget = t_Image; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_Image; BlendEnable = true; DestBlend = INVSRCColor; }
}
