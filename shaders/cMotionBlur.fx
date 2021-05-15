
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to MartinBFFan and Pao on Discord for reporting bugs
    And BSD for bug propaganda and helping to solve my issue

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

uOption(uTargetFPS, float, "Flow Basic", "Target FPS", 60.00);
uOption(uThreshold, float, "Flow Basic", "Threshold",  0.000);
uOption(uForce,     float, "Flow Basic", "Force",      16.00);

uOption(uPrefilter,     int,   "Flow Advanced", "Prefilter LODs",     4);
uOption(uBlurRadius,    float, "Flow Advanced", "Prefilter Blur",     16.00);
uOption(uInterpolation, float, "Flow Advanced", "Temporal Sharpness", 0.950);

uOption(uPy0, float2, "Flow Pyramid Weights", "Fine",    float2(0.016, 5.000));
uOption(uPy1, float2, "Flow Pyramid Weights", "Level 2", float2(0.032, 4.000));
uOption(uPy2, float2, "Flow Pyramid Weights", "Level 3", float2(0.064, 3.000));
uOption(uPy3, float2, "Flow Pyramid Weights", "Level 4", float2(0.128, 2.000));
uOption(uPy4, float2, "Flow Pyramid Weights", "Level 5", float2(0.256, 1.000));
uOption(uPy5, float2, "Flow Pyramid Weights", "Level 6", float2(0.128, 2.000));
uOption(uPy6, float2, "Flow Pyramid Weights", "Level 7", float2(0.064, 3.000));
uOption(uPy7, float2, "Flow Pyramid Weights", "Level 8", float2(0.032, 4.000));
uOption(uPy8, float2, "Flow Pyramid Weights", "Coarse",  float2(0.016, 5.000));

uOption(uIntensity, float, "Automatic Exposure", "Intensity", 8.000);
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

texture2D r_color  : COLOR;
texture2D r_buffer { RSIZE; MipLevels = LOG2(DSIZE(2)) + 1; Format = R8; };
texture2D r_filter { Width = 256; Height = 256; MipLevels = 9; Format = R8; };
texture2D r_pframe { Width = 256; Height = 256; MipLevels = 9; Format = R8; };
texture2D r_cframe { Width = 256; Height = 256; MipLevels = 9; Format = R8; };
texture2D r_cflow  { Width = 256; Height = 256; MipLevels = 9; Format = RG16F; };
texture2D r_pflow  { Width = 256; Height = 256; MipLevels = 9; Format = RG16F; };
texture2D r_pluma  { Width = 256; Height = 256; MipLevels = 9; Format = R8; };

sampler2D s_color  { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; };
sampler2D s_filter { Texture = r_filter; };
sampler2D s_pframe { Texture = r_pframe; };
sampler2D s_cframe { Texture = r_cframe; };
sampler2D s_cflow  { Texture = r_cflow; };
sampler2D s_pflow  { Texture = r_pflow; };
sampler2D s_pluma  { Texture = r_pluma; };

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

/*
    [ Pixel Shaders ]

    Pixel Blur from lygia
    [https://github.com/patriciogonzalezvivo/lygia] [BSD-3]

    logExposure2D() from MJP's TheBakingLab
    [https://github.com/TheRealMJP/BakingLab] [MIT]

    ps_flow()'s ddx/ddy port of optical flow from PixelFlow
    [https://github.com/diwi/PixelFlow] [MIT]

    flow2D()'s Interleaved Gradient Noise from the following presentation
    [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]

    flow2D()'s blur centering from John Chapman
    [http://john-chapman-graphics.blogspot.com/2013/01/per-object-motion-blur.html]
*/

float logExposure2D(float aLuma)
{
    aLuma = max(aLuma, uLowClamp);
    float aExposure = log2(max(uKeyValue / aLuma, uLowClamp));
    return exp2(aExposure);
}

float4 flow2D(v2f input, float2 flow, float i)
{
    const float3 value = float3(52.9829189, 0.06711056, 0.00583715);
    float noise = frac(value.x * frac(dot(input.vpos.xy, value.yz)));

    const float samples = 1.0 / (16.0 - 1.0);
    float2 calc = (noise * 2.0 + i) * samples - 0.5;
    return tex2D(s_color, flow * calc + input.uv);
}

struct ps2mrt0
{
    float4 render0 : SV_TARGET0;
    float4 render1 : SV_TARGET1;
    float4 render2 : SV_TARGET2;
};

struct ps2mrt1
{
    float4 render0 : SV_TARGET0;
    float4 render1 : SV_TARGET1;
};

float2 random2D(float3 p3)
{
    const float3 random3 = float3(0.1031, 0.1030, 0.0973);
    const float tau = 6.2831853071795864769252867665590;
    p3 = frac(p3 * random3);
    p3 += dot(p3, p3.yzx + 19.19);
    return frac((p3.xx + p3.yz) * p3.zy) * float2(tau, 1.0);
}

float4 ps_source(v2f input) : SV_Target
{

    const float2 psize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    const float2 rsize = uBlurRadius * psize;
    float4 c;

    for (int i = 0; i < 4; ++i)
    {
        // Uniform sample the circle
        float2 r = random2D(float3(input.vpos.xy, i));
        float2 sc; sincos(r.xx, sc.x, sc.y);
        float2 cr = sc * sqrt(r.y);
        float4 color = tex2D(s_color, cr * rsize + input.uv);

        // Average the samples as we get em
        // https://blog.demofox.org/2016/08/23/incremental-averaging/
        c = lerp(c, color, rcp(i + 1));
    }

    return max(max(c.r, c.g), c.b);
}

ps2mrt0 ps_convert(v2f input)
{
    ps2mrt0 output;
    output.render0 = tex2D(s_buffer, input.uv);
    output.render1 = tex2D(s_cframe, input.uv);
    output.render2 = tex2D(s_cflow,  input.uv);
    return output;
}

float4 ps_filter(v2f input) : SV_Target
{
    float cLuma = tex2Dlod(s_filter, float4(input.uv, 0.0, LOG2(DSIZE(2)))).r;
    float pLuma = tex2D(s_pluma, input.uv).r;
    float aLuma = lerp(pLuma, cLuma, 0.5);

    float c = tex2D(s_buffer, input.uv).r;
    c = c * logExposure2D(aLuma);
    return saturate(exp(-c * uIntensity));
}

ps2mrt1 ps_flow(v2f input)
{
    ps2mrt1 output;

    // Calculate distance
    float cLuma = tex2Dlod(s_cframe, float4(input.uv, 0.0, uPrefilter)).r;
    float pLuma = tex2Dlod(s_pframe, float4(input.uv, 0.0, uPrefilter)).r;
    float cFrameTime = uTargetFPS / (1e+3 / uFrameTime);
    float dt = cLuma - pLuma;

    // Calculate gradients and optical flow
    float3 d;
    d.x = ddx(cLuma) + ddx(pLuma);
    d.y = ddy(cLuma) + ddy(pLuma);
    d.z = rsqrt(dot(d.xy, d.xy) + cFrameTime);
    float2 cFlow = uForce * dt * (d.xy * d.zz);

    // Threshold
    float2 pFlow = tex2D(s_pflow, input.uv).xy;
    float oFlow = sqrt(dot(cFlow, cFlow) + 1e-5);
    float nFlow = max(oFlow - uThreshold, 0.0);
    cFlow *= nFlow / oFlow;

    output.render0 = lerp(pFlow, cFlow, saturate(uInterpolation));
    output.render1 = tex2Dlod(s_filter, float4(input.uv, 0.0, LOG2(DSIZE(2))));
    return output;
}

float4 ps_output(v2f input) : SV_Target
{
    /*
        Build optical flow pyramid (oFlow)
        Fine mip = lowest contribution
        Coarse mip = highest contribution
    */

    float2 oFlow;
    oFlow += tex2Dlod(s_cflow, float4(input.uv, 0.0, 0.0)).xy * ldexp(uPy0.x, -uPy0.y);
    oFlow += tex2Dlod(s_cflow, float4(input.uv, 0.0, 1.0)).xy * ldexp(uPy1.x, -uPy1.y);
    oFlow += tex2Dlod(s_cflow, float4(input.uv, 0.0, 2.0)).xy * ldexp(uPy2.x, -uPy2.y);
    oFlow += tex2Dlod(s_cflow, float4(input.uv, 0.0, 3.0)).xy * ldexp(uPy3.x, -uPy3.y);
    oFlow += tex2Dlod(s_cflow, float4(input.uv, 0.0, 4.0)).xy * ldexp(uPy4.x, -uPy4.y);
    oFlow += tex2Dlod(s_cflow, float4(input.uv, 0.0, 5.0)).xy * ldexp(uPy5.x, -uPy5.y);
    oFlow += tex2Dlod(s_cflow, float4(input.uv, 0.0, 6.0)).xy * ldexp(uPy6.x, -uPy6.y);
    oFlow += tex2Dlod(s_cflow, float4(input.uv, 0.0, 7.0)).xy * ldexp(uPy7.x, -uPy7.y);
    oFlow += tex2Dlod(s_cflow, float4(input.uv, 0.0, 8.0)).xy * ldexp(uPy8.x, -uPy8.y);

    float4 oBlur;
    oBlur += flow2D(input, oFlow, 2.0) * exp2(-3.0);
    oBlur += flow2D(input, oFlow, 4.0) * exp2(-3.0);
    oBlur += flow2D(input, oFlow, 6.0) * exp2(-3.0);
    oBlur += flow2D(input, oFlow, 8.0) * exp2(-3.0);
    oBlur += flow2D(input, oFlow, 10.0) * exp2(-3.0);
    oBlur += flow2D(input, oFlow, 12.0) * exp2(-3.0);
    oBlur += flow2D(input, oFlow, 14.0) * exp2(-3.0);
    oBlur += flow2D(input, oFlow, 16.0) * exp2(-3.0);
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
