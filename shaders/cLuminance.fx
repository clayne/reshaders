

uniform int _Select <
    ui_type = "combo";
    ui_items = " Average\0 Sum\0 Max3\0 Filmic\0 None\0";
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

void LuminancePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float4 Color = tex2D(_SampleColor, TexCoord);
    switch(_Select)
    {
        case 0:
            OutputColor0 = dot(Color.rgb, 1.0 / 3.0);
            break;
        case 1:
            OutputColor0 = dot(Color.rgb, 1.0);
            break;
        case 2:
            OutputColor0 = max(Color.r, max(Color.g, Color.b));
            break;
        case 3:
            OutputColor0 = length(Color.rgb) * rsqrt(3.0);
            break;
        default:
            OutputColor0 = Color;
            break;
    }
}

technique cLuminance
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = LuminancePS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
