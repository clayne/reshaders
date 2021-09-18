
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to
    - MartinBFFan and Pao on Discord for reporting bugs
    - BSD for bug propaganda and helping to solve my issue
    - Lord of Lunacy, KingEric1992, and Marty McFly for power of 2 function
*/

#include "cFunctions.fxh"

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax, utooltip)  \
        uniform udata option <                                                          \
        ui_category = ucategory; ui_label = ulabel;                                     \
        ui_type = utype; ui_min = umin; ui_max = umax; ui_tooltip = utooltip;           \
        > = uvalue

uOption(uScale, float, "slider", "Basic", "Scale", 1.000, 0.000, 2.000,
"Scale: Higher = More motion blur");

uOption(uConst, float, "slider", "Optical Flow", "Constraint", 1.000, 0.000, 2.000,
"Regularization: Higher = Smoother flow");

uOption(uBlend, float, "slider", "Post Process", "Temporal Smoothing", 0.250, 0.000, 0.500,
"Temporal Smoothing: Higher = Less temporal noise");

uOption(uDetail, float, "slider", "Post Process", "Flow Mipmap Bias", 4.500, 0.000, 7.000,
"Postprocess Blur: Higher = Less spatial noise");

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1
#define ISIZE 128.0

texture2D r_color  : COLOR;
texture2D r_buffer { Width = DSIZE.x; Height = DSIZE.y; Format = RG8; MipLevels = RSIZE; };
texture2D r_cinfo0 { Width = ISIZE; Height = ISIZE; Format = RGBA16; MipLevels = 8; };
texture2D r_cinfo1 { Width = ISIZE; Height = ISIZE; Format = RG16; };
texture2D r_cinfof { Width = ISIZE; Height = ISIZE; Format = RG16F; MipLevels = 8; };
texture2D r_cflow  { Width = ISIZE; Height = ISIZE; Format = RG16F; MipLevels = 8; };

sampler2D s_color  { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cinfo0 { Texture = r_cinfo0; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cinfo1 { Texture = r_cinfo1; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cinfof { Texture = r_cinfof; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cflow  { Texture = r_cflow; AddressU = MIRROR; AddressV = MIRROR; };

float gauss1D(float pos)
{
    const float sigma = 0.5;
    return exp(-(pos * pos) / (2.0 * sigma * sigma));
}

/* [ Pixel Shaders ] */

float4 blur2D(sampler2D src, float2 uv, float2 direction, float2 psize)
{
    float2 sampleuv;
    const float steps = 7.0;
    const float kernel = 2.0 * steps + 1.0;
    const float2 usize = (1.0 / psize) * direction;
    float4 output = tex2D(src, uv);
    float total = 1.0;

    [unroll]
    for(float i = 1.0; i < 2.0 * steps; i += 2.0)
    {
        const float offsetD1 = i;
        const float offsetD2 = i + 1.0;
        const float weightD1 = gauss1D(offsetD1 / kernel);
        const float weightD2 = gauss1D(offsetD2 / kernel);
        const float weightL = weightD1 + weightD2;
        total += 2.0 * weightL;

        const float offsetL = ((offsetD1 * weightD1) + (offsetD2 * weightD2)) / weightL;
        sampleuv = uv - offsetL * usize;
        output += tex2D(src, sampleuv) * weightL;
        sampleuv = uv + offsetL * usize;
        output += tex2D(src, sampleuv) * weightL;
    }

    return output / total;
}

void ps_normalize(float4 vpos : SV_POSITION,
                  float2 uv : TEXCOORD0,
                  out float2 r0 : SV_TARGET0)
{
    float3 c0 = max(tex2D(s_color, uv).rgb, 1e-3);
    c0 /= dot(c0, 1.0);
    r0 = c0.xy / max(max(c0.r, c0.g), c0.b);
}

void ps_blit(float4 vpos : SV_POSITION,
             float2 uv : TEXCOORD0,
             out float4 r0 : SV_TARGET0)
{
    r0.xy = tex2D(s_buffer, uv).xy;
    r0.zw = tex2D(s_cinfo1, uv).xy;
}

void ps_hblur(float4 vpos : SV_POSITION,
              float2 uv : TEXCOORD0,
              out float2 r0 : SV_TARGET0)
{
    r0 = blur2D(s_cinfo0, uv, float2(1.0, 0.0), ISIZE).xy;
}

void ps_vblur(float4 vpos : SV_POSITION,
              float2 uv : TEXCOORD0,
              out float2 r0 : SV_TARGET0,
              out float2 r1 : SV_TARGET1)
{
    r0 = blur2D(s_cinfo1, uv, float2(0.0, 1.0), ISIZE).xy;
    r1.x = dot(ddx(r0), 1.0);
    r1.y = dot(ddy(r0), 1.0);
}

void ps_oflow(float4 vpos: SV_POSITION,
              float2 uv : TEXCOORD0,
              out float4 r0 : SV_TARGET0,
              out float4 r1 : SV_TARGET1)
{
    const float uRegularize = max(4.0 * pow(uConst * 1e-3, 2.0), 1e-10);
    const float pyramids = log2(ISIZE);
    float2 cFlow = 0.0;

    for(float i = pyramids - 0.5; i >= 0; i--)
    {
        float4 ucalc = float4(uv, 0.0, i);
        float4 cframe = tex2Dlod(s_cinfo0, ucalc);
        float2 ddxy = tex2Dlod(s_cinfof, ucalc).xy;

        float dt = dot(cframe.xy - cframe.zw, 1.0);
        float dCalc = dot(ddxy.xy, cFlow) + dt;
        float dSmooth = rcp(dot(ddxy.xy, ddxy.xy) + uRegularize);
        cFlow = cFlow - ((ddxy.xy * dCalc) * dSmooth);
    }

    r0 = float4(cFlow.xy, 0.0, uBlend);
    r1 = float4(tex2D(s_cinfo0, uv).rgb, 0.0);
}

float4 ps_output(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_Target
{
    float4 oBlur;
    float noise = core::noise(vpos.xy);
    const float samples = 1.0 / (8.0 - 1.0);
    float2 oFlow = tex2Dlod(s_cflow, float4(uv, 0.0, uDetail)).xy;
    oFlow = oFlow * rcp(ISIZE) * core::getaspectratio();
    oFlow *= uScale;

    for(int k = 0; k < 9; k++)
    {
        float2 calc = (noise + k) * samples - 0.5;
        float4 uColor = tex2D(s_color, oFlow * calc + uv);
        oBlur = lerp(oBlur, uColor, rcp(float(k) + 1));
    }

    return oBlur;
}

technique cMotionBlur
{
    pass normalize
    {
        VertexShader = vs_generic;
        PixelShader = ps_normalize;
        RenderTarget0 = r_buffer;
    }

    pass copy
    {
        VertexShader = vs_generic;
        PixelShader = ps_blit;
        RenderTarget0 = r_cinfo0;
    }

    pass horizontalblur
    {
        VertexShader = vs_generic;
        PixelShader = ps_hblur;
        RenderTarget0 = r_cinfo1;
    }

    pass verticalblur_ddxy
    {
        VertexShader = vs_generic;
        PixelShader = ps_vblur;
        RenderTarget0 = r_cinfo0;
        RenderTarget1 = r_cinfof;
        RenderTargetWriteMask = 1 | 2;
    }

    pass opticalflow
    {
        VertexShader = vs_generic;
        PixelShader = ps_oflow;
        RenderTarget0 = r_cflow;
        RenderTarget1 = r_cinfo1;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
    }

    pass cFlowBlur
    {
        VertexShader = vs_generic;
        PixelShader = ps_output;
        SRGBWriteEnable = TRUE;
    }
}
