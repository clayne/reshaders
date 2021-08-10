
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

uOption(uIter, int, "slider", "Advanced", "Iterations", 1, 1, 16,
"Iterations: Higher = More detected flow, slightly lower performance");

uOption(uBlend, float, "slider", "Advanced", "Flow Blend", 0.250, 0.000, 0.500,
"Temporal Smoothing: Higher = Less noise between strong movements");

texture2D r_color : COLOR;
texture2D r_current_      { Width = size.x / 2.0; Height = size.y / 2.0; Format = RG8; };
texture2D r_previous_     { Width = size.x / 2.0; Height = size.y / 2.0; Format = RG8; };
texture2D r_currentflow_  { Width = size.x / 2.0; Height = size.y / 2.0; Format = RG16F; };
texture2D r_previousflow_ { Width = size.x / 2.0; Height = size.y / 2.0; Format = RG16F; };

sampler2D s_color    	 { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_current_      { Texture = r_current_; };
sampler2D s_previous_     { Texture = r_previous_; };
sampler2D s_currentflow_  { Texture = r_currentflow_; };
sampler2D s_previousflow_ { Texture = r_previousflow_; };

/* [Pixel Shaders] */

float4 ps_image(float4 vpos : SV_POSITION,
                float2 uv: TEXCOORD0) : SV_TARGET
{
    float3 uImage = tex2D(s_color, uv).rgb;
    return cv::encodenorm(normalize(uImage.rgb)).xyxy;
}

float4 ps_hsflow(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_TARGET
{
    float3 pframe = cv::decodenorm(tex2D(s_previous_, uv).xy);
    float3 cframe = cv::decodenorm(tex2D(s_current_, uv).xy);

    float3 dFd;
    dFd.x = dot(ddx(cframe), 1.0);
    dFd.y = dot(ddy(cframe), 1.0);
    dFd.z = dot(cframe - pframe, 1.0);
    const float uRegularize = max(4.0 * pow(uConst * 1e-2, 2.0), 1e-10);
    float dConst = dot(dFd.xy, dFd.xy) + uRegularize;
    float2 cFlow = 0.0;

    for(int i = 0; i < uIter; i++)
    {
        float dCalc = dot(dFd.xy, cFlow) + dFd.z;
        cFlow = cFlow - ((dFd.xy * dCalc) / dConst);
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
        RenderTarget = r_current_;
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
