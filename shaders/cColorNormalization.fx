
/*
    Various color normalization algorithms

    MIT License

    Copyright (c) 2022 brimson

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
*/

uniform int _Select <
    ui_type = "combo";
    ui_items = " Built-in RG Chromaticity\0 Built-in RGB Chromaticity\0 Standard RG Chromaticity\0 Standard RGB Chromaticity\0 Jamie Wong's RG Chromaticity\0 Jamie Wong's RGB Chromaticity\0 Angle-Retaining Chromaticity \0 None\0";
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

// Vertex shaders

void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Pixel shaders

/*
    Sources
        Angle-Retaining Chromaticity
            Title = "ARC: Angle-Retaining Chromaticity diagram for color constancy error analysis"
            Authors = Marco Buzzelli and Simone Bianco and Raimondo Schettini
            Year = 2020
            Link = http://www.ivl.disco.unimib.it/activities/arc/
        Jamie Wong's Chromaticity
            Title = "Color: From Hexcodes to Eyeballs"
            Authors = Jamie Wong
            Year = 2018
            Link = http://jamie-wong.com/post/color/
*/

void NormalizationPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float3 OutputColor0 : SV_Target0)
{
	OutputColor0 = 0.0;
    float3 Color = tex2D(_SampleColor, TexCoord).rgb;
    switch(_Select)
    {
        case 0:
            // Built-in RG Chromaticity
            OutputColor0.rg = saturate(normalize(Color).rg);
            break;
        case 1:
            // Built-in RGB Chromaticity
            OutputColor0 = saturate(normalize(Color));
            break;
        case 2:
            // Standard RG Chromaticity
            OutputColor0.rg = saturate(Color.rg / dot(Color, 1.0));
            break;
        case 3:
            // Standard RGB Chromaticity
            OutputColor0 = saturate(Color / dot(Color, 1.0));
            break;
        case 4:
            // Jamie Wong's RG Chromaticity
            OutputColor0 = Color / dot(Color, 1.0);
            OutputColor0.rg = saturate(OutputColor0.rg / max(max(OutputColor0.r, OutputColor0.g), OutputColor0.b));
            break;
        case 5:
            // Jamie Wong's RGB Chromaticity
            OutputColor0 = Color / dot(Color, 1.0);
            OutputColor0 = saturate(OutputColor0 / max(max(OutputColor0.r, OutputColor0.g), OutputColor0.b));
            break;
        case 6:
            // Angle-Retaining Chromaticity (Optimized for GPU)
            float2 AlphaA;
            AlphaA.x = dot(Color.gb, float2(sqrt(3.0), -sqrt(3.0)));
            AlphaA.y = dot(Color, float3(2.0, -1.0, -1.0));
            float AlphaR = acos(dot(Color, 1.0) / (sqrt(3.0) * length(Color)));
            float AlphaC = AlphaR / length(AlphaA);
            float2 Alpha = AlphaC * AlphaA.yx;

            float2 AlphaMin, AlphaMax;
            AlphaMin.y = -(sqrt(3.0) / 2.0) * acos(rsqrt(3.0));
            AlphaMax.y = (sqrt(3.0) / 2.0) * acos(rsqrt(3.0));
            AlphaMin.x = -acos(sqrt(2.0 / 3.0));
            AlphaMax.x = AlphaMin.x + (AlphaMax.y - AlphaMin.y);
            OutputColor0.rg = saturate((Alpha.xy - AlphaMin.xy) / (AlphaMax.xy - AlphaMin.xy));
            break;
        default:
            // No Chromaticity
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
