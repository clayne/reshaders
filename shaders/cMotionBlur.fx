
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

uOption(uScale, float, "slider", "Basic", "Scale", 2.000, 0.000, 4.000,
"Scale: Higher = More motion blur");

uOption(uRadius, float, "slider", "Basic", "Prefilter", 8.000, 0.000, 16.00,
"Preprocess Blur: Higher = Less noise");

uOption(uConst, float, "slider", "Optical Flow", "Constraint", 0.500, 0.000, 1.000,
"Regularization: Higher = Smoother flow");

uOption(uBlend, float, "slider", "Post Process", "Temporal Smoothing", 0.250, 0.000, 0.500,
"Temporal Smoothing: Higher = Less temporal noise");

uOption(uDetail, float, "slider", "Post Process", "Flow Mipmap Bias", 4.500, 0.000, 7.000,
"Postprocess Blur: Higher = Less spatial noise");

uOption(uVignette, bool, "radio", "Vignette", "Enable", false, 0, 0,
"Enable to change optical flow influence to or from center");

uOption(uInvert, bool, "radio", "Vignette", "Invert", true, 0, 0,
"Apply vignette from center if enabled");

uOption(uFalloff, float, "slider", "Vignette", "Sharpness", 1.000, 0.000, 8.000,
"Vignette Strength");

uOption(uDebug, bool, "radio", "Advanced", "Debug", false, 0, 0,
"Show optical flow result");

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1
#define ISIZE 256.0
static const int uTaps = 14;

texture2D r_color  : COLOR;
texture2D r_buffer { Width = DSIZE.x; Height = DSIZE.y; Format = RG16; MipLevels = RSIZE; };
texture2D r_cimage { Width = ISIZE; Height = ISIZE; Format = RGBA16; MipLevels = 9; };
texture2D r_cframe { Width = ISIZE; Height = ISIZE; Format = RG16;  MipLevels = 9; };
texture2D r_cddxy  { Width = ISIZE; Height = ISIZE; Format = RG16F; MipLevels = 9; };
texture2D r_cflow  { Width = ISIZE / 2; Height = ISIZE / 2; Format = RG16F; MipLevels = 8; };

sampler2D s_color  { Texture = r_color;  AddressU = MIRROR; AddressV = MIRROR; SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cimage { Texture = r_cimage; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cframe { Texture = r_cframe; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cddxy  { Texture = r_cddxy;  AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cflow  { Texture = r_cflow;  AddressU = MIRROR; AddressV = MIRROR; };

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
    float3 output = uImage.rgb / dot(uImage.rgb , 1.0);
    float obright = max(max(output.r, output.g), output.b);
    output = output.rg / obright;
    return float4(output.rg, 0.0, 0.0);
}

void ps_convert(float4 vpos : SV_POSITION,
                float2 uv : TEXCOORD0,
                float4 ofs[7] : TEXCOORD1,
                out float4 r0 : SV_TARGET0)
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

    // r0.xy = copy blurred frame from last run
    // r0.zw = blur current frame, than blur + copy at ps_filter
    r0.xy = tex2D(s_cframe, uv).xy;
    r0.zw = uImage;
}

void ps_filter(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0,
               float4 ofs[7] : TEXCOORD1,
               out float4 r0 : SV_TARGET0,
               out float4 r1 : SV_TARGET1)
{
    const float uArea = math::pi() * (uRadius * uRadius) / uTaps;
    const float uBias = log2(sqrt(uArea));

    float2 cImage;
    float2 vofs[uTaps];

    for (int i = 0; i < 7; i++)
    {
        vofs[i] = ofs[i].xy;
        vofs[i + 7] = ofs[i].zw;
    }

    for (int j = 0; j < uTaps; j++)
    {
        float2 uColor = tex2Dlod(s_cimage, float4(vofs[j], 0.0, uBias)).zw;
        cImage = lerp(cImage, uColor, rcp(float(j) + 1));
    }

    r0 = cImage;
    float2 pImage = tex2D(s_cimage, uv).xy;
    float2 cGrad;
    float2 pGrad;
    cGrad.x = dot(ddx(cImage), 1.0);
    cGrad.y = dot(ddy(cImage), 1.0);
    pGrad.x = dot(ddx(pImage), 1.0);
    pGrad.y = dot(ddy(pImage), 1.0);
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
    const float uRegularize = max(4.0 * pow(uConst * 1e-3, 2.0), 1e-10);
    const float pyramids = ceil(log2(ISIZE / 2)) - 0.5;
    float2 cFlow = 0.0;

    for(float i = pyramids; i >= 0; i--)
    {
        float4 ucalc = float4(uv, 0.0, i);
        float2 cFrame = tex2Dlod(s_cframe, ucalc).xy;
        float2 pFrame = tex2Dlod(s_cimage, ucalc).xy;
        float2 ddxy = tex2Dlod(s_cddxy, ucalc).xy;

        float dt = dot(cFrame - pFrame, 1.0);
        float dCalc = dot(ddxy.xy, cFlow) + dt;
        float dSmooth = rcp(dot(ddxy.xy, ddxy.xy) + uRegularize);
        cFlow = cFlow - ((ddxy.xy * dCalc) * dSmooth);
    }

    return float4(cFlow.xy, 0.0, uBlend);
}

float4 ps_output(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_Target
{
    float4 oBlur;
    const float samples = 1.0 / (8.0 - 1.0);
    float2 oFlow = tex2Dlod(s_cflow, float4(uv, 0.0, uDetail)).xy;
    oFlow = oFlow * rcp(ISIZE) * core::getaspectratio();
    oFlow *= uScale;
    float noise = core::noise(vpos.xy + oFlow);

    // Vignette output if called
    float2 coord = (uv - 0.5) * core::getaspectratio() * 2.0;
    float rf = length(coord) * uFalloff;
    float rf2_1 = mad(rf, rf, 1.0);

    float vigWeight = rcp(rf2_1 * rf2_1);
    vigWeight = (uInvert) ? 1.0 - vigWeight : vigWeight;
    oFlow = (uVignette) ? oFlow * vigWeight : oFlow;

    [unroll]
    for(int k = 0; k < 9; k++)
    {
        float2 calc = (noise + k) * samples - 0.5;
        float4 uColor = tex2D(s_color, oFlow * calc + uv);
        oBlur = lerp(oBlur, uColor, rcp(float(k) + 1));
    }

    return (uDebug) ? float4(oFlow, 1.0, 1.0) : oBlur;
}

technique cMotionBlur
{
    pass cNormalize
    {
        VertexShader = vs_generic;
        PixelShader = ps_source;
        RenderTarget0 = r_buffer;
    }

    pass cCopyPrevious
    {
        VertexShader = vs_convert;
        PixelShader = ps_convert;
        RenderTarget0 = r_cimage;
    }

    pass cBlurCopyFrame
    {
        VertexShader = vs_filter;
        PixelShader = ps_filter;
        RenderTarget0 = r_cframe;
        RenderTarget1 = r_cddxy;
    }

    /*
        Smooth optical flow with BlendOps
        How it works:
            Src = Current optical flow
            Dest = Previous optical flow
            SRCALPHA = Blending weight between Src and Dest
            If SRCALPHA = 0.25, the blending would be
            Src * (1.0 - 0.25) + Dest * 0.25
            The previous flow's output gets quartered every frame
        Note:
            Disable ClearRenderTargets to blend with existing
            data in r_cflow before rendering
    */

    pass cOpticalFlow
    {
        VertexShader = vs_generic;
        PixelShader = ps_flow;
        RenderTarget0 = r_cflow;
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
