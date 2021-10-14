
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

uniform float _LOD <
    ui_min = 0.0;
    ui_max = RMIPS;
    ui_label = "MipLevel";
    ui_type = "slider";
> = 0.0;

uniform float _Weight <
    ui_min = 0.0;
    ui_label = "Intensity";
    ui_type = "drag";
> = 8.0;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

texture2D _RenderLOD  < pooled = false; >
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    MipLevels = RMIPS;
    Format = RGBA8;
};

sampler2D _SampleLOD
{
    Texture = _RenderLOD;
    SRGBTexture = TRUE;
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

float4 MipMapPS(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET0
{
    return tex2D(_SampleColor, uv);
}

float4 OutputPS(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET0
{
    float4 Gaussian1 = tex2Dlod(_SampleLOD, float4(uv, 0.0, _LOD));
    float4 Gaussian2 = tex2Dlod(_SampleLOD, float4(uv, 0.0, _LOD + 1.0));
    return ((Gaussian2 - Gaussian1) * _Weight) * 0.5 + 0.5;
}
technique cDifference
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = MipMapPS;
        RenderTarget0 = _RenderLOD;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OutputPS;
        SRGBWriteEnable = TRUE;
    }
}
