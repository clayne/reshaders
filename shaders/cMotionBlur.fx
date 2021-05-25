
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

uOption(uLambda, float, "slider", "Flow Basic", "Lambda",    1.000, 0.000, 2.000);
uOption(uScale,  float, "slider", "Flow Basic", "Scale",     4.000, 0.000, 8.000);

uOption(uIntensity, float, "slider", "Flow Advanced", "Exposure Intensity", 2.000, 0.000, 4.000);
uOption(uFlowLOD,   float, "slider", "Flow Advanced", "Optical Flow LOD",   3.500, 0.000, 7.000);

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
texture2D r_buffer { RSIZE; MipLevels = LOG2(DSIZE(2)) + 1;    Format = R8;    };
texture2D r_pframe { Width = 128; Height = 128; MipLevels = 8; Format = RG16F; };
texture2D r_cframe { Width = 128; Height = 128; MipLevels = 8; Format = R16F;  };
texture2D r_cflow  { Width = 128; Height = 128; MipLevels = 8; Format = RG16F; };
texture2D r_pflow  { Width = 128; Height = 128; Format = RG16F; };
texture2D r_pluma  { Width = 128; Height = 128; Format = R16F;  };

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

struct v2f_median
{
    float4 vpos : SV_POSITION;
    float2 uv0 : TEXCOORD0;
    float4 uv1[2] : TEXCOORD1;
};

v2f_median vs_median(const uint id : SV_VertexID)
{
    v2f_median output;
    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    output.vpos = float4(coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    const float2 ts = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    const float3 d = ts.xyx * float3(1.0, 1.0, 0.0);
    output.uv0 = coord;
    output.uv1[0].xy = coord - d.xz;
    output.uv1[0].zw = coord + d.xz;
    output.uv1[1].xy = coord - d.zy;
    output.uv1[1].zw = coord + d.zy;
    return output;
}

/*
    [ Pixel Shaders ]
    Median Filter - [https://github.com/keijiro/KinoBloom] [MIT]
    aExposure     - [https://github.com/TheRealMJP/BakingLab] [MIT]
    Optical Flow  - [https://github.com/diwi/PixelFlow] [MIT]
    Pyramid HLSL  - [https://www.youtube.com/watch?v=VSSyPskheaE]
    Noise         - [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
    Blurs         - [http://john-chapman-graphics.blogspot.com/2013/01/per-object-motion-blur.html]
*/

struct ps2mrt
{
    float4 render0 : SV_TARGET0;
    float4 render1 : SV_TARGET1;
};

float max3(float3 c)
{
    return max(max(c.r, c.g), c.b);
}

// 3-tap median filter
float Median(float a, float b, float c)
{
    return a + b + c - min(min(a, b), c) - max(max(a, b), c);
}

float4 ps_source(v2f_median input) : SV_Target
{
    float s0 = max3(tex2D(s_color, input.uv0).rgb);
    float s1 = max3(tex2D(s_color, input.uv1[0].xy).rgb);
    float s2 = max3(tex2D(s_color, input.uv1[0].zw).rgb);
    float s3 = max3(tex2D(s_color, input.uv1[1].xy).rgb);
    float s4 = max3(tex2D(s_color, input.uv1[1].zw).rgb);
    return Median(Median(s0, s1, s2), s3, s4);
}

ps2mrt ps_convert(v2f input)
{
    ps2mrt output;
    output.render0.r = tex2D(s_buffer, input.uv).r;
    output.render0.g = tex2D(s_cframe, input.uv).r;
    output.render1 = tex2D(s_cflow, input.uv).rg;
    return output;
}

float exposure2D(float aLuma)
{
    aLuma = max(aLuma, 1e-8);
    float aExposure = log2(max(0.18 / aLuma, 1e-8));
    return exp2(aExposure + uIntensity);
}

float4 ps_filter(v2f input) : SV_Target
{
    float cLuma = tex2Dlod(s_pframe, float4(input.uv, 0.0, 8.0)).r;
    float pLuma = tex2D(s_pluma, input.uv).r;
    float aLuma = lerp(pLuma, cLuma, 0.5);
    float c = tex2D(s_buffer, input.uv).r;
    return saturate(c * exposure2D(aLuma));
}

void calcFlow(  in  float2 uCoord,
                in  float  uLOD,
                in  float2 uFlow,
                in  bool   uFine,
                out float2 oFlow)
{
    // Warp previous frame and calculate distance
    float pLuma = tex2Dlod(s_pframe, float4(uCoord + uFlow, 0.0, uLOD)).g;
    float cLuma = tex2Dlod(s_cframe, float4(uCoord, 0.0, uLOD)).r;
    float dt = cLuma - pLuma;

    // Calculate gradients and optical flow
    float3 d;
    d.x = ddx(cLuma) + ddx(pLuma);
    d.y = ddy(cLuma) + ddy(pLuma);
    d.xy *= 0.5;
    d.z = rsqrt(dot(d.xy, d.xy) + uLambda);
    float2 cFlow = dt * (d.xy * d.zz);
    oFlow = (uFine) ? cFlow : 2.0 * (cFlow + uFlow);
}

ps2mrt ps_flow(v2f input)
{
    ps2mrt output;
    float2 oFlow[6];
    calcFlow(input.uv, 7.0, 0.000000, false, oFlow[5]);
    calcFlow(input.uv, 6.0, oFlow[5], false, oFlow[4]);
    calcFlow(input.uv, 5.0, oFlow[4], false, oFlow[3]);
    calcFlow(input.uv, 4.0, oFlow[3], false, oFlow[2]);
    calcFlow(input.uv, 3.0, oFlow[2], false, oFlow[1]);
    calcFlow(input.uv, 2.0, oFlow[1], true,  oFlow[0]);
    float2 pFlow = tex2D(s_pflow, input.uv + oFlow[0]).xy;
    output.render0 = lerp(oFlow[0], pFlow, 0.5);
    output.render1 = tex2Dlod(s_pframe, float4(input.uv, 0.0, 8.0)).r;
    return output;
}

float4 flow2D(v2f input, float2 flow, float i)
{
    const float3 value = float3(52.9829189, 0.06711056, 0.00583715);
    float cNoise = frac(value.x * frac(dot(input.vpos.xy, value.yz)));

    const float samples = 1.0 / (16.0 - 1.0);
    float2 calc = (cNoise * 2.0 + i) * samples - 0.5;
    return tex2D(s_color, (uScale * flow) * calc + input.uv);
}

float4 ps_output(v2f input) : SV_Target
{
    float4 oBlur;
    float2 oFlow = tex2Dlod(s_cflow, float4(input.uv, 0.0, uFlowLOD)).xy;
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
        VertexShader = vs_median;
        PixelShader = ps_source;
        RenderTarget0 = r_buffer;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_convert;
        RenderTarget0 = r_pframe;
        RenderTarget1 = r_pflow;
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