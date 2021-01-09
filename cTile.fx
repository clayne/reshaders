
#include "ReShade.fxh"

uniform float _Scale <
	ui_label = "Scale";
	ui_type = "drag";
	ui_step = 0.1;
> = 100.0;

uniform float2 _Center <
	ui_label = "Center";
	ui_type = "drag";
	ui_step = 0.001;
> = float2(0.0, 0.0);

struct v2f
{
	float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

sampler2D s_Linear
{
	Texture = ReShade::BackBufferTex;
	#if BUFFER_COLOR_BIT_DEPTH != 10
		SRGBTexture = true;
	#endif
	AddressU = MIRROR;
	AddressV = MIRROR;
};

v2f v_tile(in uint id : SV_VertexID)
{
	v2f o;
	float2 texcoord;
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	o.vpos = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

	o.uv += texcoord + float2(_Center.x, -_Center.y);
	float2 s = o.uv * BUFFER_SCREEN_SIZE * (_Scale * 0.01);
	o.uv = floor(s) / BUFFER_SCREEN_SIZE;
	return o;
}

void p_tile(v2f input, out float3 c : SV_Target0)
{
	c = tex2D(s_Linear, input.uv).rgb;
}

technique Tile
{
	pass
	{
		VertexShader = v_tile;
		PixelShader = p_tile;
		#if BUFFER_COLOR_BIT_DEPTH != 10
			SRGBWriteEnable = true;
		#endif
	}
}
