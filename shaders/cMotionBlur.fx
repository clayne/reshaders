
/*
    Motion sickness for and by the mentally sick

    [1] ps_source
    - Calculate brightness using max3()
    - Generate series of mipmaps to 1x1
    - Output to r_buffer with miplevels

    [2] ps_convert
    - RenderTarget0: Calculate average exposure
    - RenderTarget1: Copy boxed frame from previous ps_filter()
    - Render both to powers of 2 resolution to smooth miplevels

    [3] ps_filter
    - Turn average-exposured current frame into soft boxes
    - Copy current frame for ps_covert() in next frame

    [4] ps_flow
    - Calculate optical flow
    - Output 8-level mip pyramid

    [5] ps_output
    - Input and weigh 8-level optical flow pyramid
    - Blur
*/

uniform float uExposure <
    ui_category = "Auto Exposure";
    ui_label = "Exposure Bias";
    ui_type = "drag";
    ui_min = 0.0;
> = 2.048;

uniform float uThreshold <
    ui_category = "Optical Flow";
    ui_label = "Flow Threshold";
    ui_type = "drag";
    ui_min = 0.0;
> = 0.064;

uniform float uScale <
    ui_category = "Optical Flow";
    ui_label = "Flow Scale";
    ui_type = "drag";
    ui_min = 0.0;
> = 0.512;

uniform float uFrameTime < source = "frametime"; >;

// Round to nearest power of 2
// Help from Lord of Lunacy, KingEric1992, and Marty McFly

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
#define DSIZE(x)   1 << LOG2(RMAX(BUFFER_WIDTH / x, BUFFER_HEIGHT / x))

#define RPOW2(x) Width = DSIZE(x); Height = DSIZE(x) // get nearest power of 2 size
#define RSIZE(x) Width = BUFFER_WIDTH / x; Height = BUFFER_HEIGHT / x
#define RFILT(x) MinFilter = x; MagFilter = x; MipFilter = x

#ifndef MIP_PREFILTER
    #define MIP_PREFILTER 1.0
#endif

texture2D r_color  : COLOR;
texture2D r_buffer { RSIZE(2); RFILT(LINEAR); Format = R8;    MipLevels = LOG2(DSIZE(2)) + 1; };
texture2D r_filter { RPOW2(4); RFILT(LINEAR); Format = R8;    MipLevels = LOG2(DSIZE(4)) + 1; };
texture2D r_pframe { RPOW2(4); RFILT(LINEAR); Format = R8;    MipLevels = LOG2(DSIZE(4)) + 1; };
texture2D r_cframe { RPOW2(4); RFILT(LINEAR); Format = R8;    MipLevels = LOG2(DSIZE(4)) + 1; };
texture2D r_flow   { RPOW2(8); RFILT(LINEAR); Format = RG16F; MipLevels = LOG2(DSIZE(8)) + 1; };

sampler2D s_color  { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_buffer { Texture = r_buffer; };
sampler2D s_filter { Texture = r_filter; };
sampler2D s_pframe { Texture = r_pframe; };
sampler2D s_cframe { Texture = r_cframe; };
sampler2D s_flow   { Texture = r_flow; };

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

struct ps2mrt
{
    float4 target0 : SV_TARGET0;
    float4 target1 : SV_TARGET1;
};

float4 ps_source(v2f input) : SV_Target
{
    float4 c = tex2D(s_color, input.uv);
    return max(max(c.r, c.g), c.b);
}

ps2mrt ps_convert(v2f input)
{
    ps2mrt output;
    output.target0 = tex2D(s_buffer, input.uv);
    output.target1 = tex2D(s_cframe, input.uv);
    return output;
}

/*
    Quintic curve texture filtering from Inigo:
    [https://www.iquilezles.org/www/articles/texture/texture.htm]
*/

float4 filter2D(sampler2D src, float2 uv, float lod)
{
    const float2 size = tex2Dsize(src, lod);
    float2 p = uv * size + 0.5;
    float2 i = floor(p);
    float2 f = frac(p);
    p = i + f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    p = (p - 0.5) / max(size, 1e-5);
    return tex2Dlod(src, float4(p, 0.0, lod));
}

// Prefilter and copy frame

float4 ps_filter(v2f input) : SV_Target
{
    return filter2D(s_filter, input.uv, MIP_PREFILTER);
}

/*
    logExposure2D() from MJP's TheBakingLab
    https://github.com/TheRealMJP/BakingLab [MIT]

    ps_flow()'s ddx/ddy port of optical flow from PixelFlow
    [https://github.com/diwi/PixelFlow] [MIT]
*/

float logExposure2D(sampler src, float2 uv, float lod)
{
    float aLuma = tex2Dlod(src, float4(uv, 0.0, lod)).r;
    aLuma = max(aLuma, 1e-5);
    float aExposure = log2(max(0.18 / aLuma, 1e-5));

    float c = tex2D(src, uv).r;
    return saturate(c * exp2(aExposure + uExposure));
}

float4 ps_flow(v2f input) : SV_Target
{
    // Calculate distance
    float cLuma = logExposure2D(s_cframe, input.uv, LOG2(DSIZE(4)));
    float pLuma = logExposure2D(s_pframe, input.uv, LOG2(DSIZE(4)));
    float dt = cLuma - pLuma;

    // cFrameTime = calculate 1.0 / fps (shudder speed) multiplied by 2
    // Calculate gradients and optical flow
    float cFrameTime = rcp(1e+3 / uFrameTime) * 2.0;
    float3 d;
    d.x = ddx(cLuma) + ddx(pLuma);
    d.y = ddy(cLuma) + ddy(pLuma);
    d.z = rsqrt(dot(d.xy, d.xy) + cFrameTime);
    float2 cFlow = (uScale * dt) * (d.xy * d.zz);

    float cOld = sqrt(dot(cFlow.xy, cFlow.xy) + 1e-5);
    float cNew = max(cOld - uThreshold, 0.0);
    cFlow *= cNew / cOld;
    return cFlow.xyxy;
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
    for(int i = 0; i <= LOG2(DSIZE(4)); i++)
    {
        float oWeight = ldexp(1.0, -LOG2(DSIZE(4)) + i);
        oFlow += filter2D(s_flow, input.uv, i).xy * oWeight;
    }

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
        RenderTarget1 = r_pframe; // Store previous frame
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
        RenderTarget0 = r_flow;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_output;
        SRGBWriteEnable = TRUE;
    }
}
