
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to MartinBFFan and Pao on Discord for reporting bugs
    And BSD for bug propaganda and helping to solve my issue
*/

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax)    \
        uniform udata option <                                                  \
        ui_category = ucategory; ui_label = ulabel;                             \
        ui_type = utype; ui_min = umin; ui_max = umax;                          \
        > = uvalue

uOption(uThreshold, float, "slider", "Basic",    "Threshold",   0.000, 0.000, 1.000);
uOption(uScale,     float, "slider", "Basic",    "Scale",       1.000, 0.000, 2.000);
uOption(uRadius,    float, "slider", "Basic",    "Prefilter",   2.000, 0.000, 4.000);

uOption(uSmooth, float, "slider", "Advanced", "Flow Smooth", 0.250, 0.000, 0.500);
uOption(uDetail, int,   "slider", "Advanced", "Flow Mip",    3, 0, 6);
uOption(uDebug,  bool,  "radio",  "Advanced", "Debug",       false, 0, 0);

#ifndef PREFILTER_BIAS
    #define PREFILTER_BIAS 0.0
#endif

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
#define RMAX(x, y)     x ^ ((x ^ y) & -(x < y)) // max(x, y)

#define DSIZE      uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE      LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1

texture2D r_color  : COLOR;
texture2D r_buffer { Width = DSIZE.x; Height = DSIZE.y; MipLevels = RSIZE; Format = R8; };
texture2D r_cflow  { Width = 64; Height = 64; Format = RG32F; MipLevels = 7; };
texture2D r_cframe { Width = 64; Height = 64; Format = R32F; };
texture2D r_pframe { Width = 64; Height = 64; Format = RGBA32F; MipLevels = 7; };

sampler2D s_color  { Texture = r_color;  SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; };
sampler2D s_cflow  { Texture = r_cflow;  };
sampler2D s_cframe { Texture = r_cframe; };
sampler2D s_pframe { Texture = r_pframe; };

/* [ Vertex Shaders ] */

struct v2f
{
    float4 vpos : SV_POSITION;
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

/*
    [ Pixel Shaders ]
    Cubic Filter - [https://github.com/haasn/libplacebo/blob/master/src/shaders/sampling.c] [GPL 2.1]
    Blur Average - [https://blog.demofox.org/2016/08/23/incremental-averaging/]
    Blur Center  - [http://john-chapman-graphics.blogspot.com/2013/01/per-object-motion-blur.html]
    Disk Kernels - [http://blog.marmakoide.org/?p=1.]
    Noise        - [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
    Optical Flow - [https://dspace.mit.edu/handle/1721.1/6337]
    Pi Constant  - [https://github.com/microsoft/DirectX-Graphics-Samples] [MIT]
    Threshold    - [https://github.com/diwi/PixelFlow] [MIT]
*/

static const float pi = 3.1415926535897932384626433832795;
static const float tpi = pi * 2.0;

float nrand(float2 n)
{
    const float3 value = float3(52.9829189, 0.06711056, 0.00583715);
    return frac(value.x * frac(dot(n.xy, value.yz)));
}

float2 Vogel2D(int uIndex, int nTaps, float2 uv)
{
    const float2 Size = exp2(-5.0) * uRadius;
    const float  GoldenAngle = pi * (3.0 - sqrt(5.0));
    const float2 Radius = (sqrt(uIndex + 0.5f) / sqrt(nTaps)) * Size;
    const float  Theta = uIndex * GoldenAngle;

    float2 SineCosine;
    sincos(Theta, SineCosine.x, SineCosine.y);
    return Radius * SineCosine.yx + uv;
}

float4 ps_source(v2f input) : SV_Target
{
    float4 uImage = tex2D(s_color, input.uv);
    float uLuma = max(max(uImage.r, uImage.g), uImage.b);
    return exp2(log2(uLuma) * rcp(2.2));
}

float4 ps_convert(v2f input) : SV_Target
{

    float4 uImage;
    const int uTaps = 32;

    [unroll]
    for (int i = 0; i < uTaps; i++)
    {
        float2 uv = Vogel2D(i, uTaps, input.uv);
        float4 uColor = tex2D(s_buffer, uv);
        uImage = lerp(uImage, uColor, rcp(i + 1));
    }

    float4 output;
    output.xy = tex2D(s_cflow, input.uv).rg; // Copy optical flow from previous ps_flow()
    output.z  = tex2D(s_cframe, input.uv).r; // Copy exposed frame from previous ps_filter()
    output.w  = uImage.r; // Input downsampled current frame to scale and mip
    return output;
}

float4 ps_copy(v2f input) : SV_Target
{
    float oColor = tex2D(s_pframe, input.uv).w;
    return max(abs(oColor), 1e-5);
}

float4 ps_flow(v2f input) : SV_Target
{
    // Calculate optical flow
    float cLuma = tex2D(s_cframe, input.uv).r;
    float pLuma = tex2D(s_pframe, input.uv).z;
    float2 dFdc = float2(ddx(cLuma), ddy(cLuma));
    float2 dFdp = float2(ddx(pLuma), ddy(pLuma));
    float dt = cLuma - pLuma;
    float dMag = (dot(dFdp, dFdc) + dt) / (dot(dFdp, dFdp) + 1e-5);
    float2 cFlow = dFdc - dFdp * dMag;

    // Threshold and normalize
    float pFlow = sqrt(dot(cFlow, cFlow) + 1e-5);
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

float4 flow2D(v2f input, float2 flow, float i)
{
    const float2 pSize = tex2Dsize(s_cflow, 0.0);
    flow /= pSize;
    float noise = nrand(input.vpos.xy);
    const float samples = 1.0 / (16.0 - 1.0);
    float2 calc = (noise * 2.0 + i) * samples - 0.5;
    return tex2D(s_color, (uScale * flow) * calc + input.uv);
}

float4 ps_output(v2f input) : SV_Target
{
    const float2 texsize = tex2Dsize(s_cflow, uDetail);
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
    float4 oBlur;

    [unroll]
    for(int i = 0; i < 9; i++)
    {
        float4 uColor = flow2D(input, oFlow, float(i * 2));
        oBlur = lerp(oBlur, uColor, rcp(i + 1));
    }

    return (uDebug) ? float4(oFlow, 0.0, 0.0) : oBlur;
}

technique cMotionBlur
{
    pass cBlur
    {
        VertexShader = vs_common;
        PixelShader = ps_source;
        RenderTarget0 = r_buffer;
    }

    pass cCopyPrevious
    {
        VertexShader = vs_common;
        PixelShader = ps_convert;
        RenderTarget0 = r_pframe;
    }

    pass cCopyFrame
    {
        VertexShader = vs_common;
        PixelShader = ps_copy;
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
