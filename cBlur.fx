
texture2D r_source : COLOR;
sampler2D s_source
{
    Texture = r_source;
    SRGBTexture = true;
};

texture2D r_mip
{
    Width = BUFFER_WIDTH / 2.0;
    Height = BUFFER_HEIGHT / 2.0;
    MipLevels = 11;
};

sampler2D s_mip
{
    Texture = r_mip;
};

struct v2f
{
    float4 vpos : SV_Position;
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

float4 ps_mip(v2f input) : SV_TARGET
{
    return tex2D(s_source, input.uv);
}

// Use EPIC poission function from BSD

static const float2 PoissonTaps[12] =
{
    float2(-0.326,-0.406), //This Distribution seems faster.....
    float2(-0.840,-0.074), //Tried many from https://github.com/bartwronski/PoissonSamplingGenerator
    float2(-0.696, 0.457), //But they seems slower then this one I found online..... WTF
    float2(-0.203, 0.621),
    float2( 0.962,-0.195),
    float2( 0.473,-0.480),
    float2( 0.519, 0.767),
    float2( 0.185,-0.893),
    float2( 0.507, 0.064),
    float2( 0.896, 0.412),
    float2(-0.322,-0.933),
    float2(-0.792,-0.598)
};

float2 Rotate2D_B(float2 r, float l)
{
    float2 Directions;
    sincos(l, Directions[0], Directions[1]);//same as float2(cos(l),sin(l))
    return float2(dot(r, float2(Directions[1], -Directions[0])), dot(r, Directions.xy));
}

float4 p_poission(sampler2D src, float2 uv, float2 pos)
{
    const int    kSampleCount = 12;
    const float  kRadius = 128.0;
    const float2 kPixSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    const float  kSampleArea = 3.14159265359f * (kRadius * kRadius) / kSampleCount;
    const float  kLod = log2(sqrt(kSampleArea));

    const float3 kValue = float3(52.9829189, 0.06711056, 0.00583715);
    float kTheta = frac(kValue.x * frac(dot(pos, kValue.yz)));

    float4 kColor;
    for(uint i = 0; i < kSampleCount; ++i)
    {
        float2 kOffset = Rotate2D_B(PoissonTaps[i], kTheta); // TODO: harass BSD on ReShade lounge about this
        kColor += tex2Dlod(s_mip, float4(uv + kOffset * kRadius * kPixSize, 0.0, kLod));
    }

    return kColor / float(kSampleCount);
}

float4 ps_blur(v2f input) : SV_TARGET
{
    return p_poission(s_mip, input.uv, input.vpos.xy);
}

technique BlurTorture
{
    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_mip;
        RenderTarget = r_mip;
    }

    pass
    {
        VertexShader = vs_basic;
        PixelShader = ps_blur;
        SRGBWriteEnable = true;
    }
}
