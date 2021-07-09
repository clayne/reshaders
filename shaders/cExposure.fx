
// From https://knarkowicz.wordpress.com/2016/01/09/automatic-exposure/

uniform float uIntensity <
    ui_type = "drag";
    ui_min = 0.0;
> = 1.0;

texture2D r_color : COLOR;
texture2D r_aluma
{
    Width = 256;
    Height = 256;
    Format = R32F;
    MipLevels = 9;
};

sampler2D s_color { Texture = r_color; SRGBTexture = TRUE; };
sampler2D s_aluma { Texture = r_aluma; };

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

float4 ps_core(v2f input) : SV_TARGET
{
    float4 oColor = tex2D(s_color, input.uv);
    return max(max(oColor.r, oColor.g), oColor.b);
}

float4 ps_expose(v2f input) : SV_TARGET
{
    float2 psize = tex2Dsize(s_aluma, 0.0);
    float lod = log2(max(psize.x, psize.y)) - log2(1.0);
    float aLuma = tex2Dlod(s_aluma, float4(input.uv, 0.0, lod)).r;
    float4 oColor = tex2D(s_color, input.uv);
    float4 oLuma = max(max(oColor.r, oColor.g), oColor.b);

    float aKeyValue = 1.03 - (2.0 / (log10(aLuma + 1.0) + 2.0));
    float aExposure = log2(max(aKeyValue / aLuma, 1e-5));
    aExposure = exp2(aExposure + uIntensity);
    float4 expose = oColor * aExposure;
    return expose * rcp(oLuma + 1.0);
}

technique cExposure
{
    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_core;
        RenderTarget = r_aluma;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_expose;
        SRGBWriteEnable = TRUE;
    }
}
