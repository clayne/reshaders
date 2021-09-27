
uniform float4 _Color <
    ui_min = 0.0;
    ui_label = "Color";
    ui_type = "color";
> = 1.0;

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

float4 ColorPS(float4 Position : SV_Position) : SV_Target
{
    return _Color;
}

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
        SRGBWriteEnable = TRUE;
    }
}
