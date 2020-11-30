
/*
	This work is licensed under a Creative Commons Attribution 3.0 Unported License.
	https://creativecommons.org/licenses/by/3.0/us/

	pFlowBlur() from Jose Negrete AKA BlueSkyDefender [https://github.com/BlueSkyDefender/AstrayFX]
*/

#include "ReShade.fxh"

uniform float _Lambda <
	ui_type = "drag";
	ui_label = "Lambda";
> = 4.0;

uniform int _Samples <
	ui_type = "drag";
	ui_min = 0; ui_max = 16;
	ui_label = "Blur Amount";
> = 4;

uniform int Debug <
	ui_type = "combo";
	ui_items = "Off\0Depth\0Direction\0";
	ui_label = "Debug View";
> = 0;

static const int size = 1024; // Textures need to be powers of 2 for elegent mipmapping

texture2D t_LOD    { Width = size; Height = size; Format = R16F; MipLevels = 5.0; };
texture2D t_cFrame { Width = size; Height = size; Format = R16F; };
texture2D t_pFrame { Width = size; Height = size; Format = R16F; };

sampler2D s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler2D s_LOD    { Texture = t_LOD; MipLODBias = 4.0; };
sampler2D s_cFrame { Texture = t_cFrame; };
sampler2D s_pFrame { Texture = t_pFrame; };

struct v2f
{
	float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

/* [ Pixel Shaders ] */

// Empty shader to generate brightpass, mipmaps, and previous frame
// Exposure algorithm from [https://github.com/TheRealMJP/BakingLab] [MIT]
void pLOD(v2f input, out float c : SV_Target0, out float p : SV_Target1)
{
	float3 col = tex2Dlod(s_Linear, float4(input.uv, 0.0, 0.0)).rgb;
	c = max(length(col), 0.0001f);
	c = log2(1.0 / c) * sqrt(exp(-_Lambda)); // Natural logarithm
	p = tex2Dlod(s_cFrame, float4(input.uv, 0.0, 0.0)).x; // Output the c_Frame we got from last frame
}

/*
	- Color optical flow, by itself, is too small to make motion blur
	- BSD's eMotion does not have this issue because depth texture colors are flat
	- Gaussian blur is expensive and we do not want more passes

	Question: What is the fastest way to smoothly blur a picture?
	Answer: Cubic-filtered texture LOD

	Taken from [https://github.com/haasn/libplacebo/blob/master/src/shaders/sampling.c] [GPL 2.1]
	How bicubic scaling with 4 texel fetches is done [http://www.mate.tue.nl/mate/pdfs/10318.pdf]
	'Efficient GPU-Based Texture Interpolation using Uniform B-Splines'
*/

float4 calcweights(float s)
{
	float4 t = float4(-0.5, 0.1666, 0.3333, -0.3333) * s + float4(1.0, 0.0, -0.5, 0.5);
	t = t * s + float4(0.0, 0.0, -0.5, 0.5);
	t = t * s + float4(-0.6666, 0.0, 0.8333, 0.1666);
	float2 a = 1.0 / t.zw;
	t.xy = t.xy * a + 1.0;
	t.x = t.x + s;
	t.y = t.y - s;
	return t;
}

// NOTE: This is a grey cubic filter. Cubic.fx is the RGB version of this ;)
void pCFrame(v2f input, out float c : SV_Target0)
{
	const float2 texsize = ldexp(size, -4.0);
	const float2 pt = 1.0 / texsize;
	float2 fcoord = frac(input.uv * texsize + 0.5);
	float4 parmx = calcweights(fcoord.x);
	float4 parmy = calcweights(fcoord.y);
	float4 cdelta;
	cdelta.xz = parmx.rg * float2(-pt.x, pt.x);
	cdelta.yw = parmy.rg * float2(-pt.y, pt.y);
	// first y-interpolation
	float3 a;
	a.r = tex2Dlod(s_LOD, float4(input.uv + cdelta.xy, 0.0, 0.0)).x;
	a.g = tex2Dlod(s_LOD, float4(input.uv + cdelta.xw, 0.0, 0.0)).x;
	a.b = lerp(a.g, a.r, parmy.b);
	// second y-interpolation
	float3 b;
	b.r = tex2Dlod(s_LOD, float4(input.uv + cdelta.zy, 0.0, 0.0)).x;
	b.g = tex2Dlod(s_LOD, float4(input.uv + cdelta.zw, 0.0, 0.0)).x;
	b.b = lerp(b.g, b.r, parmy.b);
	// x-interpolation
	c = lerp(b.b, a.b, parmx.b).x;
}

/*
	Algorithm from [https://github.com/mattatz/unity-optical-flow] [MIT]
	Optimization from [https://www.shadertoy.com/view/3l2Gz1] [CC BY-NC-SA 3.0]

	ISSUE:
	mFlow combines the optical flow result of the current AND previous frame.
	This means there are blurred ghosting that happens frame-by-frame
*/

float2 mFlow(float prev, float curr)
{
	float dt = distance(curr, prev); // dt (difference)

	float2 dd;
	dd.x = ddx(curr + prev);
	dd.y = ddy(curr + prev);
	float gmag = length(dd) + 1.0; // length() is the same thing, but 1 less instruction

	float2 flow;
	flow.x = dt * (dd.x / gmag);
	flow.y = dt * (dd.y / gmag);
	return flow;
}

void pFlowBlur(v2f input, out float3 c : SV_Target0)
{
	// Calculate optical flow and blur direction
	// BSD did this in another pass, but this should be cheaper
	// Putting it here also means the values are not clamped!
	float prev = tex2Dlod(s_pFrame, float4(input.uv, 0.0, 0.0)).x; // cubic from last frame
	float curr = tex2Dlod(s_cFrame, float4(input.uv, 0.0, 0.0)).x; // cubic from this frame
	float2 oFlow = mFlow(prev, curr);

	// Interleaved Gradient Noise by Jorge Jimenez to smoothen blur samples
	// [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
	float ign = frac(52.9829189 * frac(dot(input.vpos.xy, float2(0.06711056, 0.00583715))));

	// Apply motion blur
	const float pt = 1.0 / size;
	float total;

	[loop]
	for (float i = -_Samples; i <= _Samples; i ++)
	{
		// From [http://john-chapman-graphics.blogspot.com/2013/01/per-object-motion-blur.html]
		float2 offset = oFlow * ((i + ign) / (_Samples - 1.0) - 0.5);
		c += tex2Dlod(s_Linear, float4(input.uv + offset, 0.0, 0.0)).rgb;
		total += 1.0;
	}

	if (Debug == 0)
		c /= total;
	else if (Debug == 1)
		c = curr;
	else
		c = float3(oFlow * exp2(8.0), 0.0) + tex2Dlod(s_Linear, float4(input.uv, 0.0, 0.0)).rgb;
}

technique cMotionBlur < ui_tooltip = "Color-Based Motion Blur"; >
{
	pass LOD
	{
		VertexShader = PostProcessVS;
		PixelShader = pLOD;
		RenderTarget0 = t_LOD;
		RenderTarget1 = t_pFrame; // Store previous frame's cubic for mFlow()
	}

	pass CubicFrame
	{
		VertexShader = PostProcessVS;
		PixelShader = pCFrame;
		RenderTarget0 = t_cFrame;
	}

	pass FlowBlur
	{
		VertexShader = PostProcessVS;
		PixelShader = pFlowBlur;
		SRGBWriteEnable = true;
	}
}
