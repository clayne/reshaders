uniform float4 uColor <
    ui_min = 0.0;
    ui_label = "Color";
    ui_type = "color";
> = 1.0;

float4 vs_color(const uint id : SV_VertexID) : SV_Position
{
    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    return float4(coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

float4 ps_color(float4 vpos : SV_Position) : SV_Target { return uColor; }

technique cColor
{
    pass
    {
        VertexShader = vs_color;
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
