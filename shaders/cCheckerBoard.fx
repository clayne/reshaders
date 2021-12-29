
/* [Vertex Shaders] */

uniform float4 _Color <
    ui_min = 0.0;
    ui_label = "Color";
    ui_type = "color";
> = 1.0;

uniform bool _InvertCheckerboard <
    ui_type = "radio";
    ui_label = "Invert Checkerboard Pattern";
> = false;

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

void CheckerBoardPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float RedBlack = frac(dot(Position.xy, 0.5)) * 2.0;
    RedBlack = _InvertCheckerboard ? 1.0 - RedBlack : RedBlack;
    OutputColor0 = RedBlack == 1.0 ? _Color : 0.0;
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
