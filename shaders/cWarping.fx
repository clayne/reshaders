
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
texture2D r_buffer { Width = DSIZE.x; Height = DSIZE.y; Format = RG8; MipLevels = RSIZE; };
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

/* [Vertex Shaders] */

void vs_generic(in uint id : SV_VERTEXID,
                out float4 position : SV_POSITION,
                out float2 texcoord : TEXCOORD)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [ Pixel Shaders ] */

float gauss1D(const int position, const int kernel)
{
    const float sigma = kernel / 3.0;
    const float pi = 3.1415926535897932384626433832795f;
    float output = rsqrt(2.0 * pi * (sigma * sigma));
    return output * exp(-0.5 * position * position / (sigma * sigma));
}

float4 blur1D(sampler2D src, float2 uv, float2 direction, float2 psize)
{
    float2 sampleuv;
    const float kernel = 14;
    const float2 usize = (1.0 / psize) * direction;
    float4 output = tex2D(src, uv) * gauss1D(0.0, kernel);
    float total = gauss1D(0.0, kernel);

    [unroll]
    for(float i = 1.0; i < kernel; i += 2.0)
    {
        const float offsetD1 = i;
        const float offsetD2 = i + 1.0;
        const float weightD1 = gauss1D(offsetD1, kernel);
        const float weightD2 = gauss1D(offsetD2, kernel);
        const float weightL = weightD1 + weightD2;
        const float offsetL = ((offsetD1 * weightD1) + (offsetD2 * weightD2)) / weightL;

        sampleuv = uv - offsetL * usize;
        output += tex2D(src, sampleuv) * weightL;
        sampleuv = uv + offsetL * usize;
        output += tex2D(src, sampleuv) * weightL;
        total += 2.0 * weightL;
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
    r0 = blur1D(s_cinfo0, uv, float2(1.0, 0.0), ISIZE).xy;
}

void ps_vblur(float4 vpos : SV_POSITION,
              float2 uv : TEXCOORD0,
              out float2 r0 : SV_TARGET0)
{
    r0 = blur1D(s_cinfo1, uv, float2(0.0, 1.0), ISIZE).xy;
}

void ps_ddxy(float4 vpos : SV_POSITION,
             float2 uv : TEXCOORD0,
             out float2 r0 : SV_TARGET0,
             out float2 r1 : SV_TARGET1)
{
    const float2 psize = 1.0 / tex2Dsize(s_cinfo0, 0.0);
    float4 s_dx0 = tex2D(s_cinfo0, uv + float2(psize.x, 0.0));
    float4 s_dx1 = tex2D(s_cinfo0, uv - float2(psize.x, 0.0));
    float4 s_dy0 = tex2D(s_cinfo0, uv + float2(0.0, psize.y));
    float4 s_dy1 = tex2D(s_cinfo0, uv - float2(0.0, psize.y));
    r0.x = dot(s_dx0 - s_dx1, 1.0);
    r0.y = dot(s_dy0 - s_dy1, 1.0);
    r1 = tex2D(s_cinfo0, uv).rg;
}

void ps_oflow(float4 vpos: SV_POSITION,
              float2 uv : TEXCOORD0,
              out float4 r0 : SV_TARGET0)
{
	const float lambda = max(4.0 * pow(uConst * 1e-3, 2.0), 1e-10);
    const float pyramids = log2(ISIZE);
    float2 cFlow = 0.0;

    for(float i = pyramids - 0.5; i >= 0; i--)
    {
        float4 ucalc = float4(uv, 0.0, i);
        float4 frame = tex2Dlod(s_cinfo0, ucalc);
        float2 ddxy = tex2Dlod(s_cddxy, ucalc).xy;

        float dt = dot(frame.xy - frame.zw, 1.0);
        float dCalc = dot(ddxy.xy, cFlow) + dt;
        float dSmooth = rcp(dot(ddxy.xy, ddxy.xy) + lambda);
        cFlow = cFlow - ((ddxy.xy * dCalc) * dSmooth);
    }

    r0 = float4(cFlow.xy, 0.0, uBlend);
}

float urand(float2 uv)
{
    float f = dot(float2(12.9898, 78.233), uv);
    return frac(43758.5453 * sin(f));
}

float4 ps_output(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_Target
{
    const float aspectratio = BUFFER_WIDTH / BUFFER_HEIGHT;
    const float2 pSize = rcp(ISIZE) * aspectratio;
    float2 pFlow = tex2Dlod(s_cflow, float4(uv, 0.0, uDetail)).xy * uScale;
    pFlow = (uNoise) ? pFlow * urand(vpos.xy + pFlow / uScale) : pFlow;
    float4 pMCF = tex2D(s_color, uv + pFlow * pSize);
    float4 pMCB = tex2D(s_pcolor, uv - pFlow * pSize);
    return lerp(pMCF, pMCB, uAvg);
}

float4 ps_previous(float4 vpos : SV_POSITION,
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

    pass scale_storeprevious
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

    pass verticalblur
    {
        VertexShader = vs_generic;
        PixelShader = ps_vblur;
        RenderTarget0 = r_cinfo0;
        RenderTargetWriteMask = 1 | 2;
    }

    pass derivatives_copy
    {
        VertexShader = vs_generic;
        PixelShader = ps_ddxy;
        RenderTarget0 = r_cddxy;
        RenderTarget1 = r_cinfo1;
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
