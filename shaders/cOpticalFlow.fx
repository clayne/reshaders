
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to
    - MartinBFFan and Pao on Discord for reporting bugs
    - BSD for bug propaganda and helping to solve my issue
    - Lord of Lunacy, KingEric1992, and Marty McFly for power of 2 function
*/

#include "cFunctions.fxh"

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax, utooltip)  \
        uniform udata option <                                                  		\
        ui_category = ucategory; ui_label = ulabel;                             		\
        ui_type = utype; ui_min = umin; ui_max = umax; ui_tooltip = utooltip;   		\
        > = uvalue

uOption(uConst, float, "slider", "Basic", "Constraint", 0.250, 0.000, 1.000,
"Regularization: Higher = Smoother flow");

uOption(uBlend, float, "slider", "Advanced", "Flow Blend", 0.250, 0.000, 0.500,
"Temporal Smoothing: Higher = Less temporal noise");

uOption(uDetail, float, "slider", "Advanced", "Flow MipMap", 5.500, 0.000, 8.000,
"Postprocess Blur: Higher = Less spatial noise");

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1

texture2D r_color  : COLOR;
texture2D r_pbuffer { Width = DSIZE.x; Height = DSIZE.y; Format = RGBA16; MipLevels = RSIZE; };
texture2D r_cbuffer { Width = DSIZE.x; Height = DSIZE.y; Format = RG16; MipLevels = RSIZE; };
texture2D r_cdata   { Width = DSIZE.x; Height = DSIZE.y; Format = RG16F; MipLevels = RSIZE; };
texture2D r_cuddxy  { Width = DSIZE.x; Height = DSIZE.y; Format = RG16F; MipLevels = RSIZE; };
texture2D r_pdata   { Width = DSIZE.x; Height = DSIZE.y; Format = RG16F; };

sampler2D s_color   { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_pbuffer { Texture = r_pbuffer; };
sampler2D s_cbuffer { Texture = r_cbuffer; };
sampler2D s_cdata   { Texture = r_cdata; };
sampler2D s_cuddxy  { Texture = r_cuddxy; };
sampler2D s_pdata   { Texture = r_pdata; };

/* [ Pixel Shaders ] */

float4 ps_source(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_Target
{
    float3 uImage = tex2D(s_color, uv.xy).rgb;
    float2 output = cv::encodenorm(normalize(uImage));
    return output.xyxy;
}

void ps_convert(float4 vpos : SV_POSITION,
                float2 uv : TEXCOORD0,
                out float4 r0 : SV_TARGET0,
                out float4 r1 : SV_TARGET1,
                out float4 r2 : SV_TARGET2)
{
    // r0 = copy previous flow
    // r1.xy = copy blurred frame from last run
    // r1.zw = blur current frame, than blur + copy at ps_filter
    // r2 = get derivatives from previous frame
    float3 uImage = tex2D(s_color, uv.xy).rgb;
    r0 = tex2D(s_cdata, uv).xy;
    r1.xy = tex2D(s_cbuffer, uv).xy;
    r1.zw = cv::encodenorm(normalize(uImage));
    r2 = cv::decodenorm(r1.xy);
    r2.x = dot(ddx(r2.rgb), 1.0);
    r2.y = dot(ddy(r2.rgb), 1.0);
}

void ps_filter(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0,
               out float4 r0 : SV_TARGET0,
               out float4 r1 : SV_TARGET1)
{
    r0 = tex2D(s_pbuffer, uv.xy).zw;
    float3 oImage = cv::decodenorm(r0.xy);
    r1 = tex2D(s_cdata, uv).xy;
    r1.x += dot(ddx(oImage), 1.0);
    r1.y += dot(ddy(oImage), 1.0);
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
        float2 cFrameBuffer = tex2Dlod(s_cbuffer, ucalc).xy;
        float2 pFrameBuffer = tex2Dlod(s_pbuffer, ucalc).xy;
        float3 cFrame = cv::decodenorm(cFrameBuffer);
        float3 pFrame = cv::decodenorm(pFrameBuffer);

        float2 ddxy = tex2Dlod(s_cuddxy, ucalc).xy;
        float dt = dot(cFrame - pFrame, 1.0);
        float dCalc = dot(ddxy.xy, cFlow) + dt;
        float dSmooth = rcp(dot(ddxy.xy, ddxy.xy) + uRegularize);
        cFlow = cFlow - ((ddxy.xy * dCalc) * dSmooth);
    }

    // Smooth optical flow
    float2 pinfo = tex2D(s_pdata, uv).xy;
    return lerp(cFlow, pinfo, uBlend).xyxy;
}

float4 ps_output(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_Target
{
    return tex2Dlod(s_cdata, float4(uv, 0.0, uDetail));
}

technique cOpticalFlow
{
    pass Normalize
    {
        VertexShader = vs_generic;
        PixelShader = ps_convert;
        RenderTarget0 = r_pdata;
        RenderTarget1 = r_pbuffer;
        RenderTarget2 = r_cdata;
    }

    pass Blur_CopyFrame
    {
        VertexShader = vs_generic;
        PixelShader = ps_filter;
        RenderTarget0 = r_cbuffer;
        RenderTarget1 = r_cuddxy;
    }

    pass HSOpticalFlow
    {
        VertexShader = vs_generic;
        PixelShader = ps_flow;
        RenderTarget0 = r_cdata;
    }

    pass FlowBlend
    {
        VertexShader = vs_generic;
        PixelShader = ps_output;
        SRGBWriteEnable = TRUE;
    }
}
