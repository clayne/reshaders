
#include "ReShade.fxh"

uniform float scale <
	ui_label = "Scale";
	ui_type = "drag";
	ui_step = 0.1;
> = 100.0;

uniform float2 center <
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

#define vs_out() in uint id : SV_VertexID, out float4 vpos : SV_Position, out float4 uv : TEXCOORD0

void v_tile(v2f input, vs_out())
{
	PostProcessVS(id, vpos, input.uv);
	input.uv += float2(center.x, -center.y);
	float2 s = input.uv * BUFFER_SCREEN_SIZE * (scale * 0.01);
	uv = floor(s) / BUFFER_SCREEN_SIZE;
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
