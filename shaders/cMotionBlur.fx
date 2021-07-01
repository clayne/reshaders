
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to
    - MartinBFFan and Pao on Discord for reporting bugs
    - BSD for bug propaganda and helping to solve my issue
    - Lord of Lunacy, KingEric1992, and Marty McFly for power of 2 function

    Notes:  Blurred previous + current frames must be 32Float textures.
            This makes the optical flow not suffer from noise + banding
*/

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax)    \
        uniform udata option <                                                  \
        ui_category = ucategory; ui_label = ulabel;                             \
        ui_type = utype; ui_min = umin; ui_max = umax;                          \
        > = uvalue

uOption(uThreshold, float, "slider", "Basic", "Threshold", 0.000, 0.500, 1.000);
uOption(uScale,     float, "slider", "Basic", "Scale",     1.000, 0.000, 2.000);
uOption(uRadius,    float, "slider", "Basic", "Prefilter", 2.000, 0.000, 4.000);

uOption(uSmooth, float, "slider", "Advanced", "Flow Smooth", 0.250, 0.000, 0.500);
uOption(uDetail, int,   "slider", "Advanced", "Flow Mip",    3, 0, 6);
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

texture2D r_color  : COLOR;
texture2D r_buffer { Width = DSIZE.x; Height = DSIZE.y; MipLevels = RSIZE; Format = R8; };
texture2D r_cflow  { Width = 64; Height = 64; Format = RG32F; MipLevels = 7; };
texture2D r_cframe { Width = 64; Height = 64; Format = R32F; };
texture2D r_pframe { Width = 64; Height = 64; Format = RGBA32F; };

sampler2D s_color  { Texture = r_color; SRGBTexture = TRUE; };
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
    Blur Average - [https://blog.demofox.org/2016/08/23/incremental-averaging/]
    Blur Center  - [http://john-chapman-graphics.blogspot.com/2013/01/per-object-motion-blur.html]
    Disk Kernels - [http://blog.marmakoide.org/?p=1.]
    Noise        - [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
    Optical Flow - [https://dspace.mit.edu/handle/1721.1/6337]
    Pi & Epsilon - [https://github.com/microsoft/DirectX-Graphics-Samples] [MIT]
    Threshold    - [https://github.com/diwi/PixelFlow] [MIT]
*/

static const float Pi = 3.1415926535897f;
static const float Epsilon = 1.192092896e-07f;
static const float ImageSize = 64.0;
static const int uTaps = 16;

float4 ps_source(v2f input) : SV_Target
{
    float4 uImage = tex2D(s_color, input.uv);
    float uLuma = max(max(uImage.r, uImage.g), uImage.b);
    return exp2(log2(uLuma) * rcp(2.2));
}

float2 Vogel2D(int uIndex, float2 uv)
{
    const float2 Size = rcp(ImageSize) * uRadius;
    const float  GoldenAngle = Pi * (3.0 - sqrt(5.0));
    const float2 Radius = (sqrt(uIndex + 0.5f) / sqrt(uTaps)) * Size;
    const float  Theta = uIndex * GoldenAngle;

    float2 SineCosine;
    sincos(Theta, SineCosine.x, SineCosine.y);
    return Radius * SineCosine.yx + uv;
}

float4 ps_convert(v2f input) : SV_Target
{
    float uImage;

    [unroll]
    for (int i = 0; i < uTaps; i++)
    {
        float2 uv = Vogel2D(i, input.uv);
        float uColor = tex2D(s_buffer, uv).r;
        uImage = lerp(uImage, uColor, rcp(i + 1));
    }

    float4 output;
    output.xy = tex2D(s_cflow, input.uv).rg; // Copy previous rendertarget from ps_flow()
    output.z  = tex2D(s_cframe, input.uv).r; // Copy previous rendertarget from ps_filter()
    output.w  = uImage; // Input downsampled current frame to scale and mip
    return output;
}

float4 ps_filter(v2f input) : SV_Target
{
    float uImage;

    [unroll]
    for (int i = 0; i < uTaps; i++)
    {
        float2 uv = Vogel2D(i, input.uv);
        float uColor = tex2D(s_pframe, uv).w;
        uImage = lerp(uImage, uColor, rcp(i + 1));
    }

    return max(abs(uImage), 1e-5);
}

float4 ps_flow(v2f input) : SV_Target
{
    // Calculate optical flow
    float cLuma = tex2D(s_cframe, input.uv).r;
    float pLuma = tex2D(s_pframe, input.uv).z;
    float2 dFdc = float2(ddx(cLuma), ddy(cLuma));
    float2 dFdp = float2(ddx(pLuma), ddy(pLuma));
    float dt = cLuma - pLuma;
    float dConstraint = dot(dFdp, dFdc) + dt;
    float dSmoothness = dot(dFdp, dFdp) + Epsilon;
    float2 cFlow = dFdc - dFdp * (dConstraint / dSmoothness);

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
    oFlow *= rcp(uScale * ImageSize);

    float4 oBlur;
    const float3 value = float3(52.9829189, 0.06711056, 0.00583715);
    float noise = frac(value.x * frac(dot(input.vpos.xy, value.yz))) * 2.0;
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

    pass cBlurCopyFrame
    {
        VertexShader = vs_common;
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
