
#include "ReShade.fxh"

struct v2f
{
	float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

void p_Color(v2f input, out float3 c : SV_Target0) { c = input.uv.xyx; }

technique LinearCompare
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = p_Color;
		#if BUFFER_COLOR_BIT_DEPTH != 10
			SRGBWriteEnable = true;
		#endif
	}
}
