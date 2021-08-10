
/*
    From Lewis Lepton's shader tutorial series - episode 007 - rect shape
    https://www.youtube.com/watch?v=wQkElpJ5DYo
*/

#include "cFunctions.fxh"

uniform float2 kScale <
    ui_min = 0.0;
    ui_label = "Scale";
    ui_type = "drag";
> = float2(1.0, 0.8);

struct v2f { float4 vpos : SV_POSITION; float2 uv : TEXCOORD0; };

void ps_letterbox(v2f input, out float3 c : SV_Target0)
{
    const float2 cScale = mad(-kScale, 0.5, 0.5);
    float2 shaper  = step(cScale, input.uv);
           shaper *= step(cScale, 1.0 - input.uv);
    c = shaper.x * shaper.y;
}

technique cLetterBox
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_letterbox;
        BlendEnable = true;
        BlendOp = ADD;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
