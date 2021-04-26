
/*
    This work is licensed under a Creative Commons Attribution 3.0 Unported License.
    https://creativecommons.org/licenses/by/3.0/us/
*/

uniform float kLambda <
    ui_label = "Lambda";
    ui_type = "drag";
> = 0.001;

uniform float kScale <
    ui_label = "Scale";
    ui_type = "drag";
> = 0.064;

#ifndef MIP_PREFILTER
    #define MIP_PREFILTER 2.0
#endif

texture2D r_color  : COLOR;
texture2D r_filter { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RGB10A2; MipLevels = MIP_PREFILTER + 1.0; };
texture2D r_pframe { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RGB10A2; };
texture2D r_cframe { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RGB10A2; };
texture2D r_flow   { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RG16F; MipLevels = 9; };

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

// Output the cframe we got from last frame

struct p2mrt
{
    float4 cframe : SV_TARGET0;
    float4 pframe : SV_TARGET1;
};

p2mrt ps_copy(v2f input)
{
    p2mrt o;
    o.cframe = tex2D(s_color, input.uv);
    o.pframe = tex2D(s_cframe, input.uv);
    return o;
}

// Better texture fltering from Inigo:
// [https://www.iquilezles.org/www/articles/texture/texture.htm]

float4 filter2D(sampler2D src, float2 uv, float lod)
{
    float2 size = tex2Dsize(src, lod);
    float2 p = uv * size + 0.5;
    float2 i = floor(p);
    float2 f = p - i;
    f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    p = i + f;
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
    // Calculate frame distance
    float4 curr = tex2D(s_cframe, input.uv);
    float4 prev = tex2D(s_pframe, input.uv);
    float dist = dot(curr.rgb - prev.rgb, 1.0);

    // Calculate gradients and optical flow
    float3 both = curr.rgb + prev.rgb;
    float2 d;
    d.x = dot(ddx(both), 1.0);
    d.y = dot(ddy(both), 1.0);
    float dt = rsqrt(dot(d, d) + kLambda);
    float2 flow = -kScale * dist * (d.xy * dt);
    return flow.xyxy;
}

float2 calcFlow(v2f input, float2 flow, float i)
{
    // Interleaved Gradient Noise from
    // [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
    const float3 kValue = float3(52.9829189, 0.06711056, 0.00583715);
    float kNoise = frac(kValue.x * frac(dot(input.vpos.xy, kValue.yz)));

    // [http://john-chapman-graphics.blogspot.com/2013/01/per-object-motion-blur.html]
    const float kSamples = 1.0 / (16.0 - 1.0);
    float2 kCalc = (kNoise * 2.0 + i) * kSamples - 0.5;
    return flow * kCalc + input.uv;
}

float4 ps_output(v2f input) : SV_Target
{
    /*
        Build optical flow pyramid (oFlow)
        Lowest mip has highest precision, lowest contribution
        Highest mip has lowest spread, highest contribution
    */

    float2 oFlow = 0.0;
    oFlow += filter2D(s_flow, input.uv, 1.0).xy * ldexp(1.0, -7.0);
    oFlow += filter2D(s_flow, input.uv, 2.0).xy * ldexp(1.0, -6.0);
    oFlow += filter2D(s_flow, input.uv, 3.0).xy * ldexp(1.0, -5.0);
    oFlow += filter2D(s_flow, input.uv, 4.0).xy * ldexp(1.0, -4.0);
    oFlow += filter2D(s_flow, input.uv, 5.0).xy * ldexp(1.0, -3.0);
    oFlow += filter2D(s_flow, input.uv, 6.0).xy * ldexp(1.0, -2.0);
    oFlow += filter2D(s_flow, input.uv, 7.0).xy * ldexp(1.0, -1.0);
    oFlow += filter2D(s_flow, input.uv, 8.0).xy * ldexp(1.0,  0.0);

    const float kWeights = 1.0 / 8.0;
    float4 color = 0.0;
    color += tex2D(s_color, calcFlow(input, oFlow, 2.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input, oFlow, 4.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input, oFlow, 6.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input, oFlow, 8.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input, oFlow, 10.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input, oFlow, 12.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input, oFlow, 14.0)) * kWeights;
    color += tex2D(s_color, calcFlow(input, oFlow, 16.0)) * kWeights;
    return color;
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
        RenderTarget = r_flow;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_output;
        SRGBWriteEnable = TRUE;
    }
}
