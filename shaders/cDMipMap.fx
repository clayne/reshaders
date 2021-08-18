
/*
    Ghetto difference of gaussian using mipmaps lol
*/

#include "cFunctions.fxh"

#define DSIZE uint2(BUFFER_WIDTH, BUFFER_HEIGHT)
#define RMIPS LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1

uniform float uLod <
    ui_min = 0.0;
    ui_max = RMIPS;
    ui_label = "MipLevel";
    ui_type = "slider";
> = 0.0;

uniform float uWeight <
    ui_min = 0.0;
    ui_label = "Intensity";
    ui_type = "drag";
> = 8.0;

texture2D r_color : COLOR;

texture2D r_mipmaps
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    MipLevels = RMIPS;
    Format = RGB10A2;
};

sampler2D s_color
{
    Texture = r_color;
    SRGBTexture = TRUE;
};

sampler2D s_mipmaps
{
    Texture = r_mipmaps;
};

float4 ps_init(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET0
{
    return tex2D(s_color, uv);
}

float4 ps_output(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET0
{
    float4 g1 = tex2Dlod(s_mipmaps, float4(uv, 0.0, uLod));
    float4 g2 = tex2Dlod(s_mipmaps, float4(uv, 0.0, uLod + 1.0));
    return ((g2 - g1) * uWeight) * 0.5 + 0.5;
}
technique cDMipMap
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_init;
        RenderTarget0 = r_mipmaps;
    }

    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_output;
        SRGBWriteEnable = TRUE;
    }
}
