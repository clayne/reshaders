
/*
    Ghetto difference of gaussian using mipmaps lol
*/

#define CONST_LOG2(x) (\
    (uint((x)  & 0xAAAAAAAA) != 0) | \
    (uint(((x) & 0xFFFF0000) != 0) << 4) | \
    (uint(((x) & 0xFF00FF00) != 0) << 3) | \
    (uint(((x) & 0xF0F0F0F0) != 0) << 2) | \
    (uint(((x) & 0xCCCCCCCC) != 0) << 1))

#define BIT2_LOG2(x)  ((x) | (x) >> 1)
#define BIT4_LOG2(x)  (BIT2_LOG2(x) | BIT2_LOG2(x) >> 2)
#define BIT8_LOG2(x)  (BIT4_LOG2(x) | BIT4_LOG2(x) >> 4)
#define BIT16_LOG2(x) (BIT8_LOG2(x) | BIT8_LOG2(x) >> 8)
#define LOG2(x)       (CONST_LOG2((BIT16_LOG2(x) >> 1) + 1))
#define RMAX(x, y)     x ^ ((x ^ y) & -(x < y)) // max(x, y)

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

void vs_generic(in uint id : SV_VERTEXID,
                inout float2 uv : TEXCOORD0,
                inout float4 vpos : SV_POSITION)
{
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

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
