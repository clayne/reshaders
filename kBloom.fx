
/*
	Custom version of KinoBloom. Should be lighter than qUINT_Bloom

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

struct v2f
{
	float4 vpos : SV_Position;
	float2 uv   : TEXCOORD0;
};

texture2D _Bloom1 { Width = BUFFER_WIDTH / 2;   Height = BUFFER_HEIGHT / 2;   Format = RGBA16F; };
texture2D _Bloom2 { Width = BUFFER_WIDTH / 4;   Height = BUFFER_HEIGHT / 4;   Format = RGBA16F; };
texture2D _Bloom3 { Width = BUFFER_WIDTH / 8;   Height = BUFFER_HEIGHT / 8;   Format = RGBA16F; };
texture2D _Bloom4 { Width = BUFFER_WIDTH / 16;  Height = BUFFER_HEIGHT / 16;  Format = RGBA16F; };
texture2D _Bloom5 { Width = BUFFER_WIDTH / 32;  Height = BUFFER_HEIGHT / 32;  Format = RGBA16F; };
texture2D _Bloom6 { Width = BUFFER_WIDTH / 64;  Height = BUFFER_HEIGHT / 64;  Format = RGBA16F; };
texture2D _Bloom7 { Width = BUFFER_WIDTH / 128; Height = BUFFER_HEIGHT / 128; Format = RGBA16F; };

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

// 3-tap median filter
float3 Median(float3 a, float3 b, float3 c) { return a + b + c - min(min(a, b), c) - max(max(a, b), c); }
float Brightness(float3 c) { return max(max(c.r, c.g), c.b); }

float3 dsamp(sampler2D src, float2 uv)
{
	float3 s1 = tex2D(src, uv, int2(-1.0, -1.0)).rgb;
	float3 s2 = tex2D(src, uv, int2( 1.0, -1.0)).rgb;
	float3 s3 = tex2D(src, uv, int2(-1.0,  1.0)).rgb;
	float3 s4 = tex2D(src, uv, int2( 1.0,  1.0)).rgb;

	// Karis's luma weighted average (using brightness instead of luma)
	float4 sw;
	sw.x = 1.0 / (Brightness(s1) + 1.0);
	sw.y = 1.0 / (Brightness(s2) + 1.0);
	sw.z = 1.0 / (Brightness(s3) + 1.0);
	sw.w = 1.0 / (Brightness(s4) + 1.0);
	float one_div_wsum = 1.0 / dot(1.0, sw);

	return (s1 * sw.x + s2 * sw.y + s3 * sw.z + s4 * sw.w) * one_div_wsum;
}

// Instead of vanilla bilinear, we use gaussian from CeeJayDK's SweetFX LumaSharpen.
float4 usamp(sampler2D src, float2 uv)
{
	float2 ts = 1.0 / tex2Dsize(src, 0.0);
	float4 s;
	s.rgb += tex2D(src, uv + float2(0.5 * ts.x,  -ts.y)).rgb; // South South East
	s.rgb += tex2D(src, uv + float2(-ts.x, 0.5 * -ts.y)).rgb; // West South West
	s.rgb += tex2D(src, uv + float2( ts.x, 0.5 *  ts.y)).rgb; // East North East
	s.rgb += tex2D(src, uv + float2(0.5 * -ts.x,  ts.y)).rgb; // North North West
	s.rgb *= 0.25;
	s.a = BLOOM_INTENSITY;
	return s;
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

	s0.a = dot(m, 1.0 / 3.0);
	c  = saturate(lerp(s0.a, m, BLOOM_SAT));
	c *= pow(abs(s0.a), BLOOM_CURVE) / s0.a;
}

void p_dsamp1(v2f input, out float3 c : SV_Target0) { c = dsamp(s_Bloom1, input.uv); }
void p_dsamp2(v2f input, out float3 c : SV_Target0) { c = dsamp(s_Bloom2, input.uv); }
void p_dsamp3(v2f input, out float3 c : SV_Target0) { c = dsamp(s_Bloom3, input.uv); }
void p_dsamp4(v2f input, out float3 c : SV_Target0) { c = dsamp(s_Bloom4, input.uv); }
void p_dsamp5(v2f input, out float3 c : SV_Target0) { c = dsamp(s_Bloom5, input.uv); }
void p_dsamp6(v2f input, out float3 c : SV_Target0) { c = dsamp(s_Bloom6, input.uv); }

void p_usamp7(v2f input, out float4 c : SV_Target0) { c = usamp(s_Bloom7, input.uv); }
void p_usamp6(v2f input, out float4 c : SV_Target0) { c = usamp(s_Bloom6, input.uv); }
void p_usamp5(v2f input, out float4 c : SV_Target0) { c = usamp(s_Bloom5, input.uv); }
void p_usamp4(v2f input, out float4 c : SV_Target0) { c = usamp(s_Bloom4, input.uv); }
void p_usamp3(v2f input, out float4 c : SV_Target0) { c = usamp(s_Bloom3, input.uv); }
void p_usamp2(v2f input, out float4 c : SV_Target0) { c = usamp(s_Bloom2, input.uv); }
void p_usamp1(v2f input, out float3 c : SV_Target0)
{
	c = usamp(s_Bloom1, input.uv).rgb;

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
	#define vs()       VertexShader = PostProcessVS
	#define psd(i, j)  PixelShader = p_dsamp##i; RenderTarget = _Bloom##j
	#define psu(i, j)  PixelShader = p_usamp##i; RenderTarget = _Bloom##j
	#define blendadd() BlendEnable = true; SrcBlend = ONE; DestBlend = SRCALPHA

	pass { vs(); psd(0, 1); }
	pass { vs(); psd(1, 2); }
	pass { vs(); psd(2, 3); }
	pass { vs(); psd(3, 4); }
	pass { vs(); psd(4, 5); }
	pass { vs(); psd(5, 6); }
	pass { vs(); psd(6, 7); }
	pass { vs(); psu(7, 6); blendadd(); }
	pass { vs(); psu(6, 5); blendadd(); }
	pass { vs(); psu(5, 4); blendadd(); }
	pass { vs(); psu(4, 3); blendadd(); }
	pass { vs(); psu(3, 2); blendadd(); }
	pass { vs(); psu(2, 1); blendadd(); }
	pass
	{
		vs();
		PixelShader = p_usamp1;
		BlendEnable = true;
		DestBlend = INVSRCCOLOR;
		#if BUFFER_COLOR_BIT_DEPTH != 10
			SRGBWriteEnable = true;
		#endif
	}
}
