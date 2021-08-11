
/*
    Horn and Schunck optical flow without iterations
    http://www.cs.cmu.edu/~16385/s17/Slides/14.3_OF__HornSchunck.pdf
*/

#include "cFunctions.fxh"

#define size float2(BUFFER_WIDTH, BUFFER_HEIGHT)

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax, utooltip)  \
        uniform udata option <                                                  		\
        ui_category = ucategory; ui_label = ulabel;                             		\
        ui_type = utype; ui_min = umin; ui_max = umax; ui_tooltip = utooltip;   		\
        > = uvalue

uOption(uConst, float, "slider", "Basic", "Constraint", 0.000, 0.000, 1.000,
"Regularization: Higher = Smoother flow");

uOption(uBlend, float, "slider", "Advanced", "Flow Blend", 0.250, 0.000, 0.500,
"Temporal Smoothing: Higher = Less noise between strong movements");

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1

texture2D r_color : COLOR;
texture2D r_current_      { Width = size.x / 2.0; Height = size.y / 2.0; Format = RG8; MipLevels = RSIZE; };
texture2D r_cderivative_  { Width = size.x / 2.0; Height = size.y / 2.0; Format = RG16F; MipLevels = RSIZE; };
texture2D r_previous_     { Width = size.x / 2.0; Height = size.y / 2.0; Format = RG8; MipLevels = RSIZE; };
texture2D r_currentflow_  { Width = size.x / 2.0; Height = size.y / 2.0; Format = RG16F; };
texture2D r_previousflow_ { Width = size.x / 2.0; Height = size.y / 2.0; Format = RG16F; };

sampler2D s_color    	  { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_current_      { Texture = r_current_; };
sampler2D s_cderivative_  { Texture = r_cderivative_; };
sampler2D s_previous_     { Texture = r_previous_; };
sampler2D s_currentflow_  { Texture = r_currentflow_; };
sampler2D s_previousflow_ { Texture = r_previousflow_; };

/* [Pixel Shaders] */

void ps_image(float4 vpos : SV_POSITION,
              float2 uv : TEXCOORD0,
              out float4 r0 : SV_TARGET0,
              out float4 r1 : SV_TARGET1)
{
    float3 uImage = tex2D(s_color, uv).rgb;
    r0 = cv::encodenorm(normalize(uImage.rgb)).xyxy;
    r1 = float2(dot(ddx(uImage), 1.0), dot(ddy(uImage), 1.0)).xyxy;
}

float4 ps_hsflow(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_TARGET
{
    const float uRegularize = max(4.0 * pow(uConst * 1e-2, 2.0), 1e-10);
    const int uLod = ceil(log2(max(size.x / 2.0, size.y / 2.0)));
    float2 cFlow = 0.0;
    for(int i = uLod; i >= 0; i--)
    {
        float4 ucalc = float4(uv, 0.0, i);
        float2 cFrameBuffer = tex2Dlod(s_current_, ucalc).xy;
        float2 pFrameBuffer = tex2Dlod(s_previous_, ucalc).xy;
        float3 cFrame = cv::decodenorm(cFrameBuffer);
        float3 pFrame = cv::decodenorm(pFrameBuffer);

        float2 ddxy = tex2Dlod(s_cderivative_, ucalc).xy;
        float dt = dot(cFrame - pFrame, 1.0);

        float dCalc = dot(ddxy.xy, cFlow) + dt;
        float dSmooth = rcp(dot(ddxy.xy, ddxy.xy) + uRegularize);
        cFlow = cFlow - ((ddxy.xy * dCalc) * dSmooth);
    }
    return cFlow.xyxy;
}

float4 ps_hsblend(float4 vpos : SV_POSITION,
                  float2 uv : TEXCOORD0) : SV_TARGET
{
    float2 cflow = tex2D(s_currentflow_, uv).xy;
    float2 pflow = tex2D(s_previousflow_, uv).xy;
    float2 blend = lerp(cflow, pflow, uBlend);
    return float4(blend, 1.0, 1.0);
}

void ps_previous(float4 vpos : SV_POSITION,
                 float2 uv: TEXCOORD0,
                 out float4 render0 : SV_TARGET0,
                 out float4 render1 : SV_TARGET1)
{
    render0 = tex2D(s_current_, uv);
    render1 = tex2D(s_currentflow_, uv);
}

technique cOpticalFlow
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_image;
        RenderTarget0 = r_current_;
        RenderTarget1 = r_cderivative_;
    }

    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_hsflow;
        RenderTarget = r_currentflow_;
    }

    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_hsblend;
    }

    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_previous;
        RenderTarget0 = r_previous_;
        RenderTarget1 = r_previousflow_;
    }
}
