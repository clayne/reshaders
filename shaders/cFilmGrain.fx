
/*
    FilmGrain without texture fetches

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

uniform float _Speed <
    ui_label = "Speed";
    ui_type = "drag";
> = 2.0f;

uniform float _Variance <
    ui_label = "Variance";
    ui_type = "drag";
> = 0.5f;

uniform float _Intensity <
    ui_label = "Variance";
    ui_type = "drag";
> = 0.005f;

uniform float _Time < source = "timer"; >;

// Vertex shaders

void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Pixel shaders
// "Well ill believe it when i see it."
// Yoinked code by Luluco250 (RIP) [https://www.shadertoy.com/view/4t2fRz] [MIT]

float GaussianWeight(float x, float Sigma)
{
    const float Pi = 3.14159265359;
    Sigma = Sigma * Sigma;
    return rsqrt(Pi * Sigma) * exp(-((x * x) / (2.0 * Sigma)));
}

void FilmGrainPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    float Time = rcp(1e+3 / _Time) * _Speed;
    float Seed = dot(Position.xy, float2(12.9898, 78.233));
    float Noise = frac(sin(Seed) * 43758.5453 + Time);
    OutputColor0 = GaussianWeight(Noise, _Variance) * _Intensity;
}

technique cFilmGrain
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = FilmGrainPS;
        // (Shader[Src] * SrcBlend) + (Buffer[Dest] * DestBlend)
        // This shader: (Shader[Src] * (1.0 - Buffer[Dest])) + Buffer[Dest]
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVDESTCOLOR;
        DestBlend = ONE;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
