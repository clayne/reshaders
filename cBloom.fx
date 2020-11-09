/*
	Nyctalopia, by CopingMechanism
	This bloom's [--]ed up, as expected from an amatuer. Help is welcome! :)
*/

#include "ReShade.fxh"

#define size 1024.0 // Must be multiples of 16!
#define size_d size / 16.0

texture t_Mip0 < pooled = true; > { Width = size; Height = size; MipLevels = 5; Format = RGBA16F; };
texture t_BlurH < pooled = true; > { Width = size_d; Height = size_d; Format = RGBA16F; };
texture t_BlurV < pooled = true; > { Width = size_d; Height = size_d; Format = RGBA16F; };

sampler s_Linear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler s_Mip0 { Texture = t_Mip0; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler s_BlurH { Texture = t_BlurH; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
sampler s_BlurV { Texture = t_BlurV; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };

/* [ Vertex Shaders ] */

struct vs_in
{
	uint id : SV_VertexID;
	float2 uv : TEXCOORD0;
};

struct vs_out
{
	float4 vpos : SV_POSITION;
	float2 uv : TEXCOORD0;
	float4 b_uv[6] : TEXCOORD2; // Blur TEXCOORD
};

/* [ Vertex Shaders ] */

void VS_Median(vs_in input, out float4 vpos : SV_Position, out float4 m_uv[4] : TEXCOORD1)
{
	PostProcessVS(input.id, vpos, input.uv);
	const float3 d = BUFFER_PIXEL_SIZE.xyx * float3(1, 1, 0);
	m_uv[0] = input.uv - d.xz;
	m_uv[1] = input.uv + d.xz;
	m_uv[2] = input.uv - d.zy;
	m_uv[3] = input.uv + d.zy;
}

static const int steps = 6;
static const float offsets[steps] = { 0.65772, 2.45017, 4.41096, 6.37285, 8.33626, 10.30153 };
static const float weights[steps] = { 0.16501, 0.17507, 0.10112, 0.04268, 0.01316, 0.002960 };

void VS_BlurH(vs_in input, out float4 vpos : SV_Position, out float4 b_uv[6] : TEXCOORD2)
{
	PostProcessVS(input.id, vpos, input.uv);
	const float2 direction = float2(rcp(size_d), 0.0);
	for(int i = 0; i < steps; i++)
	{
		b_uv[i].xy = input.uv - offsets[i] * direction;
		b_uv[i].zw = input.uv + offsets[i] * direction;
	}
}

void VS_BlurV(vs_in input, out float4 vpos : SV_Position, out float4 b_uv[6] : TEXCOORD2)
{
	PostProcessVS(input.id, vpos, input.uv);
	const float2 direction = float2(0.0, rcp(size_d));
	for(int i = 0; i < steps; i++)
	{
		b_uv[i].xy = input.uv - offsets[i] * direction;
		b_uv[i].zw = input.uv + offsets[i] * direction;
	}
}

/*
	[ Helper Functions ]
	PS_Blur() by ShaderPatch https://github.com/SleepKiller/shaderpatch [MIT License]
*/

float3 Median(float3 a, float3 b, float3 c) { return a + b + c - min(min(a,b),c) - max(max(a,b),c); }

float3 Blur(sampler src, float4 b_uv[6])
{
	float3 result;
	for (int i = 0; i < steps; i++)
	{
		result += tex2D(src, b_uv[i].xy).rgb * weights[i];
		result += tex2D(src, b_uv[i].zw).rgb * weights[i];
	}

	return result;
}

/* [ Pixel Shaders ] */

void PS_Light(vs_out output, float4 m_uv[4] : TEXCOORD1, out float4 c : SV_Target0)
{
	float3 _s0 = tex2D(s_Linear, output.uv).rgb;
	float3 _s1 = tex2D(s_Linear, m_uv[0].xy).rgb;
	float3 _s2 = tex2D(s_Linear, m_uv[1].xy).rgb;
	float3 _s3 = tex2D(s_Linear, m_uv[2].xy).rgb;
	float3 _s4 = tex2D(s_Linear, m_uv[3].xy).rgb;
	float3 m = Median(Median(_s0, _s1, _s2), _s3, _s4);
	m = max(m - 0.9, 0.0);
	c = float4(m * exp(2.2 + 0.9), 1.0);
}

void PS_BlurH(vs_out output, out float4 c : SV_Target0) { c = float4(Blur(s_Mip0, output.b_uv), 1.0); }
void PS_BlurV(vs_out output, out float4 c : SV_Target0) { c = float4(Blur(s_BlurH, output.b_uv), 1.0); }

/*
	Taken from [https://github.com/haasn/libplacebo/blob/master/src/shaders/sampling.c], GPL 2.1
	Explanation of how bicubic scaling with only 4 texel fetches is done:
	http://www.mate.tue.nl/mate/pdfs/10318.pdf
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

  float3 T = float3(m * pow(x / m, c) + b);
  float3 S = float3(P - (P - S1) * exp(CP * (x - S0)));
  float3 L = float3(m + a * (x - m));

  return T * w0 + L * w1 + S * w2;
}

void PS_Cubic(vs_out output, out float3 c : SV_Target0)
{
	const float2 texsize = tex2Dsize(s_BlurV, 0.0);
	const float2 pt = 1.0 / texsize;
	float2 fcoord = frac(output.uv * texsize + 0.5);
	float4 parmx = calcweights(fcoord.x);
	float4 parmy = calcweights(fcoord.y);
	float4 cdelta;
	cdelta.xz = parmx.rg * float2(-pt.x, pt.x);
	cdelta.yw = parmy.rg * float2(-pt.y, pt.y);
	// first y-interpolation
	float3 ar = tex2Dlod(s_BlurV, float4(output.uv + cdelta.xy, 0.0, 0.0)).rgb;
	float3 ag = tex2Dlod(s_BlurV, float4(output.uv + cdelta.xw, 0.0, 0.0)).rgb;
	float3 ab = lerp(ag, ar, parmy.b);
	// second y-interpolation
	float3 br = tex2Dlod(s_BlurV, float4(output.uv + cdelta.zy, 0.0, 0.0)).rgb;
	float3 bg = tex2Dlod(s_BlurV, float4(output.uv + cdelta.zw, 0.0, 0.0)).rgb;
	float3 aa = lerp(bg, br, parmy.b);
	// x-interpolation
	c = lerp(aa, ab, parmx.b);
	c = uchimura(c);

	// Interleaved Gradient Noise by Jorge Jimenez
	const float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
	float xy_magic = dot(output.vpos.xy, magic.xy);
	float noise = frac(magic.z * frac(xy_magic)) - 0.5;
	c += float3(-noise, noise, -noise) / 255;

	c = c;
}

technique CBloom
{
	pass
	{
		VertexShader = VS_Median;
		PixelShader = PS_Light;
		RenderTarget = t_Mip0;
	}

	pass
	{
		VertexShader = VS_BlurH;
		PixelShader = PS_BlurH;
		RenderTarget = t_BlurH;
	}

	pass
	{
		VertexShader = VS_BlurV;
		PixelShader = PS_BlurV;
		RenderTarget = t_BlurV;
	}

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_Cubic;
		SRGBWriteEnable = true;
		BlendEnable = true;
		DestBlend = INVSRCCOLOR;
	}
}