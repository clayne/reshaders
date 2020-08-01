// https://github.com/keijiro/Kino :: Unlicense

#include "ReShade.fxh"

uniform float intensity <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Sharpen";
    ui_tooltip = "Increase to sharpen details within the image.";
> = 0.05;

texture BackBufferTex : COLOR;
sampler sLinear { Texture = BackBufferTex; SRGBTexture = true; };

struct VS_OUTPUT { float4 vpos : SV_Position; float2 uv : TEXCOORD0; };

int2 offset(int2 i) { return min(max(0, i), ReShade::ScreenSize - 1); }

void PS_Fragment(VS_OUTPUT IN, out float4 c : SV_Target)
{
    int2 positionSS = IN.uv * ReShade::ScreenSize;

    float4 c0 = tex2Doffset(sLinear, IN.uv, + offset(int2(-1, -1)));
    float4 c1 = tex2Doffset(sLinear, IN.uv, + offset(int2( 0, -1)));
    float4 c2 = tex2Doffset(sLinear, IN.uv, + offset(int2(+1, -1)));

    float4 c3 = tex2Doffset(sLinear, IN.uv, + offset(int2(-1, 0)));
    float4 c4 = tex2D(sLinear,IN.uv);
    // float4 c4 = tex2Dlod(sLinear, float4(IN.uv, 0.0, 0.0));
    float4 c5 = tex2Doffset(sLinear, IN.uv, + offset(int2(+1, 0)));

    float4 c6 = tex2Doffset(sLinear, IN.uv, + offset(int2(-1, +1)));
    float4 c7 = tex2Doffset(sLinear, IN.uv, + offset(int2( 0, +1)));
    float4 c8 = tex2Doffset(sLinear, IN.uv, + offset(int2(+1, +1)));

    c = c4 - (c0 + c1 + c2 + c3 - 8 * c4 + c5 + c6 + c7 + c8) * intensity;
}

technique KinoSharpen < ui_label = "KinoSharpen"; > {
    pass { VertexShader = PostProcessVS; PixelShader = PS_Fragment; SRGBWriteEnable = true; }
}