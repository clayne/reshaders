
/*
    From Lewis Lepton's shader tutorial series - episode 007 - rect shape
    https://www.youtube.com/watch?v=wQkElpJ5DYo
*/

uniform float2 kScale <
    ui_min = 0.0;
    ui_label = "Scale";
    ui_type = "drag";
> = float2(1.0, 0.8);

/* [Vertex Shaders] */

void vs_generic(in uint id : SV_VERTEXID,
                out float4 position : SV_POSITION,
                out float2 texcoord : TEXCOORD)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

void ps_letterbox(float4 vpos : SV_POSITION,
                  float2 uv : TEXCOORD0,
                  out float3 c : SV_Target0)
{
    const float2 cScale = mad(-kScale, 0.5, 0.5);
    float2 shaper  = step(cScale, uv);
           shaper *= step(cScale, 1.0 - uv);
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
            SRGBWriteEnable = TRUE;
        #endif
    }
}
