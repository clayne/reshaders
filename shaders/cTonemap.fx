
/*
    Enables one of Watch Dogs' tonemapping algorithms. No tweaking values.
    Full credits to the ReShade team. Ported by Insomnia
    Change: use gamma conversion before and after processing
*/

#include "cFunctions.fxh"

float3 p_tone(float3 n)
{
    const float3 a = float3(0.55f, 0.50f, 0.45f); // Shoulder strength
    const float3 b = float3(0.30f, 0.27f, 0.22f); // Linear strength
    const float3 c = float3(0.10f, 0.10f, 0.10f); // Linear angle
    const float3 d = float3(0.10f, 0.07f, 0.03f); // Toe strength
    const float3 e = float3(0.01f, 0.01f, 0.01f); // Toe Numerator
    const float3 f = float3(0.30f, 0.30f, 0.30f); // Toe Denominator
    return mad(n,mad(a,n,c*b),d*e) / mad(n,mad(a,n,b),d*f) - (e/f);
}

float3 ps_tonemap(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_Target
{
    float3 kLinear = tex2D(core::samplers::srgb, uv).rgb;
    const float3 kWhitePoint = 1.0 / p_tone(float3(2.80f, 2.90f, 3.10f));
    kLinear = p_tone(kLinear) * 1.25 * kWhitePoint;
    return pow(abs(kLinear), 1.25);
}

technique cTonemap
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_tonemap;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
