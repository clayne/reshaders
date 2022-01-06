
/* [Vertex Shaders] */

uniform float4 _Color1 <
    ui_min = 0.0;
    ui_label = "Color 1";
    ui_type = "color";
> = 1.0;

uniform float4 _Color2 <
    ui_min = 0.0;
    ui_label = "Color 2";
    ui_type = "color";
> = 0.0;

uniform bool _InvertCheckerboard <
    ui_type = "radio";
    ui_label = "Invert Checkerboard Pattern";
> = false;

void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

void CheckerBoardPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    float CheckerBoard = frac(dot(Position.xy, 0.5)) * 2.0;
    CheckerBoard = _InvertCheckerboard ? 1.0 - CheckerBoard : CheckerBoard;
    OutputColor0 = CheckerBoard == 1.0 ? _Color1 : _Color2;
}

technique cCheckerBoard
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = CheckerBoardPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
