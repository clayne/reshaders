
/*
    Optical flow motion blur using color by Brimson

    [1] ps_source
    - Calculate brightness using max3()
    - Output to r_buffer with miplevels to 1x1

    [2] ps_convert
    - RenderTarget0: Input downsampled current frame to scale and mip
    - RenderTarget1: Copy boxed frame from previous ps_filter()
    - RenderTarget2: Copy optical flow from previous ps_flow()
    - Render both to powers of 2 resolution to smooth miplevels

    [3] ps_filter
    - Get 1x1 mip from power of 2 current frame
    - Get 1x1 mip from previous luma
    - Apply adaptive exposure to downsampled current frame

    [4] ps_flow
    - Calculate optical flow
    - RenderTarget0: Output optical flow pyramid
    - RenderTarget1: Store current 1x1 luma for next frame

    [5] ps_output
    - Input and weigh optical flow pyramid
    - Blur
*/

#define uOption(option, type, category, label, value) \
        uniform type option <                         \
        ui_category = category; ui_label = label;     \
        ui_type = "drag"; ui_min = 0.0; 			  \
        > = value

uniform float uFrameTime < source = "frametime"; >;

uOption(uTargetFPS, float, "Specific", "Target FPS", 60.00);

uOption(uThreshold, float, "Optical Flow Basic", "Threshold", 0.040);
uOption(uForce,     float, "Optical Flow Basic", "Force",     8.000);

uOption(uPrefilter,     int,   "Optical Flow Advanced", "Prefilter LOD Bias", 1);
uOption(uInterpolation, float, "Optical Flow Advanced", "Temporal Sharpness", 0.750);
uOption(uPower,         float, "Optical Flow Advanced", "Flow Power",         1.000);

uOption(uPy0, float, "Optical Flow Pyramid", "Level 0 Weight", 0.001);
uOption(uPy1, float, "Optical Flow Pyramid", "Level 1 Weight", 0.002);
uOption(uPy2, float, "Optical Flow Pyramid", "Level 2 Weight", 0.004);
uOption(uPy3, float, "Optical Flow Pyramid", "Level 3 Weight", 0.008);
uOption(uPy4, float, "Optical Flow Pyramid", "Level 4 Weight", 0.016);
uOption(uPy5, float, "Optical Flow Pyramid", "Level 5 Weight", 0.032);
uOption(uPy6, float, "Optical Flow Pyramid", "Level 6 Weight", 0.064);
uOption(uPy7, float, "Optical Flow Pyramid", "Level 7 Weight", 0.128);
uOption(uPy8, float, "Optical Flow Pyramid", "Level 8 Weight", 0.256);

uOption(uIntensity, float, "Automatic Exposure", "Intensity", 2.000);
uOption(uKeyValue,  float, "Automatic Exposure", "Key Value", 0.180);
uOption(uLowClamp,  float, "Automatic Exposure", "Low Clamp", 0.001);

/*
    Round to nearest power of 2
    Help from Lord of Lunacy, KingEric1992, and Marty McFly
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

#define RMAX(x, y) x ^ ((x ^ y) & -(x < y)) // max(x, y)
#define DSIZE(x)   1 << LOG2(RMAX(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2))
#define RSIZE      Width = BUFFER_WIDTH / 2; Height = BUFFER_HEIGHT / 2
#define RINIT      Width = 256; Height = 256; MipLevels = 9 // get nearest power of 2 size

texture2D r_color  : COLOR;
texture2D r_buffer { RSIZE; Format = R8; MipLevels = LOG2(DSIZE(2)) + 1; };
texture2D r_filter { RINIT; Format = R8; };
texture2D r_cframe { RINIT; Format = R8; };
texture2D r_pframe { RINIT; Format = R8; };
texture2D r_cflow  { RINIT; Format = RG16F; };
texture2D r_pflow  { RINIT; Format = RG16F; };
texture2D r_pluma  { RINIT; Format = R8; };

#define SFILT(x) MinFilter = x; MagFilter = x; MipFilter = x
sampler2D s_color  { Texture = r_color;  SFILT(LINEAR); SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; SFILT(LINEAR); };
sampler2D s_filter { Texture = r_filter; SFILT(LINEAR); };
sampler2D s_cframe { Texture = r_cframe; SFILT(LINEAR); };
sampler2D s_pframe { Texture = r_pframe; SFILT(LINEAR); };
sampler2D s_cflow  { Texture = r_cflow;  SFILT(LINEAR); };
sampler2D s_pflow  { Texture = r_pflow;  SFILT(LINEAR); };
sampler2D s_pluma  { Texture = r_pluma;  SFILT(LINEAR); };

/* [ Vertex Shaders ] */

struct v2f
{
    float4 vpos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

v2f vs_common(const uint id : SV_VertexID)
{
    v2f output;
    output.uv.x = (id == 2) ? 2.0 : 0.0;
    output.uv.y = (id == 1) ? 2.0 : 0.0;
    output.vpos = float4(output.uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return output;
}

/* [ Pixel Shaders ] */

float4 ps_source(v2f input) : SV_Target
{
    float4 c = tex2D(s_color, input.uv);
    return max(max(c.r, c.g), c.b);
}

struct ps2mrt0
{
    float4 target0 : SV_TARGET0;
    float4 target1 : SV_TARGET1;
    float4 target2 : SV_TARGET2;
};

ps2mrt0 ps_convert(v2f input)
{
    ps2mrt0 output;
    output.target0 = tex2D(s_buffer, input.uv); // Store unfiltered frame
    output.target1 = tex2D(s_cframe, input.uv); // Store previous frame
    output.target2 = tex2D(s_cflow,  input.uv); // Store previous flow
    return output;
}

/*
    logExposure2D() from MJP's TheBakingLab
    https://github.com/TheRealMJP/BakingLab [MIT]
*/

float logExposure2D(float aLuma)
{
    aLuma = max(aLuma, uLowClamp);
    float aExposure = log2(max(uKeyValue / aLuma, uLowClamp));
    return exp2(aExposure + uIntensity);
}

float4 ps_filter(v2f input) : SV_Target
{
    float cLuma = tex2Dlod(s_filter, float4(input.uv, 0.0, LOG2(DSIZE(2)))).r;
    float pLuma = tex2D(s_pluma, input.uv).r;
    float aLuma = lerp(pLuma, cLuma, 0.5);

    float c = tex2D(s_buffer, input.uv).r;
    return saturate(c * logExposure2D(aLuma));
}

/*
    Quintic curve texture filtering from Inigo:
    [https://www.iquilezles.org/www/articles/texture/texture.htm]

    ps_flow()'s ddx/ddy port of optical flow from PixelFlow
    [https://github.com/diwi/PixelFlow] [MIT]

    Threshold extension from ofxFlowTools
    [https://github.com/moostrik/ofxFlowTools] [MIT]
*/

float4 filter2D(sampler2D src, float2 uv, int lod)
{
    const float2 size = tex2Dsize(src, lod);
    float2 p = uv * size + 0.5;
    float2 i = floor(p);
    float2 f = frac(p);
    p = i + f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    p = (p - 0.5) / max(size, 1e-5);
    return tex2Dlod(src, float4(p, 0.0, lod));
}

struct ps2mrt1
{
    float4 target0 : SV_TARGET0;
    float4 target1 : SV_TARGET1;
};

ps2mrt1 ps_flow(v2f input)
{
    ps2mrt1 output;

    // Calculate distance (dt) and temporal derivative (df)
    float cLuma = filter2D(s_cframe, input.uv, uPrefilter).r;
    float pLuma = filter2D(s_pframe, input.uv, uPrefilter).r;
    float cFrameTime = uTargetFPS / (1e+3 / uFrameTime);
    float dt = cLuma - pLuma;

    // Calculate gradients and optical flow
    float3 d;
    d.x = ddx(cLuma) + ddx(pLuma);
    d.y = ddy(cLuma) + ddy(pLuma);
    d.z = rsqrt(dot(d.xy, d.xy) + 1.0);
    float2 cFlow = dt * (d.xy * d.zz);
    cFlow *= uForce;

    float cMag = length(cFlow);
    cMag = max(cMag, uThreshold);
    cMag = (cMag - uThreshold) / (1.0 - uThreshold);
    cMag = saturate(pow(abs(cMag), uPower) + 1e-5);
    cFlow = normalize(cFlow) * cMag;

    float2 pFlow = tex2D(s_pflow, input.uv).rg;
    output.target0 = lerp(pFlow, cFlow, uInterpolation).xyxy;
    output.target1 = tex2Dlod(s_filter, float4(input.uv, 0.0, LOG2(DSIZE(2)))).r;
    return output;
}

/*
    flow2D()'s Interleaved Gradient Noise from the following presentation
    [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]

    flow2D()'s blur centering from John Chapman
    [http://john-chapman-graphics.blogspot.com/2013/01/per-object-motion-blur.html]
*/

float4 flow2D(v2f input, float2 flow, float i)
{
    const float3 value = float3(52.9829189, 0.06711056, 0.00583715);
    const float samples = 1.0 / (16.0 - 1.0);

    float noise = frac(value.x * frac(dot(input.vpos.xy, value.yz)));
    float2 calc = (noise * 2.0 + i) * samples - 0.5;
    return tex2D(s_color, flow * calc + input.uv);
}

float4 ps_output(v2f input) : SV_Target
{
    /*
        Build optical flow pyramid (oFlow)
        Fine mip = lowest contribution
        Coarse mip = highest contribution
    */

    float2 oFlow = 0.0;
    oFlow += filter2D(s_cflow, input.uv, 0).xy * uPy0;
    oFlow += filter2D(s_cflow, input.uv, 1).xy * uPy1;
    oFlow += filter2D(s_cflow, input.uv, 2).xy * uPy2;
    oFlow += filter2D(s_cflow, input.uv, 3).xy * uPy3;
    oFlow += filter2D(s_cflow, input.uv, 4).xy * uPy4;
    oFlow += filter2D(s_cflow, input.uv, 5).xy * uPy5;
    oFlow += filter2D(s_cflow, input.uv, 6).xy * uPy6;
    oFlow += filter2D(s_cflow, input.uv, 7).xy * uPy7;
    oFlow += filter2D(s_cflow, input.uv, 8).xy * uPy8;

    const float kWeights = 1.0 / 8.0;
    float4 oBlur = 0.0;
    oBlur += flow2D(input, oFlow, 2.0) * kWeights;
    oBlur += flow2D(input, oFlow, 4.0) * kWeights;
    oBlur += flow2D(input, oFlow, 6.0) * kWeights;
    oBlur += flow2D(input, oFlow, 8.0) * kWeights;
    oBlur += flow2D(input, oFlow, 10.0) * kWeights;
    oBlur += flow2D(input, oFlow, 12.0) * kWeights;
    oBlur += flow2D(input, oFlow, 14.0) * kWeights;
    oBlur += flow2D(input, oFlow, 16.0) * kWeights;
    return oBlur;
}

technique cMotionBlur
{
    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_source;
        RenderTarget0 = r_buffer;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_convert;
        RenderTarget0 = r_filter;
        RenderTarget1 = r_pframe;
        RenderTarget2 = r_pflow;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_filter;
        RenderTarget0 = r_cframe;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_flow;
        RenderTarget0 = r_cflow;
        RenderTarget1 = r_pluma;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_output;
        SRGBWriteEnable = TRUE;
    }
}
