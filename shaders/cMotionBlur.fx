
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to MartinBFFan and Pao on Discord for reporting bugs
    And BSD for bug propaganda and helping to solve my issue

    [1] ps_source
    - Calculate brightness using max3()
    - Output to r_buffer with miplevels to 1x1

    [2] ps_convert
    - RenderTarget0.r: Input downsampled current frame to scale and mip
    - RenderTarget0.g: Copy boxed frame from previous ps_filter()
    - RenderTarget1: Copy optical flow from previous ps_flow()
    - Render both to powers of 2 resolution to smooth miplevels

    [3] ps_filter
    - Get 1x1 mip from power of 2 current frame
    - Get 1x1 mip from previous luma
    - Apply adaptive exposure to downsampled current frame

    [4] ps_flow
    - Calculate optical flow
    - RenderTarget0: Output optical flow
    - RenderTarget1: Store current 1x1 luma for next frame

    [5] ps_output
    - Input optical flow with mip bias for smoothing
    - Blur
*/

#define uOption(option, udata, utype, ucategory, ulabel, uvalue, umin, umax)    \
        uniform udata option <                                                  \
        ui_category = ucategory; ui_label = ulabel;                             \
        ui_type = utype; ui_min = umin; ui_max = umax;                          \
        > = uvalue

uOption(uThreshold, float, "slider", "Flow Basic", "Threshold", 0.002, 0.000, 0.100);
uOption(uScale,     float, "slider", "Flow Basic", "Scale",     4.000, 0.000, 8.000);

uOption(uIntensity, float, "slider", "Flow Advanced", "Exposure Intensity", 2.000, 0.000, 4.000);
uOption(uRadius,    float, "slider", "Flow Advanced", "Prefilter Radius",   16.00, 0.000, 32.00);
uOption(uSmooth,    float, "slider", "Flow Advanced", "Flow Smoothing",     0.500, 0.000, 0.500);
uOption(uDetail,    int,   "slider", "Flow Advanced", "Optical Flow LOD",   3, 0, 6);

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
texture2D r_buffer { RSIZE; MipLevels = LOG2(DSIZE(2)) + 1;  Format = R8;    };
texture2D r_pframe { Width = 64; Height = 64; MipLevels = 7; Format = RG16F; };
texture2D r_cframe { Width = 64; Height = 64; MipLevels = 7; Format = RG16F; };
texture2D r_cflow  { Width = 64; Height = 64; MipLevels = 7; Format = RG16F; };
texture2D r_pflow  { Width = 64; Height = 64; Format = RG16F; };
texture2D r_pluma  { Width = 64; Height = 64; Format = R16F; };

sampler2D s_color  { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; };
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
    Disk Blur    - [https://github.com/spite/Wagner] [MIT]
    Blur Average - [https://blog.demofox.org/2016/08/23/incremental-averaging/]
    Exposure     - [https://john-chapman.github.io/2017/08/23/dynamic-local-exposure.html]
    Optical Flow - [https://github.com/diwi/PixelFlow] [MIT]
    Pyramid HLSL - [https://www.youtube.com/watch?v=VSSyPskheaE]
    Noise        - [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
    Cubic Filter - [https://github.com/haasn/libplacebo/blob/master/src/shaders/sampling.c] [GPL 2.1]
    Blurs        - [http://john-chapman-graphics.blogspot.com/2013/01/per-object-motion-blur.html]
*/

struct ps2mrt
{
    float4 render0 : SV_TARGET0;
    float4 render1 : SV_TARGET1;
    float4 render2 : SV_TARGET2;
};

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

    float4 uOutput = 0.0;
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
        uOutput = lerp(uOutput, uColor, rcp(i + 1));
    }

    float uImage = max(max(uOutput.r, uOutput.g), uOutput.b);
    return max(sqrt(uImage), 1e-5);
}

ps2mrt ps_convert(v2f input)
{
    ps2mrt output;
    output.render0.r = tex2D(s_buffer, input.uv).r;
    output.render0.g = tex2D(s_cframe, input.uv).r;
    output.render1 = tex2D(s_cflow, input.uv).rg;
    output.render2 = tex2D(s_cframe, input.uv).g;
    return output;
}

float4 ps_filter(v2f input) : SV_Target
{
    float cLuma = tex2Dlod(s_pframe, float4(input.uv, 0.0, 6.0)).r;
    float pLuma = tex2D(s_pluma, input.uv).r;
    float aLuma = lerp(cLuma, pLuma, 0.5f);

    float ev100 = log2(aLuma * 100.0 / 12.5);
    ev100 -= uIntensity;
    float aExposure = rcp(1.2 * exp2(ev100));
    float oColor = tex2D(s_buffer, input.uv).r;

    float2 output;
    output.r = saturate(oColor * aExposure);
    output.g = aLuma;
    return output.xyxy;
}

void calcFlow(  in float2 uCoord, in float uLevel, in float2 uFlow, in bool uFine,
                out float2 oFlow)
{
    // Warp previous frame and calculate distance
    float pLuma = tex2Dlod(s_pframe, float4(uCoord + uFlow, 0.0, uLevel)).g;
    float cLuma = tex2Dlod(s_cframe, float4(uCoord, 0.0, uLevel)).r;
    float dt = (cLuma - pLuma) * (0.125 / 2.0);

    // Calculate gradients and optical flow
    float3 d;
    d.xy  = float2(ddx(cLuma), ddy(cLuma));
    d.xy += float2(ddx(pLuma), ddy(pLuma));
    d.z = rsqrt(dot(d.xy, d.xy) + 1e-5);
    float2 cFlow = dt * (d.xy * d.zz);
    oFlow = (uFine) ? cFlow : (cFlow + uFlow) * 2.0;
}

float4 ps_flow(v2f input) : SV_Target
{
    float2 oFlow[7];
    calcFlow(input.uv, 6.0, 0.000000, false, oFlow[6]);
    calcFlow(input.uv, 5.0, oFlow[6], false, oFlow[5]);
    calcFlow(input.uv, 4.0, oFlow[5], false, oFlow[4]);
    calcFlow(input.uv, 3.0, oFlow[4], false, oFlow[3]);
    calcFlow(input.uv, 2.0, oFlow[3], false, oFlow[2]);
    calcFlow(input.uv, 1.0, oFlow[2], false, oFlow[1]);
    calcFlow(input.uv, 0.0, oFlow[1], true,  oFlow[0]);
    float cFlow = sqrt(dot(oFlow[0], oFlow[0]) + 1e-5);
    float nFlow = max(cFlow - uThreshold, 0.0);
    oFlow[0] *= nFlow / cFlow;
    float2 pFlow = tex2D(s_pflow, input.uv + oFlow[0]).xy;
    return lerp(oFlow[0], pFlow, uSmooth).xyxy;
}

float4 flow2D(v2f input, float2 flow, float i)
{
    const float samples = 1.0 / (16.0 - 1.0);
    float2 calc = (nrand(input.vpos.xy) * 2.0 + i) * samples - 0.5;
    return tex2D(s_color, (uScale * flow) * calc + input.uv);
}

float4 calcweights(float s)
{
    const float4 w1 = float4(-0.5, 0.1666, 0.3333, -0.3333);
    const float4 w2 = float4( 1.0, 0.0, -0.5, 0.5);
    const float4 w3 = float4(-0.6666, 0.0, 0.8333, 0.1666);
    float4 t = mad(w1, s, w2);
    t = mad(t, s, w2.yyzw);
    t = mad(t, s, w3);
    t.xy = mad(t.xy, rcp(t.zw), 1.0);
    t.xy += float2(s, -s);
    return t;
}

float4 ps_output(v2f input) : SV_Target
{
    const float2 texsize = tex2Dsize(s_cflow, uDetail);
    const float2 pt = 1.0 / texsize;
    const float4 po = float4(-pt.x, pt.x, -pt.y, pt.y);
    float2 fcoord = frac(input.uv * texsize + 0.5);
    float4 parmx = calcweights(fcoord.x);
    float4 parmy = calcweights(fcoord.y);
    float4 cdelta = float4(parmx.rg, parmy.rg).xzyw * po;
    // first y-interpolation
    float2 ar = tex2Dlod(s_cflow, float4(input.uv + cdelta.xy, 0.0, uDetail)).xy;
    float2 ag = tex2Dlod(s_cflow, float4(input.uv + cdelta.xw, 0.0, uDetail)).xy;
    float2 ab = lerp(ag, ar, parmy.b);
    // second y-interpolation
    float2 br = tex2Dlod(s_cflow, float4(input.uv + cdelta.zy, 0.0, uDetail)).xy;
    float2 bg = tex2Dlod(s_cflow, float4(input.uv + cdelta.zw, 0.0, uDetail)).xy;
    float2 aa = lerp(bg, br, parmy.b);
    // x-interpolation
    float2 oFlow = lerp(aa, ab, parmx.b);

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
        RenderTarget1 = r_pflow;
        RenderTarget2 = r_pluma;
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
