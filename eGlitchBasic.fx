
// KinoGlitch (basic) https://github.com/keijiro/Kino

#include "ReShade.fxh"

// NOTE: Process display-referred images into linear light, no matter the shader
sampler sLinear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };

static const uint _Seed = 0.0;

uniform float _Drift <
	ui_label = "Radius";
	ui_type = "drag";
> = 1.0;

uniform float _Jitter <
	ui_label = "Radius";
	ui_type = "drag";
> = 1.0;

uniform float _Jump <
	ui_label = "Radius";
	ui_type = "drag";
> = 1.0;

uniform float _Shake <
	ui_label = "Radius";
	ui_type = "drag";
> = 1.0;

uint Hash(uint s)
	s ^= s >> 16;
	s *= 2654435769u;
	return s;
}

struct vs_out { float4 vpos : SV_POSITION; float2 uv : TEXCOORD; };

float4 Fragment(vs_out op) : SV_Target
{
	const float2 _ScreenSize = BUFFER_SCREEN_SIZE;
	// Texture space position
	float tx = op.uv.x;
	float ty = op.y;

	// Jump
	ty = lerp(ty, frac(ty + _Jump.x), _Jump.y);

	// Screen space Y coordinate
	uint sy = ty * _ScreenSize.y;

	// Jitter
	float jitter = Hash(sy + _Seed) * 2 - 1;
	tx += jitter * (_Jitter.x < abs(jitter)) * _Jitter.y;

	// Shake
	tx = frac(tx + (Hash(_Seed) - 0.5) * _Shake);

	// Drift
	float drift = sin(ty * 2 + _Drift.x) * _Drift.y;

	// Source sample
	uint sx1 = (tx        ) * _ScreenSize.x;
	uint sx2 = (tx + drift) * _ScreenSize.x;
	float4 c1 = tex2D(sLinear, uint2(sx1, sy));
	float4 c2 = tex2D(sLinear, uint2(sx2, sy));
	float4 c = float4(c1.r, c2.g, c1.b, c1.a);

	return c;
}

technique KinoGlitch
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = Fragment;
		SRGBWriteEnable = true;
	}
}
