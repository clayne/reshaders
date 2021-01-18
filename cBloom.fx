
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

// Use Marty McFly's mipmap calculator for now
#define INT_LOG2(v) (((v >> 1) != 0) + ((v >> 2) != 0) + ((v >> 3) != 0) + ((v >> 4) != 0) + ((v >> 5) != 0) + ((v >> 6) != 0) + ((v >> 7) != 0) + ((v >> 8) != 0) + ((v >> 9) != 0) + ((v >> 10) != 0) + ((v >> 11) != 0) + ((v >> 12) != 0) + ((v >> 13) != 0) + ((v >> 14) != 0) + ((v >> 15) != 0) + ((v >> 16) != 0))
static const int BloomTex7_LowestMip = INT_LOG2(int(BUFFER_HEIGHT / 2));
#define size 1024

texture2D _Bloom1 { Width = BUFFER_WIDTH / 2; Height = BUFFER_HEIGHT / 2; Format = RGBA16F; MipLevels = BloomTex7_LowestMip; };
texture2D _Bloom2 { Width = size / 2;   Height = size / 2;   Format = RGBA16F; };
texture2D _Bloom3 { Width = size / 4;   Height = size / 4;   Format = RGBA16F; };
texture2D _Bloom4 { Width = size / 8;   Height = size / 8;   Format = RGBA16F; };
texture2D _Bloom5 { Width = size / 16;  Height = size / 16;  Format = RGBA16F; };
texture2D _Bloom6 { Width = size / 32;  Height = size / 32;  Format = RGBA16F; };
texture2D _Bloom7 { Width = size / 64;  Height = size / 64;  Format = RGBA16F; };
texture2D _Bloom8 { Width = size / 128; Height = size / 128; Format = RGBA16F; };

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

struct vpf
{
	float4 vpos : SV_Position;
	float4 uv[3] : TEXCOORD0;
};

struct v2f
{
	float4 vpos : SV_Position;
	float2 uv : TEXCOORD0;
};

struct v2v
{
	float4 vpos : SV_Position;
	float4 uv[2] : TEXCOORD0;
};

v2v v_dsamp(uint id, sampler2D src)
{
	v2v o;
	float2 texcoord;
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	o.vpos = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

	// 9 tap gaussian using 4+1 texture fetches by CeeJayDK
	// https://github.com/CeeJayDK/SweetFX - LumaSharpen.fx
	float2 ts = 1.0 / tex2Dsize(src, 0.0).xy;
	o.uv[0].xy = texcoord + float2( ts.x * 0.5, -ts.y * 2.0); // South South East
	o.uv[0].zw = texcoord + float2(-ts.x * 2.0, -ts.y * 0.5); // West South West
	o.uv[1].xy = texcoord + float2( ts.x * 2.0,  ts.y * 0.5); // East North East
	o.uv[1].zw = texcoord + float2(-ts.x * 0.5,  ts.y * 2.0); // North North West
	return o;
}

vpf vs_dsamp0(in uint id : SV_VertexID)
{
	vpf o;
	float2 texcoord;
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	o.vpos = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

	float2 ts = BUFFER_PIXEL_SIZE;
	o.uv[0].xy = texcoord + int2( 0, 0) * ts;
	o.uv[0].zw = texcoord + int2(-1, 0) * ts;
	o.uv[1].xy = texcoord + int2( 1, 0) * ts;
	o.uv[1].zw = texcoord + int2( 0,-1) * ts;
	o.uv[2].xy = texcoord + int2( 0, 1) * ts;
	return o;
}

v2v vs_dsamp1(uint id : SV_VertexID) { return v_dsamp(id, s_Bloom1); }
v2v vs_dsamp2(uint id : SV_VertexID) { return v_dsamp(id, s_Bloom2); }
v2v vs_dsamp3(uint id : SV_VertexID) { return v_dsamp(id, s_Bloom3); }
v2v vs_dsamp4(uint id : SV_VertexID) { return v_dsamp(id, s_Bloom4); }
v2v vs_dsamp5(uint id : SV_VertexID) { return v_dsamp(id, s_Bloom5); }
v2v vs_dsamp6(uint id : SV_VertexID) { return v_dsamp(id, s_Bloom6); }
v2v vs_dsamp7(uint id : SV_VertexID) { return v_dsamp(id, s_Bloom7); }

float4 dsamp(sampler src, float4 uv[2])
{
	float4x4 s = float4x4(tex2D(src, uv[0].xy), tex2D(src, uv[0].zw),
						  tex2D(src, uv[1].xy), tex2D(src, uv[1].zw));

	// Karis's luma weighted average
	const float4 w = float4(1.0 / 3.0.sss, 1.0);
	s[0].a = rcp(dot(s[0], w));
	s[1].a = rcp(dot(s[1], w));
	s[2].a = rcp(dot(s[2], w));
	s[3].a = rcp(dot(s[3], w));
	float o_div_wsum = rcp(dot(float4(s[0].a, s[1].a, s[2].a, s[3].a), 1.0));

	float4 c;
	c.rgb  = s[0].rgb * s[0].a;
	c.rgb += s[1].rgb * s[1].a;
	c.rgb += s[2].rgb * s[2].a;
	c.rgb += s[3].rgb * s[3].a;
	c.rgb *= o_div_wsum;
	c.a = 1.0;
	return c;
}

/*
	Taken from [https://github.com/haasn/libplacebo/blob/master/src/shaders/sampling.c] [GPL 2.1]
	How bicubic scaling with only 4 texel fetches is done: [http://www.mate.tue.nl/mate/pdfs/10318.pdf]
	'Efficient GPU-Based Texture Interpolation using Uniform B-Splines'
*/

float3 calcweights(float s)
{
	const float4 w1 = float4(-0.5, 0.1666, 0.3333, -0.3333);
	const float4 w2 = float4( 1.0, 0.0, -0.5, 0.5);
	const float4 w3 = float4(-0.6666, 0.0, 0.8333, 0.1666);
	float4 t = mad(w1, s, w2);
	t = mad(t, s, w2.yyzw);
	t = mad(t, s, w3);
	t.xy  = mad(t.xy, rcp(t.zw), 1.0);
	t.xy += float2(s, -s);
	return t.rgb;
}

// Could calculate float3s for a bit more performance
float3 usamp(sampler2D src, float2 uv, float psize)
{
	const float pt = rcp(psize);
	float2 fcoord = frac(mad(uv, psize, 0.5));
	float2x3 parm = float2x3(calcweights(fcoord.x), calcweights(fcoord.y));

	float4 cdelta;
	cdelta.xz = parm[0].rg * float2(-pt, pt);
	cdelta.yw = parm[1].rg * float2(-pt, pt);
	float4x3 c = float4x3(tex2D(src, uv + cdelta.xy).rgb, tex2D(src, uv + cdelta.xw).rgb,
						  tex2D(src, uv + cdelta.zy).rgb, tex2D(src, uv + cdelta.zw).rgb);

	float3 ab = lerp(c[1], c[0], parm[1].b); // first y-interpolation
	float3 aa = lerp(c[3], c[2], parm[1].b); // second y-interpolation
	return lerp(aa, ab, parm[0].b); // x-interpolation
}

// 3-tap median filter
float3 Median(float3 a, float3 b, float3 c) { return a + b + c - min(a, min(b, c)) - max(a, max(b, c)); }

void p_dsamp0(vpf input, out float4 c : SV_Target0)
{
	float4 s0 = tex2D(s_Linear, input.uv[2].xy);
	float4x3 s = float4x3(tex2D(s_Linear, input.uv[0].xy).rgb, tex2D(s_Linear, input.uv[0].zw).rgb,
						  tex2D(s_Linear, input.uv[1].xy).rgb, tex2D(s_Linear, input.uv[1].zw).rgb);
	float3 m = Median(Median(s0.rgb, s[0], s[1]), s[2], s[3]);

	s0.a   = dot(m, 1.0 / 3.0);
	c.rgb  = saturate(lerp(s0.a, m, BLOOM_SAT));
	c.rgb *= pow(s0.a, BLOOM_CURVE) / s0.a;
	c.a = 1.0;
}

void p_dsamp1(v2v input, out float4 c : SV_Target0) { c = dsamp(s_Bloom1, input.uv); }
void p_dsamp2(v2v input, out float4 c : SV_Target0) { c = dsamp(s_Bloom2, input.uv); }
void p_dsamp3(v2v input, out float4 c : SV_Target0) { c = dsamp(s_Bloom3, input.uv); }
void p_dsamp4(v2v input, out float4 c : SV_Target0) { c = dsamp(s_Bloom4, input.uv); }
void p_dsamp5(v2v input, out float4 c : SV_Target0) { c = dsamp(s_Bloom5, input.uv); }
void p_dsamp6(v2v input, out float4 c : SV_Target0) { c = dsamp(s_Bloom6, input.uv); }
void p_dsamp7(v2v input, out float4 c : SV_Target0) { c = dsamp(s_Bloom7, input.uv); }
void p_usamp0(v2f input, out float3 c : SV_Target0)
{
	c  = 0.0;
	c += usamp(s_Bloom8, input.uv, size / 128).rgb;
	c += usamp(s_Bloom7, input.uv, size / 64).rgb;
	c += usamp(s_Bloom6, input.uv, size / 32).rgb;
	c += usamp(s_Bloom5, input.uv, size / 16).rgb;
	c += usamp(s_Bloom4, input.uv, size / 8).rgb;
	c += usamp(s_Bloom3, input.uv, size / 4).rgb;
	c += usamp(s_Bloom2, input.uv, size / 2).rgb;

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
	#define vsd(i)     VertexShader = vs_dsamp##i
	#define psd(i, j)  PixelShader = p_dsamp##i; RenderTarget = _Bloom##j

	pass { vsd(0); psd(0, 1); }
	pass { vsd(1); psd(1, 2); }
	pass { vsd(2); psd(2, 3); }
	pass { vsd(3); psd(3, 4); }
	pass { vsd(4); psd(4, 5); }
	pass { vsd(5); psd(5, 6); }
	pass { vsd(6); psd(6, 7); }
	pass { vsd(7); psd(7, 8); }
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = p_usamp0;
		BlendEnable = true;
		DestBlend = INVSRCCOLOR;
		#if BUFFER_COLOR_BIT_DEPTH != 10
			SRGBWriteEnable = true;
		#endif
	}

}
