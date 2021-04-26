
uniform float2 kShiftR <
    ui_type = "drag";
> = -1.0;

uniform float2 kShiftB <
    ui_type = "drag";
> = 1.0;

texture2D r_color : COLOR;
sampler2D s_color { Texture = r_color; SRGBTexture = TRUE; };

struct v2f
{
    float4 vpos : SV_Position;
    float2 uv0 : TEXCOORD0;
    float4 uv1 : TEXCOORD1;
};

v2f vs_abberation(const uint id : SV_VertexID)
{
    v2f output;
    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    output.vpos = float4(coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    const float2 ts = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    output.uv0 = coord;
    output.uv1.xy = kShiftR * ts + coord;
    output.uv1.zw = kShiftB * ts + coord;
    return output;
}

float4 ps_abberation(v2f input) : SV_Target0
{
    float4 color;
    color.r = tex2D(s_color, input.uv1.xy).r;
    color.g = tex2D(s_color, input.uv0).g;
    color.b = tex2D(s_color, input.uv1.zw).b;
    color.a = 1.0;
    return color;
}

technique cAbberation
{
    pass
    {
        VertexShader = vs_abberation;
        PixelShader = ps_abberation;
        SRGBWriteEnable = TRUE;
    }
}
