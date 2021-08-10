
#include "cFunctions.fxh"

uniform int uSelect <
	ui_type = "combo";
	ui_items = "Average\0Sum\0Max3\0Filmic\0None\0";
	ui_label = "Method";
	ui_tooltip = "Select Gretscale";
> = 0;

float4 ps_greyscale(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_Target0
{
    float4 color = tex2D(core::samplers::srgb, uv);
    [branch] switch(uSelect)
    {
        case 0:
            return float4(dot(color.rgb, 1.0 / 3.0).rrr, 1.0);
        case 1:
            return float4(dot(color.rgb, 1.0).rrr, 1.0);
        case 2:
            return max(color.r, max(color.g, color.b));
        case 3:
            return length(color.rgb) * rsqrt(3.0);
        default:
            return color;
    }
}

technique cGrayScale
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_greyscale;
        SRGBWriteEnable = true;
    }
}
