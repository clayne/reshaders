
#include "cFunctions.fxh"

uniform float4 uColor <
    ui_min = 0.0;
    ui_label = "Color";
    ui_type = "color";
> = 1.0;

float4 ps_color(float4 vpos : SV_Position) : SV_Target { return uColor; }

technique cColor
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_color;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = DESTCOLOR;
        DestBlend = SRCALPHA;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
