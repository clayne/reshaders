
/*
	MIT License

	Copyright (c) 2015-2017 Keijiro Takahashi

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/

#include "ReShade.fxh"

uniform float BLOOM_INTENSITY <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 10.0;
	ui_label = "Bloom Intensity";
	ui_tooltip = "Scales bloom brightness.";
> = 1.0;

uniform float BLOOM_CURVE <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 10.0;
	ui_label = "Bloom Curve";
	ui_tooltip = "Higher values limit bloom to bright light sources only.";
> = 8.0;

uniform float BLOOM_SAT <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 5.0;
	ui_label = "Bloom Saturation";
	ui_tooltip = "Adjusts the color strength of the bloom effect";
> = 2.0;

#define size 2048
texture2D _Bloom1 { Width = BUFFER_WIDTH / 2; Height = BUFFER_HEIGHT / 2; Format = RGBA16F; MipLevels = 2; };
texture2D _Bloom2 { Width = size / 4;   Height = size / 4;   Format = RGBA16F; };
texture2D _Bloom3 { Width = size / 8;   Height = size / 8;   Format = RGBA16F; };
texture2D _Bloom4 { Width = size / 16;  Height = size / 16;  Format = RGBA16F; };
texture2D _Bloom5 { Width = size / 32;  Height = size / 32;  Format = RGBA16F; };
texture2D _Bloom6 { Width = size / 64;  Height = size / 64;  Format = RGBA16F; };
texture2D _Bloom7 { Width = size / 128; Height = size / 128; Format = RGBA16F; };
texture2D _Bloom8 { Width = size / 256; Height = size / 256; Format = RGBA16F; };

sampler2D s_Linear
{
	Texture = ReShade::BackBufferTex;
	#if BUFFER_COLOR_BIT_DEPTH != 10
		SRGBTexture = true;
	#endif
};

sampler2D s_Bloom1 { Texture = _Bloom1; };
sampler2D s_Bloom2 { Texture = _Bloom2; };
sampler2D s_Bloom3 { Texture = _Bloom3; };
sampler2D s_Bloom4 { Texture = _Bloom4; };
sampler2D s_Bloom5 { Texture = _Bloom5; };
sampler2D s_Bloom6 { Texture = _Bloom6; };
sampler2D s_Bloom7 { Texture = _Bloom7; };
sampler2D s_Bloom8 { Texture = _Bloom8; };

// 3-tap median filter
float3 Median(float3 a, float3 b, float3 c) { return a + b + c - min(min(a, b), c) - max(max(a, b), c); }
float Brightness(float3 c) { return max(max(c.r, c.g), c.b); }

struct v2v
{
	float4 vpos  : SV_Position;
	float4 uv[7] : TEXCOORD0;
};

struct v2f
{
	float4 vpos : SV_Position;
	float2 uv : TEXCOORD0;
};

#define vs_out() in uint id : SV_VertexID, out float4 vpos : SV_Position, out float4 uv[7] : TEXCOORD0

void v_dsamp(v2v input, sampler2D src, vs_out())
{
	float2 texcoord;
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	vpos = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

	float2 ts = 1.0 / tex2Dsize(src, 0.0);

	uv[0].xy = texcoord + int2(-1.0,-1.0) * ts;
	uv[0].zw = texcoord + int2( 1.0,-1.0) * ts;
	uv[1].xy = texcoord + int2(-1.0, 1.0) * ts;
	uv[1].zw = texcoord + int2( 1.0, 1.0) * ts;

	uv[2].xy = texcoord + int2(-2.0,-2.0) * ts;
	uv[2].zw = texcoord + int2( 0.0,-2.0) * ts;
	uv[3].xy = texcoord + int2( 2.0,-2.0) * ts;
	uv[3].zw = texcoord + int2( 2.0, 0.0) * ts;
	uv[4].xy = texcoord + int2( 2.0, 2.0) * ts;
	uv[4].zw = texcoord + int2( 0.0, 2.0) * ts;
	uv[5].xy = texcoord + int2(-2.0, 2.0) * ts;
	uv[5].zw = texcoord + int2(-2.0, 0.0) * ts;

	uv[6].xyzw = texcoord.xyxy;
}

void vs_dsamp1(v2v input, vs_out()) { v_dsamp(input, s_Bloom1, id, vpos, uv); }
void vs_dsamp2(v2v input, vs_out()) { v_dsamp(input, s_Bloom2, id, vpos, uv); }
void vs_dsamp3(v2v input, vs_out()) { v_dsamp(input, s_Bloom3, id, vpos, uv); }
void vs_dsamp4(v2v input, vs_out()) { v_dsamp(input, s_Bloom4, id, vpos, uv); }
void vs_dsamp5(v2v input, vs_out()) { v_dsamp(input, s_Bloom5, id, vpos, uv); }
void vs_dsamp6(v2v input, vs_out()) { v_dsamp(input, s_Bloom6, id, vpos, uv); }
void vs_dsamp7(v2v input, vs_out()) { v_dsamp(input, s_Bloom7, id, vpos, uv); }

float3 dsamp(sampler2D src, float4 uv[7])
{
   float3 inner;
   inner += tex2D(src, uv[0].xy).rgb;
   inner += tex2D(src, uv[0].zw).rgb;
   inner += tex2D(src, uv[1].xy).rgb;
   inner += tex2D(src, uv[1].zw).rgb;

   float3 A = tex2D(src, uv[2].xy).rgb;
   float3 B = tex2D(src, uv[2].zw).rgb;
   float3 C = tex2D(src, uv[3].xy).rgb;
   float3 D = tex2D(src, uv[3].zw).rgb;
   float3 E = tex2D(src, uv[4].xy).rgb;
   float3 F = tex2D(src, uv[4].zw).rgb;
   float3 G = tex2D(src, uv[5].xy).rgb;
   float3 H = tex2D(src, uv[5].zw).rgb;
   float3 I = tex2D(src, uv[6].xy).rgb;

   float3 color = inner * 0.125;
   color += (A + B + H + I) * (0.25 * 0.125);
   color += (B + C + I + D) * (0.25 * 0.125);
   color += (I + D + F + E) * (0.25 * 0.125);
   color += (H + I + G + F) * (0.25 * 0.125);

   return color;
}

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

// Could calculate float3s for a bit more performance
float3 usamp(sampler2D src, float2 uv)
{
	float2 texsize = tex2Dsize(src, 0.0);
	float2 pt = 1.0 / texsize;
	float2 fcoord = frac(uv * texsize + 0.5);
	float4 parmx = calcweights(fcoord.x);
	float4 parmy = calcweights(fcoord.y);
	float4 cdelta;
	cdelta.xz = parmx.rg * float2(-pt.x, pt.x);
	cdelta.yw = parmy.rg * float2(-pt.y, pt.y);
	// first y-interpolation
	float3 ar = tex2D(src, uv + cdelta.xy).rgb;
	float3 ag = tex2D(src, uv + cdelta.xw).rgb;
	float3 ab = lerp(ag, ar, parmy.b);
	// second y-interpolation
	float3 br = tex2D(src, uv + cdelta.zy).rgb;
	float3 bg = tex2D(src, uv + cdelta.zw).rgb;
	float3 aa = lerp(bg, br, parmy.b);
	// x-interpolation
	return lerp(aa, ab, parmx.b);
}

// Use Marty McFly's qUINT_Bloom's threshold for now
void p_dsamp0(v2f input, out float3 c : SV_Target0)
{
	float4 s0 = tex2D(s_Linear, input.uv, int2( 0, 0));
	float3 s1 = tex2D(s_Linear, input.uv, int2(-1, 0)).rgb;
	float3 s2 = tex2D(s_Linear, input.uv, int2( 1, 0)).rgb;
	float3 s3 = tex2D(s_Linear, input.uv, int2( 0,-1)).rgb;
	float3 s4 = tex2D(s_Linear, input.uv, int2( 0, 1)).rgb;
	float3 m = Median(Median(s0.rgb, s1, s2), s3, s4);

	s0.a = dot(m, 0.333);
	c  = saturate(lerp(s0.a, m, BLOOM_SAT));
	c *= pow(abs(s0.a), BLOOM_CURVE) / (s0.a + 1e-3);
}

void p_dsamp1(v2v input, out float3 c : SV_Target0) { c = dsamp(s_Bloom1, input.uv); }
void p_dsamp2(v2v input, out float3 c : SV_Target0) { c = dsamp(s_Bloom2, input.uv); }
void p_dsamp3(v2v input, out float3 c : SV_Target0) { c = dsamp(s_Bloom3, input.uv); }
void p_dsamp4(v2v input, out float3 c : SV_Target0) { c = dsamp(s_Bloom4, input.uv); }
void p_dsamp5(v2v input, out float3 c : SV_Target0) { c = dsamp(s_Bloom5, input.uv); }
void p_dsamp6(v2v input, out float3 c : SV_Target0) { c = dsamp(s_Bloom6, input.uv); }
void p_dsamp7(v2v input, out float3 c : SV_Target0) { c = dsamp(s_Bloom7, input.uv); }
void p_usamp0(v2f input, out float3 c : SV_Target0)
{
	c  = 0.0;
	c += usamp(s_Bloom8, input.uv).rgb;
	c += usamp(s_Bloom7, input.uv).rgb;
	c += usamp(s_Bloom6, input.uv).rgb;
	c += usamp(s_Bloom5, input.uv).rgb;
	c += usamp(s_Bloom4, input.uv).rgb;
	c += usamp(s_Bloom3, input.uv).rgb;
	c += usamp(s_Bloom2, input.uv).rgb;
	c *= BLOOM_INTENSITY;

	// ACES Tonemap from https://github.com/TheRealMJP/BakingLab
	// sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
	const float3x3 ACESInputMat = float3x3(
		0.59719, 0.35458, 0.04823,
		0.07600, 0.90834, 0.01566,
		0.02840, 0.13383, 0.83777
	);

	// ODT_SAT => XYZ => D60_2_D65 => sRGB
	const float3x3 ACESOutputMat = float3x3(
		 1.60475, -0.53108, -0.07367,
		-0.10208,  1.10813, -0.00605,
		-0.00327, -0.07276,  1.07602
	);

	float3 a = c * (c + 0.0245786f) - 0.000090537f;
	float3 b = c * (0.983729f * c + 0.4329510f) + 0.238081f;
	float3 RRTAndODTFit = a / b;

	c = mul(ACESInputMat, c);
	c = mul(ACESOutputMat, RRTAndODTFit);
}

technique KinoBloom
{
	#define vsp()      VertexShader = PostProcessVS
	#define vsd(i)     VertexShader = vs_dsamp##i
	#define psd(i, j)  PixelShader = p_dsamp##i; RenderTarget = _Bloom##j
	#define psu(i, j)  PixelShader = p_usamp##i; RenderTarget = _Bloom##j
	#define blendadd() BlendEnable = true; SrcBlend = ONE; DestBlend = SRCALPHA

	pass { vsp();  psd(0, 1); }
	pass { vsd(1); psd(1, 2); }
	pass { vsd(2); psd(2, 3); }
	pass { vsd(3); psd(3, 4); }
	pass { vsd(4); psd(4, 5); }
	pass { vsd(5); psd(5, 6); }
	pass { vsd(6); psd(6, 7); }
	pass { vsd(7); psd(7, 8); }
	pass
	{
		vsp();
		PixelShader = p_usamp0;
		BlendEnable = true;
		DestBlend = INVSRCCOLOR;
		#if BUFFER_COLOR_BIT_DEPTH != 10
			SRGBWriteEnable = true;
		#endif
	}

}
