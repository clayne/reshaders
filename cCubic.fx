/*
	Taken from [https://github.com/haasn/libplacebo/blob/master/src/shaders/sampling.c] [GPL 2.1]
	How bicubic scaling with only 4 texel fetches is done: [http://www.mate.tue.nl/mate/pdfs/10318.pdf]
	'Efficient GPU-Based Texture Interpolation using Uniform B-Splines'
*/

#include "ReShade.fxh"

sampler2D s_Linear { Texture = ReShade::BackBufferTex; };
// Hardcoded resulotion because the filter works on integer pixels
texture2D t_Downscaled { Width = 1024; Height = 1024; MipLevels = 5.0; };

sampler2D s_Downscaled
{
	Texture = t_Downscaled;
	#if BUFFER_COLOR_BIT_DEPTH != 10
		SRGBTexture = true;
	#endif
};

struct v2f
{
	float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

// Empty shader to generate mipmaps.
void p_MipGen(v2f input, out float4 c : SV_Target0) { c = tex2D(s_Linear, input.uv).rgb; }

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
void p_Cubic(v2f input, out float3 c : SV_Target0)
{
	float2 texsize = tex2Dsize(s_Downscaled, 4.0);
	float2 pt = 1 / texsize;
	float2 fcoord = frac(input.uv * texsize + 0.5);
	float4 parmx = calcweights(fcoord.x);
	float4 parmy = calcweights(fcoord.y);
	float4 cdelta;
	cdelta.xz = parmx.rg * float2(-pt.x, pt.x);
	cdelta.yw = parmy.rg * float2(-pt.y, pt.y);
	// first y-interpolation
	float3 ar = tex2Dlod(s_Downscaled, float4(input.uv + cdelta.xy, 0.0, 4.0)).rgb;
	float3 ag = tex2Dlod(s_Downscaled, float4(input.uv + cdelta.xw, 0.0, 4.0)).rgb;
	float3 ab = lerp(ag, ar, parmy.b);
	// second y-interpolation
	float3 br = tex2Dlod(s_Downscaled, float4(input.uv + cdelta.zy, 0.0, 4.0)).rgb;
	float3 bg = tex2Dlod(s_Downscaled, float4(input.uv + cdelta.zw, 0.0, 4.0)).rgb;
	float3 aa = lerp(bg, br, parmy.b);
	// x-interpolation
	c = lerp(aa, ab, parmx.b);
}

technique Cubic
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = p_MipGen;
		RenderTarget = t_Downscaled;
	}

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = p_Cubic;
		#if BUFFER_COLOR_BIT_DEPTH != 10
			SRGBWriteEnable = true;
		#endif
	}
}
