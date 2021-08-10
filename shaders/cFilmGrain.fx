
/*
    "Well ill believe it when i see it."
    Yoinked code by Luluco250 (RIP) [https://www.shadertoy.com/view/4t2fRz] [MIT]
*/

#include "cFunctions.fxh"

uniform float uSpeed <
    ui_label = "Speed";
    ui_type = "drag";
> = 2.0f;

uniform float uVariance <
    ui_label = "Variance";
    ui_type = "drag";
> = 0.5f;

uniform float uIntensity <
    ui_label = "Variance";
    ui_type = "drag";
> = 0.005f;

uniform float uTimer < source = "timer"; >;

struct v2f
{
	float4 vpos : SV_Position;
	float2 uv   : TEXCOORD0;
};

float gaussian(float x, float sigma)
{
    const float pi = 3.14159265359;
    const float cSigma = sigma * sigma;
    return rsqrt(pi * cSigma) * exp(-((x * x) / (2.0 * cSigma)));
}

float4 ps_vignette(v2f input) : SV_Target
{
    const float2 psize = core::getpixelsize();
    float cTime = rcp(1e+3 / uTimer) * uSpeed;
    float cSeed = dot(input.vpos.xy, float2(12.9898, 78.233));
    float noise = frac(sin(cSeed) * 43758.5453 + cTime);
	return gaussian(noise, uVariance) * uIntensity;
}

technique cGrain
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_vignette;
        SRGBWriteEnable = TRUE;
        // (Shader[Src] * SrcBlend) + (Buffer[Dest] * DestBlend)
        // This shader: (Shader[Src] * (1.0 - Buffer[Dest])) + Buffer[Dest]
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVDESTCOLOR;
        DestBlend = ONE;
    }
}
