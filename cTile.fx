
// Tile Effect by itsmattkc (Olive 0.1.X)

#include "ReShade.fxh"

uniform float scale <
	ui_label = "Scale";
	ui_type = "drag";
	ui_step = 0.1;
> = 100.0;

uniform float centerx <
	ui_label = "Center X";
	ui_type = "drag";
	ui_step = 0.001;
> = 0.0;

uniform float centery <
	ui_label = "Center Y";
	ui_type = "drag";
	ui_step = 0.001;
> = 0.0;

uniform bool mirrorx <
	ui_label = "Mirror X";
> = true;

uniform bool mirrory <
	ui_label = "Mirror Y";
> = true;

sampler s_Linear
{
	Texture = ReShade::BackBufferTex;
	#if BUFFER_COLOR_BIT_DEPTH != 10
		SRGBTexture = true;
	#endif
};

// glsl style mod
#define mod(x, y) (x - y * floor(x / y))

struct v2f
{
	float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

void p_Tile(v2f input, out float4 c : SV_Target0)
{
	float adj_scale = scale * 0.01;
	float2 coord = (input.uv/adj_scale - 0.5/adj_scale) + float2(-centerx, -centery) + 0.5;
	float2 modcoord = mod(coord, 1.0);

	if (mirrorx && mod(coord.x, 2.0) > 1.0) { modcoord.x = 1.0 - modcoord.x; }
	if (mirrory && mod(coord.y, 2.0) > 1.0) { modcoord.y = 1.0 - modcoord.y; }

	c = tex2D(s_Linear, modcoord);
}

technique Tile
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = p_Tile;
		#if BUFFER_COLOR_BIT_DEPTH != 10
			SRGBWriteEnable = true;
		#endif
	}
}
