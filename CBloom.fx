#include "ReShade.fxh"

texture tBlur1 < pooled = true; > { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = RGB10A2; MipLevels = 2; };
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
    color += tex2D(src, uv - offsets[3] * offset_factor).rgb * weights[3];
    color += tex2D(src, uv - offsets[2] * offset_factor).rgb * weights[2];
    color += tex2D(src, uv - offsets[1] * offset_factor).rgb * weights[1];
    color += tex2D(src, uv).rgb * weights[0];
    color += tex2D(src, uv + offsets[1] * offset_factor).rgb * weights[1];
    color += tex2D(src, uv + offsets[2] * offset_factor).rgb * weights[2];
    color += tex2D(src, uv + offsets[3] * offset_factor).rgb * weights[3];
    return color;
}

/* [Pixel Shaders -> Technique] */

struct VS_OUTPUT { float4 vpos : SV_Position; float2 uv : TEXCOORD0; };
void PS_PrePass(VS_OUTPUT IN, out float3 c : SV_Target0) { c = tex2D(sLinear, IN.uv).rgb; c *= dot(c*c, 0.333f)*c; }
void PS_Blur1(VS_OUTPUT IN, out float3 c : SV_Target0) { c = blur(sBlur1, IN.uv, tex2Dsize(sBlur1, 0.0), float2(1.0, 0.0)); }
void PS_Blur2(VS_OUTPUT IN, out float3 c : SV_Target0) { c = blur(sBlur2, IN.uv, tex2Dsize(sBlur2, 0.0), float2(0.0, 1.0)); }
void PS_Blur3(VS_OUTPUT IN, out float3 c : SV_Target0) { c = blur(sBlur3, IN.uv, tex2Dsize(sBlur3, 0.0), float2(1.0, 0.0)); }
void PS_Blur4(VS_OUTPUT IN, out float3 c : SV_Target0) { c = blur(sBlur4, IN.uv, tex2Dsize(sBlur4, 0.0), float2(0.0, 1.0)); }

technique CBloom < ui_label = "CBloom"; >
{
    pass { VertexShader = PostProcessVS; PixelShader = PS_PrePass; ClearRenderTargets = true; StencilEnable = true; RenderTarget0 = tBlur1; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_Blur1; ClearRenderTargets = true; StencilEnable = true; RenderTarget0 = tBlur2; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_Blur2; ClearRenderTargets = true; StencilEnable = true; RenderTarget0 = tBlur3; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_Blur3; ClearRenderTargets = true; StencilEnable = true; RenderTarget0 = tBlur4; }
    pass { VertexShader = PostProcessVS; PixelShader = PS_Blur4; SRGBWriteEnable = true; BlendEnable = true; DestBlend = INVSRCCOLOR; }
}
