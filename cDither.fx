#include "ReShade.fxh"

sampler s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };

void PS_ScreenSpaceDither(in float4 vpos : SV_POSITION, in float2 uv : TEXCOORD, out float4 c : SV_Target0)
{
	float3 c = tex2D(s_Linear, uv).rgb;
	// lestyn's RGB dither (7 asm instructions) from Portal 2 X360, slightly modified for VR
	float3 vDither = dot(float2(131.0, 312.0), vpos.xy);
	vDither.rgb = frac(vDither.rgb / float3(103.0, 71.0, 97.0)) - 0.5;
	c += (vDither.rgb / 255) * 0.375;
}

technique ScreenSpaceDither
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_ScreenSpaceDither;
		SRGBWriteEnable = true;
	}
}
