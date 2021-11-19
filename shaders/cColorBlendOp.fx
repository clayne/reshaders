
/*
    Color tinting without texture fetches
*/

uniform float4 _Color <
    ui_min = 0.0;
    ui_label = "Color";
    ui_type = "color";
> = 1.0;

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    // Clip a triangle twice the screen's size to make a quad
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

void ColorPS(float4 Position : SV_Position, out float4 OutputColor0 : SV_Target0)
{
    // Fill this quad with a color
    OutputColor0 = _Color;
}

// Use BlendOp to multiple the backbuffer with this quad's color
technique cColorBlendOp
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ColorPS;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = DESTCOLOR;
        DestBlend = SRCALPHA;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
