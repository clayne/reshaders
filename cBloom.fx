/*
	Taken from [https://github.com/haasn/libplacebo/blob/master/src/shaders/sampling.c] [GPL 2.1]
	How bicubic scaling with only 4 texel fetches is done: [http://www.mate.tue.nl/mate/pdfs/10318.pdf]
	'Efficient GPU-Based Texture Interpolation using Uniform B-Splines'
*/

#include "ReShade.fxh"

sampler2D s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
// Hardcoded resulotion because the filter works on integer pixels
texture2D t_Downscaled < pooled = true; > { Width = 1024; Height = 1024; MipLevels = 6.0; Format = RGB10A2; };
sampler2D s_Downscaled { Texture = t_Downscaled; };

texture2D t_C0 { Width = 512; Height = 512; Format = RGB10A2; };
texture2D t_C1 { Width = 512; Height = 512; Format = RGB10A2; };
texture2D t_C2 { Width = 512; Height = 512; Format = RGB10A2; };

texture2D t_B0 { Width = 512; Height = 512; Format = RGB10A2; };
texture2D t_B1 { Width = 512; Height = 512; Format = RGB10A2; };
texture2D t_B2 < pooled = true; > { Width = 512; Height = 512; Format = RGB10A2; };

sampler2D s_C0 { Texture = t_C0; };
sampler2D s_C1 { Texture = t_C1; };
sampler2D s_C2 { Texture = t_C2; };

sampler2D s_B0 { Texture = t_B0; };
sampler2D s_B1 { Texture = t_B1; };
sampler2D s_B2 { Texture = t_B2; };

struct vs_in
{
	float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

// Empty shader to generate mipmaps.

void PS_MipGen(vs_in input, out float3 c : SV_Target0)
{
	float3 col = tex2D(s_Linear, input.uv).rgb;

	c = step(1.0, length(col));

	c *= (0.002 * col) / (1.1 - col);

	c = c * exp(2.2);
}

/*
	Uchimura 2017, "HDR theory and practice"
	Math: https://www.desmos.com/calculator/gslcdxvipg
	Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp
*/

float3 uchimura(float3 x)
{
  const float P = 1.0;  // max display brightness
  const float a = 1.0;  // contrast
  const float m = 0.22; // linear section start
  const float l = 0.4;  // linear section length
  const float c = 1.33; // black
  const float b = 0.0;  // pedestal

  float l0 = ((P - m) * l) / a;
  float L0 = m - m / a;
  float L1 = m + (1.0 - m) / a;
  float S0 = m + l0;
  float S1 = m + a * l0;
  float C2 = (a * P) / (P - S1);
  float CP = -C2 / P;

  float3 w0 = float3(1.0 - smoothstep(0.0, m, x));
  float3 w2 = float3(step(m + l0, x));
  float3 w1 = float3(1.0 - w0 - w2);

  float3 T = float3(m * pow(abs(x / m), c) + b);
  float3 S = float3(P - (P - S1) * exp(CP * (x - S0)));
  float3 L = float3(m + a * (x - m));

  return T * w0 + L * w1 + S * w2;
}

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
			  out float3 c0 : SV_Target0,
			  out float3 c1 : SV_Target1,
			  out float3 c2 : SV_Target2)
{
	c0 = pCubic(s_Downscaled, input.uv, 4.0);
	c1 = pCubic(s_Downscaled, input.uv, 5.0);
	c2 = pCubic(s_Downscaled, input.uv, 6.0);
}

struct vs_blur
{
	float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
	float4 c0_uv[9] : TEXCOORD1;
};

void VS_Blur(vs_in input,in uint id : SV_VertexID,
						 out float4 vpos : SV_Position,
						 out float4 c0_uv[9] : TEXCOORD1)
{
	const float2 c0_pt = 1.0 / tex2Dsize(s_C0, 3.0);
	const float2 c1_pt = 1.0 / tex2Dsize(s_C1, 4.0);
	const float2 c2_pt = 1.0 / tex2Dsize(s_C2, 5.0);

	PostProcessVS(id, vpos, input.uv);
	const float2 direction = float2(1.0, 0.0);
	const int steps = 3;
	for(int i = 0; i < steps; i++)
	{
		c0_uv[i].xy = input.uv - (c0_pt * direction * i);
		c0_uv[i].zw = input.uv + (c0_pt * direction * i);
		c0_uv[i+3].xy = input.uv - (c1_pt * direction * i);
		c0_uv[i+3].zw = input.uv + (c1_pt * direction * i);
		c0_uv[i+6].xy = input.uv - (c2_pt * direction * i);
		c0_uv[i+6].zw = input.uv + (c2_pt * direction * i);
	}
}

void VS_BlurV(vs_in input,in uint id : SV_VertexID,
						 out float4 vpos : SV_Position,
						 out float4 c0_uv[9] : TEXCOORD1)
{
	const float2 c0_pt = 1.0 / tex2Dsize(s_C0, 3.0);
	const float2 c1_pt = 1.0 / tex2Dsize(s_C1, 4.0);
	const float2 c2_pt = 1.0 / tex2Dsize(s_C2, 5.0);

	PostProcessVS(id, vpos, input.uv);
	const float2 direction = float2(0.0, 1.0);
	const int steps = 3;
	for(int i = 0; i < steps; i++)
	{
		c0_uv[i].xy = input.uv - (c0_pt * direction * i);
		c0_uv[i].zw = input.uv + (c0_pt * direction * i);
		c0_uv[i+3].xy = input.uv - (c1_pt * direction * i);
		c0_uv[i+3].zw = input.uv + (c1_pt * direction * i);
		c0_uv[i+6].xy = input.uv - (c2_pt * direction * i);
		c0_uv[i+6].zw = input.uv + (c2_pt * direction * i);
	}
}

void PS_Blur(vs_blur input,
			  out float3 c0 : SV_Target0,
			  out float3 c1 : SV_Target1,
			  out float3 c2 : SV_Target2)
{
	// Apply motion blur
	const float2 c0_pt = 1.0 / tex2Dsize(s_C0, 3.0);
	const float2 c1_pt = 1.0 / tex2Dsize(s_C1, 4.0);
	const float2 c2_pt = 1.0 / tex2Dsize(s_C2, 5.0);
	float3 color;
	const int _Samples = 3;
	const float weights[_Samples] = {0.27901, 0.44198, 0.27901};

	[loop] for (int i = 0; i < _Samples; i++)
	{
		c0 += tex2Dlod(s_C0, float4(input.c0_uv[i].xy, 0.0, 3.0)).rgb * weights[i];
		c0 += tex2Dlod(s_C0, float4(input.c0_uv[i].zw, 0.0, 3.0)).rgb * weights[i];
		c1 += tex2Dlod(s_C1, float4(input.c0_uv[i+3].xy, 0.0, 4.0)).rgb * weights[i];
		c1 += tex2Dlod(s_C1, float4(input.c0_uv[i+3].zw, 0.0, 4.0)).rgb * weights[i];
		c2 += tex2Dlod(s_C2, float4(input.c0_uv[i+6].xy, 0.0, 5.0)).rgb * weights[i];
		c2 += tex2Dlod(s_C2, float4(input.c0_uv[i+6].zw, 0.0, 5.0)).rgb * weights[i];
	}
}

void PS_BlurV(vs_blur input, out float3 c0 : SV_Target0)
{
	// Apply motion blur
	const float2 c0_pt = 1.0 / tex2Dsize(s_B0, 3.0);
	const float2 c1_pt = 1.0 / tex2Dsize(s_B1, 4.0);
	const float2 c2_pt = 1.0 / tex2Dsize(s_B2, 5.0);
	float3 color;
	const int _Samples = 3;
	const float weights[_Samples] = {0.27901, 0.44198, 0.27901};

	[loop] for (int i = 0; i < _Samples; i++)
	{
		c0 += tex2Dlod(s_B0, float4(input.c0_uv[i].xy, 0.0, 3.0)).rgb * weights[i];
		c0 += tex2Dlod(s_B0, float4(input.c0_uv[i].zw, 0.0, 3.0)).rgb * weights[i];
		c0 += tex2Dlod(s_B1, float4(input.c0_uv[i+3].xy, 0.0, 4.0)).rgb * weights[i];
		c0 += tex2Dlod(s_B1, float4(input.c0_uv[i+3].zw, 0.0, 4.0)).rgb * weights[i];
		c0 += tex2Dlod(s_B2, float4(input.c0_uv[i+6].xy, 0.0, 5.0)).rgb * weights[i];
		c0 += tex2Dlod(s_B2, float4(input.c0_uv[i+6].zw, 0.0, 5.0)).rgb * weights[i];
	}
	c0 = uchimura(c0);

	// Interleaved Gradient Noise by Jorge Jimenez
	const float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
	float xy_magic = dot(input.vpos.xy, magic.xy);
	float noise = frac(magic.z * frac(xy_magic)) - 0.5;
	c0 += float3(-noise, noise, -noise) / 255;
}

technique cBloom
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_MipGen;
		RenderTarget0 = t_Downscaled;
	}

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_Cubic;
		RenderTarget0 = t_C0;
		RenderTarget1 = t_C1;
		RenderTarget2 = t_C2;
	}

	pass
	{
		VertexShader = VS_Blur;
		PixelShader = PS_Blur;
		RenderTarget0 = t_B0;
		RenderTarget1 = t_B1;
		RenderTarget2 = t_B2;
	}

	pass
	{
		VertexShader = VS_BlurV;
		PixelShader = PS_BlurV;
		SRGBWriteEnable = true;
		BlendEnable = true;
		DestBlend = INVSRCCOLOR;
	}
}
