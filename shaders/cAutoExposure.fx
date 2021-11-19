
/*
    Adaptive, temporal exposure by Brimson
    Based on https://github.com/TheRealMJP/BakingLab
    THIS EFFECT IS DEDICATED TO THE BRAVE SHADER DEVELOPERS OF RESHADE
*/

uniform float _TimeRate <
    ui_label = "Smoothing";
    ui_type = "drag";
    ui_tooltip = "Exposure time smoothing";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.95;

uniform float _ManualBias <
    ui_label = "Exposure";
    ui_type = "drag";
    ui_tooltip = "Optional manual bias ";
    ui_min = 0.0;
> = 2.0;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

texture2D _RenderLumaLOD
{
    Width = 256;
    Height = 256;
    MipLevels = 9;
    Format = R16F;
};

sampler2D _SampleLumaLOD
{
    Texture = _RenderLumaLOD;
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

void BlitPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    float4 Color = tex2D(_SampleColor, TexCoord);

    // OutputColor.rgb = Output the highest brightness out of red/green/blue component
    // OutputColor.a = Output the weight for temporal blending
    OutputColor0 = float4(max(Color.r, max(Color.g, Color.b)).rrr, _TimeRate);
}

void ExposurePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    // Average Luma = Average value (1x1) for all of the pixels
    float AverageLuma = tex2Dlod(_SampleLumaLOD, float4(TexCoord, 0.0, 8.0)).r;
    float4 Color = tex2D(_SampleColor, TexCoord);

    // KeyValue is an exposure compensation curve
    // Source: https://knarkowicz.wordpress.com/2016/01/09/automatic-exposure/
    float KeyValue = 1.03 - (2.0 / (log10(AverageLuma + 1.0) + 2.0));
    float ExposureValue = log2(KeyValue / AverageLuma) + _ManualBias;
    OutputColor0 = Color * exp2(ExposureValue);
}

technique cAutoExposure
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS;
        RenderTarget = _RenderLumaLOD;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ExposurePS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
