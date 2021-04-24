
/*
    This work is licensed under a Creative Commons Attribution 3.0 Unported License.
    https://creativecommons.org/licenses/by/3.0/us/
*/

uniform float kThreshold <
    ui_label = "Threshold";
    ui_type = "drag";
> = 0.016;

uniform float kScale <
    ui_label = "Scale";
    ui_type = "drag";
> = 0.320;

texture2D r_color  : COLOR;
texture2D r_filter { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RGB10A2; MipLevels = 3; };
texture2D r_pframe { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RGB10A2; };
texture2D r_cframe { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RGB10A2; };
texture2D r_flow   { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RG16F;   MipLevels = 9; };

sampler2D s_color
{
    Texture = r_color;
    #if BUFFER_COLOR_BIT_DEPTH != 10
        SRGBTexture = true;
    #endif
};

sampler2D s_filter { Texture = r_filter; MipLODBias = 2.0; };
sampler2D s_pframe { Texture = r_pframe; };
sampler2D s_cframe { Texture = r_cframe; };
sampler2D s_flow   { Texture = r_flow; };

struct v2f
{
    float4 vpos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

v2f vs_basic(const uint id : SV_VertexID)
{
    v2f output;
    output.uv.x = (id == 2) ? 2.0 : 0.0;
    output.uv.y = (id == 1) ? 2.0 : 0.0;
    output.vpos = float4(output.uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return output;
}

/* [ Pixel Shaders ] */

struct p2mrt
{
    float4 cframe : SV_TARGET0;
    float4 pframe : SV_TARGET1;
};

p2mrt ps_lod(v2f input)
{
    p2mrt o;
    o.cframe = tex2D(s_color, input.uv);
    o.pframe = tex2D(s_cframe, input.uv); // Output the cframe we got from last frame
    return o;
}

// Prefilter frame via mipmaps and copy it
float4 ps_filter(v2f input) : SV_Target
{
    return tex2D(s_filter, input.uv);
}

float4 ps_flow(v2f input) : SV_Target
{
    // Partial derivatives port of
    // [https://github.com/diwi/PixelFlow] [MIT]

    // Calculate frame distance
    float4 kCurr = tex2D(s_cframe, input.uv);
    float4 kPrev = tex2D(s_pframe, input.uv);
    float kDist = dot(kCurr.rgb - kPrev.rgb, 1.0);

    // Calculate gradients and optical flow
    float3 kBoth = kCurr.rgb + kPrev.rgb;
    float3 kCalc;
    kCalc.x = dot(ddx(kBoth), 1.0);
    kCalc.y = dot(ddy(kBoth), 1.0);
    kCalc.z = rsqrt(dot(kCalc.xy, kCalc.xy) + 1.0);
    float2 kFlow = -kScale * kDist * (kCalc.xy * kCalc.zz);

    float kOld = sqrt(dot(kFlow.xy, kFlow.xy) + 1e-5);
    float kNew = max(kOld - kThreshold, 0.0);
    kFlow *= kNew / kOld;
    return kFlow.xyxy;
}

float4 filter(float2 uv, float lod)
{
    // Better texture fltering from Inigo:
    // [https://www.iquilezles.org/www/articles/texture/texture.htm]
    float2 kResolution = tex2Dsize(s_flow, lod);
    float2 kP = uv * kResolution + 0.5;
    float2 kI = floor(kP);
    float2 kF = kP - kI;
    kF = kF * kF * kF * (kF * (kF * 6.0 - 15.0) + 10.0);
    kP = kI + kF;
    kP = (kP - 0.5) / kResolution;
    return float4(kP, 0.0, lod);
}

float2 calcFlow(v2f input, float2 flow, float i)
{
    // Interleaved Gradient Noise from
    // [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
    const float3 kValue = float3(52.9829189, 0.06711056, 0.00583715);
    float kNoise = frac(kValue.x * frac(dot(input.vpos.xy, kValue.yz)));

    // Center blur from
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
    oFlow += tex2Dlod(s_flow, filter(input.uv, 1.0)).xy * ldexp(1.0, -7.0);
    oFlow += tex2Dlod(s_flow, filter(input.uv, 2.0)).xy * ldexp(1.0, -6.0);
    oFlow += tex2Dlod(s_flow, filter(input.uv, 3.0)).xy * ldexp(1.0, -5.0);
    oFlow += tex2Dlod(s_flow, filter(input.uv, 4.0)).xy * ldexp(1.0, -4.0);
    oFlow += tex2Dlod(s_flow, filter(input.uv, 5.0)).xy * ldexp(1.0, -3.0);
    oFlow += tex2Dlod(s_flow, filter(input.uv, 6.0)).xy * ldexp(1.0, -2.0);
    oFlow += tex2Dlod(s_flow, filter(input.uv, 7.0)).xy * ldexp(1.0, -1.0);
    oFlow += tex2Dlod(s_flow, filter(input.uv, 8.0)).xy * ldexp(1.0,  0.0);

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
        VertexShader = vs_basic;
        PixelShader = ps_lod;
        RenderTarget0 = r_filter;
        RenderTarget1 = r_pframe; // Store previous frame
    }

    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_filter;
        RenderTarget0 = r_cframe;
    }

    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_flow;
        RenderTarget = r_flow;
    }

    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_output;
        SRGBWriteEnable = true;
    }
}
