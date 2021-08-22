
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

texture2D r_mips
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    MipLevels = LOG2(RMAX(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)) + 1;
    Format = R16F;
};

texture2D r_factor
{
    Width = 1;
    Height = 1;
    Format = R16F;
};

sampler2D s_color
{
    Texture = r_color;
    SRGBTexture = TRUE;
};

sampler2D s_mips
{
    Texture = r_mips;
};

sampler2D s_factor
{
    Texture = r_factor;
};

float4 ps_init(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_Target0
{
    float4 color = tex2D(s_color, uv);
    return max(color.r, max(color.g, color.b));
}

float4 ps_blit(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_Target0
{
    return float4(tex2D(s_mips, uv).rgb, uRate);
}

float4 ps_expose(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET0
{
    float aLuma = tex2D(s_factor, uv).r;
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
        PixelShader = ps_init;
        RenderTarget = r_mips;
    }

    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_blit;
        RenderTarget = r_factor;
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
