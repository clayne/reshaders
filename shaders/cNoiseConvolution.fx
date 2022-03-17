

/*
    Convolution with Vogel spirals and gradient noise

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

uniform float _Radius <
    ui_label = "Convolution radius";
    ui_type = "drag";
    ui_min = 0.0;
> = 64.0;

uniform int _Samples <
    ui_label = "Convolution sample count";
    ui_type = "drag";
    ui_min = 0;
> = 8;

texture2D RenderColor : COLOR;

sampler2D SampleColor
{
    Texture = RenderColor;
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

// Pixel Shaders
// Vogel disk sampling: http://blog.marmakoide.org/?p=1
// Rotated noise sampling: http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare (slide 123)

static const float Pi = 3.1415926535897932384626433832795;

float2 VogelSample(int Index, int SamplesCount)
{
    const float GoldenAngle = Pi * (3.0 - sqrt(5.0));
    float Radius = sqrt(float(Index) + 0.5) * rsqrt(float(SamplesCount));
    float Theta = float(Index) * GoldenAngle;

    float2 SinCosTheta = 0.0;
    sincos(Theta, SinCosTheta.x, SinCosTheta.y);
    return Radius * SinCosTheta;
}

float GradientNoise(float2 Position)
{
    const float3 Numbers = float3(0.06711056f, 0.00583715f, 52.9829189f);
    return frac(Numbers.z * frac(dot(Position.xy, Numbers.xy)));
}

void NoiseConvolutionPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    OutputColor0 = 0.0;

    const float2 PixelSize = 1.0 / uint2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float Noise = 2.0 * Pi * GradientNoise(Position.xy);

    float2 Rotation = 0.0;
    sincos(Noise, Rotation.y, Rotation.x);

    float2x2 RotationMatrix = float2x2(Rotation.x, Rotation.y,
                                      -Rotation.y, Rotation.x);

    for(int i = 0; i < _Samples; i++)
    {
        float2 SampleOffset = mul(VogelSample(i, _Samples), RotationMatrix);
        OutputColor0 += tex2D(SampleColor, TexCoord.xy + (SampleOffset * _Radius) * PixelSize);
    }

    OutputColor0 = OutputColor0 / _Samples;
}

technique cNoiseConvolution
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = NoiseConvolutionPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
