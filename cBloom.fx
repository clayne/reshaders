#include "ReShade.fxh"
#define size 1024

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

texture2D t_lod     { Width = size; Height = size; MipLevels = 5; };
texture2D t_dlod    { Width = size / 16; Height = size / 16; };
texture2D t_hblur   { Width = size / 16; Height = size / 16; };
texture2D t_vblur   { Width = size / 16; Height = size / 16; };
texture2D t_usamp0  { Width = size / 8; Height = size / 8; };
texture2D t_usamp1  { Width = size / 4; Height = size / 4; };
texture2D t_usamp2  { Width = size / 2; Height = size / 2; };

sampler2D s_Linear  { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
sampler2D s_lod     { Texture = t_lod;  };
sampler2D s_dlod    { Texture = t_dlod; };
sampler2D s_hblur   { Texture = t_hblur; };
sampler2D s_vblur   { Texture = t_vblur; };
sampler2D s_usamp0  { Texture = t_usamp0; };
sampler2D s_usamp1  { Texture = t_usamp1; };
sampler2D s_usamp2  { Texture = t_usamp2; };

struct v2f
{
    float4 vpos : SV_Position;
    float2 uv : TEXCOORD0;
};

void p_lod(v2f input, out float4 c : SV_Target0)
{
    c = tex2D(s_Linear, input.uv);
	c.w = saturate(dot(c.rgb, 0.333));

	c.rgb = saturate(lerp(c.w, c.rgb, BLOOM_SAT));
	c.rgb *= (pow(c.w, BLOOM_CURVE) * BLOOM_INTENSITY) / (c.w + 1e-3);
}

float4 sample(sampler src, float2 uv)
{
    float4 c;
    const float ps = rcp(tex2Dsize(src, 0.0));
    c.rgb  = tex2D(src, uv + float2( 0.5 * ps, -ps)).rgb; // South South East
    c.rgb += tex2D(src, uv + float2(-ps, 0.5 * -ps)).rgb; // West South West
    c.rgb += tex2D(src, uv + float2( ps, 0.5 *  ps)).rgb; // East North East
    c.rgb += tex2D(src, uv + float2( 0.5 * -ps, ps)).rgb; // North North West
    c.rgb *= 0.25;  // Divide by the number of texture fetches
    c.w = 1.0;
    return c;
}

void p_dlod(v2f input, out float4 c : SV_Target0) { c = sample(s_lod, input.uv); }

static const int step_count = 6;
static const float weights[step_count] = { 0.16501, 0.17507, 0.10112, 0.04268, 0.01316, 0.00296 };
static const float offsets[step_count] = { 0.65772, 2.45017, 4.41096, 6.37285, 8.33626, 10.30153 };
static const float2 direction = float2(0.0, 1.0);

void p_hblur(v2f input, out float4 c : SV_Target0)
{
    float4 result;
    for (int i = 0; i < step_count; i++)
    {
        const float2 uvo = offsets[i] * direction.yx;
        const float3 samples = tex2D(s_dlod, input.uv + uvo) + tex2D(s_dlod, input.uv - uvo);
        result += weights[i] * samples;
    }
}

void p_vblur(v2f input, out float4 c : SV_Target0)
{
    float4 result;
    for (int i = 0; i < step_count; i++)
    {
        const float2 uvo = offsets[i] * direction.xy;
        const float3 samples = tex2D(s_dlod, input.uv + uvo) + tex2D(s_dlod, input.uv - uvo);
        result += weights[i] * samples;
    }
}

void p_usamp0 (v2f input, out float4 c : SV_Target0) { c = sample(s_vblur,  input.uv); }
void p_usamp1 (v2f input, out float4 c : SV_Target0) { c = sample(s_usamp0, input.uv); }
void p_usamp2 (v2f input, out float4 c : SV_Target0) { c = sample(s_usamp1, input.uv); }
void p_combine(v2f input, out float4 c : SV_Target0) { c = sample(s_usamp2, input.uv); }

technique cBloom
{
    pass { VertexShader = PostProcessVS; PixelShader = p_lod;    RenderTarget = t_lod;    }
    pass { VertexShader = PostProcessVS; PixelShader = p_dlod;   RenderTarget = t_dlod;   }
    pass { VertexShader = PostProcessVS; PixelShader = p_hblur;  RenderTarget = t_hblur;  }
    pass { VertexShader = PostProcessVS; PixelShader = p_vblur;  RenderTarget = t_vblur;  }
    pass { VertexShader = PostProcessVS; PixelShader = p_usamp0; RenderTarget = t_usamp0; }
    pass { VertexShader = PostProcessVS; PixelShader = p_usamp1; RenderTarget = t_usamp1; }
    pass { VertexShader = PostProcessVS; PixelShader = p_usamp2; RenderTarget = t_usamp2; }
    pass { VertexShader = PostProcessVS; PixelShader = p_combine; SRGBWriteEnable = true; }
}