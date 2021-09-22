
uniform float4 uColor <
    ui_min = 0.0;
    ui_label = "Color";
    ui_type = "color";
> = 1.0;

void vs_generic(in uint id : SV_VERTEXID,
                out float4 position : SV_POSITION,
                out float2 texcoord : TEXCOORD)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

float4 ps_color(float4 vpos : SV_Position) : SV_Target
{
    return uColor;
}

technique cColor
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_color;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = DESTCOLOR;
        DestBlend = SRCALPHA;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
