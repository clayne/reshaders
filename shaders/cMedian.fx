
/*
    Simple 3x3 median shader

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

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

void MedianOffsets(in float2 TexCoord, in float2 PixelSize, out float4 SampleOffsets[3])
{
    // Sample locations:
    // [0].xy [1].xy [2].xy
    // [0].xz [1].xz [2].xz
    // [0].xw [1].xw [2].xw
    SampleOffsets[0] = TexCoord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
    SampleOffsets[1] = TexCoord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
    SampleOffsets[2] = TexCoord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
}

void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = TexCoord.xyxy * float4(2.0, -2.0, 0.0, 0.0) + float4(-1.0, 1.0, 0.0, 1.0);
}

void MedianVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
{
    float2 TexCoord0;
    PostProcessVS(ID, Position, TexCoord0);
    MedianOffsets(TexCoord0, 1.0 / (float2(BUFFER_WIDTH, BUFFER_HEIGHT)), Offsets);
}

// Math functions: https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/MiniEngine/Core/Shaders/DoFMedianFilterCS.hlsl

float4 Max3(float4 a, float4 b, float4 c)
{
    return max(max(a, b), c);
}

float4 Min3(float4 a, float4 b, float4 c)
{
    return min(min(a, b), c);
}

float4 Med3(float4 a, float4 b, float4 c)
{
    return clamp(a, min(b, c), max(b, c));
}

float4 Med9(float4 x0, float4 x1, float4 x2,
            float4 x3, float4 x4, float4 x5,
            float4 x6, float4 x7, float4 x8)
{
    float4 A = Max3(Min3(x0, x1, x2), Min3(x3, x4, x5), Min3(x6, x7, x8));
    float4 B = Min3(Max3(x0, x1, x2), Max3(x3, x4, x5), Max3(x6, x7, x8));
    float4 C = Med3(Med3(x0, x1, x2), Med3(x3, x4, x5), Med3(x6, x7, x8));
    return Med3(A, B, C);
}

void MedianPS(in float4 Position : SV_Position, in float4 Offsets[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    // Sample locations:
    // [0].xy [1].xy [2].xy
    // [0].xz [1].xz [2].xz
    // [0].xw [1].xw [2].xw
    float4 OutputColor = 0.0;
    float4 Sample[9];
    Sample[0] = tex2D(_SampleColor, Offsets[0].xy);
    Sample[1] = tex2D(_SampleColor, Offsets[1].xy);
    Sample[2] = tex2D(_SampleColor, Offsets[2].xy);
    Sample[3] = tex2D(_SampleColor, Offsets[0].xz);
    Sample[4] = tex2D(_SampleColor, Offsets[1].xz);
    Sample[5] = tex2D(_SampleColor, Offsets[2].xz);
    Sample[6] = tex2D(_SampleColor, Offsets[0].xw);
    Sample[7] = tex2D(_SampleColor, Offsets[1].xw);
    Sample[8] = tex2D(_SampleColor, Offsets[2].xw);
    OutputColor0 = Med9(Sample[0], Sample[1], Sample[2],
                        Sample[3], Sample[4], Sample[5],
                        Sample[6], Sample[7], Sample[8]);
}

technique cMedian
{
    pass
    {
        VertexShader = MedianVS;
        PixelShader = MedianPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
