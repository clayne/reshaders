
/*
    Unlimited 11-Tap blur using mipmaps
    Based on https://github.com/spite/Wagner/blob/master/fragment-shaders/box-blur-fs.glsl
    Special Thanks to BlueSkyDefender for help and patience
*/

uniform float kRadius <
    ui_label = "Radius";
    ui_type = "slider";
    ui_step = 0.01;
> = 0.1;

texture2D r_color : COLOR;

texture2D r_mip
{
    Width = BUFFER_WIDTH / 2.0;
    Height = BUFFER_HEIGHT / 2.0;
    Format = RGB10A2;
    MipLevels = 2;
};

texture2D r_blur
{
    Width = BUFFER_WIDTH / 2.0;
    Height = BUFFER_HEIGHT / 2.0;
    Format = RGB10A2;
    MipLevels = 2;
};

sampler2D s_color
{
    Texture = r_color;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = true;
};

sampler2D s_mip
{
    Texture = r_mip;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D s_blur
{
    Texture = r_blur;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

struct v2f
{
    float4 vpos : SV_Position;
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

float4 ps_mip(v2f input) : SV_TARGET
{
    return tex2D(s_color, input.uv);
}

float4 p_noiseblur(sampler2D src, float2 uv, float2 pos, float2 delta)
{
    float4 kColor;
    float kTotal;
    const float kSampleCount = 2.0;

    // Interleaved Gradient Noise from
    // http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
    const float3 kValue = float3(52.9829189, 0.06711056, 0.00583715);
    float kOffset = frac(kValue.x * frac(dot(pos, kValue.yz)));

    for(float t= -kSampleCount; t <= kSampleCount; t++)
    {
        float kPercent = (t + kOffset - 0.5) / (kSampleCount * 2.0);
        float kWeight = 1.0 - abs(kPercent);

        float4 kSample = tex2Dlod(src, float4(uv + delta * kPercent, 0.0, 2.0));
        kColor += kSample * kWeight;
        kTotal += kWeight;
    }

    return kColor / kTotal;
}

float4 ps_blurh(v2f input) : SV_TARGET
{
    float2 sc; sincos(radians(0.0), sc[0], sc[1]);
    return p_noiseblur(s_mip, input.uv, input.vpos.xy, sc.yx * kRadius);
}

float4 ps_blurv(v2f input) : SV_TARGET
{
    float2 sc; sincos(radians(90.0), sc[0], sc[1]);
    return p_noiseblur(s_blur, input.uv, input.vpos.xy, sc.yx * kRadius);
}

technique cBlur
{
    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_mip;
        RenderTarget = r_mip;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_blurh;
        RenderTarget = r_blur;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_blurv;
        SRGBWriteEnable = true;
    }
}
