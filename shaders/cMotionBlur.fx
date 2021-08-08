
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to
    - MartinBFFan and Pao on Discord for reporting bugs
    - BSD for bug propaganda and helping to solve my issue
    - Lord of Lunacy, KingEric1992, and Marty McFly for power of 2 function

    Notes:  Blurred previous + current frames must be 32Float textures.
            This makes the optical flow not suffer from noise + banding

    LOD Compute  - [https://john-chapman.github.io/2019/03/29/convolution.html]
    Median3      - [https://github.com/GPUOpen-Effects/FidelityFX-CAS] [MIT]
    Noise        - [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
    Normals Pack - [https://aras-p.info/texts/CompactNormalStorage.html]
    Optical Flow - [https://dspace.mit.edu/handle/1721.1/6337]
    Pi Constant  - [https://github.com/microsoft/DirectX-Graphics-Samples] [MIT]
    Vignette     - [https://github.com/keijiro/KinoVignette] [MIT]
    Vogel Disk   - [http://blog.marmakoide.org/?p=1]
*/

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax, utooltip)  \
        uniform udata option <                                                  		\
        ui_category = ucategory; ui_label = ulabel;                             		\
        ui_type = utype; ui_min = umin; ui_max = umax; ui_tooltip = utooltip;   		\
        > = uvalue

uOption(uConst, float, "slider", "Basic", "Constraint", 0.000, 0.000, 1.000,
"Regularization: Higher = Smoother flow");

uOption(uScale, float, "slider", "Basic", "Scale", 2.000, 0.000, 4.000,
"Scale: Higher = More motion blur");

uOption(uRadius, float, "slider", "Basic", "Prefilter", 8.000, 0.000, 16.00,
"Preprocess Blur: Higher = Less noise");

uOption(uIter, int, "slider", "Advanced", "Iterations", 1, 1, 16,
"Iterations: Higher = More detected flow, slightly lower performance");

uOption(uBlend, float, "slider", "Advanced", "Flow Blend", 0.250, 0.000, 0.500,
"Temporal Smoothing: Higher = Less noise between strong movements");

uOption(uDetail, float, "slider", "Advanced", "Flow MipMap", 5.500, 0.000, 8.000,
"Postprocess Blur: Higher = Less noise");

uOption(uDebug, bool, "radio", "Advanced", "Debug", false, 0, 0,
"Show optical flow result");

uOption(uVignette, bool,  "radio",  "Vignette", "Enable", false, 0, 0,
"Enable to change optical flow influence to or from center");

uOption(uInvert, bool,  "radio",  "Vignette", "Invert", true, 0, 0,
"");

uOption(uFalloff, float, "slider", "Vignette", "Sharpness", 1.000, 0.000, 8.000,
"Vignette Strength");

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

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1
#define ISIZE 256.0

static const float aRatio = BUFFER_WIDTH / BUFFER_HEIGHT;
static const float Pi = 3.1415926535897f;
static const int uTaps = 14;

texture2D r_color  : COLOR;
texture2D r_buffer { Width = DSIZE.x; Height = DSIZE.y; MipLevels = RSIZE; Format = RG8; };
texture2D r_cimage { Width = ISIZE; Height = ISIZE; Format = RG32F; MipLevels = 9; };
texture2D r_cframe { Width = ISIZE; Height = ISIZE; Format = RG32F; };
texture2D r_cflow  { Width = ISIZE; Height = ISIZE; Format = RG32F; MipLevels = 9; };
texture2D r_pframe { Width = ISIZE; Height = ISIZE; Format = RGBA32F; };

sampler2D s_color  { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cimage { Texture = r_cimage; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cframe { Texture = r_cframe; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cflow  { Texture = r_cflow;  AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_pframe { Texture = r_pframe; AddressU = MIRROR; AddressV = MIRROR; };

/* [ Vertex Shaders ] */

void v2f_core(  in uint id,
                inout float2 uv,
                inout float4 vpos)
{
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

float2 Vogel2D(int uIndex, float2 uv, float2 pSize)
{
    const float  GoldenAngle = Pi * (3.0 - sqrt(5.0));
    const float2 Radius = (sqrt(uIndex + 0.5f) / sqrt(uTaps)) * pSize;
    const float  Theta = uIndex * GoldenAngle;

    float2 SineCosine;
    sincos(Theta, SineCosine.x, SineCosine.y);
    return Radius * SineCosine.yx + uv;
}

void vs_convert(in uint id : SV_VERTEXID,
                inout float4 vpos : SV_POSITION,
                inout float2 uv : TEXCOORD0,
                inout float4 ofs[7] : TEXCOORD1)
{
    // Calculate texel offset of the mipped texture
    const float cLOD = log2(max(DSIZE.x, DSIZE.y)) - log2(ISIZE);
    const float2 uSize = rcp(DSIZE.xy / exp2(cLOD)) * uRadius;
    v2f_core(id, uv, vpos);

    for(int i = 0; i < 7; i++)
    {
        ofs[i].xy = Vogel2D(i, uv, uSize);
        ofs[i].zw = Vogel2D(7 + i, uv, uSize);
    }
}

void vs_filter(in uint id : SV_VERTEXID,
               inout float4 vpos : SV_POSITION,
               inout float4 ofs[8] : TEXCOORD0)
{
    const float2 uSize = rcp(ISIZE) * uRadius;
    float2 uv;
    v2f_core(id, uv, vpos);

    for(int i = 0; i < 8; i++)
    {
        ofs[i].xy = Vogel2D(i, uv, uSize);
        ofs[i].zw = Vogel2D(8 + i, uv, uSize);
    }
}

void vs_common(in uint id : SV_VERTEXID,
               inout float4 vpos : SV_POSITION,
               inout float2 uv : TEXCOORD0)
{
    v2f_core(id, uv, vpos);
}

/* [ Pixel Shaders ] */

float urand(float2 vpos)
{
    const float3 value = float3(52.9829189, 0.06711056, 0.00583715);
    return frac(value.x * frac(dot(vpos.xy, value.yz)));
}

float2 encode(float3 n)
{
    float f = rsqrt(8.0 * n.z + 8.0);
    return n.xy * f + 0.5;
}

float3 decode(float2 enc)
{
    float2 fenc = enc * 4.0 - 2.0;
    float f = dot(fenc, fenc);
    float g = sqrt(1.0 - f / 4.0);
    float3 n;
    n.xy = fenc * g;
    n.z = 1.0 - f / 2.0;
    return n;
}

float4 ps_source(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_Target
{
    float3 uImage = tex2D(s_color, uv.xy).rgb;
    float2 output = encode(normalize(uImage));

    // Vignette output if called
    const float2 aspectratio = BUFFER_WIDTH * BUFFER_RCP_HEIGHT;
    float2 coord = (uv - 0.5) * aspectratio * 2.0;
    float rf = length(coord) * uFalloff;
    float rf2_1 = mad(rf, rf, 1.0);

    float vigWeight = rcp(rf2_1 * rf2_1);
    vigWeight = (uInvert) ? 1.0 - vigWeight : vigWeight;

    float2 outputvignette = output * vigWeight;
    return (uVignette) ? float4(outputvignette, 0.0, 0.0) : float4(output, 0.0, 0.0);
}

void ps_convert(float4 vpos : SV_POSITION,
                float2 uv : TEXCOORD0,
                float4 ofs[7] : TEXCOORD1,
                out float4 r0 : SV_TARGET0,
                out float4 r1 : SV_TARGET1)
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

    // r0 = copy previous flow (.xy) and blurred frame (.zw) from last run
    // r1 = blur current frame, than blur + copy at ps_filter
    r0.xy = tex2D(s_cflow, uv).xy;
    r0.zw = tex2D(s_cframe, uv).xy;
    r1 = uImage;
}

float4 ps_filter(float4 vpos : SV_POSITION,
                 float4 ofs[8] : TEXCOORD0) : SV_Target
{
    const int cTaps = 16;
    const float uArea = Pi * (uRadius * uRadius) / uTaps;
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
    float4 cFrameBuffer = tex2D(s_cframe, uv);
    float4 pFrameBuffer = tex2D(s_pframe, uv);

    // Calculate optical flow without post neighborhood average
    float3 cFrame = decode(cFrameBuffer.xy);
    float3 pFrame = decode(pFrameBuffer.zw);

    float3 dFd;
    dFd.x = dot(ddx(cFrame), 1.0);
    dFd.y = dot(ddy(cFrame), 1.0);
    dFd.z = dot(cFrame - pFrame, 1.0);
    const float uRegularize = max(4.0 * pow(uConst * 1e-3, 2.0), 1e-10);
    float dConst = dot(dFd.xy, dFd.xy) + uRegularize;
    float2 cFlow = 0.0;

    for(int i = 0; i < uIter; i++)
    {
        float dCalc = dot(dFd.xy, cFlow) + dFd.z;
        cFlow = cFlow - ((dFd.xy * dCalc) / dConst);
    }

    // Smooth optical flow
    return lerp(cFlow, pFrameBuffer.xy, uBlend).xyxy;
}

float4 ps_output(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_Target
{
    float4 oBlur;
    float noise = urand(vpos.xy) * 2.0;
    const float samples = 1.0 / (16.0 - 1.0);
    float2 oFlow = tex2Dlod(s_cflow, float4(uv, 0.0, uDetail)).xy;
    oFlow = oFlow * rcp(ISIZE) * aRatio;
    oFlow *= uScale;

    for(int k = 0; k < 9; k++)
    {
        float2 calc = (noise + k * 2.0) * samples - 0.5;
        float4 uColor = tex2D(s_color, oFlow * calc + uv);
        oBlur = lerp(oBlur, uColor, rcp(float(k) + 1));
    }

    return (uDebug) ? float4(oFlow, 1.0, 1.0) : oBlur;
}

technique cMotionBlur
{
    pass cBlur
    {
        VertexShader = vs_common;
        PixelShader = ps_source;
        RenderTarget0 = r_buffer;
    }

    pass cCopyPrevious
    {
        VertexShader = vs_convert;
        PixelShader = ps_convert;
        RenderTarget0 = r_pframe;
        RenderTarget1 = r_cimage;
    }

    pass cBlurCopyFrame
    {
        VertexShader = vs_filter;
        PixelShader = ps_filter;
        RenderTarget0 = r_cframe;
    }

    pass cOpticalFlow
    {
        VertexShader = vs_common;
        PixelShader = ps_flow;
        RenderTarget0 = r_cflow;
    }

    pass cFlowBlur
    {
        VertexShader = vs_common;
        PixelShader = ps_output;
        SRGBWriteEnable = TRUE;
    }
}
