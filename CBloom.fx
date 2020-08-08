#include "ReShade.fxh"

texture tBlur1 < pooled = true; > { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = RGB10A2; };
texture tBlur2 < pooled = true; > { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = RGB10A2; MipLevels = 2; };
texture tBlur3 < pooled = true; > { Width = BUFFER_WIDTH/8; Height = BUFFER_HEIGHT/8; Format = RGB10A2; };
texture tBlur4 < pooled = true; > { Width = BUFFER_WIDTH/8; Height = BUFFER_HEIGHT/8; Format = RGB10A2; };

sampler sLinear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler sBlur1 { Texture = tBlur1; };
sampler sBlur2 { Texture = tBlur2; };
sampler sBlur3 { Texture = tBlur3; };
sampler sBlur4 { Texture = tBlur4; };

/* [Effect] */

static const float offsets[4] = { 0.0000000, 1.4697715, 3.4298467, 5.3908140 };
static const float weights[4] = { 0.1210733, 0.2193107, 0.1476820, 0.0724707 };

float3 blur(sampler src, float2 uv, float2 pxSize, float2 direction)
{
    const float2 offset_factor = rcp(pxSize) * direction;

    float3 color; // Center Sampler
    color += tex2D(src, uv - offset_factor * offsets[3]).rgb * weights[3];
    color += tex2D(src, uv - offset_factor * offsets[2]).rgb * weights[2];
    color += tex2D(src, uv - offset_factor * offsets[1]).rgb * weights[1];
    color += tex2D(src, uv).rgb * weights[0];
    color += tex2D(src, uv + offset_factor * offsets[1]).rgb * weights[1];
    color += tex2D(src, uv + offset_factor * offsets[2]).rgb * weights[2];
    color += tex2D(src, uv + offset_factor * offsets[3]).rgb * weights[3];
    return color;
}

/* [Pixel Shaders -> Technique] */

struct vs_output { float4 vpos : SV_Position; float2 uv : TEXCOORD0; };
void PS_Light(vs_output op, out float3 c : SV_Target) { c = tex2D(sLinear, op.uv).rgb; c = (c-0.333f) * lerp(c, dot(c, 0.333f), -c); }
void PS_Blur1(vs_output op, out float3 c : SV_Target) { c = blur(sBlur1, op.uv, tex2Dsize(sBlur1, 2.0), float2(1.0, 0.0)); }
void PS_Blur2(vs_output op, out float3 c : SV_Target) { c = blur(sBlur2, op.uv, tex2Dsize(sBlur2, 2.0), float2(0.0, 1.0)); }
void PS_Blur3(vs_output op, out float3 c : SV_Target) { c = blur(sBlur3, op.uv, tex2Dsize(sBlur3, 0.0), float2(1.0, 0.0)); }
void PS_Blur4(vs_output op, out float3 c : SV_Target) { c = blur(sBlur4, op.uv, tex2Dsize(sBlur4, 0.0), float2(0.0, 1.0)); }

technique CBloom < ui_label = "CBloom"; >
{
    pass { VertexShader = PostProcessVS; PixelShader = PS_Light; RenderTarget = tBlur1; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_Blur1; RenderTarget = tBlur2; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_Blur2; RenderTarget = tBlur3; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_Blur3; RenderTarget = tBlur4; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_Blur4; SRGBWriteEnable = true; BlendEnable = true; DestBlend = INVSRCCOLOR; }
}
