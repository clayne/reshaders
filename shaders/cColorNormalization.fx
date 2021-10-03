
// The various types of color normalization via http://jamie-wong.com/post/color/

uniform int _Select <
    ui_type = "combo";
    ui_items = " Built-in Normalized RGB\0 Normalized RGB\0 Built-in RG Chromaticity\0 RG Chromaticity\0 Jamie's RG Chromaticity\0 None\0";
    ui_label = "Method";
    ui_tooltip = "Select Luminance";
> = 0;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

void NormalizationPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float3 OutputColor0 : SV_TARGET0)
{
    float3 Color = tex2D(_SampleColor, TexCoord).rgb;
    switch(_Select)
    {
        case 0:
            OutputColor0 = normalize(Color);
            break;
        case 1:
            // Note: You can reconstruct blue channel, the remainder ratio, by (1.0 - Red - Green)
            OutputColor0 = Color / dot(Color, 1.0);
            break;
        case 2:
            OutputColor0 = float3(normalize(Color).xy , 0.0);
            break;
        case 3:
            OutputColor0 = float3(Color.xy / dot(Color, 1.0), 0.0);
            break;
        case 4:
            float3 NColor = Color / dot(Color, 1.0);
            float NBright = max(NColor.r, max(NColor.g, NColor.b));
            OutputColor0 = float3(NColor.xy / NBright, 0.0);
            break;
        default:
            OutputColor0 = Color;
            break;
    }
}

technique cNormalizedColor
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = NormalizationPS;
        SRGBWriteEnable = TRUE;
    }
}
