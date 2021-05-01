
/*
    This work is licensed under (CC BY-NC-SA 3.0)
    https://creativecommons.org/licenses/by-nc-sa/3.0/
*/

uniform float kLambda <
    ui_label = "Lambda";
    ui_type = "drag";
> = 0.064;

uniform float kScale <
    ui_label = "Scale";
    ui_type = "drag";
> = 0.128;

#ifndef MIP_PREFILTER
    #define MIP_PREFILTER 4.0
#endif

// Round to nearest power of 2 from Luluco
// [https://github.com/luluco250/FXShaders] [MIT]

#define d_npot(x) ((((x - 1) >> 1) | ((x - 1) >> 2) | \
                    ((x - 1) >> 4) | ((x - 1) >> 8) | ((x - 1) >> 16)) + 1)

#define d_size d_npot(BUFFER_WIDTH) / 2.0

texture2D r_color  : COLOR;
texture2D r_filter { Width = d_size; Height = d_size; Format = R8; MipLevels = MIP_PREFILTER + 1.0; };
texture2D r_pframe { Width = d_size; Height = d_size; Format = R8; };
texture2D r_cframe { Width = d_size; Height = d_size; Format = R8; };
texture2D r_flow   { Width = d_size / 2.0; Height = d_size / 2.0; Format = RG16F; MipLevels = 8; };

sampler2D s_color  { Texture = r_color; SRGBTexture = TRUE; };
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
    float4 cframe : SV_TARGET0;
    float4 pframe : SV_TARGET1;
};

// Pack current frame to luma and output cframe from last frame.  Exposure from:
// [https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/Exposure.hlsl]

ps2mrt ps_copy(v2f input)
{
    ps2mrt o;
    float4 c = tex2D(s_color, input.uv);
    o.cframe = max(max(c.r, c.g), c.b);
    o.pframe = tex2D(s_cframe, input.uv);
    return o;
}

// Quintic curve texture filtering from Inigo:
// [https://www.iquilezles.org/www/articles/texture/texture.htm]

float4 filter2D(sampler2D src, float2 uv, float lod)
{
    const float2 size = tex2Dsize(src, lod);
    float2 p = uv * size + 0.5;
    float2 i = floor(p);
    float2 f = frac(p);
    p = i + f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    p = (p - 0.5) / size;
    return tex2Dlod(src, float4(p, 0.0, lod));
}

// Prefilter and copy frame

float4 ps_filter(v2f input) : SV_Target
{
    return filter2D(s_filter, input.uv, MIP_PREFILTER);
}

// Partial derivatives port of [https://github.com/diwi/PixelFlow] [MIT]

float4 ps_flow(v2f input) : SV_Target
{
    // Calculate distance
    float curr = tex2D(s_cframe, input.uv).r * 3.0;
    float prev = tex2D(s_pframe, input.uv).r * 3.0;
    float dt = curr - prev;

    // Calculate gradients and optical flow
    float3 d;
    d.x = ddx(curr) + ddx(prev);
    d.y = ddy(curr) + ddx(prev);
    d.z = rsqrt(dot(d.xy, d.xy) + kLambda);
    return kScale * dt * (d.xyxy * d.zzzz);
}

float4 flow2D(v2f input, float2 flow, float i)
{
    // Interleaved Gradient Noise from
    // [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
    const float3 value = float3(52.9829189, 0.06711056, 0.00583715);
    float noise = frac(value.x * frac(dot(input.vpos.xy, value.yz)));

    // [http://john-chapman-graphics.blogspot.com/2013/01/per-object-motion-blur.html]
    const float samples = 1.0 / (16.0 - 1.0);
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
    oFlow += filter2D(s_flow, input.uv, 0.0).xy * ldexp(1.0, -8.0);
    oFlow += filter2D(s_flow, input.uv, 1.0).xy * ldexp(1.0, -7.0);
    oFlow += filter2D(s_flow, input.uv, 2.0).xy * ldexp(1.0, -6.0);
    oFlow += filter2D(s_flow, input.uv, 3.0).xy * ldexp(1.0, -5.0);
    oFlow += filter2D(s_flow, input.uv, 4.0).xy * ldexp(1.0, -4.0);
    oFlow += filter2D(s_flow, input.uv, 5.0).xy * ldexp(1.0, -3.0);
    oFlow += filter2D(s_flow, input.uv, 6.0).xy * ldexp(1.0, -2.0);
    oFlow += filter2D(s_flow, input.uv, 7.0).xy * ldexp(1.0, -1.0);

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
        PixelShader = ps_copy;
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
