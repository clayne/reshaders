/*
    Nyctalopia, by CopingMechanism
    This bloom's [--]ed up, as expected from an amatuer. Help is welcome! :)
*/

#include "ReShade.fxh"

#define size 1024.0 // Must be multiples of 16!
#define size_d size / 32.0

texture t_Mip0 < pooled = true; > { Width = size; Height = size; MipLevels = 6; Format = RGBA16F; };
texture t_BlurH < pooled = true; > { Width = size_d; Height = size_d; Format = RGBA16F; };
texture t_BlurV < pooled = true; > { Width = size_d; Height = size_d; Format = RGBA16F; };

sampler s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler s_Mip0 { Texture = t_Mip0; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler s_BlurH { Texture = t_BlurH; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler s_BlurV { Texture = t_BlurV; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };

/* [ Vertex Shaders ] */

struct vs_in
{
    uint id : SV_VertexID;
    float4 vpos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

struct vs_out
{
    float4 vpos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 m_uv[4] : TEXCOORD1; // Median TEXCOORD
    float4 b_uv[6] : TEXCOORD2; // Blur TEXCOORD
};

/* [ Vertex Shaders ] */

void VS_Median(vs_in input, out float4 vpos : SV_Position, out float4 m_uv[4] : TEXCOORD1)
{
    PostProcessVS(input.id, vpos, input.uv);
    const float3 d = BUFFER_PIXEL_SIZE.xyx * float3(1, 1, 0);
    m_uv[0] = input.uv - d.xz;
    m_uv[1] = input.uv + d.xz;
    m_uv[2] = input.uv - d.zy;
    m_uv[3] = input.uv + d.zy;
}

static const int steps = 6;
static const float offsets[steps] = { 0.65772, 2.45017, 4.41096, 6.37285, 8.33626, 10.30153 };
static const float weights[steps] = { 0.16501, 0.17507, 0.10112, 0.04268, 0.01316, 0.002960 };

void VS_BlurH(vs_in input, out float4 vpos : SV_Position, out float4 b_uv[6] : TEXCOORD2)
{
    PostProcessVS(input.id, vpos, input.uv);
    const float2 direction = float2(rcp(size_d), 0.0);
    for(int i = 0; i < steps; i++)
    {
        b_uv[i].xy = input.uv - offsets[i] * direction;
        b_uv[i].zw = input.uv + offsets[i] * direction;
    }
}

void VS_BlurV(vs_in input, out float4 vpos : SV_Position, out float4 b_uv[6] : TEXCOORD2)
{
    PostProcessVS(input.id, vpos, input.uv);
    const float2 direction = float2(0.0, rcp(size_d));
    for(int i = 0; i < steps; i++)
    {
        b_uv[i].xy = input.uv - offsets[i] * direction;
        b_uv[i].zw = input.uv + offsets[i] * direction;
    }
}

/*
    [ Helper Functions ]
    PS_Blur() by ShaderPatch https://github.com/SleepKiller/shaderpatch [MIT License]
*/

float3 Median(float3 a, float3 b, float3 c) { return a + b + c - min(min(a,b),c) - max(max(a,b),c); }

float3 Blur(sampler src, float4 b_uv[6])
{
    float3 result;
    for (int i = 0; i < steps; i++)
    {
        result += tex2D(src, b_uv[i].xy).rgb * weights[i];
        result += tex2D(src, b_uv[i].zw).rgb * weights[i];
    }

    return result;
}

/*
    [ Uchimura 2017, "HDR theory and practice" ]
    Reference: https://github.com/dmnsgn/glsl-tone-map [MIT License]
    Math: https://www.desmos.com/calculator/gslcdxvipg
    Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
*/

float3 uchimura(float3 x)
{
    const float P = 1.0;  // max display brightness
    const float a = 1.0;  // contrast
    const float m = 0.22; // linear section start
    const float l = 0.4;  // linear section length
    const float c = 1.33; // black

    const float l0 = ((P - m) * l) / a;
    const float2 S0 = float2(m + l0, m + a * l0);
    const float CP = -((a * P) / (P - S0.y));

    float3 w0 = 1.0 - smoothstep(0.0, m, x);
    float3 w2 = step(m + l0, x);
    float3 w1 = 1.0 - w0 - w2;

    float3 T = m * pow(abs(x / m), c);
    float3 S = P - (P - S0.y) * exp(CP * (x - S0.x));
    float3 L = m + a * (x - m);

    return T * w0 + L * w1 + S * w2;
}

/* [ Pixel Shaders ] */

float4 PS_Light(vs_out output) : SV_Target
{
    float4 _s0 = tex2D(s_Linear, output.uv);
    float3 _s1 = tex2D(s_Linear, output.m_uv[0]).rgb;
    float3 _s2 = tex2D(s_Linear, output.m_uv[1]).rgb;
    float3 _s3 = tex2D(s_Linear, output.m_uv[2]).rgb;
    float3 _s4 = tex2D(s_Linear, output.m_uv[3]).rgb;
    float3 m = Median(Median(_s0.rgb, _s1, _s2), _s3, _s4);
    m = saturate((m * -0.1) / (max(m, 0.01) - 1.01));
    return float4(lerp(0.0, m, dot(m, m)), 1.0);
}

float4 PS_BlurH(vs_out output) : SV_Target { return float4(Blur(s_Mip0, output.b_uv), 1.0); }
float4 PS_BlurV(vs_out output) : SV_Target { return float4(Blur(s_BlurH, output.b_uv), 1.0); }

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
             +  tex2D(s_BlurV, float2(t1.x, t1.y) / texSize) * s1.x) * s1.y;

    // Interleaved Gradient Noise
    const float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
    float xy_magic = dot(output.vpos.xy, magic.xy);
    float noise = frac(magic.z * frac(xy_magic)) - 0.5;
    c += float3(-noise, noise, -noise) / 255;

    return float4(uchimura(c.rgb), 1.0);
}

//  SRGBWriteEnable = true; BlendEnable = true; DestBlend = INVSRCCOLOR;
technique CBloom
{
    pass { VertexShader = VS_Median; PixelShader = PS_Light; RenderTarget = t_Mip0; }
    pass { VertexShader = VS_BlurH; PixelShader = PS_BlurH; RenderTarget = t_BlurH; }
    pass { VertexShader = VS_BlurV; PixelShader = PS_BlurV; RenderTarget = t_BlurV; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_CatmullRom; SRGBWriteEnable = true; BlendEnable = true; DestBlend = INVSRCCOLOR; }
}
