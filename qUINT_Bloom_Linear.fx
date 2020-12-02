/*=============================================================================

	This bloom's a bit different from the original. There is no adapt eye, the
	input's linear sRGB, and the tonemap operation is Baking Lab's ACES Fitted.

	ReShade 4 effect file
    github.com/martymcmodding

	Support me:
   		paypal.me/mcflypg
   		patreon.com/mcflypg

    Simple Bloom
    by Marty McFly / P.Gilcher
    part of qUINT shader library for ReShade 4

    Copyright (c) Pascal Gilcher / Marty McFly. All rights reserved.

=============================================================================*/

/*=============================================================================
	UI Uniforms
=============================================================================*/

uniform float BLOOM_INTENSITY <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 10.0;
	ui_label = "Bloom Intensity";
	ui_tooltip = "Scales bloom brightness.";
> = 1.2;

uniform float BLOOM_CURVE <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 10.0;
	ui_label = "Bloom Curve";
	ui_tooltip = "Higher values limit bloom to bright light sources only.";
> = 1.5;

uniform float BLOOM_SAT <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 5.0;
	ui_label = "Bloom Saturation";
	ui_tooltip = "Adjusts the color strength of the bloom effect";
> = 2.0;

uniform float4 MULT_1_4 <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Bloom Layer 1-4 Intensity";
	ui_tooltip = "Intensity of this bloom layer. 1 is sharpest layer, 7 the most blurry.";
> = float4(0.01, 0.05, 0.05, 0.1);

uniform float3 MULT_5_7 <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Bloom Layer 5-7 Intensity";
	ui_tooltip = "Intensity of this bloom layer. 1 is sharpest layer, 7 the most blurry.";
> = float3(0.05, 0.05, 0.01);

/*=============================================================================
	Textures, Samplers, Globals
=============================================================================*/

#include "ReShade.fxh"
#define size float2(BUFFER_WIDTH, BUFFER_HEIGHT)
#define psize 1.0 / size

texture2D _BloomTexSource	{ Width = BUFFER_WIDTH/2;   Height = BUFFER_HEIGHT/2;    Format = RGBA16F; };
texture2D _BloomTex1		{ Width = BUFFER_WIDTH/2;   Height = BUFFER_HEIGHT/2;    Format = RGBA16F; };
texture2D _BloomTex2		{ Width = BUFFER_WIDTH/4;   Height = BUFFER_HEIGHT/4;    Format = RGBA16F; };
texture2D _BloomTex3		{ Width = BUFFER_WIDTH/8;   Height = BUFFER_HEIGHT/8;    Format = RGBA16F; };
texture2D _BloomTex4		{ Width = BUFFER_WIDTH/16;  Height = BUFFER_HEIGHT/16;   Format = RGBA16F; };
texture2D _BloomTex5		{ Width = BUFFER_WIDTH/32;  Height = BUFFER_HEIGHT/32;   Format = RGBA16F; };
texture2D _BloomTex6		{ Width = BUFFER_WIDTH/64;  Height = BUFFER_HEIGHT/64;   Format = RGBA16F; };
texture2D _BloomTex7		{ Width = BUFFER_WIDTH/128; Height = BUFFER_HEIGHT/128;  Format = RGBA16F; };

sampler2D s_BloomSource 
{
	Texture = ReShade::BackBufferTex;
	#if BUFFER_COLOR_BIT_DEPTH != 10
		SRGBTexture = true;
	#endif
};

sampler2D s_BloomTexSource 	{ Texture = _BloomTexSource; };
sampler2D s_BloomTex1 	   	{ Texture = _BloomTex1; };
sampler2D s_BloomTex2		{ Texture = _BloomTex2; };
sampler2D s_BloomTex3		{ Texture = _BloomTex3; };
sampler2D s_BloomTex4		{ Texture = _BloomTex4; };
sampler2D s_BloomTex5		{ Texture = _BloomTex5; };
sampler2D s_BloomTex6		{ Texture = _BloomTex6; };
sampler2D s_BloomTex7		{ Texture = _BloomTex7; };

/*=============================================================================
	Functions
=============================================================================*/

float3 dsamp(sampler2D tex, float2 tex_size, float2 uv)
{
	float4 offset_uv = 0.0;

	float2 kernel_small_offsets = float2(2.0, 2.0) / tex_size;
	float2 kernel_large_offsets = float2(4.0, 4.0) / tex_size;

	float3 kernel_center = tex2D(tex, uv).rgb;
	float3 kernel_small = 0.0;

	offset_uv.xy = uv + kernel_small_offsets;
	kernel_small += tex2Dlod(tex, offset_uv).rgb; // ++
	offset_uv.x = uv.x - kernel_small_offsets.x;
	kernel_small += tex2Dlod(tex, offset_uv).rgb; // -+
	offset_uv.y = uv.y - kernel_small_offsets.y;
	kernel_small += tex2Dlod(tex, offset_uv).rgb; // --
	offset_uv.x = uv.x + kernel_small_offsets.x;
	kernel_small += tex2Dlod(tex, offset_uv).rgb; // +-

	return kernel_center / 5.0	
	      + kernel_small / 5.0;
}

float3 usamp(sampler2D tex, float2 texel_size, float2 uv)
{
	float4 offset_uv = 0.0;

	float4 kernel_small_offsets;
	kernel_small_offsets.xy = 1.5 * texel_size;
	kernel_small_offsets.zw = kernel_small_offsets.xy * 2;

	float3 kernel_center = tex2D(tex, uv).rgb;
	float3 kernel_small_1 = 0.0;

	offset_uv.xy = uv.xy - kernel_small_offsets.xy;
	kernel_small_1 += tex2Dlod(tex, offset_uv).rgb; // --
	offset_uv.x += kernel_small_offsets.z;
	kernel_small_1 += tex2Dlod(tex, offset_uv).rgb; // +-
	offset_uv.y += kernel_small_offsets.w;
	kernel_small_1 += tex2Dlod(tex, offset_uv).rgb; // ++
	offset_uv.x -= kernel_small_offsets.z;
	kernel_small_1 += tex2Dlod(tex, offset_uv).rgb; // -+

	return kernel_center / 5.0
	     + kernel_small_1 / 5.0;
}

/*=============================================================================
	Pixel Shaders
=============================================================================*/

struct v2f
{
	float4 vpos : SV_Position;
	float2 uv : TEXCOORD0;
};

void p_BloomPrepass(v2f input, out float4 c : SV_Target0)
{
	c = tex2D(s_BloomSource, input.uv);
	c.w = saturate(dot(c.rgb, 0.333));

	c.rgb = saturate(lerp(c.w, c.rgb, BLOOM_SAT));
	c.rgb *= (pow(c.w, BLOOM_CURVE) * BLOOM_INTENSITY) / (c.w + 1e-3);
}

void p_dSample1(v2f input, out float3 c : SV_Target0) { c = dsamp(s_BloomTexSource, ldexp(size, -1.0), input.uv); }
void p_dSample2(v2f input, out float3 c : SV_Target0) { c = dsamp(s_BloomTex1, ldexp(size, -2.0), input.uv); }
void p_dSample3(v2f input, out float3 c : SV_Target0) { c = dsamp(s_BloomTex2, ldexp(size, -3.0), input.uv); }
void p_dSample4(v2f input, out float3 c : SV_Target0) { c = dsamp(s_BloomTex3, ldexp(size, -4.0), input.uv); }
void p_dSample5(v2f input, out float3 c : SV_Target0) { c = dsamp(s_BloomTex4, ldexp(size, -5.0), input.uv); }
void p_dSample6(v2f input, out float3 c : SV_Target0) { c = dsamp(s_BloomTex5, ldexp(size, -6.0), input.uv); }
void p_dSample7(v2f input, out float3 c : SV_Target0) { c = dsamp(s_BloomTex6, ldexp(size, -7.0), input.uv); }

void p_uSample1(v2f input, out float4 c : SV_Target0) { c = float4(usamp(s_BloomTex7, ldexp(psize, 7.0), input.uv) * MULT_5_7.z, MULT_5_7.y); }
void p_uSample2(v2f input, out float4 c : SV_Target0) { c = float4(usamp(s_BloomTex6, ldexp(psize, 6.0), input.uv), MULT_5_7.x); }
void p_uSample3(v2f input, out float4 c : SV_Target0) { c = float4(usamp(s_BloomTex5, ldexp(psize, 5.0), input.uv), MULT_1_4.w); }
void p_uSample4(v2f input, out float4 c : SV_Target0) { c = float4(usamp(s_BloomTex4, ldexp(psize, 4.0), input.uv), MULT_1_4.z); }
void p_uSample5(v2f input, out float4 c : SV_Target0) { c = float4(usamp(s_BloomTex3, ldexp(psize, 3.0), input.uv), MULT_1_4.y); }
void p_uSample6(v2f input, out float4 c : SV_Target0) { c = float4(usamp(s_BloomTex2, ldexp(psize, 2.0), input.uv), MULT_1_4.x); }

// Tonemap from Matt Pettineo's and Stephen Hill's work at
// https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/ACES.hlsl

void p_Combine(v2f input, out float3 c : SV_Target0)
{
	float3 bloom = usamp(s_BloomTex1, ldexp(psize, 1.0), input.uv);
	bloom /= dot(MULT_1_4.xyzw, 1.0) + dot(MULT_5_7.xyz, 1.0);
	c = bloom;

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

/*=============================================================================
	Techniques
=============================================================================*/

technique Bloom
< ui_tooltip = "                >> qUINT::Bloom <<\n\n"
			   "Bloom is a shader that produces a glow around bright\n"
               "light sources and other emitters on screen.\n"
               "\nBloom is written by Marty McFly / Pascal Gilcher"; >
{
    pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = p_BloomPrepass;
		RenderTarget0 = _BloomTexSource;
	}

	#define PASS_DOWNSAMPLE(i) pass { VertexShader = PostProcessVS; PixelShader = p_dSample##i; RenderTarget0 = _BloomTex##i; }

	PASS_DOWNSAMPLE(1)
	PASS_DOWNSAMPLE(2)
	PASS_DOWNSAMPLE(3)
	PASS_DOWNSAMPLE(4)
	PASS_DOWNSAMPLE(5)
	PASS_DOWNSAMPLE(6)
	PASS_DOWNSAMPLE(7)

	#define PASS_UPSAMPLE(i,j) pass { VertexShader = PostProcessVS; PixelShader = p_uSample##i; RenderTarget0 = _BloomTex##j; ClearRenderTargets = false; BlendEnable = true; BlendOp = ADD; SrcBlend = ONE; DestBlend = SRCALPHA;}

	PASS_UPSAMPLE(1,6)
	PASS_UPSAMPLE(2,5)
	PASS_UPSAMPLE(3,4)
	PASS_UPSAMPLE(4,3)
	PASS_UPSAMPLE(5,2)
	PASS_UPSAMPLE(6,1)

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = p_Combine;
		#if BUFFER_COLOR_BIT_DEPTH != 10
			SRGBWriteEnable = true;
		#endif
		BlendEnable = true;
		DestBlend = INVSRCCOLOR;
	}
}
