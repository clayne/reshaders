// https://github.com/keijiro/Kino :: Unlicense

#include "ReShade.fxh"

uniform float4 _Color <
    ui_label = "Color";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = float4(0.0, 0.0, 0.0, 0.0);

uniform float4 _Background <
    ui_label = "Background";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = float4(1.0, 1.0, 1.0, 0.0);

uniform float _upperThreshold <
    ui_label = "Threshold";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.05f;

uniform float _lowerThreshold <
    ui_label = "Threshold";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.05f;

uniform float _ColorSensitivity <
    ui_label = "ColorSensitivity";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.0f;

sampler _MainTex { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
static const float2 _MainTex_TexelSize = ReShade::ScreenSize;

struct VS_OUTPUT { float4 vpos : SV_Position; float2 uv : TEXCOORD0; };

void PS_Contour(VS_OUTPUT i, out float4 c : SV_Target)
{
    // Color samples
    float4 c0 = tex2Doffset(_MainTex, i.uv, float2(0.0, 0.0));
    float3 c1 = tex2Doffset(_MainTex, i.uv, _MainTex_TexelSize.xy).rgb;
    float3 c2 = tex2Doffset(_MainTex, i.uv, float2(_MainTex_TexelSize.x, 0)).rgb;
    float3 c3 = tex2Doffset(_MainTex, i.uv, float2(0, _MainTex_TexelSize.y)).rgb;

    float edge;
    const float _InvRange = rcp(_upperThreshold - _lowerThreshold);
    // Roberts cross operator
    float3 cg1 = c1 - c0.rgb;
    float3 cg2 = c3 - c2;
    float cg = sqrt(dot(cg1, cg1) + dot(cg2, cg2));

    edge = cg * _ColorSensitivity;

    // Thresholding
    edge = saturate((edge - _Threshold) * _InvRange);

    float3 cb = lerp(c0.rgb, _Background.rgb, _Background.a);
    float3 co = lerp(cb, _Color.rgb, edge * _Color.a);
    c = float4(co, c0.a);
}

technique KinoSharpen < ui_label = "KinoSharpen"; > {
    pass { VertexShader = PostProcessVS; PixelShader = PS_Contour; SRGBWriteEnable = true; }
}