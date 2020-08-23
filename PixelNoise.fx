
// A mash of https://www.shadertoy.com/view/4djSRW and https://www.shadertoy.com/view/XsVBDR

#include "ReShade.fxh"

uniform float blurRadius <
    ui_label = "Radius";
    ui_type = "drag";
> = 1.0;

uniform float blurSeed <
    ui_label = "Seed";
    ui_type = "drag";
> = 1.0;

// NOTE: Process display-referred images into linear light, no matter the shader
sampler sLinear { Texture = ReShade::BackBufferTex; SRGBTexture = true; };

struct vs_out { float4 vpos : SV_POSITION; float2 uv : TEXCOORD; };

float2 hash23(float3 p3)
{
    p3 = frac(p3 * float3(443.897, 441.423, .0973));
    p3 += dot(p3, p3.yzx+19.19);
    return frac((p3.xx+p3.yz)*p3.zy);
}

float3 PS_Noise(vs_out op) : SV_Target
{
    float2 r = hash23(float3(op.uv, blurSeed));
    r.x*=6.28305308;

    // uniform sample the circle
    float2 cr = float2(sin(r.x),cos(r.x))*sqrt(r.y);

    return tex2D(sLinear, op.uv + cr * (blurRadius/ReShade::ScreenSize)).rgb;
}

technique OneDotRead
{
    pass { VertexShader = PostProcessVS; PixelShader = PS_Noise; SRGBWriteEnable = true; }
}
