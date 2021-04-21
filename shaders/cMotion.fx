
/*
    This work is licensed under a Creative Commons Attribution 3.0 Unported License.
    https://creativecommons.org/licenses/by/3.0/us/
*/

uniform float kRadius <
    ui_label = "Radius";
    ui_type = "slider";
> = 0.16;

uniform float kLambda <
    ui_label = "Lambda";
    ui_type = "drag";
> = 0.64;

uniform float kScale <
    ui_label = "Scale";
    ui_type = "drag";
> = 1.28;

texture2D r_source : COLOR;
texture2D r_lod    { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RGB10A2; MipLevels = 3; };
texture2D r_pframe { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RGB10A2; };
texture2D r_cframe { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RGB10A2; };
texture2D r_blurh  { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RG16F; MipLevels = 3; };
texture2D r_blurv  { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RG16F; MipLevels = 3; };

sampler2D s_source
{
    Texture = r_source;
    #if BUFFER_COLOR_BIT_DEPTH != 10
        SRGBTexture = true;
    #endif
};

sampler2D s_lod    { Texture = r_lod; MipLODBias = 2.0; };
sampler2D s_pframe { Texture = r_pframe; };
sampler2D s_cframe { Texture = r_cframe; };
sampler2D s_blurh  { Texture = r_blurh; MipLODBias = 2.0; };
sampler2D s_blurv  { Texture = r_blurv; MipLODBias = 2.0; };

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
    o.cframe = tex2D(s_source, input.uv);
    o.pframe = tex2D(s_cframe, input.uv); // Output the cframe we got from last frame
    return o;
}

float4 ps_copy(v2f input) : SV_Target
{
    return tex2D(s_lod, input.uv);
}

float4 ps_flow(v2f input) : SV_Target
{
    float4 curr = tex2D(s_cframe, input.uv);
    float4 prev = tex2D(s_pframe, input.uv);

    // Distance between current and previous frame
    float dt = distance(curr, prev);
    curr = smoothstep(prev, curr, dt);

    // Partial derivatives port of
    // [https://github.com/mattatz/unity-optical-flow] [MIT]
    float3 d;
    d.x = dot(ddx(curr), 1.0);
    d.y = dot(ddy(curr), 1.0);
    d.z = rsqrt(dot(d.xy, d.xy) + kLambda);
    return kScale * dt * (d.xyxy * d.zzzz);
}

float pnoise(float2 pos)
{
    // Interleaved Gradient Noise from
    // http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
    const float3 kValue = float3(52.9829189, 0.06711056, 0.00583715);
    return frac(kValue.x * frac(dot(pos, kValue.yz)));
}

float4 p_noiseblur(sampler2D src, v2f input, float2 delta)
{
    float4 kColor;
    float kTotal;
    const float kSampleCount = 2.0;

    for(float t= -kSampleCount; t <= kSampleCount; t++)
    {
        float kPercent = (t + pnoise(input.vpos.xy) - 0.5) / (kSampleCount * 2.0);
        float kWeight = 1.0 - abs(kPercent);

        float4 kSample = tex2D(src, input.uv + delta * kPercent);
        kColor += kSample * kWeight;
        kTotal += kWeight;
    }

    return kColor / kTotal;
}

float4 ps_blur(v2f input) : SV_Target
{
    float2 sc; sincos(radians(0.0), sc[0], sc[1]);
    return p_noiseblur(s_blurh, input, sc.yx * kRadius).rgrg;
}

float2 calcFlow(v2f input, float2 flow, float i)
{
    // From [http://john-chapman-graphics.blogspot.com/2013/01/per-object-motion-blur.html]
    const float kSamples = 1.0 / (16.0 - 1.0);
    float2 kCalc = (pnoise(input.vpos.xy) * 2.0 + i) * kSamples - 0.5;
    return flow * kCalc + input.uv;
}

float4 ps_output(v2f input) : SV_Target
{
    float2 sc; sincos(radians(90.0), sc[0], sc[1]);
    float2 oFlow = p_noiseblur(s_blurv, input, sc.yx * kRadius).rg;

    const float kWeights = 1.0 / 8.0;
    float4 color = 0.0;
    color += tex2D(s_source, calcFlow(input, oFlow, 2.0)) * kWeights;
    color += tex2D(s_source, calcFlow(input, oFlow, 4.0)) * kWeights;
    color += tex2D(s_source, calcFlow(input, oFlow, 6.0)) * kWeights;
    color += tex2D(s_source, calcFlow(input, oFlow, 8.0)) * kWeights;
    color += tex2D(s_source, calcFlow(input, oFlow, 10.0)) * kWeights;
    color += tex2D(s_source, calcFlow(input, oFlow, 12.0)) * kWeights;
    color += tex2D(s_source, calcFlow(input, oFlow, 14.0)) * kWeights;
    color += tex2D(s_source, calcFlow(input, oFlow, 16.0)) * kWeights;
    return color;
}

technique cMotionBlur
{
    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_lod;
        RenderTarget0 = r_lod;
        RenderTarget1 = r_pframe; // Store previous frame
    }

    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_copy;
        RenderTarget0 = r_cframe;
    }

    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_flow;
        RenderTarget = r_blurh;
    }

    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_blur;
        RenderTarget = r_blurv;
    }

    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_output;
        SRGBWriteEnable = true;
    }
}
