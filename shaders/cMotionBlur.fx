
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to MartinBFFan and Pao on Discord for reporting bugs
    And BSD for bug propaganda and helping to solve my issue
*/

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax)    \
        uniform udata option <                                                  \
        ui_category = ucategory; ui_label = ulabel;                             \
        ui_type = utype; ui_min = umin; ui_max = umax;                          \
        > = uvalue

uOption(uThreshold, float, "slider", "Basic",    "Threshold",   0.010, 0.000, 0.020);
uOption(uScale,     float, "slider", "Basic",    "Scale",       0.020, 0.000, 0.040);
uOption(uRadius,    float, "slider", "Basic",    "Prefilter",   64.00, 0.000, 256.0);

uOption(uIntensity, float, "slider", "Advanced", "Exposure",    2.000, 0.000, 4.000);
uOption(uSmooth,    float, "slider", "Advanced", "Flow Smooth", 0.100, 0.000, 0.500);
uOption(uDetail,    float, "slider", "Advanced", "Flow Blur",   2.750, 0.000, 6.000);

#ifndef PREFILTER_BIAS
    #define PREFILTER_BIAS 1.5
#endif

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
texture2D r_buffer { RSIZE; MipLevels = LOG2(DSIZE(2)) + 1;  Format = R32F;  };
texture2D r_cflow  { Width = 64; Height = 64; MipLevels = 7; Format = RG32F; };
texture2D r_cframe { Width = 64; Height = 64; Format = RG32F;   };
texture2D r_pframe { Width = 64; Height = 64; Format = RGBA32F; };

sampler2D s_color  { Texture = r_color;  SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; MipLODBias = PREFILTER_BIAS; };
sampler2D s_cflow  { Texture = r_cflow;  };
sampler2D s_cframe { Texture = r_cframe; };
sampler2D s_pframe { Texture = r_pframe; };

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
    Noise Blur   - [https://github.com/patriciogonzalezvivo/lygia] [BSD-3]
    Blur Average - [https://blog.demofox.org/2016/08/23/incremental-averaging/]
    Exposure     - [https://john-chapman.github.io/2017/08/23/dynamic-local-exposure.html]
    Optical Flow - [https://core.ac.uk/download/pdf/148690295.pdf]
    Threshold    - [https://github.com/diwi/PixelFlow] [MIT]
    Noise        - [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
    Blurs        - [http://john-chapman-graphics.blogspot.com/2013/01/per-object-motion-blur.html]
*/

float nrand(float2 n)
{
    const float3 value = float3(52.9829189, 0.06711056, 0.00583715);
    return frac(value.x * frac(dot(n.xy, value.yz)));
}

float2 rotate2D(float2 p, float a)
{
    float2 output;
    float2 sc;
    sincos(a, sc.x, sc.y);
    output.x = dot(p, float2(sc.y, -sc.x));
    output.y = dot(p, float2(sc.x,  sc.y));
    return output.xy;
}

float4 ps_source(v2f input) : SV_Target
{
    const int uTaps = 12;
    const float uSize = uRadius;

    float2 cTaps[uTaps];
    cTaps[0]  = float2(-0.326,-0.406);
    cTaps[1]  = float2(-0.840,-0.074);
    cTaps[2]  = float2(-0.696, 0.457);
    cTaps[3]  = float2(-0.203, 0.621);
    cTaps[4]  = float2( 0.962,-0.195);
    cTaps[5]  = float2( 0.473,-0.480);
    cTaps[6]  = float2( 0.519, 0.767);
    cTaps[7]  = float2( 0.185,-0.893);
    cTaps[8]  = float2( 0.507, 0.064);
    cTaps[9]  = float2( 0.896, 0.412);
    cTaps[10] = float2(-0.322,-0.933);
    cTaps[11] = float2(-0.792,-0.598);

    float4 uImage;
    float  uRand = 6.28 * nrand(input.vpos.xy);
    float4 uBasis;
    uBasis.xy = rotate2D(float2(1.0, 0.0), uRand);
    uBasis.zw = rotate2D(float2(0.0, 1.0), uRand);

    [unroll]
    for (int i = 0; i < uTaps; i++)
    {
        float2 ofs = cTaps[i];
        ofs.x = dot(ofs, uBasis.xz);
        ofs.y = dot(ofs, uBasis.yw);
        float2 uv = input.uv + uSize * ofs / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
        float4 uColor = tex2D(s_color, uv);
        uImage = lerp(uImage, uColor, rcp(i + 1));
    }

    return max(max(uImage.r, uImage.g), uImage.b);
}

float4 ps_convert(v2f input) : SV_Target
{
    float4 output;
    output.xy = tex2D(s_cflow, input.uv).rg; // Copy optical flow from previous ps_flow()
    output.z  = tex2D(s_cframe, input.uv).r; // Copy exposed frame from previous ps_filter()
    output.w  = max(tex2D(s_buffer, input.uv).r, 1e-5); // Input downsampled current frame to scale and mip
    return output;
}

float4 ps_filter(v2f input) : SV_Target
{
    float aLuma = tex2Dlod(s_pframe, float4(input.uv, 0.0, 8.0)).w;
    aLuma = exp(aLuma);
    float ev100 = log2(aLuma * 100.0 / 12.5) - uIntensity;
    ev100 = rcp(1.2 * exp2(ev100));
    float oColor = tex2D(s_pframe, input.uv).w;
    return saturate(oColor * ev100);
}

float4 ps_flow(v2f input) : SV_Target
{
    // Calculate distance
    float pLuma = tex2D(s_pframe, input.uv).z;
    float cLuma = tex2D(s_cframe, input.uv).r;
    float dt = cLuma - pLuma;

    float2 dFdp = float2(ddx(pLuma), ddy(pLuma));
    float2 dFdc = float2(ddx(cLuma), ddy(cLuma));

    // Calculate gradients and optical flow
    float p = dot(dFdp, dFdc) + dt;
    float d = dot(dFdp, dFdp) + 1e-5;
    float2 cFlow = dFdc - dFdp * (p / d);

    // Threshold
    float pFlow = sqrt(dot(cFlow, cFlow) + 1e-5);
    float nFlow = max(pFlow - uThreshold, 0.0);
    cFlow *= nFlow / pFlow;

    // Smooth optical flow
    float2 sFlow = tex2D(s_pframe, input.uv).xy;
    return lerp(cFlow, sFlow, uSmooth).xyxy;
}

float4 flow2D(v2f input, float2 flow, float i)
{
    float noise = nrand(input.vpos.xy);
    const float samples = 1.0 / (16.0 - 1.0);
    float2 calc = (noise * 2.0 + i) * samples - 0.5;
    return tex2D(s_color, (uScale * flow) * calc + input.uv);
}

float4 ps_output(v2f input) : SV_Target
{
    float2 oFlow = tex2Dlod(s_cflow, float4(input.uv, 0.0, uDetail)).xy;
    float4 oBlur;

    [unroll]
    for(int i = 0; i < 9; i++)
    {
        float4 uColor = flow2D(input, oFlow, float(i * 2));
        oBlur = lerp(oBlur, uColor, rcp(i + 1));
    }

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
        RenderTarget0 = r_pframe;
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
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_output;
        SRGBWriteEnable = TRUE;
    }
}
