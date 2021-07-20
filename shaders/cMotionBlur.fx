
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to
    - MartinBFFan and Pao on Discord for reporting bugs
    - BSD for bug propaganda and helping to solve my issue
    - Lord of Lunacy, KingEric1992, and Marty McFly for power of 2 function
    Notes:  Blurred previous + current frames must be 32Float textures.
            This makes the optical flow not suffer from noise + banding
    LOD Compute  - [https://john-chapman.github.io/2019/03/29/convolution.html]
    Noise        - [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
    Optical Flow - [https://dspace.mit.edu/handle/1721.1/6337]
    Pi Constant  - [https://github.com/microsoft/DirectX-Graphics-Samples] [MIT]
    Threshold    - [https://github.com/diwi/PixelFlow] [MIT]
    Vignette     - [https://github.com/keijiro/KinoVignette] [MIT]
    Vogel Disk   - [http://blog.marmakoide.org/?p=1]
*/

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax)    \
        uniform udata option <                                                  \
        ui_category = ucategory; ui_label = ulabel;                             \
        ui_type = utype; ui_min = umin; ui_max = umax;                          \
        > = uvalue

uOption(uThreshold, float, "slider", "Basic", "Threshold", 0.000, 0.000, 1.000);
uOption(uScale,     float, "slider", "Basic", "Scale",     4.000, 0.000, 8.000);
uOption(uRadius,    float, "slider", "Basic", "Prefilter", 8.000, 0.000, 16.00);

uOption(uSmooth, float, "slider", "Advanced", "Flow Smooth", 0.250, 0.000, 0.500);
uOption(uDetail, float, "slider", "Advanced", "Flow Mip",    5.900, 0.000, 8.000);
uOption(uDebug,  bool,  "radio",  "Advanced", "Debug",       false, 0, 0);

uOption(uVignette, bool,  "radio",  "Vignette", "Enable",    false, 0, 0);
uOption(uInvert,   bool,  "radio",  "Vignette", "Invert",    true,  0, 0);
uOption(uFalloff,  float, "slider", "Vignette", "Sharpness", 1.000, 0.000, 8.000);

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

#ifndef SET_BUFFER_RESOLUTION
    #define SET_BUFFER_RESOLUTION 256
#endif

static const float Pi = 3.1415926535897f;
static const float Epsilon = 1e-7;
static const int uTaps = 14;

texture2D r_color  : COLOR;
texture2D r_buffer { Width = DSIZE.x; Height = DSIZE.y; MipLevels = RSIZE; Format = RGB10A2; };
texture2D r_cImage { Width = SET_BUFFER_RESOLUTION; Height = SET_BUFFER_RESOLUTION; Format = RGB10A2; MipLevels = LOG2(SET_BUFFER_RESOLUTION) + 1; };
texture2D r_cframe { Width = SET_BUFFER_RESOLUTION; Height = SET_BUFFER_RESOLUTION; Format = RGBA32F; };
texture2D r_pframe { Width = SET_BUFFER_RESOLUTION; Height = SET_BUFFER_RESOLUTION; Format = RGBA32F; };
texture2D r_cflow  { Width = SET_BUFFER_RESOLUTION; Height = SET_BUFFER_RESOLUTION; Format = RG32F; MipLevels = LOG2(SET_BUFFER_RESOLUTION) + 1; };
texture2D r_pflow  { Width = SET_BUFFER_RESOLUTION; Height = SET_BUFFER_RESOLUTION; Format = RG32F; };

sampler2D s_color  { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cImage { Texture = r_cImage; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cframe { Texture = r_cframe; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_pframe { Texture = r_pframe; AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_cflow  { Texture = r_cflow;  AddressU = MIRROR; AddressV = MIRROR; };
sampler2D s_pflow  { Texture = r_pflow;  AddressU = MIRROR; AddressV = MIRROR; };

/* [ Vertex Shaders ] */

void v2f_core(  in uint id,
                inout float2 uv,
                inout float4 vpos)
{
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void vs_source(in uint id : SV_VERTEXID,
            inout float4 vpos : SV_POSITION,
            inout float2 uv : TEXCOORD0,
            inout float4 ofs : TEXCOORD1)
{
    // Calculate 3x3 gaussian kernel in 4 fetches
    v2f_core(id, uv, vpos);
    const float2 usize = rcp(float2(BUFFER_WIDTH, BUFFER_HEIGHT));
    ofs = uv.xyxy + float4(-usize.xy, usize.xy); // --++
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

void vs_convert(    in uint id : SV_VERTEXID,
                    inout float4 vpos : SV_POSITION,
                    inout float2 uv : TEXCOORD0,
                    inout float4 ofs[7] : TEXCOORD1)
{
    // Calculate texel offset of the mipped texture
    const float cLOD = log2(max(DSIZE.x, DSIZE.y)) - log2(SET_BUFFER_RESOLUTION);
    const float2 uSize = rcp(DSIZE.xy / exp2(cLOD)) * uRadius;
    v2f_core(id, uv, vpos);

    for(int i = 0; i < 7; i++)
    {
        ofs[i].xy = Vogel2D(i, uv, uSize);
        ofs[i].zw = Vogel2D(7 + i, uv, uSize);
    }
}

void vs_flow(   in uint id : SV_VERTEXID,
                inout float4 vpos : SV_POSITION,
                inout float4 uddx : TEXCOORD0,
                inout float4 uddy : TEXCOORD1)
{
    float2 uv;
    const float2 psize = rcp(SET_BUFFER_RESOLUTION);
    v2f_core(id, uv, vpos);
    uddx = uv.xxxy + float4(-1.0, 1.0, 0.0, 0.0) * psize.xxxy;
    uddy = uv.yyxx + float4(-1.0, 1.0, 0.0, 0.0) * psize.yyxx;
}

void vs_filter( in uint id : SV_VERTEXID,
                inout float4 vpos : SV_POSITION,
                inout float4 ofs[8] : TEXCOORD0)
{
    const float2 uSize = rcp(SET_BUFFER_RESOLUTION) * uRadius;
    float2 uv;
    v2f_core(id, uv, vpos);

    for(int i = 0; i < 8; i++)
    {
        ofs[i].xy = Vogel2D(i, uv, uSize);
        ofs[i].zw = Vogel2D(8 + i, uv, uSize);
    }
}

void vs_output( in uint id : SV_VERTEXID,
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

float4 ps_source(   float4 vpos : SV_POSITION,
                    float2 uv : TEXCOORD0,
                    float4 ofs : TEXCOORD1) : SV_Target
{
    float4 uImage;
    uImage += normalize(tex2D(s_color, ofs.xy)); // ++
    uImage += normalize(tex2D(s_color, ofs.zw)); // --
    uImage += normalize(tex2D(s_color, ofs.xw)); // -+
    uImage += normalize(tex2D(s_color, ofs.zy)); // +-
    uImage *= 0.25;
    float4 output = float4(uImage.rgb, 1.0);

    // Vignette output if called
    const float2 aspectratio = BUFFER_WIDTH * BUFFER_RCP_HEIGHT;
    float2 coord = (uv - 0.5) * aspectratio * 2.0;
    float rf = length(coord) * uFalloff;
    float rf2_1 = mad(rf, rf, 1.0);

    float vigWeight = rcp(rf2_1 * rf2_1);
    vigWeight = (uInvert) ? 1.0 - vigWeight : vigWeight;

    float4 outputvignette = output * vigWeight;
    return (uVignette) ? outputvignette : output;
}

void ps_convert(float4 vpos : SV_POSITION,
                float2 uv : TEXCOORD0,
                float4 ofs[7] : TEXCOORD1,
                out float4 render0 : SV_TARGET0,
                out float4 render1 : SV_TARGET1,
                out float4 render2 : SV_TARGET2)
{
    // Manually calculate LOD between texture and rendertarget size
    const float cLOD = log2(max(DSIZE.x, DSIZE.y)) - log2(SET_BUFFER_RESOLUTION);
    const int cTaps = 14;
    float uImage;
    float2 vofs[cTaps];

    for (int i = 0; i < 7; i++)
    {
        vofs[i] = ofs[i].xy;
        vofs[i + 7] = ofs[i].zw;
    }

    for (int j = 0; j < cTaps; j++)
    {
        float uColor = tex2Dlod(s_buffer, float4(vofs[j], 0.0, cLOD)).r;
        uImage = lerp(uImage, uColor, rcp(float(j) + 1));
    }

    render0 = tex2D(s_cflow, uv).rgrg; // Copy previous rendertarget from ps_flow()
    render1 = tex2D(s_cframe, uv); // Copy previous rendertarget from ps_filter()
    render2 = uImage; // Input downsampled current frame to scale and mip
}

float4 ps_filter(   float4 vpos : SV_POSITION,
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
        float4 uColor = tex2Dlod(s_cImage, float4(vofs[j], 0.0, uBias));
        uImage = lerp(uImage, uColor, rcp(float(j) + 1));
    }

    const float ubit = rcp(exp2(10.0) - 1.0); // 10bit
    return max(uImage, Epsilon);
}

float4 ps_flow( float4 vpos : SV_POSITION,
                float4 uddx : TEXCOORD0,
                float4 uddy : TEXCOORD1) : SV_Target
{
    // Calculate optical flow
    float3 cLuma = tex2D(s_cframe, uddx.zw).rgb; // [0, 0]
    float3 pLuma = tex2D(s_pframe, uddx.zw).rgb; // [0, 0]

    float3 dFdcx;
    dFdcx  = tex2D(s_cframe, uddx.yw).rgb; // [ 1, 0]
    dFdcx -= tex2D(s_cframe, uddx.xw).rgb; // [-1, 0]

    float3 dFdcy;
    dFdcy  = tex2D(s_cframe, uddy.zy).rgb; // [ 0, 1]
    dFdcy -= tex2D(s_cframe, uddy.zx).rgb; // [ 0,-1]

    float3 dFdpx;
    dFdpx  = tex2D(s_pframe, uddx.yw).rgb; // [ 1, 0]
    dFdpx -= tex2D(s_pframe, uddx.xw).rgb; // [-1, 0]

    float3 dFdpy;
    dFdpy  = tex2D(s_pframe, uddy.zy).rgb; // [ 0, 1]
    dFdpy -= tex2D(s_pframe, uddy.zx).rgb; // [ 0,-1]

    float2 dFdc;
    dFdc.x = dot(dFdcx, 1.0);
    dFdc.y = dot(dFdcy, 1.0);

    float2 dFdp;
    dFdp.x = dot(dFdpx, 1.0);
    dFdp.y = dot(dFdpy, 1.0);

    float3 dt = cLuma - pLuma;
    float dBrightness = dot(dFdp, dFdc) + dot(dt, 1.0);
    float dSmoothness = dot(dFdp, dFdp) + Epsilon;
    float2 cFlow = dFdc - dFdp * (dBrightness / dSmoothness);

    // Threshold and normalize
    float pFlow = sqrt(dot(cFlow, cFlow) + Epsilon);
    float nFlow = max(pFlow - uThreshold, 0.0);
    cFlow *= nFlow / pFlow;

    // Smooth optical flow
    float2 sFlow = tex2D(s_pflow, uddx.zw).rg; // [0, 0]
    return lerp(cFlow, sFlow, uSmooth).xyxy;
}

float4 ps_output(   float4 vpos : SV_POSITION,
                    float2 uv : TEXCOORD0) : SV_Target
{
    float2 oFlow = tex2Dlod(s_cflow, float4(uv, 0.0, uDetail)).rg;
    oFlow /= SET_BUFFER_RESOLUTION;
    oFlow *= uScale;

    float4 oBlur;
    float noise = urand(vpos.xy) * 2.0;
    const float samples = 1.0 / (16.0 - 1.0);

    for(int k = 0; k < 9; k++)
    {
        float2 calc = (noise + k * 2.0) * samples - 0.5;
        float4 uColor = tex2D(s_color, oFlow * calc + uv);
        oBlur = lerp(oBlur, uColor, rcp(float(k) + 1));
    }

    return (uDebug) ? float4(oFlow, 0.0, 0.0) : oBlur;
}

technique cMotionBlur
{
    pass cBlur
    {
        VertexShader = vs_source;
        PixelShader = ps_source;
        RenderTarget0 = r_buffer;
    }

    pass cCopyPrevious
    {
        VertexShader = vs_convert;
        PixelShader = ps_convert;
        RenderTarget0 = r_pflow;
        RenderTarget1 = r_pframe;
        RenderTarget2 = r_cImage;
    }

    pass cBlurCopyFrame
    {
        VertexShader = vs_filter;
        PixelShader = ps_filter;
        RenderTarget0 = r_cframe;
    }

    pass cOpticalFlow
    {
        VertexShader = vs_flow;
        PixelShader = ps_flow;
        RenderTarget0 = r_cflow;
    }

    pass cFlowBlur
    {
        VertexShader = vs_output;
        PixelShader = ps_output;
        SRGBWriteEnable = TRUE;
    }
}