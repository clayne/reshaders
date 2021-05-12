
uniform float kColor <
    ui_min = 0.0;
    ui_label = "Color";
    ui_type = "drag";
> = 1.0;

texture2D r_color : COLOR;
sampler2D s_color
{
	Texture = r_color;
	SRGBTexture = TRUE;
};

struct v2f
{
	float4 vpos : SV_Position;
	float2 uv   : TEXCOORD0;
};

v2f vs_color(const uint id : SV_VertexID)
{
	v2f output;
    output.uv.x = (id == 2) ? 2.0 : 0.0;
    output.uv.y = (id == 1) ? 2.0 : 0.0;
    output.vpos = float4(output.uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return output;
}

float3 Saturation(float3 c, float sat)
{
    float luma = max(c.r, max(c.g, c.b));
    return luma.xxx + sat.xxx * (c - luma.xxx);
}

float4 ps_color(v2f input) : SV_Target
{
	float4 color = tex2D(s_color, input.uv);
	float luma = max(color.r, max(color.g, color.b));
	return Saturation(color.rgb, kColor).rgbr;
}

technique cColor
{
    pass
    {
        VertexShader = vs_color;
        PixelShader = ps_color;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
