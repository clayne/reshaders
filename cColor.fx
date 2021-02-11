
uniform float4 kColor <
    ui_min = 0.0;
    ui_label = "Color";
    ui_type = "color";
> = 1.0;

struct v2f { float4 vpos : SV_Position; };

v2f vs_color(const uint id : SV_VertexID)
{
    v2f o;
    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    o.vpos = float4(coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return o;
}

float4 ps_color(v2f input) : SV_Target { return kColor; }

technique cColor
{
    pass
    {
        VertexShader = vs_color;
        PixelShader = ps_color;
        BlendEnable = true;
        BlendOp = ADD;
        SrcBlend = DESTCOLOR;
        DestBlend = SRCALPHA;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
