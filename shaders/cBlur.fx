
/*
    Convolution with Vogel Spirals

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

namespace SharedResources
{
    namespace RGBA8
    {
        texture2D _RenderTemporary1 < pooled = true; >
        {
            Width = BUFFER_WIDTH >> 1;
            Height = BUFFER_HEIGHT >> 1;
            Format = RGBA8;
            MipLevels = 8;
        };
    }
}

uniform float _Offset <
    ui_label = "Sample offset";
    ui_type = "drag";
    ui_min = 0.0;
> = 0.0;

uniform float _Radius <
    ui_label = "Convolution radius";
    ui_type = "drag";
    ui_min = 0.0;
> = 64.0;

uniform int _Samples <
    ui_label = "Convolution sample count";
    ui_type = "drag";
    ui_min = 0;
> = 16;

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

sampler2D _SampleTemporary_RGBA8_1
{
    Texture = SharedResources::RGBA8::_RenderTemporary1;
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
// Repurposed Wojciech Sterna's shadow sampling code as a screen-space convolution
// http://maxest.gct-game.net/content/chss.pdf

void VogelSample(int Index, int SamplesCount, float Phi, out float2 OutputValue)
{
    const float GoldenAngle = 2.4;
    float Radius = sqrt(float(Index) + 0.5) * rsqrt(float(SamplesCount));
    float Theta = float(Index) * GoldenAngle + Phi;

    float2 SineCosine;
    SineCosine[0] = sin(Theta);
    SineCosine[1] = cos(Theta);
    OutputValue = Radius * SineCosine;
}

void VogelBlur(sampler2D Source, float2 TexCoord, float2 ScreenSize, float Radius, int Samples, float Phi, out float4 OutputColor)
{
    // Initialize variables we need to accumulate samples and calculate offsets
    float2 Output;
    float2 Offset;

    // LOD calculation to fill in the gaps between samples
    const float Pi = 3.1415926535897932384626433832795;
    float SampleArea = Pi * (Radius * Radius) / float(Samples);
    float LOD = max(0.0, 0.5 * log2(SampleArea));

    // Offset and weighting attributes
    float2 PixelSize = 1.0 / ldexp(ScreenSize, -LOD);
    float Weight = 1.0 / (float(Samples) + 1.0);

    for(int i = 0; i < Samples; i++)
    {
        VogelSample(i, Samples, Phi, Offset);
        OutputColor += tex2Dlod(Source, float4(TexCoord + (Offset * PixelSize), 0.0, LOD)) * Weight;
    }
}

void BlitPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    OutputColor0 = tex2D(_SampleColor, TexCoord);
}

void VogelConvolutionPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    VogelBlur(_SampleTemporary_RGBA8_1, TexCoord, uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2), _Radius, _Samples, _Offset, OutputColor0);
}

technique cBlur
{
    pass GenerateMipLevels
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS;
        RenderTarget0 = SharedResources::RGBA8::_RenderTemporary1;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }

    pass VogelBlur
    {
        VertexShader = PostProcessVS;
        PixelShader = VogelConvolutionPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
