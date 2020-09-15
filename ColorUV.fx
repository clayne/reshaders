
#include "ReShade.fxh"

float3 PS_Color(in float4 v : SV_POSITION, in float2 uv : TEXCOORD) : SV_Target
{
    return uv.xyx;
}

technique LinearCompare
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Color;
        SRGBWriteEnable = true;
    }
}
