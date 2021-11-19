
/*
    From Lewis Lepton's shader tutorial series - episode 007 - rect shape
    https://www.youtube.com/watch?v=wQkElpJ5DYo
*/

uniform float2 _Scale <
    ui_min = 0.0;
    ui_label = "Scale";
    ui_type = "drag";
> = float2(1.0, 0.8);

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

void LetterboxPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float3 OutputColor : SV_Target0)
{
    // Output a rectangle
    const float2 Scale = -_Scale * 0.5 + 0.5;
    float2 Shaper  = step(Scale, TexCoord);
           Shaper *= step(Scale, 1.0 - TexCoord);
    OutputColor = Shaper.x * Shaper.y;
}

technique cLetterBox
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = LetterboxPS;
        // Blend the rectangle with the backbuffer
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
