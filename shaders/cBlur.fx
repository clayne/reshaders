
/*
    Vogel Disk  - [http://blog.marmakoide.org/?p=1s]
    LOD Compute - [https://john-chapman.github.io/2019/03/29/convolution.html]
    Pi Constant - [https://github.com/microsoft/DirectX-Graphics-Samples] [MIT]
*/

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

static const float Pi = 3.1415926535897f;
static const float Epsilon = 1e-7;
static const float ImageSize = 128.0;
static const int uTaps = 14;

texture2D r_color  : COLOR;
texture2D r_image { Width = DSIZE.x; Height = DSIZE.y; MipLevels = RSIZE; Format = RGBA8; };
texture2D r_blur  { Width = ImageSize; Height = ImageSize; Format = RGBA8; MipLevels = 8; };

sampler2D s_color { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_image { Texture = r_image; SRGBTexture = TRUE; };
sampler2D s_blur  { Texture = r_blur;  SRGBTexture = TRUE; };

/* [ Vertex Shaders ] */

void v2f_core(  in uint id,
                inout float2 uv,
                inout float4 vpos)
{
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void vs_common( in uint id : SV_VERTEXID,
                inout float4 vpos : SV_POSITION,
                inout float2 uv : TEXCOORD0)
{
    v2f_core(id, uv, vpos);
}

void vs_3x3(in uint id : SV_VERTEXID,
            inout float4 vpos : SV_POSITION,
            inout float4 ofs[2] : TEXCOORD0)
{
    float2 uv;
    v2f_core(id, uv, vpos);
    const float2 usize = rcp(float2(BUFFER_WIDTH, BUFFER_HEIGHT));
    ofs[0].xy = uv + float2(-1.0,  1.0) * usize;
    ofs[0].zw = uv + float2( 1.0,  1.0) * usize;
    ofs[1].xy = uv + float2(-1.0, -1.0) * usize;
    ofs[1].zw = uv + float2( 1.0, -1.0) * usize;
}

static const int oNum = 7;

float2 Vogel2D(int uIndex, float2 uv, float2 pSize)
{
    const float2 Size = pSize * uRadius;
    const float  GoldenAngle = Pi * (3.0 - sqrt(5.0));
    const float2 Radius = (sqrt(uIndex + 0.5f) / sqrt(uTaps)) * Size;
    const float  Theta = uIndex * GoldenAngle;

    float2 SineCosine;
    sincos(Theta, SineCosine.x, SineCosine.y);
    return Radius * SineCosine.yx + uv;
}

void vs_source( in uint id : SV_VERTEXID,
                inout float4 vpos : SV_POSITION,
                inout float4 ofs[oNum] : TEXCOORD0)
{
    const float cLOD = log2(max(DSIZE.x, DSIZE.y)) - log2(ImageSize);
    const float2 uSize = rcp(DSIZE.xy / exp2(cLOD));
    float2 uv;
    v2f_core(id, uv, vpos);

    for(int i = 0; i < oNum; i++)
    {
        ofs[i].xy = Vogel2D(i, uv, uSize);
        ofs[i].zw = Vogel2D(oNum + i, uv, uSize);
    }
}

void vs_filter( in uint id : SV_VERTEXID,
                inout float4 vpos : SV_POSITION,
                inout float4 ofs[oNum] : TEXCOORD0)
{
    const float2 uSize = rcp(ImageSize);
    float2 uv;
    v2f_core(id, uv, vpos);

    for(int i = 0; i < oNum; i++)
    {
        ofs[i].xy = Vogel2D(i, uv, uSize);
        ofs[i].zw = Vogel2D(oNum + i, uv, uSize);
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

float4 ps_convert(float4 vpos : SV_POSITION, float4 ofs[7] : TEXCOORD0) : SV_Target
{
    float4 uImage;
    float2 vofs[14];

    for (int i = 0; i < 7; i++)
    {
        vofs[i] = ofs[i].xy;
        vofs[i + 7] = ofs[i].zw;
    }

    for (int j = 0; j < uTaps; j++)
    {
        float4 uColor = tex2D(s_image, vofs[j]);
        uImage = lerp(uImage, uColor, rcp(float(j) + 1));
    }

    return uImage;
}

float4 ps_filter(float4 vpos : SV_POSITION, float4 ofs[7] : TEXCOORD0) : SV_Target
{
    const float uArea = Pi * (uRadius * uRadius) / uTaps;
    const float uBias = log2(sqrt(uArea));

    float4 uImage;
    float2 vofs[14];

    for (int i = 0; i < 7; i++)
    {
        vofs[i] = ofs[i].xy;
        vofs[i + 7] = ofs[i].zw;
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
