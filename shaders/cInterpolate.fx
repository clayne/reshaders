
/*
    This shader will NOT insert frames, just something I played around with
    It's practically useless in games and media players
    However, putting frame blending to 1 does do a weird paint effect LUL

    Optical flow motion blur using color by Brimson
    Special Thanks to
    - MartinBFFan and Pao on Discord for reporting bugs
    - BSD for bug propaganda and helping to solve my issue
*/

#include "cFunctions.fxh"

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax, utooltip)  \
        uniform udata option <                                                  		\
        ui_category = ucategory; ui_label = ulabel;                             		\
        ui_type = utype; ui_min = umin; ui_max = umax; ui_tooltip = utooltip;   		\
        > = uvalue

uOption(uConst, float, "slider", "Basic", "Constraint", 0.000, 0.000, 1.000,
"Regularization: Higher = Smoother flow");

uOption(uRadius, float, "slider", "Basic", "Prefilter", 8.000, 0.000, 16.00,
"Preprocess Blur: Higher = Less noise");

uOption(uIter, int, "slider", "Advanced", "Iterations", 1, 1, 16,
"Iterations: Higher = More detected flow, slightly lower performance");

uOption(uBlend, float, "slider", "Advanced", "Flow Blend", 0.250, 0.000, 0.500,
"Temporal Smoothing: Higher = Less noise between strong movements");

uOption(uDetail, float, "slider", "Advanced", "Flow MipMap", 5.500, 0.000, 8.000,
"Postprocess Blur: Higher = Less noise");

uOption(uAverage, float, "slider", "Advanced", "Frame Average", 0.000, 0.000, 1.000,
"Frame Average: Higher = More past frame blend influence");

uOption(uDebug, bool, "radio", "Advanced", "Debug", false, 0, 0,
"Show optical flow result");

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1
#define ISIZE 256.0
static const int uTaps = 14;

texture2D r_color  : COLOR;
texture2D r_buffer { Width = DSIZE.x; Height = DSIZE.y; MipLevels = RSIZE; Format = RG8; };
texture2D r_cimage { Width = ISIZE; Height = ISIZE; Format = RG16; MipLevels = 9; };
texture2D r_cframe { Width = ISIZE; Height = ISIZE; Format = RG16; };
texture2D r_cflow  { Width = ISIZE; Height = ISIZE; Format = RG16F; MipLevels = 9; };
texture2D r_pframe { Width = ISIZE; Height = ISIZE; Format = RG16; };
texture2D r_pflow  { Width = ISIZE; Height = ISIZE; Format = RG16F; };
texture2D r_pcolor { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };

sampler2D s_color  { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cimage { Texture = r_cimage; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cframe { Texture = r_cframe; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cflow  { Texture = r_cflow;  AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_pframe { Texture = r_pframe; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_pflow  { Texture = r_pflow;  AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_pcolor { Texture = r_pcolor; SRGBTexture = TRUE; };

/* [ Vertex Shaders ] */

void vs_convert(in uint id : SV_VERTEXID,
                inout float4 vpos : SV_POSITION,
                inout float2 uv : TEXCOORD0,
                inout float4 ofs[7] : TEXCOORD1)
{
    // Calculate texel offset of the mipped texture
    const float2 uSize = math::computelodtexel(DSIZE.xy, ISIZE) * uRadius;
    core::vsinit(id, uv, vpos);

    for(int i = 0; i < 7; i++)
    {
        ofs[i].xy = math::vogel(i, uv, uSize, uTaps);
        ofs[i].zw = math::vogel(7 + i, uv, uSize, uTaps);
    }
}

void vs_filter(in uint id : SV_VERTEXID,
               inout float4 vpos : SV_POSITION,
               inout float4 ofs[8] : TEXCOORD0)
{
    const float2 uSize = rcp(ISIZE) * uRadius;
    float2 uv;
    core::vsinit(id, uv, vpos);

    for(int i = 0; i < 8; i++)
    {
        ofs[i].xy = math::vogel(i, uv, uSize, uTaps);
        ofs[i].zw = math::vogel(8 + i, uv, uSize, uTaps);
    }
}

/* [ Pixel Shaders ] */

float4 ps_source(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_Target
{
    float3 uImage = tex2D(s_color, uv.xy).rgb;
    return cv::encodenorm(normalize(uImage)).xyxy;
}

void ps_convert(float4 vpos : SV_POSITION,
                float2 uv : TEXCOORD0,
                float4 ofs[7] : TEXCOORD1,
                out float4 r0 : SV_TARGET0,
                out float4 r1 : SV_TARGET1,
				out float4 r2 : SV_TARGET2)
{
    const int cTaps = 14;
    float4 uImage;
    float2 vofs[cTaps];

    for (int i = 0; i < 7; i++)
    {
        vofs[i] = ofs[i].xy;
        vofs[i + 7] = ofs[i].zw;
    }

    for (int j = 0; j < cTaps; j++)
    {
        float4 uColor = tex2D(s_buffer, vofs[j]);
        uImage = lerp(uImage, uColor, rcp(float(j) + 1));
    }

    // r0 = copy previous flow
	// r1 = copy blurred frame from last run
    // r2 = blur current frame, than blur + copy at ps_filter
    r0 = tex2D(s_cflow, uv).xy;
    r1 = tex2D(s_cframe, uv).xy;
    r2 = uImage;
}

float4 ps_filter(   float4 vpos : SV_POSITION,
                    float4 ofs[8] : TEXCOORD0) : SV_Target
{
    const int cTaps = 16;
    const float uArea = math::pi() * (uRadius * uRadius) / uTaps;
    const float uBias = log2(sqrt(uArea));

    float4 uImage;
    float2 vofs[cTaps];

    for (int i = 0; i < 8; i++)
    {
        vofs[i] = ofs[i].xy;
        vofs[i + 8] = ofs[i].zw;
    }

    for (int j = 0; j < cTaps; j++)
    {
        float4 uColor = tex2Dlod(s_cimage, float4(vofs[j], 0.0, uBias));
        uImage = lerp(uImage, uColor, rcp(float(j) + 1));
    }

    return uImage;
}

/*
    Possible improvements
    - Coarse to fine refinement (may have to use ddxy instead)
    - Better penalty function outside quadratic

    Idea:
    - Make derivatives pass with mipchain
    -- cddxy (RG32F)
    - Copy previous using ps_convert's 4th MRT (or pack with pflow)
    -- pddxy (also RG32F)
    - Use derivatives mipchain on pyramid

    Possible issues I need help on:
    - Scaling summed previous flow to next "upscaled" level
    - If previous frame does warp right in the flow pass with tex2Dlod()
    - If HS can work this way with 1 iteration
    - Resolution customization will have to go for now until this works
*/

float4 ps_flow(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0) : SV_Target
{
    float2 cFrameBuffer = tex2D(s_cframe, uv).xy;
    float2 pFrameBuffer = tex2D(s_pframe, uv).xy;

    // Calculate optical flow without post neighborhood average
    float3 cFrame = cv::decodenorm(cFrameBuffer);
    float3 pFrame = cv::decodenorm(pFrameBuffer);

    float3 dFd;
    dFd.x = dot(ddx(cFrame), 1.0);
    dFd.y = dot(ddy(cFrame), 1.0);
    dFd.z = dot(cFrame - pFrame, 1.0);
    const float uRegularize = max(4.0 * pow(uConst * 1e-3, 2.0), 1e-10);
    float dConst = rcp(dot(dFd.xy, dFd.xy) + uRegularize);
    float2 cFlow = 0.0;

    for(int i = 0; i < uIter; i++)
    {
        float dCalc = dot(dFd.xy, cFlow) + dFd.z;
        cFlow = cFlow - ((dFd.xy * dCalc) * dConst);
    }

    // Smooth optical flow
    float2 pFlow = tex2D(s_pflow, uv).xy;
    return lerp(cFlow, pFlow, uBlend).xyxy;
}

// Median masking inspired by vs-mvtools
// https://github.com/dubhater/vapoursynth-mvtools

float4 Median3( float4 a, float4 b, float4 c)
{
    return max(min(a, b), min(max(a, b), c));
}

float4 ps_output(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_Target
{
    const float2 pSize = rcp(ISIZE) * core::getaspectratio();
    float2 pFlow = tex2Dlod(s_cflow, float4(uv, 0.0, uDetail)).xy;
    float4 pRef = tex2D(s_color, uv);
    float4 pSrc = tex2D(s_pcolor, uv);
    float4 pMCB = tex2D(s_color, uv - pFlow * pSize);
    float4 pMCF = tex2D(s_pcolor, uv + pFlow * pSize);
    float4 pAvg = lerp(pRef, pSrc, uAverage);
    return (uDebug) ? float4(pFlow, 1.0, 1.0) : Median3(pMCF, pMCB, pAvg);
}

float4 ps_previous( float4 vpos : SV_POSITION,
                    float2 uv : TEXCOORD0) : SV_Target
{
    return float4(tex2D(s_color, uv).rgb, 1.0);
}

technique cInterpolate
{
    pass cBlur
    {
        VertexShader = vs_generic;
        PixelShader = ps_source;
        RenderTarget0 = r_buffer;
    }

    pass cCopyPrevious
    {
        VertexShader = vs_convert;
        PixelShader = ps_convert;
        RenderTarget0 = r_pflow;
        RenderTarget1 = r_pframe;
        RenderTarget2 = r_cimage;
    }

    pass cBlurCopyFrame
    {
        VertexShader = vs_filter;
        PixelShader = ps_filter;
        RenderTarget0 = r_cframe;
    }

    pass cOpticalFlow
    {
        VertexShader = vs_generic;
        PixelShader = ps_flow;
        RenderTarget0 = r_cflow;
    }

    pass cInterpolate
    {
        VertexShader = vs_generic;
        PixelShader = ps_output;
        SRGBWriteEnable = TRUE;
    }

    pass cStorePrevious
    {
        VertexShader = vs_generic;
        PixelShader = ps_previous;
        RenderTarget = r_pcolor;
        SRGBWriteEnable = TRUE;
    }
}
