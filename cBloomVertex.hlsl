#include "ReShade.fxh"

texture tBlurA < pooled = true; > { Width = BUFFER_WIDTH/2.0; Height = BUFFER_HEIGHT/2.0; Format = RGB10A2; };
texture tBlurB < pooled = true; > { Width = BUFFER_WIDTH/2.0; Height = BUFFER_HEIGHT/2.0; Format = RGB10A2; };

// NOTE: Process display-referred images into linear light, no matter the shader
sampler sLinear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler sBlurA { Texture = tBlurA; };
sampler sBlurB { Texture = tBlurB; };

struct vertexInput
{
    uint id : SV_VertexID.
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
};

struct output_13tap
{
    float4 vertex : SV_POSITION;
    float2 texcoord : TEXCOORD0;
    float4 blurTexcoord[3] : TEXCOORD1;
};

// Blur - Vertex Shader

output_13tap VS_Blur13_H(vertexInput IN)
{
    output_13tap OUT;
    OUT.vertex = PostProcessVS(IN.id, output_13tap.vertex, IN.texcoord)

    float2 offset1 = float2(ReShade::PixelSize.x * 1.41176470, 0.0);
    float2 offset2 = float2(ReShade::PixelSize.x * 3.29411764, 0.0);
    float2 offset3 = float2(ReShade::PixelSize.x * 5.17647058, 0.0);

    OUT.texcoord = uv;
    OUT.blurTexcoord[0].xy = uv + offset1;
    OUT.blurTexcoord[0].zw = uv - offset1;
    OUT.blurTexcoord[1].xy = uv + offset2;
    OUT.blurTexcoord[1].zw = uv - offset2;
    OUT.blurTexcoord[2].xy = uv + offset3;
    OUT.blurTexcoord[2].zw = uv - offset3;
    return OUT;
}

output_13tap VS_Blur13_V(vertexInput IN)
{
    output_13tap OUT;
    OUT.vertex = PostProcessVS(IN.id, output_13tap.vertex, IN.texcoord)

    float2 offset1 = float2(0.0, ReShade::PixelSize.y * 1.41176470);
    float2 offset2 = float2(0.0, ReShade::PixelSize.y * 3.29411764);
    float2 offset3 = float2(0.0, ReShade::PixelSize.y * 5.17647058);

    OUT.texcoord = uv;
    OUT.blurTexcoord[0].xy = uv + offset1;
    OUT.blurTexcoord[0].zw = uv - offset1;
    OUT.blurTexcoord[1].xy = uv + offset2;
    OUT.blurTexcoord[1].zw = uv - offset2;
    OUT.blurTexcoord[2].xy = uv + offset3;
    OUT.blurTexcoord[2].zw = uv - offset3;
    return OUT;
}

float3 PS_blur13(output_13tap IN) : SV_Target
{
    float3 sum = tex2D(_MainTex, IN.texcoord).xyz * 0.19648255;
    sum += tex2D(_MainTex, IN.blurTexcoord[0].xy).xyz * 0.29690696;
    sum += tex2D(_MainTex, IN.blurTexcoord[0].zw).xyz * 0.29690696;
    sum += tex2D(_MainTex, IN.blurTexcoord[1].xy).xyz * 0.09447039;
    sum += tex2D(_MainTex, IN.blurTexcoord[1].zw).xyz * 0.09447039;
    sum += tex2D(_MainTex, IN.blurTexcoord[2].xy).xyz * 0.01038136;
    sum += tex2D(_MainTex, IN.blurTexcoord[2].zw).xyz * 0.01038136;
    return sum;
}

float3 PS_Light0(vs_out op) : SV_Target { float3 c = tex2D(sLinear, op.uv).rgb; c = (c - 0.75) * lerp(c, dot(c, c), c) * c; return ceil(c); }

technique CBloom
{
    pass { VertexShader = PostProcessVS; PixelShader = PS_blur13; RenderTarget = tBlurA; }
    pass { VertexShader = VS_Blur13_H; PixelShader = PS_blur13; RenderTarget = tBlurB; }
    pass { VertexShader = VS_Blur13_V; PixelShader = PS_blur13; SRGBWriteEnable = true; BlendEnable = true; DestBlend = INVSRCColor; }
}
