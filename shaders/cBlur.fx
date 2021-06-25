
/*
    Unlimited 16-Tap blur using mipmaps
    Based on https://github.com/spite/Wagner/blob/master/fragment-shaders/box-blur-fs.glsl [MIT]
    and [http://blog.marmakoide.org/?p=1.]
    Special Thanks to BlueSkyDefender for help and patience
*/

uniform float kRadius <
    ui_label = "Radius";
    ui_type = "slider";
    ui_max = 512.0;
    ui_min = 0.001;
> = 0.1;

/*
    Round to nearest power of 2
    Help from Lord of Lunacy, KingEric1992, and Marty McFly
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

#define RMAX(x, y) x ^ ((x ^ y) & -(x < y)) // max(x, y)
#define DSIZE      1 << LOG2(RMAX(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2))

texture2D r_color : COLOR;
texture2D r_blur { Width = DSIZE; Height = DSIZE; Format = RGB10A2; MipLevels = LOG2(DSIZE) + 1; };

sampler2D s_color { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_blur  { Texture = r_blur; AddressU = MIRROR; AddressV = MIRROR; };

struct v2f
{
    float4 vpos : SV_Position;
    float2 uv : TEXCOORD0;
};

v2f vs_common(const uint id : SV_VertexID)
{
    v2f output;
    output.uv.x = (id == 2) ? 2.0 : 0.0;
    output.uv.y = (id == 1) ? 2.0 : 0.0;
    output.vpos = float4(output.uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return output;
}

static const float pi = 3.1415926535897932384626433832795;
static const float tpi = pi * 2.0;

float nrand(float2 n)
{
    const float3 value = float3(52.9829189, 0.06711056, 0.00583715);
    return frac(value.x * frac(dot(n.xy, value.yz)));
}

float2 Vogel2D(int uIndex, int nTaps, float phi)
{
    const float GoldenAngle = pi * (3.0 - sqrt(5.0));
    const float r = sqrt(uIndex + 0.5f) / sqrt(nTaps);
    float theta = uIndex * GoldenAngle + phi;

    float2 sc;
    sincos(theta, sc.x, sc.y);
    return r * sc.yx;
}

float mod2D(float x, float y) { return x - y * floor(x / y); }

float4 ps_blur(v2f input) : SV_TARGET
{
	const int uTaps = 16;
    float uBoard = mod2D(dot(input.vpos.xy, 1.0), 2.0);
    const float2 ps = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * kRadius;
    float urand = nrand(input.vpos.xy * uBoard) * tpi;
    float4 uImage;

    [unroll]
    for (int i = 0; i < uTaps; i++)
    {
        float2 ofs = Vogel2D(i, uTaps, urand);
        float2 uv = input.uv + ofs * ps;
        float4 uColor = tex2D(s_color, uv);
        uImage = lerp(uImage, uColor, rcp(i + 1));
    }

    return uImage;
}

float4 calcweights(float s)
{
    const float4 w1 = float4(-0.5, 0.1666, 0.3333, -0.3333);
    const float4 w2 = float4( 1.0, 0.0, -0.5, 0.5);
    const float4 w3 = float4(-0.6666, 0.0, 0.8333, 0.1666);
    float4 t = mad(w1, s, w2);
    t = mad(t, s, w2.yyzw);
    t = mad(t, s, w3);
    t.xy = mad(t.xy, rcp(t.zw), 1.0);
    t.x += s;
    t.y -= s;
    return t;
}

float4 ps_smooth(v2f input) : SV_TARGET
{

    const float kPi = 3.14159265359f;
    float area   = kPi * (kRadius * kRadius);
          area   = area / 12; // area per sample
    float lod    = ceil(log2(sqrt(area)))-1; // select mip level with similar area to the sample

    float2 texsize = tex2Dsize(s_blur, lod);
    float2 pt = 1.0 / texsize;
    float2 fcoord = frac(input.uv * texsize + 0.5);
    float4 parmx = calcweights(fcoord.x);
    float4 parmy = calcweights(fcoord.y);
    float4 cdelta;
    cdelta.xz = parmx.rg * float2(-pt.x, pt.x);
    cdelta.yw = parmy.rg * float2(-pt.y, pt.y);
    // first y-interpolation
    float4 ar = tex2Dlod(s_blur, float4(input.uv + cdelta.xy, 0.0, lod));
    float4 ag = tex2Dlod(s_blur, float4(input.uv + cdelta.xw, 0.0, lod));
    float4 ab = lerp(ag, ar, parmy.b);
    // second y-interpolation
    float4 br = tex2Dlod(s_blur, float4(input.uv + cdelta.zy, 0.0, lod));
    float4 bg = tex2Dlod(s_blur, float4(input.uv + cdelta.zw, 0.0, lod));
    float4 aa = lerp(bg, br, parmy.b);
    // x-interpolation
    return lerp(aa, ab, parmx.b);
}

technique cBlur
{
    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_blur;
        RenderTarget = r_blur;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_smooth;
        SRGBWriteEnable = TRUE;
    }
}
