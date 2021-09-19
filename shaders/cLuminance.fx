

uniform int uSelect <
    ui_type = "combo";
    ui_items = "Average\0Sum\0Max3\0Filmic\0None\0";
    ui_label = "Method";
    ui_tooltip = "Select Luminance";
> = 0;

texture2D r_color : COLOR;

sampler2D s_color
{
    Texture = r_color;
    SRGBTexture = TRUE;
};

/* [Vertex Shaders] */

void vs_generic(in uint id : SV_VERTEXID,
                inout float2 uv : TEXCOORD0,
                inout float4 vpos : SV_POSITION)
{
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

float4 ps_greyscale(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_Target0
{
    float4 color = tex2D(s_color, uv);
    [branch] switch(uSelect)
    {
        case 0:
            return float4(dot(color.rgb, 1.0 / 3.0).rrr, 1.0);
        case 1:
            return float4(dot(color.rgb, 1.0).rrr, 1.0);
        case 2:
            return max(color.r, max(color.g, color.b));
        case 3:
            return length(color.rgb) * rsqrt(3.0);
        default:
            return color;
    }
}

technique cGrayScale
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_greyscale;
        SRGBWriteEnable = TRUE;
    }
}
