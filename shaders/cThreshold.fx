
/*
    Quadratic thresholding from cBloom
*/

uniform float _Threshold <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Threshold";
> = 0.8;

uniform float _Smooth <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Smoothing";
> = 0.5;

uniform float _Saturation <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Saturation";
> = 1.0;

uniform float _Intensity <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Intensity";
> = 1.0;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

float Med3(float x, float y, float z)
{
    return max(min(x, y), min(max(x, y), z));
}

/* [Pixel Shaders] */

void ThresholdPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    const float Knee = mad(_Threshold, _Smooth, 1e-5f);
    const float3 Curve = float3(_Threshold - Knee, Knee * 2.0, 0.25 / Knee);
    float4 Color = tex2D(_SampleColor, TexCoord);

    // Under-threshold
    float Brightness = Med3(Color.r, Color.g, Color.b);
    float ResponseCurve = clamp(Brightness - Curve.x, 0.0, Curve.y);
    ResponseCurve = Curve.z * ResponseCurve * ResponseCurve;

    // Combine and apply the brightness response curve
    Color = Color * max(ResponseCurve, Brightness - _Threshold) / max(Brightness, 1e-10);
    Brightness = Med3(Color.r, Color.g, Color.b);
    OutputColor0 = saturate(lerp(Brightness, Color, _Saturation) * _Intensity);
}

technique cThreshold
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ThresholdPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}