
/*
    Nyctalopia, by CopingMechanism
    This bloom's [--]ed up, as expected from an amatuer. Help is welcome! :)

    PS_Blur() by ShaderPatch https://github.com/SleepKiller/shaderpatch (MIT License)
    aces_main_bakinglab() by TheRealMJP https://github.com/TheRealMJP/BakingLab (MIT License)
*/

#include "ReShade.fxh"

#define size 512.0
#define rcp_size 1.0/size

texture t_LOD_6 < pooled = true; > { Width = size; Height = size; MipLevels = 6; Format = RGB10A2; };
texture t_BlurH < pooled = true; > { Width = size/32; Height = size/32; Format = RGB10A2; };
texture t_BlurV < pooled = true; > { Width = size/32; Height = size/32; Format = RGB10A2; };

sampler s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler s_LOD_6 { Texture = t_LOD_6; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler s_BlurH { Texture = t_BlurH; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler s_BlurV { Texture = t_BlurV; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };

// [ Pixel Shaders -> Techniques ]

struct vs_out { float4 vpos : SV_POSITION; float2 uv : TEXCOORD; };

float4 PS_Light(vs_out o) : SV_Target
{
    float3 m = tex2D(s_Linear, o.uv).rgb;
    m = saturate(lerp(-dot(m,m)-m, m, m)) * dot(m, m); // Threshold by Lerp (), Intensify by Dot()
    return float4(m, 1.0);
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

float4 PS_BlurH(vs_out o) : SV_Target { return float4(PS_Blur(o, s_LOD_6, float2(rcp_size * 32, 0.0)), 1.0); }
float4 PS_BlurV(vs_out o) : SV_Target { return float4(PS_Blur(o, s_BlurH, float2(0.0, rcp_size * 32)), 1.0); }

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
    https://www.shadertoy.com/view/tlXSR2
    For more details, see [ vec3.ca/bicubic-filtering-in-fewer-taps/ ] & [ mate.tue.nl/mate/pdfs/10318.pdf ]
    Polynomials converted to hornerform using wolfram-alpha hornerform()
*/

float4 PS_CatmullRom(vs_out o) : SV_Target
{
    float2 texSize = size / 32;
    float2 iTc = o.uv * texSize;
    float2 tc = floor(iTc - 0.5) + 0.5;

    float2 f = iTc - tc;
    float2 w0 = f * ( f * ( 0.5 - 1.0/6.0 * f ) - 0.5 ) + 1.0/6.0;
    float2 w1 = (0.5 * f - 1.0) * (f * f) + 2.0/3.0;
    float2 w2 = f * ( f * (0.5 - 0.5 * f) + 0.5) + 1.0/6.0;
    float2 w3 = (1.0/6.0) * f* (f * f);

    float2 s0 = w0 + w1;
    float2 s1 = w2 + w3;
    float2 f0 = w1 / s0;
    float2 f1 = w3 / s1;
    float2 t0 = tc - 1.0 + f0;
    float2 t1 = tc + 1.0 + f1;

    float4 c =
             (tex2D(s_BlurV, float2(t0.x, t0.y) / texSize) * s0.x
           +  tex2D(s_BlurV, float2(t1.x, t0.y) / texSize) * s1.x) * s0.y
           + (tex2D(s_BlurV, float2(t0.x, t1.y) / texSize) * s0.x
           +  tex2D(s_BlurV, float2(t1.x, t1.y) / texSize) * s1.x ) * s1.y;

    return float4(aces_main_bakinglab(c.rgb), 1.0);
}

technique CBloom
{
    pass { VertexShader = PostProcessVS; PixelShader = PS_Light; RenderTarget = t_LOD_6; } // Generate 6 Mipmaps from a 512x512 texture
    pass { VertexShader = PostProcessVS; PixelShader = PS_BlurH; RenderTarget = t_BlurH; } // Horizontal Blur
    pass { VertexShader = PostProcessVS; PixelShader = PS_BlurV; RenderTarget = t_BlurV; } // Vertical Blur - Write Back to t_BlurH
    pass { VertexShader = PostProcessVS; PixelShader = PS_CatmullRom; SRGBWriteEnable = true; BlendEnable = true; DestBlend = INVSRCColor; } // Catmull-Rom Upsample and Tonemap
}
