
// From https://knarkowicz.wordpress.com/2016/01/09/automatic-exposure/

#include "cFunctions.fxh"

uniform float uIntensity <
    ui_type = "drag";
    ui_min = 0.0;
> = 1.0;

texture2D r_aluma
{
    Width = 256;
    Height = 256;
    Format = R32F;
    MipLevels = 9;
};

sampler2D s_aluma { Texture = r_aluma; };

// Get the average luminance for "every" pixel on the screen
// We lose a lot of information due to directly downscaling from native to 256x256

float4 ps_core(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0) : SV_TARGET
{
    float4 oColor = tex2D(core::samplers::srgb, uv);
    return max(max(oColor.r, oColor.g), oColor.b);
}

// Calculate exposure

float4 ps_expose(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_TARGET
{
    // Fetch 1x1 LOD from previous pass
    float avgLuma = tex2Dlod(s_aluma, float4(uv, 0.0, 99.0)).r;
    float4 oColor = tex2D(core::samplers::srgb, uv);

    float aExposure = log2(0.18) - log2(avgLuma);
    aExposure = exp2(aExposure);
    return oColor * aExposure;
}

technique cExposure
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_core;
        RenderTarget = r_aluma;
    }

    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_expose;
        SRGBWriteEnable = TRUE;
    }
}
