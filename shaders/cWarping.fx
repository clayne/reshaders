
/*
    This shader will NOT insert frames, just something I played around with
    It's practically useless in games and media players
    However, putting frame blending to 1 does do a weird paint effect LUL

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

uOption(uScale, float, "slider", "Basic", "Scale",  2.000, 0.000, 4.000,
"Velocity Scale: Higher = More warping");

uOption(uConst, float, "slider", "Basic", "Constraint", 2.000, 0.000, 4.000,
"Regularization: Higher = Smoother flow");

uOption(uNoise, bool, "radio", "Basic", "Noise", true, 0, 0,
"Noise warping");

uOption(uBlend, float, "slider", "Advanced", "Flow Blend", 0.950, 0.000, 1.000,
"Temporal Smoothing: Higher = Less temporal noise");

uOption(uDetail, float, "slider", "Advanced", "Flow MipMap", 0.000, 0.000, 7.000,
"Postprocess Blur: Higher = Less spatial noise");

uOption(uAvg, float, "slider", "Advanced", "Warp Factor", 0.950, 0.000, 1.000,
"Higher = More warp opacity");

uOption(uDebug, bool, "radio", "Advanced", "Debug", false, 0, 0,
"Show optical flow result");

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1
#define ISIZE 128.0

texture2D r_color  : COLOR;
texture2D r_buffer { Width = DSIZE.x; Height = DSIZE.y; Format = RG16; MipLevels = RSIZE; };
texture2D r_cinfo0 { Width = ISIZE; Height = ISIZE; Format = RGBA16; MipLevels = 8; };
texture2D r_cinfo1 { Width = ISIZE; Height = ISIZE; Format = RG16; };
texture2D r_cddxy  { Width = ISIZE; Height = ISIZE; Format = RG16F; MipLevels = 8; };
texture2D r_cflow  { Width = ISIZE; Height = ISIZE; Format = RG16F; MipLevels = 8; };
texture2D r_pcolor { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };

sampler2D s_color  { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cinfo0 { Texture = r_cinfo0; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cinfo1 { Texture = r_cinfo1; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cddxy  { Texture = r_cddxy; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cflow  { Texture = r_cflow; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_pcolor { Texture = r_pcolor; SRGBTexture = TRUE; };

static const int step_count = 6;

static const float weights[step_count] =
{
	0.16501, 0.17507, 0.10112,
	0.04268, 0.01316, 0.00296
};

static const float offsets[step_count] =
{
	0.65772, 2.45017, 4.41096,
	6.37285, 8.33626, 10.30153
};

/* [ Pixel Shaders ] */

float4 blur2D(sampler2D src, float2 uv, float2 direction, float2 psize)
{
    float4 output;

    for (int i = 0; i < step_count; ++i) {
        const float2 texcoord_offset = offsets[i] * direction / psize;
        const float4 samples =
        tex2D(src, uv + texcoord_offset) +
        tex2D(src, uv - texcoord_offset);
        output += weights[i] * samples;
    }

    return output;
}

void ps_normalize(float4 vpos : SV_POSITION,
                  float2 uv : TEXCOORD0,
                  out float2 r0 : SV_TARGET0)
{
    r0 = normalize(tex2D(s_color, uv).rgb).xy;
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
        float2 ddxy = tex2Dlod(s_cddxy, ucalc).xy;

        float dt = dot(cframe.xy - cframe.zw, 1.0);
        float dCalc = dot(ddxy.xy, cFlow) + dt;
        float dSmooth = rcp(dot(ddxy.xy, ddxy.xy) + uRegularize);
        cFlow = cFlow - ((ddxy.xy * dCalc) * dSmooth);
    }

    r0 = float4(cFlow.xy, 0.0, uBlend);
    r1 = float4(tex2D(s_cinfo0, uv).rgb, 0.0);
}

float urand(float2 uv)
{
    float f = dot(float2(12.9898, 78.233), uv);
    return frac(43758.5453 * sin(f));
}

float4 ps_output(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_Target
{
    const float2 pSize = rcp(ISIZE) * core::getaspectratio();
    float2 pFlow = tex2Dlod(s_cflow, float4(uv, 0.0, uDetail)).xy * uScale;
    pFlow = (uNoise) ? pFlow * urand(vpos.xy + pFlow / uScale) : pFlow;
    float4 pMCF = tex2D(s_color, uv + pFlow * pSize);
    float4 pMCB = tex2D(s_pcolor, uv - pFlow * pSize);
    return lerp(pMCF, pMCB, uAvg);
}

float4 ps_previous( float4 vpos : SV_POSITION,
                    float2 uv : TEXCOORD0) : SV_Target
{
    return tex2D(s_color, uv);
}

technique cWarping
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
        RenderTarget1 = r_cddxy;
        RenderTargetWriteMask = 1 | 2;
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

    pass interpolate
    {
        VertexShader = vs_generic;
        PixelShader = ps_output;
        SRGBWriteEnable = TRUE;
    }
    pass blit
    {
        VertexShader = vs_generic;
        PixelShader = ps_previous;
        RenderTarget = r_pcolor;
        SRGBWriteEnable = TRUE;
    }
}
