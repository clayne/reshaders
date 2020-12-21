
#include "ReShade.fxh"

struct v2f
{
	float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

void p_ScreenSpaceDither(v2f input, out float4 c : SV_Target0)
{
	// lestyn's RGB dither (7 asm instructions) from Portal 2 X360, slightly modified for VR
	float3 vDither = dot(float2(131.0, 312.0), input.vpos.xy);
	vDither.rgb = frac(vDither.rgb / float3(103.0, 71.0, 97.0)) - 0.5;
	c = (vDither.rgb / 255) * 0.375;
}

technique ScreenSpaceDither
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = p_ScreenSpaceDither;
		#if BUFFER_COLOR_BIT_DEPTH != 10
			SRGBWriteEnable = true;
		#endif
		BlendEnable = true;
		BlendOp = ADD;
		SrcBlend = SRCCOLOR;
		DestBlend = ONE;
	}
}
