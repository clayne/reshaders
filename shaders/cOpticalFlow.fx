
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
texture2D r_filter0 { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RGB10A2; };
texture2D r_pframe0 { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RGB10A2; };
texture2D r_cframe0 { Width = BUFFER_WIDTH / 2.0; Height = BUFFER_HEIGHT / 2.0; Format = RGB10A2; };

sampler2D s_color
{
    Texture = r_color;
    #if BUFFER_COLOR_BIT_DEPTH != 10
        SRGBTexture = true;
    #endif
};

sampler2D s_filter { Texture = r_filter0; };
sampler2D s_pframe { Texture = r_pframe0; };
sampler2D s_cframe { Texture = r_cframe0; };

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

// Copy frame

float4 ps_filter(v2f input) : SV_Target
{
    return tex2D(s_filter, input.uv);
}

// Partial derivatives port of [https://github.com/diwi/PixelFlow] [MIT]

float4 ps_flow(v2f input) : SV_Target
{
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

technique cOpticalFlow
{
    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_copy;
        RenderTarget0 = r_filter0;
        RenderTarget1 = r_pframe0; // Store previous frame
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
    }
}
