
/*
    Optical flow visualization shader

    BSD 3-Clause License

    Copyright (c) 2022, Paul Dang <brimson.net@gmail.com>
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

#define FP16_MINIMUM float((1.0 / float(1 << 14)) * (0.0 + (1.0 / 1024.0)))

#define RCP_HEIGHT (1.0 / BUFFER_HEIGHT)
#define ASPECT_RATIO (BUFFER_WIDTH * RCP_HEIGHT)
#define ROUND_UP_EVEN(x) int(x) + (int(x) % 2)
#define RENDER_BUFFER_WIDTH int(ROUND_UP_EVEN(256.0 * ASPECT_RATIO))
#define RENDER_BUFFER_HEIGHT int(256.0)

#define SIZE int2(RENDER_BUFFER_WIDTH, RENDER_BUFFER_HEIGHT)
#define BUFFER_SIZE_1 int2(ROUND_UP_EVEN(SIZE.x >> 0), ROUND_UP_EVEN(SIZE.y >> 0))
#define BUFFER_SIZE_2 int2(ROUND_UP_EVEN(SIZE.x >> 1), ROUND_UP_EVEN(SIZE.y >> 1))
#define BUFFER_SIZE_3 int2(ROUND_UP_EVEN(SIZE.x >> 2), ROUND_UP_EVEN(SIZE.y >> 2))
#define BUFFER_SIZE_4 int2(ROUND_UP_EVEN(SIZE.x >> 3), ROUND_UP_EVEN(SIZE.y >> 3))
#define BUFFER_SIZE_5 int2(ROUND_UP_EVEN(SIZE.x >> 4), ROUND_UP_EVEN(SIZE.y >> 4))
#define BUFFER_SIZE_6 int2(ROUND_UP_EVEN(SIZE.x >> 5), ROUND_UP_EVEN(SIZE.y >> 5))

#define TEXTURE(NAME, SIZE, FORMAT, LEVELS) \
    texture2D NAME \
    { \
        Width = SIZE.x; \
        Height = SIZE.y; \
        Format = FORMAT; \
        MipLevels = LEVELS; \
    };

#define SAMPLER(NAME, TEXTURE) \
    sampler2D NAME             \
    { \
        Texture = TEXTURE; \
        AddressU = MIRROR; \
        AddressV = MIRROR; \
        MagFilter = LINEAR; \
        MinFilter = LINEAR; \
        MipFilter = LINEAR; \
    };

namespace Shared_Resources_Flow
{
    TEXTURE(Render_Common_0, int2(BUFFER_WIDTH >> 1, BUFFER_HEIGHT >> 1), RG16F, 4)
    SAMPLER(Sample_Common_0, Render_Common_0)

    TEXTURE(Render_Common_1_A, BUFFER_SIZE_1, RG16F, 9)
    SAMPLER(Sample_Common_1_A, Render_Common_1_A)

    TEXTURE(Render_Common_1_B, BUFFER_SIZE_1, RG16F, 9)
    SAMPLER(Sample_Common_1_B, Render_Common_1_B)

    TEXTURE(Render_Common_2_A, BUFFER_SIZE_2, RG16F, 7)
    SAMPLER(Sample_Common_2_A, Render_Common_2_A)

    TEXTURE(Render_Common_2_B, BUFFER_SIZE_2, RG16F, 1)
    SAMPLER(Sample_Common_2_B, Render_Common_2_B)

    TEXTURE(Render_Common_3, BUFFER_SIZE_3, RG16F, 1)
    SAMPLER(Sample_Common_3, Render_Common_3)

    TEXTURE(Render_Common_4, BUFFER_SIZE_4, RG16F, 1)
    SAMPLER(Sample_Common_4, Render_Common_4)

    TEXTURE(Render_Common_5, BUFFER_SIZE_5, RG16F, 1)
    SAMPLER(Sample_Common_5, Render_Common_5)

    TEXTURE(Render_Common_6, BUFFER_SIZE_6, RG16F, 1)
    SAMPLER(Sample_Common_6, Render_Common_6)
}

namespace OpticalFlow
{
    // Shader properties

    #define OPTION(DATA_TYPE, NAME, TYPE, CATEGORY, LABEL, MINIMUM, MAXIMUM, DEFAULT) \
        uniform DATA_TYPE NAME <                                                      \
            ui_type = TYPE;                                                           \
            ui_category = CATEGORY;                                                   \
            ui_label = LABEL;                                                         \
            ui_min = MINIMUM;                                                         \
            ui_max = MAXIMUM;                                                         \
        > = DEFAULT;

    OPTION(float, _Constraint, "slider", "Optical flow", "Motion constraint", 0.0, 1.0, 0.5)
    OPTION(float, _MipBias, "drag", "Optical flow", "Optical flow mipmap bias", 0.0, 6.0, 0.0)
    OPTION(float, _BlendFactor, "slider", "Optical flow", "Temporal blending factor", 0.0, 0.9, 0.1)

    OPTION(bool, _NormalizedShading, "radio", "Velocity shading", "Normalize velocity shading", 0.0, 1.0, true)
    OPTION(float, _LineColorShift, "color", "Velocity streaming", "Line color shift", 0.0, 1.0, 1.0)
    OPTION(float, _LineOpacity, "slider", "Velocity streaming", "Line opacity", 0.0, 1.0, 1.0)

    OPTION(bool, _BackgroundColor, "radio", "Velocity streaming", "Enable plain base color", 0.0, 1.0, false)
    OPTION(float, _BackgoundColorShift, "color", "Velocity streaming", "Background color shift", 0.0, 1.0, 0.0)

    OPTION(bool, _NormalDirection, "radio", "Velocity streaming", "Normalize direction", 0.0, 1.0, false)
    OPTION(bool, _ScaleLineVelocity, "radio", "Velocity streaming", "Scale velocity color", 0.0, 1.0, false)

    #ifndef RENDER_VELOCITY_STREAMS
        #define RENDER_VELOCITY_STREAMS 0
    #endif

    #ifndef VERTEX_SPACING
        #define VERTEX_SPACING 20
    #endif

    #ifndef VELOCITY_SCALE_FACTOR
        #define VELOCITY_SCALE_FACTOR 20
    #endif

    #define LINES_X uint(BUFFER_WIDTH / VERTEX_SPACING)
    #define LINES_Y uint(BUFFER_HEIGHT / VERTEX_SPACING)
    #define NUM_LINES (LINES_X * LINES_Y)
    #define SPACE_X (BUFFER_WIDTH / LINES_X)
    #define SPACE_Y (BUFFER_HEIGHT / LINES_Y)
    #define VELOCITY_SCALE (SPACE_X + SPACE_Y) * VELOCITY_SCALE_FACTOR

    texture2D Render_Color : COLOR;

    sampler2D Sample_Color
    {
        Texture = Render_Color;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBTexture = TRUE;
        #endif
    };

    TEXTURE(Render_Common_1_C, BUFFER_SIZE_1, RG16F, 9)
    SAMPLER(Sample_Common_1_C, Render_Common_1_C)

    TEXTURE(Render_Optical_Flow, BUFFER_SIZE_1, RG16F, 9)
    SAMPLER(Sample_Optical_Flow, Render_Optical_Flow)

    // Optical flow visualization

    #if RENDER_VELOCITY_STREAMS
        TEXTURE(Render_Lines, int2(BUFFER_WIDTH, BUFFER_HEIGHT), RGBA8, 1)
        SAMPLER(Sample_Lines, Render_Lines)
    #endif

    SAMPLER(Sample_Color_Gamma, Render_Color)

    /*
        [Vertex Shaders]

        [1] Velocity streaming and shading
            https://github.com/diwi/PixelFlow

            MIT License

            Copyright (c) 2016 Thomas Diewald

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

    void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
    {
        TexCoord.x = (ID == 2) ? 2.0 : 0.0;
        TexCoord.y = (ID == 1) ? 2.0 : 0.0;
        Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    }

    static const float4 BlurOffsets[3] =
    {
        float4(0.0, 1.490652, 3.4781995, 5.465774),
        float4(0.0, 7.45339, 9.441065, 11.42881),
        float4(0.0, 13.416645, 15.404578, 17.392626)
    };

    void Blur_VS(in bool IsAlt, in float2 PixelSize, in uint ID, inout float4 Position, inout float4 TexCoords[7])
    {
        Basic_VS(ID, Position, TexCoords[0].xy);

        if (!IsAlt)
        {
            TexCoords[1] = TexCoords[0].xyyy + (BlurOffsets[0].xyzw / PixelSize.xyyy);
            TexCoords[2] = TexCoords[0].xyyy + (BlurOffsets[1].xyzw / PixelSize.xyyy);
            TexCoords[3] = TexCoords[0].xyyy + (BlurOffsets[2].xyzw / PixelSize.xyyy);
            TexCoords[4] = TexCoords[0].xyyy - (BlurOffsets[0].xyzw / PixelSize.xyyy);
            TexCoords[5] = TexCoords[0].xyyy - (BlurOffsets[1].xyzw / PixelSize.xyyy);
            TexCoords[6] = TexCoords[0].xyyy - (BlurOffsets[2].xyzw / PixelSize.xyyy);
        }
        else
        {
            TexCoords[1] = TexCoords[0].xxxy + (BlurOffsets[0].yzwx / PixelSize.xxxy);
            TexCoords[2] = TexCoords[0].xxxy + (BlurOffsets[1].yzwx / PixelSize.xxxy);
            TexCoords[3] = TexCoords[0].xxxy + (BlurOffsets[2].yzwx / PixelSize.xxxy);
            TexCoords[4] = TexCoords[0].xxxy - (BlurOffsets[0].yzwx / PixelSize.xxxy);
            TexCoords[5] = TexCoords[0].xxxy - (BlurOffsets[1].yzwx / PixelSize.xxxy);
            TexCoords[6] = TexCoords[0].xxxy - (BlurOffsets[2].yzwx / PixelSize.xxxy);
        }

    }

    #define BLUR_VS(NAME, IS_ALT, PIXEL_SIZE) \
        void NAME(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 TexCoords[7] : TEXCOORD0) \
        { \
            Blur_VS(IS_ALT, PIXEL_SIZE, ID, Position, TexCoords); \
        }

    BLUR_VS(Pre_Blur_0_VS, false, BUFFER_SIZE_1)
    BLUR_VS(Pre_Blur_1_VS, true, BUFFER_SIZE_1)
    BLUR_VS(Post_Blur_0_VS, false, BUFFER_SIZE_2)
    BLUR_VS(Post_Blur_1_VS, true, BUFFER_SIZE_2)

    void Sample_3x3_VS(in uint ID, in float2 TexelSize, out float4 Position, out float4 TexCoords[3])
    {
        float2 CoordVS = 0.0;
        Basic_VS(ID, Position, CoordVS);
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        TexCoords[0] = CoordVS.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) / TexelSize.xyyy);
        TexCoords[1] = CoordVS.xyyy + (float4(0.0, 1.0, 0.0, -1.0) / TexelSize.xyyy);
        TexCoords[2] = CoordVS.xyyy + (float4(1.0, 1.0, 0.0, -1.0) / TexelSize.xyyy);
    }

    #define SAMPLE_3X3_VS(NAME, BUFFER_SIZE)                                                                        \
        void NAME(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[3] : TEXCOORD0) \
        {                                                                                                           \
            Sample_3x3_VS(ID, BUFFER_SIZE, Position, TexCoords);                                                    \
        }

    SAMPLE_3X3_VS(Sample_3x3_1_VS, BUFFER_SIZE_1)
    SAMPLE_3X3_VS(Sample_3x3_2_VS, BUFFER_SIZE_2)
    SAMPLE_3X3_VS(Sample_3x3_3_VS, BUFFER_SIZE_3)
    SAMPLE_3X3_VS(Sample_3x3_4_VS, BUFFER_SIZE_4)
    SAMPLE_3X3_VS(Sample_3x3_5_VS, BUFFER_SIZE_5)
    SAMPLE_3X3_VS(Sample_3x3_6_VS, BUFFER_SIZE_6)

    void Derivatives_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 TexCoords[2] : TEXCOORD0)
    {
        float2 CoordVS = 0.0;
        Basic_VS(ID, Position, CoordVS);
        TexCoords[0] = CoordVS.xxyy + (float4(-1.5, 1.5, -0.5, 0.5) / BUFFER_SIZE_1.xxyy);
        TexCoords[1] = CoordVS.xxyy + (float4(-0.5, 0.5, -1.5, 1.5) / BUFFER_SIZE_1.xxyy);
    }

    void Velocity_Streams_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 Velocity : TEXCOORD0)
    {
        int LineID = ID / 2; // Line Index
        int VertexID = ID % 2; // Vertex Index within the line (0 = start, 1 = end)

        // Get Row (x) and Column (y) position
        int Row = LineID / LINES_X;
        int Column = LineID - LINES_X * Row;

        // Compute origin (line-start)
        const float2 Spacing = float2(SPACE_X, SPACE_Y);
        float2 Offset = Spacing * 0.5;
        float2 Origin = Offset + float2(Column, Row) * Spacing;

        // Get velocity from texture at origin location
        const float2 PixelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
        float2 VelocityCoord = 0.0;
        VelocityCoord.xy = Origin.xy * PixelSize.xy;
        VelocityCoord.y = 1.0 - VelocityCoord.y;
        Velocity = tex2Dlod(Shared_Resources_Flow::Sample_Common_2_A, float4(VelocityCoord, 0.0, _MipBias)).xy;

        // Scale velocity
        float2 Direction = Velocity * VELOCITY_SCALE;

        float Length = length(Direction + 1e-5);
        Direction = Direction / sqrt(Length * 0.1);

        // Color for fragmentshader
        Velocity = Direction * 0.2;

        // Compute current vertex position (based on VertexID)
        float2 VertexPosition = 0.0;

        if(_NormalDirection)
        {
            // Lines: Normal to velocity direction
            Direction *= 0.5;
            float2 DirectionNormal = float2(Direction.y, -Direction.x);
            VertexPosition = Origin + Direction - DirectionNormal + DirectionNormal * VertexID * 2;
        }
        else
        {
            // Lines: Velocity direction
            VertexPosition = Origin + Direction * VertexID;
        }

        // Finish vertex position
        float2 VertexPositionNormal = (VertexPosition + 0.5) * PixelSize; // [0, 1]
        Position = float4(VertexPositionNormal * 2.0 - 1.0, 0.0, 1.0); // ndc: [-1, +1]
    }

    /*
        [Pixel Shaders]

        [1] Horn-Schunck Optical Flow
            https://github.com/Dtananaev/cv_opticalFlow

                Copyright (c) 2014-2015, Denis Tananaev All rights reserved.

                Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

                Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

                Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the
                documentation and/or other materials provided with the distribution.

                THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
                INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
                DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
                EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
                LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
                STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
                ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

        [2] Robert's cross operator
            https://homepages.inf.ed.ac.uk/rbf/HIPR2/roberts.htm

        [3] Prewitt compass operator
            https://homepages.inf.ed.ac.uk/rbf/HIPR2/prewitt.htm
    */

    void Normalize_Frame_PS(in float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD, out float2 Color : SV_TARGET0)
    {
        float4 Frame = max(tex2D(Sample_Color, TexCoord), exp2(-10.0));
        Color.xy = saturate(Frame.xy / dot(Frame.xyz, 1.0));
    }

    void Blit_Frame_PS(in float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD, out float4 OutputColor0 : SV_TARGET0)
    {
        OutputColor0 = tex2D(Shared_Resources_Flow::Sample_Common_0, TexCoord);
    }

    static const float BlurWeights[10] =
    {
        0.06299088,
        0.122137636,
        0.10790718,
        0.08633988,
        0.062565096,
        0.04105926,
        0.024403222,
        0.013135255,
        0.006402994,
        0.002826693
    };

    void Gaussian_Blur(in sampler2D Source, in float4 TexCoords[7], bool Alt, out float4 OutputColor0)
    {
        float TotalWeights = BlurWeights[0];
        OutputColor0 = (tex2D(Source, TexCoords[0].xy) * BlurWeights[0]);

        int CoordIndex = 1;
        int WeightIndex = 1;

        while(CoordIndex < 4)
        {
            if(!Alt)
            {
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex].xy) * BlurWeights[WeightIndex + 0]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex].xz) * BlurWeights[WeightIndex + 1]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex].xw) * BlurWeights[WeightIndex + 2]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex + 3].xy) * BlurWeights[WeightIndex + 0]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex + 3].xz) * BlurWeights[WeightIndex + 1]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex + 3].xw) * BlurWeights[WeightIndex + 2]);
            }
            else
            {
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex].xw) * BlurWeights[WeightIndex + 0]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex].yw) * BlurWeights[WeightIndex + 1]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex].zw) * BlurWeights[WeightIndex + 2]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex + 3].xw) * BlurWeights[WeightIndex + 0]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex + 3].yw) * BlurWeights[WeightIndex + 1]);
                OutputColor0 += (tex2D(Source, TexCoords[CoordIndex + 3].zw) * BlurWeights[WeightIndex + 2]);
            }

            CoordIndex = CoordIndex + 1;
            WeightIndex = WeightIndex + 3;
        }

        for(int i = 1; i < 10; i++)
        {
            TotalWeights += (BlurWeights[i] * 2.0);
        }

        OutputColor0 = OutputColor0 / TotalWeights;
    }

    void Pre_Blur_0_PS(in float4 Position : SV_POSITION, in float4 TexCoords[7] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Shared_Resources_Flow::Sample_Common_1_A, TexCoords, false, OutputColor0);
    }

    void Pre_Blur_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[7] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Shared_Resources_Flow::Sample_Common_1_B, TexCoords, true, OutputColor0);
    }

    void Derivatives_Z_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
    {
        float2 Current = tex2D(Shared_Resources_Flow::Sample_Common_1_A, TexCoord).xy;
        float2 Previous = tex2D(Sample_Common_1_C, TexCoord).xy;
        OutputColor0 = dot(Current - Previous, 1.0);
    }

    void Derivatives_XY_PS(in float4 Position : SV_POSITION, in float4 TexCoords[2] : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
    {
        // Bilinear 5x5 Sobel by CeeJayDK
        //   B1 B2
        // A0     A1
        // A2     B0
        //   C0 C1
        float2 A0 = tex2D(Shared_Resources_Flow::Sample_Common_1_A, TexCoords[0].xw).xy * 4.0; // <-1.5, +0.5>
        float2 A1 = tex2D(Shared_Resources_Flow::Sample_Common_1_A, TexCoords[0].yw).xy * 4.0; // <+1.5, +0.5>
        float2 A2 = tex2D(Shared_Resources_Flow::Sample_Common_1_A, TexCoords[0].xz).xy * 4.0; // <-1.5, -0.5>
        float2 B0 = tex2D(Shared_Resources_Flow::Sample_Common_1_A, TexCoords[0].yz).xy * 4.0; // <+1.5, -0.5>
        float2 B1 = tex2D(Shared_Resources_Flow::Sample_Common_1_A, TexCoords[1].xw).xy * 4.0; // <-0.5, +1.5>
        float2 B2 = tex2D(Shared_Resources_Flow::Sample_Common_1_A, TexCoords[1].yw).xy * 4.0; // <+0.5, +1.5>
        float2 C0 = tex2D(Shared_Resources_Flow::Sample_Common_1_A, TexCoords[1].xz).xy * 4.0; // <-0.5, -1.5>
        float2 C1 = tex2D(Shared_Resources_Flow::Sample_Common_1_A, TexCoords[1].yz).xy * 4.0; // <+0.5, -1.5>

        OutputColor0 = 0.0;
        float2 Ix = ((B2 + A1 + B0 + C1) - (B1 + A0 + A2 + C0)) / 12.0;
        float2 Iy = ((A0 + B1 + B2 + A1) - (A2 + C0 + C1 + B0)) / 12.0;
        OutputColor0.x = dot(Ix, 1.0);
        OutputColor0.y = dot(Iy, 1.0);
    }

    #define COARSEST_LEVEL 5

    // Calculate first level of Horn-Schunck Optical Flow
    void Coarse_Optical_Flow_TV(in float2 TexCoord, in float Level, in float4 UV, out float2 OpticalFlow)
    {
        OpticalFlow = 0.0;
        const float Alpha = max((_Constraint * 1e-3) / pow(4.0, COARSEST_LEVEL - Level), FP16_MINIMUM);

        // Load textures
        float2 SD = tex2Dlod(Sample_Common_1_C, float4(TexCoord, 0.0, Level + 0.5)).xy;
        float TD = tex2Dlod(Shared_Resources_Flow::Sample_Common_1_B, float4(TexCoord, 0.0, Level + 0.5)).x;

        float C = 0.0;
        float2 Aii = 0.0;
        float Aij = 0.0;
        float2 Bi = 0.0;

        // Calculate constancy assumption nonlinearity
        C = rsqrt((TD * TD) + FP16_MINIMUM);

        // Build linear equation
        // [Aii Aij] [X] = [Bi]
        // [Aij Aii] [Y] = [Bi]
        Aii = 1.0 / (C * (SD.xy * SD.xy) + Alpha);
        Aij = C * (SD.x * SD.y);
        Bi = C * (SD.xy * TD);

        // Solve linear equation for [U, V]
        // [Ix^2+A IxIy] [U] = -[IxIt]
        // [IxIy Iy^2+A] [V] = -[IyIt]
        OpticalFlow.x = Aii.x * ((Alpha * UV.x) - (Aij * UV.y) - Bi.x);
        OpticalFlow.y = Aii.y * ((Alpha * UV.y) - (Aij * OpticalFlow.x) - Bi.y);
    }

    void Gradient(in float4x2 Samples, out float Gradient)
    {
        // 2x2 Robert's cross
        // [0] [2]
        // [1] [3]
        float4 SqGradientUV = 0.0;
        SqGradientUV.xy = (Samples[0] - Samples[3]); // <IxU, IxV>
        SqGradientUV.zw = (Samples[2] - Samples[1]); // <IyU, IyV>
        Gradient = rsqrt((dot(SqGradientUV, SqGradientUV) * 0.25) + FP16_MINIMUM);
    }

    float2 Prewitt(float2 SampleUV[9], float3x3 Weights)
    {
        // [0] [3] [6]
        // [1] [4] [7]
        // [2] [5] [8]
        float2 Output;
        Output += (SampleUV[0] * Weights._11);
        Output += (SampleUV[1] * Weights._12);
        Output += (SampleUV[2] * Weights._13);
        Output += (SampleUV[3] * Weights._21);
        Output += (SampleUV[4] * Weights._22);
        Output += (SampleUV[5] * Weights._23);
        Output += (SampleUV[6] * Weights._31);
        Output += (SampleUV[7] * Weights._32);
        Output += (SampleUV[8] * Weights._33);
        return Output;
    }

    void Process_Gradients(in float2 SampleUV[9], inout float4 AreaGrad, inout float4 UVGradient)
    {
        // Calculate center gradient using Prewitt compass operator
        // 0.xy           | 0.zw           | 1.xy           | 1.zw           | 2.xy           | 2.zw           | 3.xy           | 3.zw
        // .......................................................................................................................................
        // -1.0 +1.0 +1.0 | +1.0 +1.0 +1.0 | +1.0 +1.0 +1.0 | +1.0 +1.0 +1.0 | +1.0 +1.0 -1.0 | +1.0 -1.0 -1.0 | -1.0 -1.0 -1.0 | -1.0 -1.0 +1.0 |
        // -1.0 -2.0 +1.0 | -1.0 -2.0 +1.0 | +1.0 -2.0 +1.0 | +1.0 -2.0 -1.0 | +1.0 -2.0 -1.0 | +1.0 -2.0 -1.0 | +1.0 -2.0 +1.0 | -1.0 -2.0 +1.0 |
        // -1.0 +1.0 +1.0 | -1.0 -1.0 +1.0 | -1.0 -1.0 -1.0 | +1.0 -1.0 -1.0 | +1.0 +1.0 -1.0 | +1.0 +1.0 +1.0 | +1.0 +1.0 +1.0 | +1.0 +1.0 +1.0 |

        float4 PrewittUV[4];
        PrewittUV[0].xy = Prewitt(SampleUV, float3x3(-1.0, +1.0, +1.0, -1.0, -2.0, +1.0, -1.0, +1.0, +1.0));
        PrewittUV[0].zw = Prewitt(SampleUV, float3x3(+1.0, +1.0, +1.0, -1.0, -2.0, +1.0, -1.0, -1.0, +1.0));
        PrewittUV[1].xy = Prewitt(SampleUV, float3x3(+1.0, +1.0, +1.0, +1.0, -2.0, +1.0, -1.0, -1.0, -1.0));
        PrewittUV[1].zw = Prewitt(SampleUV, float3x3(+1.0, +1.0, +1.0, +1.0, -2.0, -1.0, +1.0, -1.0, -1.0));
        PrewittUV[2].xy = Prewitt(SampleUV, float3x3(+1.0, +1.0, -1.0, +1.0, -2.0, -1.0, +1.0, +1.0, -1.0));
        PrewittUV[2].zw = Prewitt(SampleUV, float3x3(+1.0, -1.0, -1.0, +1.0, -2.0, -1.0, +1.0, +1.0, +1.0));
        PrewittUV[3].xy = Prewitt(SampleUV, float3x3(-1.0, -1.0, -1.0, +1.0, -2.0, +1.0, +1.0, +1.0, +1.0));
        PrewittUV[3].zw = Prewitt(SampleUV, float3x3(-1.0, -1.0, +1.0, -1.0, -2.0, +1.0, +1.0, +1.0, +1.0));

        float2 MaxGradient[3];
        MaxGradient[0] = max(max(abs(PrewittUV[0].xy), abs(PrewittUV[0].zw)), max(abs(PrewittUV[1].xy), abs(PrewittUV[1].zw)));
        MaxGradient[1] = max(max(abs(PrewittUV[2].xy), abs(PrewittUV[2].zw)), max(abs(PrewittUV[3].xy), abs(PrewittUV[3].zw)));

        const float Weight = 1.0 / 5.0;
        MaxGradient[2] = max(abs(MaxGradient[0]), abs(MaxGradient[1])) * Weight;
        float CenterGradient = rsqrt((dot(MaxGradient[2], MaxGradient[2])) + FP16_MINIMUM);

        // Area smoothness gradients
        // .............................
        //  [0]     [1]     [2]     [3]
        // 0 3 . | . 3 6 | . . . | . . .
        // 1 4 . | . 4 7 | 1 4 . | . 4 7
        // . . . | . . . | 2 5 . | . 5 8
        Gradient(float4x2(SampleUV[0], SampleUV[3], SampleUV[1], SampleUV[4]), AreaGrad[0]);
        Gradient(float4x2(SampleUV[3], SampleUV[6], SampleUV[4], SampleUV[7]), AreaGrad[1]);
        Gradient(float4x2(SampleUV[1], SampleUV[4], SampleUV[2], SampleUV[5]), AreaGrad[2]);
        Gradient(float4x2(SampleUV[4], SampleUV[7], SampleUV[5], SampleUV[8]), AreaGrad[3]);
        UVGradient = 0.5 * (CenterGradient + AreaGrad);
    }

    void Area_Average(in float2 SampleNW, in float2 SampleNE, in float2 SampleSW, in float2 SampleSE, out float2 Color)
    {
        Color = (SampleNW + SampleNE + SampleSW + SampleSE) * 0.25;
    }

    // Calculate following levels of Horn-Schunck Optical Flow
    void Optical_Flow_TV(in sampler2D SourceUV, in float4 TexCoords[3], in float Level, out float2 OpticalFlow)
    {
        OpticalFlow = 0.0;
        const float Alpha = max((_Constraint * 1e-3) / pow(4.0, COARSEST_LEVEL - Level), FP16_MINIMUM);

        // Load textures
        float2 SD = tex2Dlod(Sample_Common_1_C, float4(TexCoords[1].xz, 0.0, Level + 0.5)).xy;
        float TD = tex2Dlod(Shared_Resources_Flow::Sample_Common_1_B, float4(TexCoords[1].xz, 0.0, Level + 0.5)).x;

        // Optical flow calculation
        float2 SampleUV[9];
        float4 AreaGrad;
        float4 UVGradient;
        float2 AreaAvg[4];
        float4 CenterAverage;
        float4 UVAverage;

        // SampleUV[i]
        // 0 3 6
        // 1 4 7
        // 2 5 8
        SampleUV[0] = tex2D(SourceUV, TexCoords[0].xy).xy;
        SampleUV[1] = tex2D(SourceUV, TexCoords[0].xz).xy;
        SampleUV[2] = tex2D(SourceUV, TexCoords[0].xw).xy;
        SampleUV[3] = tex2D(SourceUV, TexCoords[1].xy).xy;
        SampleUV[4] = tex2D(SourceUV, TexCoords[1].xz).xy;
        SampleUV[5] = tex2D(SourceUV, TexCoords[1].xw).xy;
        SampleUV[6] = tex2D(SourceUV, TexCoords[2].xy).xy;
        SampleUV[7] = tex2D(SourceUV, TexCoords[2].xz).xy;
        SampleUV[8] = tex2D(SourceUV, TexCoords[2].xw).xy;

        // Process area gradients in each patch, per plane
        Process_Gradients(SampleUV, AreaGrad, UVGradient);

        // Calculate area + center averages of estimated vectors
        Area_Average(SampleUV[0], SampleUV[3], SampleUV[1], SampleUV[4], AreaAvg[0]);
        Area_Average(SampleUV[3], SampleUV[6], SampleUV[4], SampleUV[7], AreaAvg[1]);
        Area_Average(SampleUV[1], SampleUV[4], SampleUV[2], SampleUV[5], AreaAvg[2]);
        Area_Average(SampleUV[4], SampleUV[7], SampleUV[5], SampleUV[8], AreaAvg[3]);

        CenterAverage += ((SampleUV[0] + SampleUV[6] + SampleUV[2] + SampleUV[8]) * 1.0);
        CenterAverage += ((SampleUV[3] + SampleUV[1] + SampleUV[7] + SampleUV[5]) * 2.0);
        CenterAverage += (SampleUV[4] * 4.0);
        CenterAverage = CenterAverage / 16.0;

        float C = 0.0;
        float2 Aii = 0.0;
        float Aij = 0.0;
        float2 Bi = 0.0;

        // Calculate constancy assumption nonlinearity
        // Dot-product increases when the current gradient + previous estimation are parallel
        // IxU + IyV = -It -> IxU + IyV + It = 0.0
        C = dot(SD.xy, CenterAverage.xy) + TD;
        C = rsqrt((C * C) + FP16_MINIMUM);

        // Build linear equation
        // [Aii Aij] [X] = [Bi]
        // [Aij Aii] [Y] = [Bi]
        Aii = 1.0 / (dot(UVGradient, 1.0) * Alpha + (C * (SD.xy * SD.xy)));
        Aij = C * (SD.x * SD.y);
        Bi = C * (SD.xy * TD);

        // Solve linear equation for [U, V]
        // [Ix^2+A IxIy] [U] = -[IxIt]
        // [IxIy Iy^2+A] [V] = -[IyIt]
        UVAverage.xy = (AreaGrad.xx * AreaAvg[0]) + (AreaGrad.yy * AreaAvg[1]) + (AreaGrad.zz * AreaAvg[2]) + (AreaGrad.ww * AreaAvg[3]);
        OpticalFlow.x = Aii.x * ((Alpha * UVAverage.x) - (Aij * CenterAverage.y) - Bi.x);
        OpticalFlow.y = Aii.y * ((Alpha * UVAverage.y) - (Aij * OpticalFlow.x) - Bi.y);
    }

    #define LEVEL_PS(NAME, SAMPLER, LEVEL)                                                                             \
        void NAME(in float4 Position : SV_POSITION, in float4 TexCoords[3] : TEXCOORD0, out float2 Color : SV_TARGET0) \
        {                                                                                                              \
            Optical_Flow_TV(SAMPLER, TexCoords, LEVEL, Color);                                                         \
        }

    void Level_6_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float2 Color : SV_TARGET0)
    {
        Coarse_Optical_Flow_TV(TexCoord, 5.0, 0.0, Color);
    }

    LEVEL_PS(Level_5_PS, Shared_Resources_Flow::Sample_Common_6, 4.0)
    LEVEL_PS(Level_4_PS, Shared_Resources_Flow::Sample_Common_5, 3.0)
    LEVEL_PS(Level_3_PS, Shared_Resources_Flow::Sample_Common_4, 2.0)
    LEVEL_PS(Level_2_PS, Shared_Resources_Flow::Sample_Common_3, 1.0)

    void Level_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        OutputColor0 = 0.0;
        Optical_Flow_TV(Shared_Resources_Flow::Sample_Common_2_A, TexCoords, 0.0, OutputColor0.xy);
        OutputColor0.ba = float2(0.0, _BlendFactor);
    }

    void Copy_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        OutputColor0 = tex2D(Shared_Resources_Flow::Sample_Common_1_A, TexCoord);
    }

    void Post_Blur_0_PS(in float4 Position : SV_POSITION, in float4 TexCoords[7] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Sample_Optical_Flow, TexCoords, false, OutputColor0);
        OutputColor0.a = 1.0;
    }

    void Post_Blur_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[7] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Shared_Resources_Flow::Sample_Common_2_B, TexCoords, true, OutputColor0);
        OutputColor0.a = 1.0;
    }

    void Velocity_Shading_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
    {
        float2 Velocity = tex2Dlod(Shared_Resources_Flow::Sample_Common_2_A, float4(TexCoord, 0.0, _MipBias)).xy;

        if(_NormalizedShading)
        {
            float Velocity_Length = saturate(rsqrt(dot(Velocity, Velocity)));
            OutputColor0.rg = (Velocity * Velocity_Length) * 0.5 + 0.5;
            OutputColor0.b = -dot(OutputColor0.rg, 1.0) * 0.5 + 1.0;
            OutputColor0.rgb /= max(max(OutputColor0.x, OutputColor0.y), OutputColor0.z);
            OutputColor0.a = 1.0;
        }
        else
        {
            OutputColor0 = float4(Velocity, 0.0, 1.0);
        }
    }

    #if RENDER_VELOCITY_STREAMS
        void Velocity_Streams_PS(in float4 Position : SV_POSITION, in float2 Velocity : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
        {
            OutputColor0.rg = (_ScaleLineVelocity) ? (Velocity.xy / (length(Velocity) * VELOCITY_SCALE * 0.05)) : normalize(Velocity.xy);
            OutputColor0.rg = OutputColor0.xy * 0.5 + 0.5;
            OutputColor0.b = -dot(OutputColor0.rg, 1.0) * 0.5 + 1.0;
            OutputColor0.rgb /= max(max(OutputColor0.x, OutputColor0.y), OutputColor0.z);
            OutputColor0.a = 1.0;
        }

        void Velocity_Streams_Display_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float3 OutputColor0 : SV_TARGET0)
        {
            float4 Lines = tex2D(Sample_Lines, TexCoord);
            float3 Main_Color = (_BackgroundColor) ? _BackgoundColorShift : tex2D(Sample_Color_Gamma, TexCoord).rgb * _BackgoundColorShift;
            OutputColor0 = lerp(Main_Color, Lines.rgb * _LineColorShift, Lines.aaa * _LineOpacity);
        }
    #endif

    #define PASS(VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
        pass \
        { \
            VertexShader = VERTEX_SHADER; \
            PixelShader = PIXEL_SHADER; \
            RenderTarget0 = RENDER_TARGET; \
        }

    technique cOpticalFlow
    {
        // Normalize current frame
        PASS(Basic_VS, Normalize_Frame_PS, Shared_Resources_Flow::Render_Common_0)

        // Scale frame
        PASS(Basic_VS, Blit_Frame_PS, Shared_Resources_Flow::Render_Common_1_A)

        // Gaussian blur
        PASS(Pre_Blur_0_VS, Pre_Blur_0_PS, Shared_Resources_Flow::Render_Common_1_B)
        PASS(Pre_Blur_1_VS, Pre_Blur_1_PS, Shared_Resources_Flow::Render_Common_1_A) // Save this to store later

        // Calculate spatial and temporal derivative pyramid
        PASS(Basic_VS, Derivatives_Z_PS, Shared_Resources_Flow::Render_Common_1_B)
        PASS(Derivatives_VS, Derivatives_XY_PS, Render_Common_1_C)

        // Bilinear Optical Flow
        PASS(Basic_VS, Level_6_PS, Shared_Resources_Flow::Render_Common_6)
        PASS(Sample_3x3_6_VS, Level_5_PS, Shared_Resources_Flow::Render_Common_5)
        PASS(Sample_3x3_5_VS, Level_4_PS, Shared_Resources_Flow::Render_Common_4)
        PASS(Sample_3x3_4_VS, Level_3_PS, Shared_Resources_Flow::Render_Common_3)
        PASS(Sample_3x3_3_VS, Level_2_PS, Shared_Resources_Flow::Render_Common_2_A)

        pass
        {
            VertexShader = Sample_3x3_2_VS;
            PixelShader = Level_1_PS;
            RenderTarget0 = Render_Optical_Flow;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        // Copy current convolved frame for next frame
        PASS(Basic_VS, Copy_PS, Render_Common_1_C)

        // Gaussian blur
        PASS(Post_Blur_0_VS, Post_Blur_0_PS, Shared_Resources_Flow::Render_Common_2_B)
        PASS(Post_Blur_1_VS, Post_Blur_1_PS, Shared_Resources_Flow::Render_Common_2_A)

        // Visualize optical flow

        #if RENDER_VELOCITY_STREAMS
            // Render to a fullscreen buffer (cringe!)
            pass
            {
                PrimitiveTopology = LINELIST;
                VertexCount = NUM_LINES * 2;
                VertexShader = Velocity_Streams_VS;
                PixelShader = Velocity_Streams_PS;
                ClearRenderTargets = TRUE;
                RenderTarget0 = Render_Lines;
            }

            pass
            {
                VertexShader = Basic_VS;
                PixelShader = Velocity_Streams_Display_PS;
                ClearRenderTargets = FALSE;
            }
        #else
            pass
            {
                VertexShader = Basic_VS;
                PixelShader = Velocity_Shading_PS;
            }
        #endif
    }
}
