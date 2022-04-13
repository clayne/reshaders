
/*
    Linear Gaussian blur shader

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

uniform float _Sigma <
    ui_type = "drag";
    ui_min = 0.0;
> = 1.0;

texture2D Render_Color : COLOR;

sampler2D Sample_Color
{
    Texture = Render_Color;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

// Vertex shaders

void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 Coord : TEXCOORD0)
{
    Coord.x = (ID == 2) ? 2.0 : 0.0;
    Coord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(Coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Pixel shaders
// Linear Gaussian blur based on https://www.rastergrid.com/blog/2010/09/efficient-Gaussian-blur-with-linear-sampling/

float Gaussian(float Pixel_Index, float Sigma)
{
    const float Pi = 3.1415926535897932384626433832795f;
    float Output = rsqrt(2.0 * Pi * (Sigma * Sigma));
    return Output * exp(-(Pixel_Index * Pixel_Index) / (2.0 * Sigma * Sigma));
}

void Gaussian_Blur(in float2 Coord, in bool Is_Horizontal, out float4 OutputColor0)
{
    float2 Direction = Is_Horizontal ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float2 PixelSize = (1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT)) * Direction;
    float Kernel_Size = _Sigma * 3.0;

    if(_Sigma == 0.0)
    {
        OutputColor0 = tex2Dlod(Sample_Color, float4(Coord, 0.0, 0.0));
    }
    else
    {
        // Sample and weight center first to get even number sides
        float Total_Weight = Gaussian(0.0, _Sigma);
        float4 Output_Color = tex2D(Sample_Color, Coord) * Total_Weight;

        for(float i = 1.0; i < Kernel_Size; i += 2.0)
        {
            float Offset_1 = i;
            float Offset_2 = i + 1.0;
            float Weight_1 = Gaussian(Offset_1, _Sigma);
            float Weight_2 = Gaussian(Offset_2, _Sigma);
            float Linear_Weight = Weight_1 + Weight_2;
            float Linear_Offset = ((Offset_1 * Weight_1) + (Offset_2 * Weight_2)) / Linear_Weight;

            Output_Color += tex2Dlod(Sample_Color, float4(Coord - Linear_Offset * PixelSize, 0.0, 0.0)) * Linear_Weight;
            Output_Color += tex2Dlod(Sample_Color, float4(Coord + Linear_Offset * PixelSize, 0.0, 0.0)) * Linear_Weight;
            Total_Weight += Linear_Weight * 2.0;
        }

        // Normalize intensity to prevent altered output
        OutputColor0 = Output_Color / Total_Weight;
    }
}

void Horizontal_Gaussian_Blur_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    Gaussian_Blur(Coord, true, OutputColor0);
}

void Vertical_Gaussian_Blur_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    Gaussian_Blur(Coord, false, OutputColor0);
}

technique cHorizontalGaussianBlur
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Horizontal_Gaussian_Blur_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}

technique cVerticalGaussianBlur
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Vertical_Gaussian_Blur_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}

