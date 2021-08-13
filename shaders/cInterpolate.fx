
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

uOption(uConst, float, "slider", "Basic", "Constraint", 0.500, 0.000, 1.000,
"Regularization: Higher = Smoother flow");

uOption(uRadius, float, "slider", "Basic", "Prefilter", 8.000, 0.000, 16.00,
"Preprocess Blur: Higher = Less noise");

uOption(uBlend, float, "slider", "Advanced", "Flow Blend", 0.250, 0.000, 0.500,
"Temporal Smoothing: Higher = Less temporal noise");

uOption(uDetail, float, "slider", "Advanced", "Flow MipMap", 5.500, 0.000, 8.000,
"Postprocess Blur: Higher = Less spatial noise");

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
texture2D r_cimage { Width = ISIZE; Height = ISIZE; Format = RGBA16; MipLevels = 9; };
texture2D r_cframe { Width = ISIZE; Height = ISIZE; Format = RG16; MipLevels = 9; };
texture2D r_cinfo  { Width = ISIZE; Height = ISIZE; Format = RG16F; MipLevels = 9; };
texture2D r_cddxy  { Width = ISIZE; Height = ISIZE; Format = RG16F; MipLevels = 9; };
texture2D r_pinfo  { Width = ISIZE; Height = ISIZE; Format = RG16F; };
texture2D r_pcolor { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };

sampler2D s_color  { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; };
sampler2D s_cimage { Texture = r_cimage; };
sampler2D s_cframe { Texture = r_cframe; };
sampler2D s_cinfo  { Texture = r_cinfo; };
sampler2D s_cddxy  { Texture = r_cddxy; };
sampler2D s_pinfo  { Texture = r_pinfo; };
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
               inout float2 uv : TEXCOORD0,
               inout float4 ofs[7] : TEXCOORD1)
{
    const float2 uSize = rcp(ISIZE) * uRadius;
    core::vsinit(id, uv, vpos);

    for(int i = 0; i < 7; i++)
    {
        ofs[i].xy = math::vogel(i, uv, uSize, uTaps);
        ofs[i].zw = math::vogel(7 + i, uv, uSize, uTaps);
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
    float2 uImage;
    float2 vofs[uTaps];

    for (int i = 0; i < 7; i++)
    {
        vofs[i] = ofs[i].xy;
        vofs[i + 7] = ofs[i].zw;
    }

    for (int j = 0; j < uTaps; j++)
    {
        float2 uColor = tex2D(s_buffer, vofs[j]).xy;
        uImage = lerp(uImage, uColor, rcp(float(j) + 1));
    }

    // r0 = copy previous flow
    // r1.xy = copy blurred frame from last run
    // r1.zw = blur current frame, than blur + copy at ps_filter
    // r2 = get derivatives from previous frame
    r0 = tex2D(s_cinfo, uv).xy;
    r1.xy = tex2D(s_cframe, uv).xy;
    r1.zw = uImage;
    float3 rEnc = cv::decodenorm(r1.xy);
    r2 = float2(dot(ddx(rEnc), 1.0), dot(ddy(rEnc), 1.0));
}

void ps_filter(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0,
               float4 ofs[7] : TEXCOORD1,
               out float4 r0 : SV_TARGET0,
               out float4 r1 : SV_TARGET1)
{
    const float uArea = math::pi() * (uRadius * uRadius) / uTaps;
    const float uBias = log2(sqrt(uArea));

    float2 uImage;
    float2 vofs[uTaps];

    for (int i = 0; i < 7; i++)
    {
        vofs[i] = ofs[i].xy;
        vofs[i + 7] = ofs[i].zw;
    }

    for (int j = 0; j < uTaps; j++)
    {
        float2 uColor = tex2Dlod(s_cimage, float4(vofs[j], 0.0, uBias)).zw;
        uImage = lerp(uImage, uColor, rcp(float(j) + 1));
    }

    r0 = uImage;
    float3 oImage = cv::decodenorm(uImage);
    r1  = tex2D(s_cinfo, uv).xy;
    r1 += float2(dot(ddx(oImage), 1.0), dot(ddy(oImage), 1.0));
}

/*
    https://www.cs.auckland.ac.nz/~rklette/CCV-CIMAT/pdfs/B08-HornSchunck.pdf
    - Use a regular image pyramid for input frames I(., .,t)
    - Processing starts at a selected level (of lower resolution)
    - Obtained results are used for initializing optic flow values at a
      lower level (of higher resolution)
    - Repeat until full resolution level of original frames is reached
*/

float4 ps_flow(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0) : SV_Target
{
    const float uRegularize = max(4.0 * pow(uConst * 1e-3, 2.0), 1e-10);
    float2 cFlow = 0.0;
    for(int i = 8; i >= 0; i--)
    {
        float4 ucalc = float4(uv, 0.0, i);
        float2 cFrameBuffer = tex2Dlod(s_cframe, ucalc).xy;
        float2 pFrameBuffer = tex2Dlod(s_cimage, ucalc).xy;
        float3 cFrame = cv::decodenorm(cFrameBuffer);
        float3 pFrame = cv::decodenorm(pFrameBuffer);

        float2 ddxy = tex2Dlod(s_cddxy, ucalc).xy;
        float dt = dot(cFrame - pFrame, 1.0);
        float dCalc = dot(ddxy.xy, cFlow) + dt;
        float dSmooth = rcp(dot(ddxy.xy, ddxy.xy) + uRegularize);
        cFlow = cFlow - ((ddxy.xy * dCalc) * dSmooth);
    }

    // Smooth optical flow
    float2 pinfo = tex2D(s_pinfo, uv).xy;
    return lerp(cFlow, pinfo, uBlend).xyxy;
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
    float2 pFlow = tex2Dlod(s_cinfo, float4(uv, 0.0, uDetail)).xy;
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
    return tex2D(s_color, uv);
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
        RenderTarget0 = r_pinfo;
        RenderTarget1 = r_cimage;
        RenderTarget2 = r_cinfo;
    }

    pass cBlurCopyFrame
    {
        VertexShader = vs_filter;
        PixelShader = ps_filter;
        RenderTarget0 = r_cframe;
        RenderTarget1 = r_cddxy;
    }

    pass cOpticalFlow
    {
        VertexShader = vs_generic;
        PixelShader = ps_flow;
        RenderTarget0 = r_cinfo;
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
