
#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax)    \
        uniform udata option <                                                  \
        ui_category = ucategory; ui_label = ulabel;                             \
        ui_type = utype; ui_min = umin; ui_max = umax;                          \
        > = uvalue

uOption(uRadius, float, "slider", "Basic", "Blur Radius", 8.000, 0.000, 16.00);

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

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1

static const float ImageSize = 128.0;
static const int uTaps = 16;

texture2D r_color  : COLOR;

texture2D r_image
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    MipLevels = RSIZE;
    Format = RGBA8;
};

texture2D r_blur
{
    Width = ImageSize;
    Height = ImageSize;
    Format = RGBA8;
    MipLevels = 8;
};

sampler2D s_color
{
    Texture = r_color;
    SRGBTexture = TRUE;
};

sampler2D s_image
{
    Texture = r_image;
    SRGBTexture = TRUE;
};

sampler2D s_blur
{
    Texture = r_blur;
    SRGBTexture = TRUE;
};

/* [ Vertex Shaders ] */

void vsinit(in uint id,
            inout float2 uv : TEXCOORD0,
            inout float4 vpos : SV_POSITION)
{
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void vs_3x3(in uint id : SV_VERTEXID,
            inout float4 vpos : SV_POSITION,
            inout float4 ofs[2] : TEXCOORD0)
{
    float2 uv;
    vsinit(id, uv, vpos);
    ofs[0].xy = uv + float2(-1.0,  1.0) * float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    ofs[0].zw = uv + float2( 1.0,  1.0) * float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    ofs[1].xy = uv + float2(-1.0, -1.0) * float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    ofs[1].zw = uv + float2( 1.0, -1.0) * float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
}

float pi() { return 3.1415926535897f; }

float computelod(float2 imagesize, float2 rendersize)
{
    const float tsize = log2(max(imagesize.x, imagesize.y));
    const float rsize = log2(max(rendersize.x, rendersize.y));
    return tsize - rsize;
}

float2 computelodtexel(float2 imagesize, float2 rendersize)
{
    const float ulod = computelod(imagesize, rendersize);
    return 1.0 / (imagesize / exp2(ulod));
}

float  fsqrt(float c)  { return c * rsqrt(c); }
float2 fsqrt(float2 c) { return c * rsqrt(c); }
float3 fsqrt(float3 c) { return c * rsqrt(c); }
float4 fsqrt(float4 c) { return c * rsqrt(c); }

float2 vogel(int uIndex, float2 pSize, int uTaps)
{
    const float  GoldenAngle = pi() * (3.0 - sqrt(5.0));
    const float2 Radius = (sqrt(uIndex + 0.5f) / sqrt(uTaps)) * pSize;
    const float  Theta = uIndex * GoldenAngle;

    float2 SineCosine;
    sincos(Theta, SineCosine.x, SineCosine.y);
    return Radius * SineCosine.yx;
}

static const int oNum = 8;

void vs_source( in uint id : SV_VERTEXID,
                inout float4 vpos : SV_POSITION,
                inout float4 ofs[oNum] : TEXCOORD0)
{
    float2 uv;
    vsinit(id, uv, vpos);
    const float2 uSize = computelodtexel(DSIZE, ImageSize) * uRadius;

    for(int i = 0; i < oNum; i++)
    {
        ofs[i].xy = uv + vogel(i, uSize, uTaps);
        ofs[i].zw = uv + vogel(i, uSize, uTaps);
    }
}

void vs_filter( in uint id : SV_VERTEXID,
                inout float4 vpos : SV_POSITION,
                inout float4 ofs[oNum] : TEXCOORD0)
{
    float2 uv;
    vsinit(id, uv, vpos);
    const float2 uSize = rcp(ImageSize) * uRadius;

    for(int i = 0; i < oNum; i++)
    {
        ofs[i].xy = uv + vogel(i, uSize, uTaps);
        ofs[i].zw = uv + vogel(i, uSize, uTaps);
    }
}

/* [ Pixel Shaders ] */

float urand(float2 vpos)
{
    const float3 value = float3(52.9829189, 0.06711056, 0.00583715);
    return frac(value.x * frac(dot(vpos.xy, value.yz)));
}

float4 ps_source(float4 vpos : SV_POSITION, float4 uv[2] : TEXCOORD0) : SV_Target
{
    float4 uImage;
    uImage += tex2D(s_color, uv[0].xy);
    uImage += tex2D(s_color, uv[0].zw);
    uImage += tex2D(s_color, uv[1].xy);
    uImage += tex2D(s_color, uv[1].zw);
    uImage *= 0.25;
    return uImage;
}

float4 ps_convert(float4 vpos : SV_POSITION, float4 ofs[oNum] : TEXCOORD0) : SV_Target
{
    float4 uImage;
    float2 vofs[uTaps];

    for (int i = 0; i < oNum; i++)
    {
        vofs[i] = ofs[i].xy;
        vofs[i + oNum] = ofs[i].zw;
    }

    for (int j = 0; j < uTaps; j++)
    {
        float4 uColor = tex2D(s_image, vofs[j]);
        uImage = lerp(uImage, uColor, rcp(float(j) + 1));
    }

    return uImage;
}

float4 ps_filter(float4 vpos : SV_POSITION, float4 ofs[oNum] : TEXCOORD0) : SV_Target
{
    const float uArea = pi() * (uRadius * uRadius) / uTaps;
    const float uBias = log2(sqrt(uArea));

    float4 uImage;
    float2 vofs[uTaps];

    for (int i = 0; i < oNum; i++)
    {
        vofs[i] = ofs[i].xy;
        vofs[i + oNum] = ofs[i].zw;
    }

    for (int j = 0; j < uTaps; j++)
    {
        float4 uColor = tex2Dlod(s_blur, float4(vofs[j], 0.0, uBias));
        uImage = lerp(uImage, uColor, rcp(float(j) + 1));
    }

    return uImage + urand(vpos.xy) / 255.0;
}

technique cBlur
{
    pass
    {
        VertexShader = vs_3x3;
        PixelShader = ps_source;
        RenderTarget0 = r_image;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = vs_source;
        PixelShader = ps_convert;
        RenderTarget0 = r_blur;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = vs_filter;
        PixelShader = ps_filter;
        SRGBWriteEnable = TRUE;
    }
}
