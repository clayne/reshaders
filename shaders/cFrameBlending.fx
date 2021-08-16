
/*
    Frame blending without blendops
*/

#include "cFunctions.fxh"

uniform float uBlend <
    ui_label = "Blend Factor"; ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.5;

texture2D r_color  : COLOR;
texture2D r_pimage { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };

sampler2D s_color  { Texture = r_color;  SRGBTexture = TRUE; };
sampler2D s_pimage { Texture = r_pimage; SRGBTexture = TRUE; };

/* [Pixel Shaders] */

// Execute the blending first (the pframe will initially be 0)

float4 ps_blend(float4 vpos : SV_POSITION, float2 uv: TEXCOORD0) : SV_TARGET
{
    float4 cframe = tex2D(s_color, uv);
    float4 pframe = tex2D(s_pimage, uv);
    return lerp(cframe, pframe, uBlend);
}

// Save the results generated from ps_blend() into a texture to use later

float4 ps_pimage(float4 vpos : SV_POSITION, float2 uv: TEXCOORD0) : SV_TARGET
{
    return tex2D(s_color, uv);
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
        PixelShader = ps_pimage;
        RenderTarget = r_pimage;
        SRGBWriteEnable = TRUE;
    }
}
