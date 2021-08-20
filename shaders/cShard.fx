
// Simple, crispy unsharp shader

uniform float uWeight <
    ui_type = "drag";
> = 8.0;

uniform bool uDebug <
    ui_type = "radio";
> = true;

#include "cFunctions.fxh"

texture2D r_color : COLOR;
sampler2D s_color { Texture = r_color; SRGBTexture = TRUE; };

float4 ps_shard(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET
{
    const float2 pSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float4 uOriginal = tex2D(s_color, uv);
    float4 uBlur;
    uBlur += tex2D(s_color, uv + float2(-0.5, +0.5) * pSize) * 0.25;
    uBlur += tex2D(s_color, uv + float2(+0.5, +0.5) * pSize) * 0.25;
    uBlur += tex2D(s_color, uv + float2(-0.5, -0.5) * pSize) * 0.25;
    uBlur += tex2D(s_color, uv + float2(+0.5, -0.5) * pSize) * 0.25;
	float4 uOutput = uOriginal + (uOriginal - uBlur) * uWeight;
	return (uDebug) ? (uOriginal - uBlur) * uWeight * 0.5 + 0.5 : uOutput;
}

technique cShard
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_shard;
        SRGBWriteEnable = TRUE;
    }
}
