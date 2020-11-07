
#include "ReShade.fxh"

uniform int Blur_Amount <
	ui_type = "drag";
	ui_min = 0; ui_max = 32;
	ui_label = "Blur Amount";
	ui_tooltip = "Blur Step Ammount";
	ui_category = "Motion Blur";
> = 8;

uniform int Debug <
	ui_type = "combo";
	ui_items = "Off\0Depth\0Direction\0";
	ui_label = "Debug View";
	ui_tooltip = "View Debug Buffers.";
	ui_category = "Debug Buffer";
> = 0;

#define size 1024

texture2D t_LOD    < pooled = true; > { Width = size; Height = size; Format = R32F; MipLevels = 5; };
texture2D t_cFrame < pooled = true; > { Width = size; Height = size; Format = R32F; };
texture2D t_pFrame < pooled = true; > { Width = size; Height = size; Format = R32F; };
texture2D t_mInfo  < pooled = true; > { Width = size; Height = size; Format = RGBA16F; };

sampler2D s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler2D s_LOD    { Texture = t_LOD; MipLODBias = 4.0; };
sampler2D s_cFrame { Texture = t_cFrame; };
sampler2D s_pFrame { Texture = t_pFrame; };
sampler2D s_mInfo  { Texture = t_mInfo; };

struct vs_in
{
	uint id : SV_VertexID;
	float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

/* [ Pixel Shaders ] */

float ds(float2 uv) { return tex2Dlod(s_cFrame, float4(uv, 0.0, 0.0)).x; }

// Empty shader to generate mipmaps and previous frame

void pLOD(vs_in input, out float c : SV_Target0, out float p : SV_Target1)
{
	float3 col = tex2D(s_Linear, input.uv).rgb;
	c = length(col);
	p = ds(input.uv);
}

/*
	Taken from [https://github.com/haasn/libplacebo/blob/master/src/shaders/sampling.c] [GPL 2.1]
	Explanation of how bicubic scaling with only 4 texel fetches is done:
	http://www.mate.tue.nl/mate/pdfs/10318.pdf
	'Efficient GPU-Based Texture Interpolation using Uniform B-Splines'
*/

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

void pCFrame(vs_in input, out float3 c : SV_Target0)
{
	float2 texsize = tex2Dsize(s_LOD, 4.0);
	float2 pt = 1.0 / texsize;
	float2 fcoord = frac(input.uv * texsize + 0.5);
	float4 parmx = calcweights(fcoord.x);
	float4 parmy = calcweights(fcoord.y);
	float4 cdelta;
	cdelta.xz = parmx.rg * float2(-pt.x, pt.x);
	cdelta.yw = parmy.rg * float2(-pt.y, pt.y);
	// first y-interpolation
	float4 ar = tex2Dlod(s_LOD, float4(input.uv + cdelta.xy, 0.0, 0.0));
	float4 ag = tex2Dlod(s_LOD, float4(input.uv + cdelta.xw, 0.0, 0.0));
	float4 ab = lerp(ag, ar, parmy.b);
	// second y-interpolation
	float4 br = tex2Dlod(s_LOD, float4(input.uv + cdelta.zy, 0.0, 0.0));
	float4 bg = tex2Dlod(s_LOD, float4(input.uv + cdelta.zw, 0.0, 0.0));
	float4 aa = lerp(bg, br, parmy.b);
	// x-interpolation
	c = lerp(aa, ab, parmx.b).x;
}

/*
	Algorithm from [https://github.com/mattatz/unity-optical-flow] [MIT License]
	Optimization from [https://www.shadertoy.com/view/3l2Gz1] [CC BY-NC-SA 3.0]
*/

float4 mFlow(vs_in input, float prev, float curr)
{
	const float _Scale = 4.0;
	const float _Lambda = 0.1;
	const float _Threshold = 0.0;

	float2 currdd = float2(ddx(curr), ddy(curr));
	float2 prevdd = float2(ddx(prev), ddy(prev));

	float dt = curr - prev; // dt
	float dx = currdd.x + prevdd.x; // dx_curr + dx_prev
	float dy = currdd.y + prevdd.y; // dy_curr + dy_prev

	float gmag = sqrt(dx * dx + dy * dy + _Lambda);
	float invGmag = rcp(gmag);
	float3 vx = dt * (dx * invGmag);
	float3 vy = dt * (dy * invGmag);

	float2 flow;
	const float inv3 = rcp(3.0);
	flow.x = -(vx.x + vx.y + vx.z) * inv3;
	flow.y = -(vy.x + vy.y + vy.z) * inv3;

	float w = length(flow);
	float nw = (w - _Threshold) / (1.0 - _Threshold);
	flow = lerp(float2(0.0, 0.0), normalize(flow) * nw * _Scale, step(_Threshold, w));
	return float4(flow, 0.0, 1.0);
}

void pMFlow(vs_in input, out float4 c : SV_Target0)
{
	float Current = ds(input.uv);
	float Past = tex2D(s_pFrame, input.uv).x;
	c = float4(mFlow(input, Past, Current).xy, 0.0, 1.0);
}

void pFlowBlur(vs_in input, out float3 c : SV_Target0)
{
	float weight = 1.0, blursamples = Blur_Amount;
	// Direction of blur and assumption that blur should be stronger near the cam.
	float2 uvoffsets = tex2Dlod(s_mInfo, float4(input.uv, 0.0, 0.0)).xy;
	// Apply motion blur
	float3 sum, accumulation, weightsum;

	[loop]
	for (float i = -blursamples; i <= blursamples; i++)
	{
	  float3 currsample = tex2Dlod(s_Linear, float4(input.uv + (i * uvoffsets) * rcp(size), 0, 0)).rgb;
	  accumulation += currsample * weight;
	  weightsum += weight;
	}

	if(Debug == 0)
	  c = accumulation / weightsum;
	else if(Debug == 1)
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

	pass Flow
	{
		VertexShader = PostProcessVS;
		PixelShader = pMFlow;
		RenderTarget0 = t_mInfo;
	}

	pass MotionBlur
	{
		VertexShader = PostProcessVS;
		PixelShader = pFlowBlur;
		SRGBWriteEnable = true;
	}
}
