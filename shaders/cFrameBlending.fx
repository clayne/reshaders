
/*
    Frame blending without blendops
*/

#include "cFunctions.fxh"

uniform float uBlend <
    ui_label = "Blend Factor"; ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.5;

texture2D r_previous { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
sampler2D s_previous { Texture = r_previous; SRGBTexture = TRUE; };

/* [Pixel Shaders] */

// Execute the blending first (the pframe will initially be 0)

float4 ps_blend(float4 vpos : SV_POSITION, float2 uv: TEXCOORD0) : SV_TARGET
{
    float4 cframe = tex2D(core::samplers::srgb, uv);
    float4 pframe = tex2D(s_previous, uv);
    return lerp(cframe, pframe, uBlend);
}

// Save the results generated from ps_blend() into a texture to use later

float4 ps_previous(float4 vpos : SV_POSITION, float2 uv: TEXCOORD0) : SV_TARGET
{
    return tex2D(core::samplers::srgb, uv);
}

technique cBlending
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_blend;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_previous;
        RenderTarget = r_previous;
        SRGBWriteEnable = TRUE;
    }
}
