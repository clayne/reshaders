
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

/*
    Use EPIC poission function from BSD
*/

static const float kPi = 3.14159265359f;

float3 Sampling_Hemisphere_Uniform(float2 uv)
{
	float phi = uv.y * 2.0 * kPi;
	float ct = 1.0 - uv.x;
	float st = sqrt(1.0 - ct * ct);

    float cosphi, sinphi;
    sincos(phi, sinphi * st, cosphi * st);
	return float3(cosphi, sinphi , ct);
}

float4 p_poission(sampler2D src, float2 uv, float2 pos)
{
    const float2 kTexSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    const float2 kPixSize = 1.0 / kTexSize;
    const int kSampleCount = 16;
    const float kRadius = 16.0;

    const float3 kValue = float3(52.9829189, 0.06711056, 0.00583715);
    float kTheta = frac(kValue.x * frac(dot(pos, kValue.yz)));

    float kSinTheta, kCosTheta;
    sincos(kTheta, kSinTheta, kCosTheta);
    float2x2 kRotation = float2x2(kCosTheta, kSinTheta,
                                 -kSinTheta, kCosTheta);

    float4 kColor = 0.0;
    float kRN = 1.0 / float(kSampleCount);

    float kSampleArea = kPi * (kRadius * kRadius) / kSampleCount;
    float kLod = log2(sqrt(kSampleArea));

    for(uint i = 0; i < kSampleCount; ++i)
    {
        float2 kOffset = Sampling_Hemisphere_Uniform(uv).xy; // TODO: harass BSD on ReShade lounge about this
        kOffset = mul(kOffset, kRotation);
        kColor += tex2Dlod(s_mip, float4(uv + kOffset * kRadius * kPixSize, 0.0, kLod));
    }

    return kColor * kRN;
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
