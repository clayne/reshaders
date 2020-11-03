
// https://github.com/keijiro/Kino :: Unlicense

#include "ReShade.fxh"

uniform float4 _EdgeColor <
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Edge Color";
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float2 _EdgeThresholds <
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Middle threshold";
> = float2(0.0, 0.0);

uniform float _FillOpacity <
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Fill Opacity";
> = 0.0;

uniform float4 _ColorKey0 <
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Color Key 0";
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 _ColorKey1 <
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Color Key 1";
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 _ColorKey2 <
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Color Key 2";
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 _ColorKey3 <
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Color Key 3";
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 _ColorKey4 <
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Color Key 4";
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 _ColorKey5 <
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Color Key 5";
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 _ColorKey6 <
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Color Key 6";
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 _ColorKey7 <
    ui_min = 0.0;
    ui_max = 1.0;
    ui_label = "Color Key 7";
> = float4(1.0, 1.0, 1.0, 1.0);

texture BackBufferTex : COLOR;
sampler s_Linear { Texture = BackBufferTex; SRGBTexture = true; };

void PS_Fragment(in float4 vpos : SV_Position, in float2 uv : TEXCOORD, out float4 c : SV_Target)
{
    uint2 positionSS = uv * BUFFER_SCREEN_SIZE;

    // Source color
    float4 c0 = tex2D(s_Linear, positionSS);

    // Four sample points of the roberts cross operator
    // TL / BR / TR / BL
    uint2 uv0 = positionSS;
    uint2 uv1 = min(positionSS + uint2(1, 1), BUFFER_SCREEN_SIZE - 1);
    uint2 uv2 = uint2(uv1.x, uv0.y);
    uint2 uv3 = uint2(uv0.x, uv1.y);

    // Color samples
    float3 c1 = tex2D(s_Linear, uv1).rgb;
    float3 c2 = tex2D(s_Linear, uv2).rgb;
    float3 c3 = tex2D(s_Linear, uv3).rgb;

    // Roberts cross operator
    float3 g1 = c1 - c0.rgb;
    float3 g2 = c3 - c2;
    float g = sqrt(dot(g1, g1) + dot(g2, g2)) * 10;

    // Apply fill gradient.
    float3 fill = _ColorKey0.rgb;
    float lum = dot(c0.rgb, 0.333);

    #ifdef RECOLOR_GRADIENT_LERP
        fill = lerp(fill, _ColorKey1.rgb, saturate((lum - _ColorKey0.w) / (_ColorKey1.w - _ColorKey0.w)));
        fill = lerp(fill, _ColorKey2.rgb, saturate((lum - _ColorKey1.w) / (_ColorKey2.w - _ColorKey1.w)));
        fill = lerp(fill, _ColorKey3.rgb, saturate((lum - _ColorKey2.w) / (_ColorKey3.w - _ColorKey2.w)));
        #ifdef RECOLOR_GRADIENT_EXT
        fill = lerp(fill, _ColorKey4.rgb, saturate((lum - _ColorKey3.w) / (_ColorKey4.w - _ColorKey3.w)));
        fill = lerp(fill, _ColorKey5.rgb, saturate((lum - _ColorKey4.w) / (_ColorKey5.w - _ColorKey4.w)));
        fill = lerp(fill, _ColorKey6.rgb, saturate((lum - _ColorKey5.w) / (_ColorKey6.w - _ColorKey5.w)));
        fill = lerp(fill, _ColorKey7.rgb, saturate((lum - _ColorKey6.w) / (_ColorKey7.w - _ColorKey6.w)));
        #endif
    #else
        fill = lum > _ColorKey0.w ? _ColorKey1.rgb : fill;
        fill = lum > _ColorKey1.w ? _ColorKey2.rgb : fill;
        fill = lum > _ColorKey2.w ? _ColorKey3.rgb : fill;
        #ifdef RECOLOR_GRADIENT_EXT
        fill = lum > _ColorKey3.w ? _ColorKey4.rgb : fill;
        fill = lum > _ColorKey4.w ? _ColorKey5.rgb : fill;
        fill = lum > _ColorKey5.w ? _ColorKey6.rgb : fill;
        fill = lum > _ColorKey6.w ? _ColorKey7.rgb : fill;
        #endif
    #endif

    float edge = smoothstep(_EdgeThresholds.x, _EdgeThresholds.y, g);
    float3 cb = lerp(c0.rgb, fill, _FillOpacity);
    float3 co = lerp(cb, _EdgeColor.rgb, edge * _EdgeColor.a);
    return float4(co, c0.a);
}

technique KinoRecolor
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Fragment;
        SRGBWriteEnable = true;
    }
}
