
/*
    The various types of color normalization
        Learn more
            http://jamie-wong.com/post/color/
*/

uniform int _Select <
    ui_type = "combo";
    ui_items = " Built-in RG Chromaticity\0 Built-in RGB Chromaticity\0 RG Chromaticity\0 RGB Chromaticity\0 Jamie's RG Chromaticity\0 Jamie's RGB Chromaticity\0 None\0";
    ui_label = "Method";
    ui_tooltip = "Select Luminance";
> = 0;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
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
            OutputColor0.rg = normalize(Color).rg;
            break;
        case 1:
            OutputColor0 = normalize(Color);
            break;
        case 2:
            OutputColor0.rg = Color.rg / dot(Color, 1.0);
            break;
        case 3:
            OutputColor0 = Color / dot(Color, 1.0);
            break;
        case 4:
            OutputColor0 = Color / dot(Color, 1.0);
            OutputColor0.rg /= max(max(OutputColor0.r, OutputColor0.g), OutputColor0.b);
            break;
        case 5:
            OutputColor0 = Color / dot(Color, 1.0);
            OutputColor0 /= max(max(OutputColor0.r, OutputColor0.g), OutputColor0.b);
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
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
