
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

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1

texture2D r_color  : COLOR;
texture2D r_pbuffer { Width = DSIZE.x; Height = DSIZE.y; Format = RGBA16; MipLevels = RSIZE; };
texture2D r_cbuffer { Width = DSIZE.x; Height = DSIZE.y; Format = RG16; MipLevels = RSIZE; };
texture2D r_cuddxy  { Width = DSIZE.x; Height = DSIZE.y; Format = RG16F; MipLevels = RSIZE; };

sampler2D s_color   { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_pbuffer { Texture = r_pbuffer; };
sampler2D s_cbuffer { Texture = r_cbuffer; };
sampler2D s_cuddxy  { Texture = r_cuddxy; };

/* [ Pixel Shaders ] */

void ps_convert(float4 vpos : SV_POSITION,
                float2 uv : TEXCOORD0,
                out float4 r0 : SV_TARGET0)
{
    // r0.xy = copy blurred frame from last run
    // r0.zw = blur current frame, than blur + copy at ps_filter
    // r1 = get derivatives from previous frame
    float3 uImage = tex2D(s_color, uv.xy).rgb;
    r0.xy = tex2D(s_cbuffer, uv).xy;
    r0.zw = cv::encodenorm(normalize(uImage));
}

void ps_filter(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0,
               out float4 r0 : SV_TARGET0,
               out float4 r1 : SV_TARGET1)
{
    float4 uImage = tex2D(s_pbuffer, uv);
    r0 = uImage.zw;
    float2 cGrad;
    float2 pGrad;
    cGrad.x = dot(ddx(uImage.zw), 1.0);
    cGrad.y = dot(ddy(uImage.zw), 1.0);
    pGrad.x = dot(ddx(uImage.xy), 1.0);
    pGrad.y = dot(ddy(uImage.xy), 1.0);
    r1 = cGrad + pGrad;
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
    const float uRegularize = max(4.0 * pow(uConst * 1e-2, 2.0), 1e-10);
    float2 cFlow = 0.0;
    for(int i = 8; i >= 0; i--)
    {
        float4 ucalc = float4(uv, 0.0, i);
        float2 cFrame = tex2Dlod(s_cbuffer, ucalc).xy;
        float2 pFrame = tex2Dlod(s_pbuffer, ucalc).xy;

        float2 ddxy = tex2Dlod(s_cuddxy, ucalc).xy;
        float dt = dot(cFrame - pFrame, 1.0);
        float dCalc = dot(ddxy.xy, cFlow) + dt;
        float dSmooth = rcp(dot(ddxy.xy, ddxy.xy) + uRegularize);
        cFlow = cFlow - ((ddxy.xy * dCalc) * dSmooth);
    }

    return float4(cFlow.xy * 0.5 + 0.5, 1.0, 1.0);
}

technique cOpticalFlow
{
    pass cNormalize
    {
        VertexShader = vs_generic;
        PixelShader = ps_convert;
        RenderTarget0 = r_pbuffer;
    }

    pass cProcessFrame
    {
        VertexShader = vs_generic;
        PixelShader = ps_filter;
        RenderTarget0 = r_cbuffer;
        RenderTarget1 = r_cuddxy;
    }

    pass cOpticalFlow
    {
        VertexShader = vs_generic;
        PixelShader = ps_flow;
    }
}
