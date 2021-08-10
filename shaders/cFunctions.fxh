
// Special thanks to Lord of Lunacy, KingEric1992, and Marty McFly for power of 2 function

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

/*
    noise() - [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
*/

namespace core
{
    float getaspectratio() { return BUFFER_WIDTH * BUFFER_RCP_HEIGHT; }
	float2 getpixelsize()  { return float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT); }
	float2 getscreensize() { return float2(BUFFER_WIDTH, BUFFER_HEIGHT); }

    texture2D r_color : COLOR;

    namespace samplers
    {
        sampler2D srgb { Texture = r_color; SRGBTexture = TRUE; };
        sampler2D color { Texture = r_color; SRGBTexture = FALSE; };
    }

    void vsinit(in uint id,
                inout float2 uv,
                inout float4 vpos)
    {
        uv.x = (id == 2) ? 2.0 : 0.0;
        uv.y = (id == 1) ? 2.0 : 0.0;
        vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    }

    float noise(float2 vpos)
    {
        const float3 n = float3(0.06711056, 0.00583715, 52.9829189);
        return frac(n.z * frac(dot(vpos.xy, n.xy)));
    }
}

void vs_generic(in uint id : SV_VERTEXID,
                inout float4 vpos : SV_POSITION,
                inout float2 uv : TEXCOORD0)
{
    core::vsinit(id, uv, vpos);
}

/*
    computelod() - [https://john-chapman.github.io/2019/03/29/convolution.html]
    median()     - [https://github.com/GPUOpen-Effects/FidelityFX-CAS] [MIT]
    vogel()      - [http://blog.marmakoide.org/?p=1s]
    pi()         - [https://github.com/microsoft/DirectX-Graphics-Samples] [MIT]
*/

namespace math
{
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

    float2 vogel(int uIndex, float2 uv, float2 pSize, int uTaps)
    {
        const float  GoldenAngle = pi() * (3.0 - sqrt(5.0));
        const float2 Radius = (sqrt(uIndex + 0.5f) / sqrt(uTaps)) * pSize;
        const float  Theta = uIndex * GoldenAngle;

        float2 SineCosine;
        sincos(Theta, SineCosine.x, SineCosine.y);
        return Radius * SineCosine.yx + uv;
    }

    float min3(float3 c) { return min(c.r, min(c.g, c.b)); }
    float max3(float3 c) { return max(c.r, max(c.g, c.b)); }

    float median(float a, float b, float c)
    {
        return max(min(a, b), min(max(a, b), c));
    }

    float2 median(float2 a, float2 b, float2 c)
    {
        return max(min(a, b), min(max(a, b), c));
    }

    float3 median(float3 a, float3 b, float3 c)
    {
        return max(min(a, b), min(max(a, b), c));
    }

    float4 median(float4 a, float4 b, float4 c)
    {
        return max(min(a, b), min(max(a, b), c));
    }
}

/*
    Encode and decode normal - [https://aras-p.info/texts/CompactNormalStorage.html]
*/

namespace cv
{
    float2 encodenorm(float3 n)
    {
        float f = rsqrt(8.0 * n.z + 8.0);
        return n.xy * f + 0.5;
    }

    float3 decodenorm(float2 enc)
    {
        float2 fenc = enc * 4.0 - 2.0;
        float f = dot(fenc, fenc);
        float g = sqrt(1.0 - f / 4.0);
        float3 n;
        n.xy = fenc * g;
        n.z = 1.0 - f / 2.0;
        return n;
    }
}
