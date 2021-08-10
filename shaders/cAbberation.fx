
#include "cFunctions.fxh"

uniform float2 kShiftR <
    ui_type = "drag";
> = -1.0;

uniform float2 kShiftB <
    ui_type = "drag";
> = 1.0;

texture2D r_color : COLOR;
sampler2D s_color { Texture = r_color; SRGBTexture = TRUE; };

void vs_abberation(in uint id : SV_VERTEXID,
                   inout float4 vpos : SV_POSITION,
                   inout float2 uv0 : TEXCOORD0,
                   inout float4 uv1 : TEXCOORD1)
{
    core::vsinit(id, uv0, vpos);
    uv1.xy = uv0 + kShiftR * core::getpixelsize();
    uv1.zw = uv0 + kShiftB * core::getpixelsize();
}

float4 ps_abberation(float4 vpos : SV_POSITION,
                     float2 uv0 : TEXCOORD0,
                     float4 uv1 : TEXCOORD1) : SV_Target0
{
    float4 color;
    color.r = tex2D(s_color, uv1.xy).r;
    color.g = tex2D(s_color, uv0).g;
    color.b = tex2D(s_color, uv1.zw).b;
    color.a = 1.0;
    return color;
}

technique cAbberation
{
    pass
    {
        VertexShader = vs_abberation;
        PixelShader = ps_abberation;
        SRGBWriteEnable = TRUE;
    }
}
