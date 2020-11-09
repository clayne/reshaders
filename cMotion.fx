
/*
	This work is licensed under a Creative Commons Attribution 3.0 Unported License.
	So you are free to share, modify and adapt it for your needs, and even use it for commercial use.
	https://creativecommons.org/licenses/by/3.0/us/

	ds(), pMFlow(), and pFlowBlur()
	derived from Jose Negrete AKA BlueSkyDefender [https://github.com/BlueSkyDefender/AstrayFX]
*/

#include "ReShade.fxh"

uniform float _Scale <
	ui_type = "drag";
	ui_label = "Scale";
	ui_category = "Optical Flow";
> = 3.0;

uniform float _Lambda <
	ui_type = "drag";
	ui_label = "Lambda";
	ui_category = "Optical Flow";
> = 0.03;

uniform float _Threshold <
	ui_type = "drag";
	ui_label = "Threshold";
	ui_category = "Optical Flow";
> = 0.003;

uniform int _Samples <
	ui_type = "drag";
	ui_min = 0; ui_max = 16;
	ui_label = "Blur Amount";
	ui_category = "Blur Composite";
> = 8;

uniform int Debug <
	ui_type = "combo";
	ui_items = "Off\0Depth\0Direction\0";
	ui_label = "Debug View";
	ui_category = "Blur Composite";
> = 0;

#define size 1024

texture2D t_LOD    { Width = size; Height = size; Format = R32F; MipLevels = 5.0; };
texture2D t_cFrame { Width = size; Height = size; Format = R32F; };
texture2D t_pFrame { Width = size; Height = size; Format = R32F; };

sampler2D s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler2D s_LOD    { Texture = t_LOD; MipLODBias = 4.0; };
sampler2D s_cFrame { Texture = t_cFrame; };
sampler2D s_pFrame { Texture = t_pFrame; };

struct vs_in
{
	uint id : SV_VertexID;
	float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

/* [ Pixel Shaders ] */

// I think ds() retreives cFrame but with specified coordinates
float ds(float2 uv) { return tex2Dlod(s_cFrame, float4(uv, 0.0, 0.0)).x; }

// Empty shader to generate brightpass, mipmaps, and previous frame
void pLOD(vs_in input, out float c : SV_Target0, out float p : SV_Target1)
{
	float3 col = tex2Dlod(s_Linear, float4(input.uv, 0.0, 0.0)).rgb;
	c = col.r + col.g + col.b; // Sum RGB to make it grey and bright
	p = ds(input.uv);  // Output the c_Frame we got from last frame
}

/*
	- Color optical flow, by itself, is too small to make motion blur
	- BSD's eMotion does not have this issue because depth texture colors are flat
	- Gaussian blur is expensive and we do not want more passes

	Question: What is the fastest way to smoothly blur a picture?
	Answers:
		A. Cubic-filtered texture LOD
		B. Threshold to black/white
		C. A and B

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
void pCFrame(vs_in input, out float c : SV_Target0)
{
	const float2 texsize = tex2Dsize(s_LOD, 4.0);
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
	Algorithm from [https://github.com/mattatz/unity-optical-flow] [MIT License]
	Optimization from [https://www.shadertoy.com/view/3l2Gz1] []
*/

float4 mFlow(vs_in input, float prev, float curr)
{
	// Sobel operator gradient
	float2 currdd = float2(ddx(curr), ddy(curr));
	float2 prevdd = float2(ddx(prev), ddy(prev));

	float dt = curr - prev; // dt (difference)

	float2 d;
	d.x = currdd.x + prevdd.x; // dx_curr + dx_prev
	d.y = currdd.y + prevdd.y; // dy_curr + dy_prev

	float gmag = sqrt(d.x * d.x + d.y * d.y + _Lambda);
	float3 vx = dt * (d.x / gmag);
	float3 vy = dt * (d.y / gmag);

	const float inv3 = rcp(3.0);
	float2 flow;
	flow.x = -(vx.x + vx.y + vx.z) * inv3;
	flow.y = -(vy.x + vy.y + vy.z) * inv3;

	float w = length(flow); // Gradient length
	float nw = (w - _Threshold) / (1.0 - _Threshold);
	flow = lerp(0.0, normalize(flow) * nw * _Scale, step(_Threshold, w));
	return float4(flow, 0.0, 1.0);
}

void pFlowBlur(vs_in input, out float3 c : SV_Target0)
{
	// Calculate optical flow and blur direction here
	// BSD did this in another pass, but a few more instructions should be cheaper than a pass
	// Putting it here also means the values are no longer clamped!
	float Current = ds(input.uv);
	float Past = tex2D(s_pFrame, input.uv).x;
	float2 uvoffsets = mFlow(input, Past, Current).xy;

	// Apply motion blur
	const float weight = 1.0;
	float3 sum, accumulation, weightsum;

	[loop]
	for (float i = -_Samples; i <= _Samples; i++)
	{
		float3 currsample = tex2Dlod(s_Linear, float4(input.uv + (i * uvoffsets) * rcp(size), 0.0, 0.0)).rgb;
		accumulation += currsample * weight;
		weightsum += weight;
	}

	if (Debug == 0)
		c = accumulation / weightsum;
	else if (Debug == 1)
		c = ds(input.uv).x;
	else
		c = float3(mad(uvoffsets, 0.5, 0.5), 0.0);
}

technique cMotionBlur < ui_tooltip = "Color-Based Motion Blur"; >
{
	pass LOD
	{
		VertexShader = PostProcessVS;
		PixelShader = pLOD;
		RenderTarget0 = t_LOD;
		RenderTarget1 = t_pFrame;
	}

	pass CopyFrame
	{
		VertexShader = PostProcessVS;
		PixelShader = pCFrame;
		RenderTarget0 = t_cFrame;
	}

	pass MotionBlur
	{
		VertexShader = PostProcessVS;
		PixelShader = pFlowBlur;
		SRGBWriteEnable = true;
	}
}
