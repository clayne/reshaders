
#include "cFunctions.fxh"

uniform float2 kShiftR <
    ui_type = "drag";
> = -1.0;

uniform float2 kShiftB <
    ui_type = "drag";
> = 1.0;

texture2D r_color : COLOR;
sampler2D s_color { Texture = r_color; SRGBTexture = TRUE; };

/*
    NOTE: pixelsize = 1.0 / screensize
    uv + kShiftR * core::getpixelsize() == uv + kShiftR / screensize

    QUESTION: "Why do we have to divide our shifting value with screensize?"
    ANSWER: Texture coordinates in window-space is between 0.0 - 1.0.
            Thus, uv + 1.0 moves the texture to the window's other side, rendering it out of sight
*/

float4 ps_abberation(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_Target0
{
    float4 color;
    color.r = tex2D(s_color, uv + kShiftR * core::getpixelsize()).r; // shifted red channel
    color.g = tex2D(s_color, uv).g; // center green channel
    color.b = tex2D(s_color, uv + kShiftB * core::getpixelsize()).b; // shifted blue channel
    color.a = 1.0;
    return color;
}

technique cAbberation
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_abberation;
        SRGBWriteEnable = TRUE;
    }
}
