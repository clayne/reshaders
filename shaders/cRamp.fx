/*
    Material shader from https://github.com/blender/blender

    Blender uses the GNU General Public License, which describes the rights
    to distribute or change the code.

    Please read this file for the full license.
    doc/license/GPL-license.txt

    Apart from the GNU GPL, Blender is not available under other licenses.

    2010, Blender Foundation
    foundation@blender.org
*/

#include "ReShade.fxh"

uniform float4 kColor1 <
    ui_type = "color";
    ui_label = "Color 1";
> = float4(0.5, 0.5, 0.5, 0.5);

uniform float4 kColor2 <
    ui_type = "color";
    ui_label = "Color 2";
> = float4(0.5, 0.5, 0.5, 0.5);

uniform float2 kMulBias <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "MulBias";
> = float2(0.5, 0.5);

sampler2D s_source
{
    Texture = ReShade::BackBufferTex;
    #if BUFFER_COLOR_BIT_DEPTH != 10
        SRGBTexture = true;
    #endif
};

struct v2f { float4 vpos : SV_POSITION; float2 uv : TEXCOORD0; };

void p_ramp(v2f input, out float4 c : SV_Target0)
{
    c = tex2D(s_source, input.uv);
    c = saturate(mad(c, kMulBias.x, kMulBias.y));
    c = lerp(kColor1, kColor2, c);
}

technique cRamp
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = p_ramp;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
