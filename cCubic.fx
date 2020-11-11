/*
	Taken from [https://github.com/haasn/libplacebo/blob/master/src/shaders/sampling.c] [GPL 2.1]
	How bicubic scaling with only 4 texel fetches is done: [http://www.mate.tue.nl/mate/pdfs/10318.pdf]
	'Efficient GPU-Based Texture Interpolation using Uniform B-Splines'
*/

#include "ReShade.fxh"

sampler2D s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
// Hardcoded resulotion because the filter works on integer pixels
texture2D t_Downscaled { Width = 1024; Height = 1024; MipLevels = 5.0; };
sampler2D s_Downscaled { Texture = t_Downscaled; MipLODBias = 4.0; };

struct vs_in
{
	uint id : SV_VertexID;
	float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

// Empty shader to generate mipmaps.

void PS_MipGen(vs_in input, out float4 c : SV_Target0) { c = tex2D(s_Linear, input.uv).rgb; }

float4 calcweights(float s)
{
	float4 t = float4(-0.5, 0.1666, 0.3333, -0.3333) * s + float4(1, 0, -0.5, 0.5);
	t = t * s + float4(0, 0, -0.5, 0.5);
	t = t * s + float4(-0.6666, 0, 0.8333, 0.1666);
	float2 a = 1.0 / t.zw;
	t.xy = t.xy * a + 1.0;
	t.x = t.x + s;
	t.y = t.y - s;
	return t;
}

// Could calculate float3s for a bit more performance

float3 pCubic(sampler src, float2 uv, float lod)
{
	float2 texsize = tex2Dsize(src, lod);
	float2 pt = 1 / texsize;
	float2 fcoord = frac(uv * texsize + 0.5);
	float4 parmx = calcweights(fcoord.x);
	float4 parmy = calcweights(fcoord.y);
	float4 cdelta;
	cdelta.xz = parmx.rg * float2(-pt.x, pt.x);
	cdelta.yw = parmy.rg * float2(-pt.y, pt.y);
	// first y-interpolation
	float3 ar = tex2Dlod(s_Downscaled, float4(uv + cdelta.xy, 0.0, lod)).rgb;
	float3 ag = tex2Dlod(s_Downscaled, float4(uv + cdelta.xw, 0.0, lod)).rgb;
	float3 ab = lerp(ag, ar, parmy.b);
	// second y-interpolation
	float3 br = tex2Dlod(s_Downscaled, float4(uv + cdelta.zy, 0.0, lod)).rgb;
	float3 bg = tex2Dlod(s_Downscaled, float4(uv + cdelta.zw, 0.0, lod)).rgb;
	float3 aa = lerp(bg, br, parmy.b);
	// x-interpolation
	return lerp(aa, ab, parmx.b);
}

void PS_Cubic(vs_in input,
			  out float4 c0 : SV_Target0)
{
	c0 = pCubic(s_Downscaled, input.uv, 0.0);
	c0 += pCubic(s_Downscaled, input.uv, 2.0);
	c0 += pCubic(s_Downscaled, input.uv, 4.0);
	c0 += pCubic(s_Downscaled, input.uv, 6.0);
}

technique Cubic
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_MipGen;
		RenderTarget = t_Downscaled;
	}

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_Cubic;
		SRGBWriteEnable = true;
	}
}
