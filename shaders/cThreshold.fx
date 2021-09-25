
/*
    Quadratic thresholding from cBloom
*/

uniform float uThreshold <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Threshold";
> = 0.8;

uniform float uSmooth <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Smoothing";
> = 0.5;

uniform float uSaturation <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Saturation";
> = 1.0;

uniform float uIntensity <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Intensity";
> = 1.0;

texture2D r_color : COLOR;

sampler2D s_color
{
    Texture = r_color;
    SRGBTexture = TRUE;
};

/* [Vertex Shaders] */

void vs_generic(in uint id : SV_VERTEXID,
                inout float4 position : SV_POSITION,
                inout float2 texcoord : TEXCOORD0)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

void ps_threshold(float4 vpos : SV_POSITION,
                  float2 uv : TEXCOORD0,
                  out float4 r0 : SV_TARGET0)
{
    const float knee = mad(uThreshold, uSmooth, 1e-5f);
    const float3 curve = float3(uThreshold - knee, knee * 2.0, 0.25 / knee);
    float4 s = tex2D(s_color, uv);

    // Under-threshold
    float br = max(s.r, max(s.g, s.b));
    float rq = clamp(br - curve.x, 0.0, curve.y);
    rq = curve.z * rq * rq;

    // Combine and apply the brightness response curve
    s *= max(rq, br - uThreshold) / max(br, 1e-10);
    r0 = saturate(lerp(br, s, uSaturation) * uIntensity);
}

technique cThreshold
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_threshold;
        SRGBWriteEnable = TRUE;
    }
}