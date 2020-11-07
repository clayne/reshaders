
#include "ReShade.fxh"

void PS_Color(in float4 v : SV_POSITION, in float2 uv : TEXCOORD, out float3 c : SV_Target0)
{
    c = uv.xyx;
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
