
/*
    Adaptive, temporal exposure by Brimson
    Based on https://john-chapman.github.io/2017/08/23/dynamic-local-exposure.html
    THIS EFFECT IS DEDICATED TO THE BRAVE SHADER DEVELOPERS OF RESHADE
*/

#include "cFunctions.fxh"

uniform float uRate <
    ui_label = "Smoothing";
    ui_type = "drag";
    ui_tooltip = "Exposure time smoothing";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.95;

uniform float uBias <
    ui_label = "Exposure";
    ui_type = "drag";
    ui_tooltip = "Optional manual bias ";
    ui_min = 0.0;
> = 0.0;

texture2D r_color : COLOR;

texture2D r_luma
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    MipLevels = LOG2(RMAX(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)) + 1;
    Format = R16F;
};

sampler2D s_color
{
    Texture = r_color;
    SRGBTexture = TRUE;
};

sampler2D s_luma
{
    Texture = r_luma;
};

float4 ps_blit(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_Target0
{
    float4 color = tex2D(s_color, uv);
    return float4(max(color.r, max(color.g, color.b)).rrr, uRate);
}

float4 ps_expose(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET0
{
	const float lod = ceil(log2(max(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)));
    float aLuma = tex2Dlod(s_luma, float4(uv, 0.0, lod)).r;
    float4 oColor = tex2D(s_color, uv);

    float ev100 = log2(aLuma * 100.0) - log2(12.5);
    ev100 -= uBias;
    ev100 = 1.0 / (1.2 * exp2(ev100));
    return oColor * ev100;
}

technique cAutoExposure
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_luma;
        RenderTarget = r_luma;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
    }

    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_expose;
        SRGBWriteEnable = TRUE;
    }
}
