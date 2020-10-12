/*
    Nyctalopia, by CopingMechanism
    This bloom's [--]ed up, as expected from an amatuer. Help is welcome! :)

    PS_Blur() by ShaderPatch https://github.com/SleepKiller/shaderpatch [MIT License]
*/

#include "ReShade.fxh"

#define size 1024.0 // Must be multiples of 16!
#define size_d size / 32.0

texture t_LOD_0 < pooled = true; > { Width = size; Height = size; MipLevels = 6; Format = RGBA16F; };
texture t_BlurH < pooled = true; > { Width = size_d; Height = size_d; Format = RGBA16F; };
texture t_BlurV < pooled = true; > { Width = size_d; Height = size_d; Format = RGBA16F; };

sampler s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler s_LOD_0 { Texture = t_LOD_0; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler s_BlurH { Texture = t_BlurH; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler s_BlurV { Texture = t_BlurV; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };

/* [ Vertex Shaders ] */

struct vs_in { uint id : SV_VertexID; float4 vpos : SV_POSITION; float2 uv : TEXCOORD; };
struct vs_out { float4 vpos : SV_POSITION; float2 uv : TEXCOORD0; float4 b_uv[6] : TEXCOORD1; };

void VS_BlurH(vs_in input, out float4 position : SV_Position, out float4 b_uv[6] : TEXCOORD1)
{
    PostProcessVS(input.id, position, input.uv);
    const int steps = 6;
    const float offsets[steps] = { 0.65772, 2.45017, 4.41096, 6.37285, 8.33626, 10.30153 };
    const float2 direction = float2(rcp(size_d), 0.0);
    for(int i = 0; i < steps; i++)
    {
        b_uv[i].xy = input.uv - offsets[i] * direction;
        b_uv[i].zw = input.uv + offsets[i] * direction;
    }
}

void VS_BlurV(vs_in input, out float4 position : SV_Position, out float4 b_uv[6] : TEXCOORD1)
{
    PostProcessVS(input.id, position, input.uv);
    const int steps = 6;
    const float offsets[steps] = { 0.65772, 2.45017, 4.41096, 6.37285, 8.33626, 10.30153 };
    const float2 direction = float2(0.0, rcp(size_d));
    for(int i = 0; i < steps; i++)
    {
        b_uv[i].xy = input.uv - offsets[i] * direction;
        b_uv[i].zw = input.uv + offsets[i] * direction;
    }
}

/* [ Helper Functions ] */

float3 PS_Blur(sampler src, float4 b_uv[6] : TEXCOORD1)
{
    const int steps = 6;
    const float weights[steps] = { 0.16501, 0.17507, 0.10112, 0.04268, 0.01316, 0.002960 };

    float3 result;
    for (int i = 0; i < steps; i++)
    {
        result += tex2D(src, b_uv[i].xy).rgb * weights[i];
        result += tex2D(src, b_uv[i].zw).rgb * weights[i];
    }

    return result;
}

/*
    Reference: https://github.com/dmnsgn/glsl-tone-map [MIT License]
    Uchimura 2017, "HDR theory and practice"
    Math: https://www.desmos.com/calculator/gslcdxvipg
    Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
*/

float3 uchimura(float3 x, float P, float a, float m, float l, float c, float b)
{
    const float l0 = ((P - m) * l) / a;
    const float L0 = m - m / a;
    const float L1 = m + (1.0 - m) / a;
    const float S0 = m + l0;
    const float S1 = m + a * l0;
    const float C2 = (a * P) / (P - S1);
    const float CP = -C2 / P;

    float3 w0 = 1.0 - smoothstep(0.0, m, x);
    float3 w2 = step(m + l0, x);
    float3 w1 = 1.0 - w0 - w2;

    float3 T = m * pow(abs(x / m), c) + b;
    float3 S = P - (P - S1) * exp(CP * (x - S0));
    float3 L = m + a * (x - m);

    return T * w0 + L * w1 + S * w2;
}

float3 uchimura(float3 x)
{
    const float P = 1.0;  // max display brightness
    const float a = 1.0;  // contrast
    const float m = 0.22; // linear section start
    const float l = 0.4;  // linear section length
    const float c = 1.33; // black
    const float b = 0.0;  // pedestal

    return uchimura(x, P, a, m, l, c, b);
}

/* [ Pixel Shaders ] */

float4 PS_Light(vs_out output) : SV_Target
{
    float3 m = tex2D(s_Linear, output.uv).rgb;
    return float4(step(1.0, m) * dot(m, m), 1.0);
}

float4 PS_BlurH(vs_out output) : SV_Target { return float4(PS_Blur(s_LOD_0, output.b_uv), 1.0); }
float4 PS_BlurV(vs_out output) : SV_Target { return float4(PS_Blur(s_BlurH, output.b_uv), 1.0); }

/*
    https://www.shadertoy.com/view/tlXSR2
    For more details, see [ vec3.ca/bicubic-filtering-in-fewer-taps/ ] & [ mate.tue.nl/mate/pdfs/10318.pdf ]
    Polynomials converted to hornerform using wolfram-alpha hornerform()
*/

float4 PS_CatmullRom(vs_out output) : SV_Target
{
    const float texSize = size_d;
    float2 iTc = output.uv * texSize;
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

    float4 c = (tex2D(s_BlurV, float2(t0.x, t0.y) / texSize) * s0.x
             +  tex2D(s_BlurV, float2(t1.x, t0.y) / texSize) * s1.x) * s0.y
             + (tex2D(s_BlurV, float2(t0.x, t1.y) / texSize) * s0.x
             +  tex2D(s_BlurV, float2(t1.x, t1.y) / texSize) * s1.x ) * s1.y;

    // Interleaved gradient noise by Jorge Jimenez :: Function by bacondither [BSD-3 License]
    const float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
    float xy_magic = dot(output.vpos.xy, magic.xy);
    float noise = (frac(magic.z*frac(xy_magic)) - 0.5)/(exp2(8.0) - 1.0);
    c += float3(-noise, noise, -noise);

    return float4(uchimura(c.rgb), 1.0);
}

technique CBloom
{
    pass { VertexShader = PostProcessVS; PixelShader = PS_Light; RenderTarget = t_LOD_0; } // Generate Mipmaps from a square texture
    pass { VertexShader = VS_BlurH; PixelShader = PS_BlurH; RenderTarget = t_BlurH; } // Horizontal Blur
    pass { VertexShader = VS_BlurV; PixelShader = PS_BlurV; RenderTarget = t_BlurV; } // Vertical Blur
    pass { VertexShader = PostProcessVS; PixelShader = PS_CatmullRom; SRGBWriteEnable = true; BlendEnable = true; DestBlend = INVSRCCOLOR; } // Upsample + Dither + Tonemap
}
