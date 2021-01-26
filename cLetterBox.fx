
/* 
    From Lewis Lepton's shader tutorial series - episode 007 - rect shape
    https://www.youtube.com/watch?v=wQkElpJ5DYo
*/

#include "ReShade.fxh"

uniform float2 kScale <
    ui_label = "Falloff";
    ui_type = "drag";
> = float2(0.5, 0.5);

struct v2f
{
    float4 vpos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

void ps_letterbox(v2f input, out float3 c : SV_Target0)
{
    kScale = 0.5 - kScale * 0.5;
    float2 shaper  = step(kScale, input.uv);
           shaper *= step(kScale, 1.0 - input.uv);
    c = shaper.x * shaper.y;
}

technique cLetterBox
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ps_letterbox;
        BlendOp = ADD;
        SrcBlend = DESTCOLOR;
        DestBlend = SRCALPHA;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
