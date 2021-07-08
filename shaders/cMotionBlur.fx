
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to
    - MartinBFFan and Pao on Discord for reporting bugs
    - BSD for bug propaganda and helping to solve my issue
    - Lord of Lunacy, KingEric1992, and Marty McFly for power of 2 function

    Notes:  Blurred previous + current frames must be 32Float textures.
            This makes the optical flow not suffer from noise + banding

    Gaussian     - [https://github.com/SleepKiller/shaderpatch] [MIT]
    Noise        - [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
    Optical Flow - [https://dspace.mit.edu/handle/1721.1/6337]
    Pi Constant  - [https://github.com/microsoft/DirectX-Graphics-Samples] [MIT]
    Threshold    - [https://github.com/diwi/PixelFlow] [MIT]
*/

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax)    \
        uniform udata option <                                                  \
        ui_category = ucategory; ui_label = ulabel;                             \
        ui_type = utype; ui_min = umin; ui_max = umax;                          \
        > = uvalue

uOption(uThreshold, float, "slider", "Basic", "Threshold", 1.000, 0.000, 2.000);
uOption(uScale,     float, "slider", "Basic", "Scale",     2.000, 0.000, 4.000);
uOption(uRadius,    float, "slider", "Basic", "Prefilter", 4.000, 0.000, 8.000);

uOption(uSmooth, float, "slider", "Advanced", "Flow Smooth", 0.250, 0.000, 0.500);
uOption(uDetail, int,   "slider", "Advanced", "Flow Mip",    4, 1, 7);
uOption(uDebug,  bool,  "radio",  "Advanced", "Debug",       false, 0, 0);

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
texture2D r_buffer { Width = DSIZE.x; Height = DSIZE.y; MipLevels = RSIZE; Format = R8; };
texture2D r_cflow  { Width = ImageSize; Height = ImageSize; Format = RG32F; MipLevels = 8; };
texture2D r_cframe { Width = ImageSize; Height = ImageSize; Format = R32F; };
texture2D r_pframe { Width = ImageSize; Height = ImageSize; Format = RGBA32F; };

sampler2D s_color  { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; };
sampler2D s_cflow  { Texture = r_cflow;  };
sampler2D s_cframe { Texture = r_cframe; };
sampler2D s_pframe { Texture = r_pframe; };

/* [ Vertex Shaders ] */

void v2f_core(in uint id, inout float2 uv, out float4 vpos)
{
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

struct v2f
{
    float4 vpos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

v2f vs_common(const uint id : SV_VertexID)
{
    v2f output;
    v2f_core(id, output.uv, output.vpos);
    return output;
}

struct v2f_3x3
{
    float4 vpos : SV_Position;
    float4 ofs[2] : TEXCOORD0;
};

v2f_3x3 vs_3x3(const uint id : SV_VertexID)
{
    v2f_3x3 output;
    float2 uv;
    v2f_core(id, uv, output.vpos);

    const float2 usize = rcp(float2(BUFFER_WIDTH, BUFFER_HEIGHT));
    output.ofs[0].xy = uv + float2(-0.5,  0.5) * usize;
    output.ofs[0].zw = uv + float2( 0.5,  0.5) * usize;
    output.ofs[1].xy = uv + float2(-0.5, -0.5) * usize;
    output.ofs[1].zw = uv + float2( 0.5, -0.5) * usize;
    return output;
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

struct v2f_source
{
    float4 vpos : SV_Position;
    float2 uv : TEXCOORD0;
    float4 ofs[oNum] : TEXCOORD1;
};

v2f_source vs_source(const uint id : SV_VertexID)
{
    const float cLOD = log2(max(DSIZE.x, DSIZE.y)) - log2(ImageSize);
    const float2 uSize = rcp(DSIZE.xy / exp2(cLOD));

    v2f_source output;
    v2f_core(id, output.uv, output.vpos);

    for(int i = 0; i < oNum; i++)
    {
        output.ofs[i].xy = Vogel2D(i, output.uv, uSize);
        output.ofs[i].zw = Vogel2D(oNum + i, output.uv, uSize);
    }

    return output;
}

struct v2f_filter
{
    float4 vpos : SV_Position;
    float4 ofs[oNum] : TEXCOORD1;
};

v2f_filter vs_filter(const uint id : SV_VertexID)
{
    const float2 uSize = rcp(ImageSize);
    float2 uv;

    v2f_filter output;
    v2f_core(id, uv, output.vpos);

    for(int i = 0; i < oNum; i++)
    {
        output.ofs[i].xy = Vogel2D(i, uv, uSize);
        output.ofs[i].zw = Vogel2D(oNum + i, uv, uSize);
    }

    return output;
}

/* [ Pixel Shaders ] */

float4 ps_source(v2f_3x3 input) : SV_Target
{
    float4 uImage;
    uImage += tex2D(s_color, input.ofs[0].xy);
    uImage += tex2D(s_color, input.ofs[0].zw);
    uImage += tex2D(s_color, input.ofs[1].xy);
    uImage += tex2D(s_color, input.ofs[1].zw);
    uImage *= 0.25;
    float uLuma = max(max(uImage.r, uImage.g), uImage.b);
    return fwidth(uLuma);
}

float4 ps_convert(v2f_source input) : SV_Target
{
    float uImage;
    float2 vofs[14] =
    {
        input.ofs[0].xy,
        input.ofs[1].xy,
        input.ofs[2].xy,
        input.ofs[3].xy,
        input.ofs[4].xy,
        input.ofs[5].xy,
        input.ofs[6].xy,
        input.ofs[0].zw,
        input.ofs[1].zw,
        input.ofs[2].zw,
        input.ofs[3].zw,
        input.ofs[4].zw,
        input.ofs[5].zw,
        input.ofs[6].zw
    };

    [unroll]
    for (int i = 0; i < uTaps; i++)
    {
        float uColor = tex2D(s_buffer, vofs[i]).r;
        uImage = lerp(uImage, uColor, rcp(i + 1));
    }

    float4 output;
    output.xy = tex2D(s_cflow, input.uv).rg; // Copy previous rendertarget from ps_flow()
    output.z  = tex2D(s_cframe, input.uv).r; // Copy previous rendertarget from ps_filter()
    output.w  = uImage; // Input downsampled current frame to scale and mip
    return output;
}

float4 ps_filter(v2f_filter input) : SV_Target
{
    float uImage;
    float2 vofs[14] =
    {
        input.ofs[0].xy,
        input.ofs[1].xy,
        input.ofs[2].xy,
        input.ofs[3].xy,
        input.ofs[4].xy,
        input.ofs[5].xy,
        input.ofs[6].xy,
        input.ofs[0].zw,
        input.ofs[1].zw,
        input.ofs[2].zw,
        input.ofs[3].zw,
        input.ofs[4].zw,
        input.ofs[5].zw,
        input.ofs[6].zw
    };

    [unroll]
    for (int i = 0; i < uTaps; i++)
    {
        float uColor = tex2D(s_pframe, vofs[i]).w;
        uImage = lerp(uImage, uColor, rcp(i + 1));
    }

    return max(sqrt(uImage), Epsilon);
}

float4 ps_flow(v2f input) : SV_Target
{
    // Calculate optical flow
    float cLuma = tex2D(s_cframe, input.uv).r;
    float pLuma = tex2D(s_pframe, input.uv).z;
    float2 dFdc = float2(ddx(cLuma), ddy(cLuma));
    float2 dFdp = float2(ddx(pLuma), ddy(pLuma));
    float dt = cLuma - pLuma;
    float dBrightness = dot(dFdp, dFdc) + dt;
    float dSmoothness = dot(dFdp, dFdp) + Epsilon;
    float2 cFlow = dFdc - dFdp * (dBrightness / dSmoothness);

    // Threshold and normalize
    float pFlow = sqrt(dot(cFlow, cFlow) + Epsilon);
    float nFlow = max(pFlow - uThreshold, 0.0);
    cFlow *= nFlow / pFlow;

    // Smooth optical flow
    float2 sFlow = tex2D(s_pframe, input.uv).xy;
    return lerp(cFlow, sFlow, uSmooth).xyxy;
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
    t.xy += float2(s, -s);
    return t;
}

float4 ps_output(v2f input) : SV_Target
{
    const float2 texsize = ldexp(ImageSize, -uDetail);
    const float2 pt = 1.0 / texsize;
    float2 fcoord = frac(input.uv * texsize + 0.5);
    float4 parmx = calcweights(fcoord.x);
    float4 parmy = calcweights(fcoord.y);
    float4 cdelta;
    cdelta.xzyw = float4(parmx.rg, parmy.rg) * float4(-pt.x, pt.x, -pt.y, pt.y);
    // first y-interpolation
    float2 ar = tex2Dlod(s_cflow, float4(input.uv + cdelta.xy, 0.0, uDetail)).rg;
    float2 ag = tex2Dlod(s_cflow, float4(input.uv + cdelta.xw, 0.0, uDetail)).rg;
    float2 ab = lerp(ag, ar, parmy.b);
    // second y-interpolation
    float2 br = tex2Dlod(s_cflow, float4(input.uv + cdelta.zy, 0.0, uDetail)).rg;
    float2 bg = tex2Dlod(s_cflow, float4(input.uv + cdelta.zw, 0.0, uDetail)).rg;
    float2 aa = lerp(bg, br, parmy.b);
    // x-interpolation
    float2 oFlow = lerp(aa, ab, parmx.b);
    oFlow /= ImageSize;
    oFlow *= uScale;

    float4 oBlur;
    const float4 value = float4(52.9829189, 0.06711056, 0.00583715, 2.0);
    float noise = frac(value.x * frac(dot(input.vpos.xy, value.yz))) * value.w;
    const float samples = 1.0 / (16.0 - 1.0);

    [unroll]
    for(int i = 0; i < 9; i++)
    {
        float2 calc = (noise + i * 2.0) * samples - 0.5;
        float4 uColor = tex2D(s_color, oFlow * calc + input.uv);
        oBlur = lerp(oBlur, uColor, rcp(i + 1));
    }

    return (uDebug) ? float4(oFlow, 0.0, 0.0) : oBlur;
}

technique cMotionBlur
{
    pass cBlur
    {
        VertexShader = vs_3x3;
        PixelShader = ps_source;
        RenderTarget0 = r_buffer;
    }

    pass cCopyPrevious
    {
        VertexShader = vs_source;
        PixelShader = ps_convert;
        RenderTarget0 = r_pframe;
    }

    pass cBlurCopyFrame
    {
        VertexShader = vs_filter;
        PixelShader = ps_filter;
        RenderTarget0 = r_cframe;
    }

    pass cOpticalFlow
    {
        VertexShader = vs_common;
        PixelShader = ps_flow;
        RenderTarget0 = r_cflow;
    }

    pass cFlowBlur
    {
        VertexShader = vs_common;
        PixelShader = ps_output;
        SRGBWriteEnable = TRUE;
    }
}
