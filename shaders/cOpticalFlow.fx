
/*
    This work is licensed under a Creative Commons Attribution 3.0 Unported License.
    https://creativecommons.org/licenses/by/3.0/us/
*/

#define uInit(x, y) ui_category = x; ui_label = y
#define uType(x) ui_type = x; ui_min = 0.0

uniform float uThreshold <
    uInit("Optical Flow Basic", "Threshold");
    uType("drag");
> = 0.050;

uniform float uForce <
    uInit("Optical Flow Basic", "Force");
    uType("drag");
> = 2.500;

uniform float uInterpolation <
    uInit("Optical Flow Advanced", "Temporal Sharpness");
    uType("drag");
> = 0.750;

uniform float uExposure <
    uInit("Optical Flow Advanced", "Exposure Intensity");
    uType("drag");
> = 2.000;

uniform float uPower <
    uInit("Optical Flow Advanced", "Flow Sharpness");
    uType("drag");
> = 1.000;

uniform float uLambda <
    uInit("Optical Flow Advanced", "Flow Time Factor");
    uType("drag");
> = 1.000;

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
#define RSIZE(x)   Width = BUFFER_WIDTH / x; Height = BUFFER_HEIGHT / x

texture2D r_color  : COLOR;
texture2D r_filter0 { RSIZE(2); Format = RG8; MipLevels = LOG2(DSIZE(2)) + 1; };
texture2D r_pframe0 { RSIZE(2); Format = R8;  MipLevels = LOG2(DSIZE(2)) + 1; };
texture2D r_cframe0 { RSIZE(2); Format = R8;  MipLevels = LOG2(DSIZE(2)) + 1; };
texture2D r_cflow0  { RSIZE(2); Format = RG16F; };
texture2D r_pflow0  { RSIZE(2); Format = RG16F; };

sampler2D s_color  { Texture = r_color; SRGBTexture = true; };
sampler2D s_filter { Texture = r_filter0; };
sampler2D s_pframe { Texture = r_pframe0; };
sampler2D s_cframe { Texture = r_cframe0; };
sampler2D s_cflow  { Texture = r_cflow0;  };
sampler2D s_pflow  { Texture = r_pflow0;  };

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

// Output the cframe we got from last frame

struct ps2mrt0
{
    float4 target0 : SV_TARGET0;
    float4 target1 : SV_TARGET1;
    float4 target2 : SV_TARGET2;
};

ps2mrt0 ps_copy(v2f input)
{
    ps2mrt0 output;
    float4 scolor = tex2D(s_color, input.uv);
    output.target0 = max(max(scolor.r, scolor.g), scolor.b);
    output.target1 = tex2D(s_cframe, input.uv).r;
    output.target2 = tex2D(s_cflow, input.uv).rg;
    return output;
}

// Copy frame

/*
    logExposure2D() from MJP's TheBakingLab
    https://github.com/TheRealMJP/BakingLab [MIT]
*/

float logExposure2D(float aLuma)
{
    aLuma = max(aLuma, 1e-2);
    float aExposure = log2(max(0.18 / aLuma, 1e-2));
    return exp2(aExposure + uExposure);
}

float4 ps_filter(v2f input) : SV_Target
{
    float cLuma = tex2Dlod(s_filter, float4(input.uv, 0.0, LOG2(DSIZE(2)))).r;
    float pLuma = tex2Dlod(s_cframe, float4(input.uv, 0.0, LOG2(DSIZE(2)))).r;
    float aLuma = lerp(pLuma, cLuma, 0.5);

    float c = tex2D(s_filter, input.uv).r;
    aLuma = logExposure2D(aLuma);
    return saturate(c * aLuma);
}

// Partial derivatives port of [https://github.com/diwi/PixelFlow] [MIT]

struct ps2mrt1
{
    float4 target0 : SV_TARGET0;
    float4 target1 : SV_TARGET1;
};

float4 ps_flow(v2f input) : SV_Target
{
    ps2mrt1 output;

    // Calculate distance (dt) and temporal derivative (df)
    float cLuma = tex2D(s_cframe, input.uv).r;
    float pLuma = tex2D(s_pframe, input.uv).r;
    float dt = cLuma - pLuma;

    // Calculate gradients and optical flow
    float3 d;
    d.x = ddx(cLuma) + ddx(pLuma);
    d.y = ddy(cLuma) + ddy(pLuma);
    d.z = rsqrt(dot(d.xy, d.xy) + uLambda);
    float2 cFlow = dt * (d.xy * d.zz);
    cFlow *= uForce;

    float cMag = sqrt(dot(cFlow, cFlow) + 1e-3);
    cMag = max(cMag, uThreshold);
    cMag = (cMag - uThreshold) / (1.0 - uThreshold);
    cMag = pow(abs(cMag), uPower);
    cFlow = normalize(cFlow) * min(max(cMag, 0.0), 1.0);

    float2 pFlow = tex2D(s_pflow, input.uv).rg;
    return lerp(pFlow, cFlow, uInterpolation).xyxy;
}

float4 ps_display(v2f input) : SV_Target
{
    return tex2D(s_cflow, input.uv).rgrg * float4(1.0, 1.0, 0.0, 0.0);
}

technique cOpticalFlow
{
    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_copy;
        RenderTarget0 = r_filter0;
        RenderTarget1 = r_pframe0;
        RenderTarget2 = r_pflow0;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_filter;
        RenderTarget0 = r_cframe0;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_flow;
        RenderTarget0 = r_cflow0;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_display;
        BlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        SRGBWriteEnable = TRUE;
    }
}
