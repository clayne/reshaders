
/*
    Linear Gaussian blur shader

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

uniform float _Sigma <
    ui_type = "drag";
    ui_min = 0.0;
> = 1.0;

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
// Linear Gaussian blur based on https://www.rastergrid.com/blog/2010/09/efficient-Gaussian-blur-with-linear-sampling/

float Gaussian(float PixelIndex, float Sigma)
{
    const float Pi = 3.1415926535897932384626433832795f;
    float Output = rsqrt(2.0 * Pi * (Sigma * Sigma));
    return Output * exp(-(PixelIndex * PixelIndex) / (2.0 * Sigma * Sigma));
}

void GaussianBlur(in float2 TexCoord, in bool Horizontal, out float4 OutputColor0)
{
    float2 Direction = Horizontal ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float2 PixelSize = (1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT)) * Direction;
    float KernelSize = _Sigma * 3.0;

    if(_Sigma == 0.0)
    {
        OutputColor0 = tex2Dlod(_SampleColor, float4(TexCoord, 0.0, 0.0));
    }
    else
    {
        // Sample and weight center first to get even number sides
        float TotalWeight = Gaussian(0.0, _Sigma);
        float4 OutputColor = tex2D(_SampleColor, TexCoord) * TotalWeight;

        for(float i = 1.0; i < KernelSize; i += 2.0)
        {
            float Offset1 = i;
            float Offset2 = i + 1.0;
            float Weight1 = Gaussian(Offset1, _Sigma);
            float Weight2 = Gaussian(Offset2, _Sigma);
            float LinearWeight = Weight1 + Weight2;
            float LinearOffset = ((Offset1 * Weight1) + (Offset2 * Weight2)) / LinearWeight;

            OutputColor += tex2Dlod(_SampleColor, float4(TexCoord - LinearOffset * PixelSize, 0.0, 0.0)) * LinearWeight;
            OutputColor += tex2Dlod(_SampleColor, float4(TexCoord + LinearOffset * PixelSize, 0.0, 0.0)) * LinearWeight;
            TotalWeight += LinearWeight * 2.0;
        }

        // Normalize intensity to prevent altered output
        OutputColor0 = OutputColor / TotalWeight;
    }
}

void HorizontalGaussianBlurPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    GaussianBlur(TexCoord, true, OutputColor0);
}

void VerticalGaussianBlurPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    GaussianBlur(TexCoord, false, OutputColor0);
}

technique cHorizontalGaussianBlur
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = HorizontalGaussianBlurPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}

technique cVerticalGaussianBlur
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = VerticalGaussianBlurPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}

