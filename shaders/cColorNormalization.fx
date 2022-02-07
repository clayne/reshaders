
/*
    Various color normalization algorithms

    BSD 3-Clause License

    Copyright (c) 2022, Paul Dang
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

    3. Neither the name of the copyright holder nor the names of its
    contributors may be used to endorse or promote products derived from
    this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
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
            Copyright 2020 Marco Buzzelli, Simone Bianco, Raimondo Schettini.
            If you use this code in your research, please cite:
            @article{buzzelli2020arc,
                title = {ARC: Angle-Retaining Chromaticity diagram for color constancy error analysis},
                author = {Marco Buzzelli and Simone Bianco and Raimondo Schettini},
                journal = {J. Opt. Soc. Am. A},
                number = {11},
                pages = {1721--1730},
                publisher = {OSA},
                volume = {37},
                month = {Nov},
                year = {2020},
                doi = {10.1364/JOSAA.398692}
            }

        Jamie Wong's Chromaticity
            Title = "Color: From Hexcodes to Eyeballs"
            Authors = Jamie Wong
            Year = 2018
            Link = http://jamie-wong.com/post/color/
*/

void NormalizationPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float3 OutputColor0 : SV_Target0)
{
    OutputColor0 = 0.0;
    const float Minima = ldexp(1.0, -8.0);
    float3 Color = max(tex2D(_SampleColor, TexCoord).rgb, Minima);
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
            float3 NormalizedRGB = Color / dot(Color, 1.0);
            OutputColor0.rg = saturate(NormalizedRGB.rg / max(max(NormalizedRGB.r, NormalizedRGB.g), NormalizedRGB.b));
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
