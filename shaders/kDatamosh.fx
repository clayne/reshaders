
/*
    Color datamoshing shader

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

#define SIZE int2(BUFFER_WIDTH >> 2, BUFFER_HEIGHT >> 2)
#define BUFFER_SIZE_1 int2(SIZE >> 0)
#define BUFFER_SIZE_2 int2(SIZE >> 2)
#define BUFFER_SIZE_3 int2(SIZE >> 4)
#define BUFFER_SIZE_4 int2(SIZE >> 6)

#define TEXTURE(NAME, SIZE, FORMAT, LEVELS) \
    texture2D NAME                          \
    {                                       \
        Width = SIZE.x;                     \
        Height = SIZE.y;                    \
        Format = FORMAT;                    \
        MipLevels = LEVELS;                 \
    };

#define SAMPLER(NAME, TEXTURE) \
    sampler2D NAME             \
    {                          \
        Texture = TEXTURE;     \
        AddressU = MIRROR;     \
        AddressV = MIRROR;     \
        MagFilter = LINEAR;    \
        MinFilter = LINEAR;    \
        MipFilter = LINEAR;    \
    };

#define OPTION(DATA_TYPE, NAME, TYPE, CATEGORY, LABEL, MINIMUM, MAXIMUM, DEFAULT) \
    uniform DATA_TYPE NAME <                                                      \
        ui_type = TYPE;                                                           \
        ui_category = CATEGORY;                                                   \
        ui_label = LABEL;                                                         \
        ui_min = MINIMUM;                                                         \
        ui_max = MAXIMUM;                                                         \
    > = DEFAULT;

#define PASS(VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
    pass                                                 \
    {                                                    \
        VertexShader = VERTEX_SHADER;                    \
        PixelShader = PIXEL_SHADER;                      \
        RenderTarget0 = RENDER_TARGET;                   \
    }

namespace Shared_Resources_Datamosh
{
    // Store convoluted normalized frame 1 and 3

    TEXTURE(Render_Common_0, int2(BUFFER_WIDTH >> 1, BUFFER_HEIGHT >> 1), RG16F, 4)
    SAMPLER(Sample_Common_0, Render_Common_0)

    // Normalized, prefiltered frames for processing

    TEXTURE(Render_Common_1_A, BUFFER_SIZE_1, RG16F, 8)
    SAMPLER(Sample_Common_1_A, Render_Common_1_A)

    TEXTURE(Render_Common_1_B, BUFFER_SIZE_1, RGBA16F, 8)
    SAMPLER(Sample_Common_1_B, Render_Common_1_B)

    // Estimation levels

    TEXTURE(Render_Common_2, BUFFER_SIZE_2, RG16F, 1)
    SAMPLER(Sample_Common_2, Render_Common_2)

    TEXTURE(Render_Common_3, BUFFER_SIZE_3, RG16F, 1)
    SAMPLER(Sample_Common_3, Render_Common_3)

    TEXTURE(Render_Common_4, BUFFER_SIZE_4, RG16F, 1)
    SAMPLER(Sample_Common_4, Render_Common_4)
}

namespace Datamosh
{
    // Shader properties

    uniform float _Time < source = "timer"; >;

    OPTION(int, _BlockSize, "slider", "Datamosh", "Block Size", 4, 32, 16)
    OPTION(float, _Entropy, "slider", "Datamosh", "Entropy", 0.0, 1.0, 0.5)
    OPTION(float, _Contrast, "slider", "Datamosh", "Contrast of stripe-shaped noise", 0.0, 4.0, 2.0)
    OPTION(float, _Scale, "slider", "Datamosh", "Scale factor for velocity vectors", 0.0, 4.0, 2.0)
    OPTION(float, _Diffusion, "slider", "Datamosh", "Amount of random displacement", 0.0, 4.0, 2.0)

    OPTION(float, _Constraint, "slider", "Optical flow", "Motion threshold", 0.0, 2.0, 1.0)
    OPTION(float, _MipBias, "slider", "Optical flow", "Optical flow mipmap bias", 0.0, 7.0, 0.0)
    OPTION(float, _BlendFactor, "slider", "Optical flow", "Temporal blending factor", 0.0, 0.9, 0.1)

    #ifndef LINEAR_SAMPLING
        #define LINEAR_SAMPLING 0
    #endif

    #if LINEAR_SAMPLING == 1
        #define _FILTER LINEAR
    #else
        #define _FILTER POINT
    #endif

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

    TEXTURE(Render_Common_1_P, BUFFER_SIZE_1, RG16F, 8)
    SAMPLER(Sample_Common_1_P, Render_Common_1_P)

    TEXTURE(Render_Optical_Flow, BUFFER_SIZE_1, RG16F, 1)
    SAMPLER(Sample_Optical_Flow, Render_Optical_Flow)

    sampler2D Sample_Optical_Flow_Post
    {
        Texture = Shared_Resources_Datamosh::Render_Common_1_B;
        MagFilter = _FILTER;
        MinFilter = _FILTER;
    };

    TEXTURE(Render_Accumulation, BUFFER_SIZE_1, R16F, 1)

    sampler2D Sample_Accumulation
    {
        Texture = Render_Accumulation;
        MagFilter = _FILTER;
        MinFilter = _FILTER;
    };

    TEXTURE(Render_Feedback, int2(BUFFER_WIDTH, BUFFER_HEIGHT), RGBA8, 1)

    sampler2D Sample_Feedback
    {
        Texture = Render_Feedback;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBTexture = TRUE;
        #endif
    };

    // Vertex Shaders

    void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
    {
        TexCoord.x = (ID == 2) ? 2.0 : 0.0;
        TexCoord.y = (ID == 1) ? 2.0 : 0.0;
        Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    }

    static const float2 BlurOffsets[8] =
    {
        float2(0.0, 0.0),
        float2(0.0, 1.4850045),
        float2(0.0, 3.4650571),
        float2(0.0, 5.445221),
        float2(0.0, 7.4255576),
        float2(0.0, 9.406127),
        float2(0.0, 11.386987),
        float2(0.0, 13.368189)
    };

    void Blur_0_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[8] : TEXCOORD0)
    {
        float2 CoordVS = 0.0;
        Basic_VS(ID, Position, CoordVS);
        TexCoords[0] = CoordVS.xyxy;

        for(int i = 1; i < 8; i++)
        {
            TexCoords[i].xy = CoordVS.xy - (BlurOffsets[i].yx / BUFFER_SIZE_1);
            TexCoords[i].zw = CoordVS.xy + (BlurOffsets[i].yx / BUFFER_SIZE_1);
        }
    }

    void Blur_1_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[8] : TEXCOORD0)
    {
        float2 CoordVS = 0.0;
        Basic_VS(ID, Position, CoordVS);
        TexCoords[0] = CoordVS.xyxy;

        for(int i = 1; i < 8; i++)
        {
            TexCoords[i].xy = CoordVS.xy - (BlurOffsets[i].xy / BUFFER_SIZE_1);
            TexCoords[i].zw = CoordVS.xy + (BlurOffsets[i].xy / BUFFER_SIZE_1);
        }
    }

    void Sample_3x3_VS(in uint ID : SV_VERTEXID, in float2 TexelSize, out float4 Position : SV_POSITION, out float4 TexCoords[3] : TEXCOORD0)
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

    void Sample_3x3_1_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_1, Position, TexCoords);
    }

    void Sample_3x3_2_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_2, Position, TexCoords);
    }

    void Sample_3x3_3_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_3, Position, TexCoords);
    }

    void Sample_3x3_4_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_4, Position, TexCoords);
    }

    void Derivatives_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 TexCoords[2] : TEXCOORD0)
    {
        float2 CoordVS = 0.0;
        Basic_VS(ID, Position, CoordVS);
        TexCoords[0] = CoordVS.xxyy + (float4(-1.5, 1.5, -0.5, 0.5) / BUFFER_SIZE_1.xxyy);
        TexCoords[1] = CoordVS.xxyy + (float4(-0.5, 0.5, -1.5, 1.5) / BUFFER_SIZE_1.xxyy);
    }

    // Pixel Shaders

    void Normalize_Frame_PS(in float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD, out float2 Color : SV_TARGET0)
    {
        float4 Frame = max(tex2D(Sample_Color, TexCoord), exp2(-10.0));
        Color.xy = saturate(Frame.xy / dot(Frame.rgb, 1.0));
    }

    void Blit_Frame_PS(in float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD, out float4 OutputColor0 : SV_TARGET0)
    {
        OutputColor0 = tex2D(Shared_Resources_Datamosh::Sample_Common_0, TexCoord);
    }

    static const float BlurWeights[8] =
    {
        0.079788454,
        0.15186256,
        0.12458323,
        0.08723135,
        0.05212966,
        0.026588224,
        0.011573823,
        0.0042996835
    };

    void Gaussian_Blur(in sampler2D Source, in float4 TexCoords[8], out float4 OutputColor0)
    {
        float TotalWeights = BlurWeights[0];
        OutputColor0 = (tex2D(Source, TexCoords[0].xy) * BlurWeights[0]);

        for(int i = 1; i < 8; i++)
        {
            OutputColor0 += (tex2D(Source, TexCoords[i].xy) * BlurWeights[i]);
            OutputColor0 += (tex2D(Source, TexCoords[i].zw) * BlurWeights[i]);
            TotalWeights += (BlurWeights[i] * 2.0);
        }

        OutputColor0 = OutputColor0 / TotalWeights;
    }

    void Pre_Blur_0_PS(in float4 Position : SV_POSITION, in float4 TexCoords[8] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Shared_Resources_Datamosh::Sample_Common_1_A, TexCoords, OutputColor0);
    }

    void Pre_Blur_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[8] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Shared_Resources_Datamosh::Sample_Common_1_B, TexCoords, OutputColor0);
    }

    void Derivatives_PS(in float4 Position : SV_POSITION, in float4 TexCoords[2] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        // Bilinear 5x5 Sobel by CeeJayDK
        //   B1 B2
        // A0     A1
        // A2     B0
        //   C0 C1
        float2 A0 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, TexCoords[0].xw).xy * 4.0; // <-1.5, +0.5>
        float2 A1 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, TexCoords[0].yw).xy * 4.0; // <+1.5, +0.5>
        float2 A2 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, TexCoords[0].xz).xy * 4.0; // <-1.5, -0.5>
        float2 B0 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, TexCoords[0].yz).xy * 4.0; // <+1.5, -0.5>
        float2 B1 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, TexCoords[1].xw).xy * 4.0; // <-0.5, +1.5>
        float2 B2 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, TexCoords[1].yw).xy * 4.0; // <+0.5, +1.5>
        float2 C0 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, TexCoords[1].xz).xy * 4.0; // <-0.5, -1.5>
        float2 C1 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, TexCoords[1].yz).xy * 4.0; // <+0.5, -1.5>

        //    -1 0 +1
        // -1 -2 0 +2 +1
        // -2 -2 0 +2 +2
        // -1 -2 0 +2 +1
        //    -1 0 +1
        OutputColor0.xy = ((B2 + A1 + B0 + C1) - (B1 + A0 + A2 + C0)) / 12.0;

        //    +1 +2 +1
        // +1 +2 +2 +2 +1
        //  0  0  0  0  0
        // -1 -2 -2 -2 -1
        //    -1 -2 -1
        OutputColor0.zw = ((A0 + B1 + B2 + A1) - (A2 + C0 + C1 + B0)) / 12.0;
        OutputColor0.xz *= rsqrt(dot(OutputColor0.xz, OutputColor0.xz) + 1.0);
        OutputColor0.yw *= rsqrt(dot(OutputColor0.yw, OutputColor0.yw) + 1.0);
    }

    #define MaxLevel 7
    #define E 1e-4

    void Coarse_Optical_Flow_TV(in float2 TexCoord, in float Level, in float2 UV, out float2 OpticalFlow)
    {
        OpticalFlow = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-4, Level - MaxLevel), 1e-7);

        // Load textures
        float2 Current = tex2Dlod(Shared_Resources_Datamosh::Sample_Common_1_A, float4(TexCoord, 0.0, Level)).xy;
        float2 Previous = tex2Dlod(Sample_Common_1_P, float4(TexCoord, 0.0, Level)).xy;

        // <Rx, Gx, Ry, Gy>
        float4 SD = tex2Dlod(Shared_Resources_Datamosh::Sample_Common_1_B, float4(TexCoord, 0.0, Level));

        // <Rz, Gz>
        float2 TD = Current - Previous;

        // Calculate constancy term
        float C = 0.0;
        float2 Aii = 0.0;
        float Aij = 0.0;
        float2 Bi = 0.0;

        // Calculate forward motion vectors

        C = dot(TD, 1.0);
        C = rsqrt(C * C + (E * E));

        Aii.x = 1.0 / (C * dot(SD.xy, SD.xy) + Alpha);
        Aii.y = 1.0 / (C * dot(SD.zw, SD.zw) + Alpha);

        Aij = C * dot(SD.xy, SD.zw);

        Bi.x = C * dot(SD.xy, TD);
        Bi.y = C * dot(SD.zw, TD);

        OpticalFlow.x = Aii.x * ((Alpha * UV.x) - (Aij * UV.y) - Bi.x);
        OpticalFlow.y = Aii.y * ((Alpha * UV.y) - (Aij * OpticalFlow.x) - Bi.y);
    }

    void Gradient_Average(in float2 SampleNW,
                          in float2 SampleNE,
                          in float2 SampleSW,
                          in float2 SampleSE,
                          out float Gradient,
                          out float2 Average)
    {
        // NW NE
        // SW SE
        float4 SqGradientUV = 0.0;
        SqGradientUV.xy = (SampleNW + SampleSW) - (SampleNE + SampleSE); // <IxU, IxV>
        SqGradientUV.zw = (SampleNW + SampleNE) - (SampleSW + SampleSE); // <IyU, IyV>
        SqGradientUV = SqGradientUV * 0.5;
        Gradient = rsqrt((dot(SqGradientUV.xzyw, SqGradientUV.xzyw) * 0.25) + (E * E));
        Average = (SampleNW + SampleNE + SampleSW + SampleSE) * 0.25;
    }

    void Process_Area(in float2 SampleUV[9],
                      inout float4 UVGradient,
                      inout float2 CenterAverage,
                      inout float2 UVAverage)
    {
        float CenterGradient = 0.0;
        float4 AreaGradient = 0.0;
        float2 AreaAverage[4];
        float4 GradientUV = 0.0;
        float SqGradientUV = 0.0;

        // Center smoothness gradient and average
        // 0 3 6
        // 1 4 7
        // 2 5 8
        GradientUV.xy = (SampleUV[0] + (SampleUV[1] * 2.0) + SampleUV[2]) - (SampleUV[6] + (SampleUV[7] * 2.0) + SampleUV[8]); // <IxU, IxV>
        GradientUV.zw = (SampleUV[0] + (SampleUV[3] * 2.0) + SampleUV[6]) - (SampleUV[2] + (SampleUV[5] * 2.0) + SampleUV[8]); // <IxU, IxV>
        SqGradientUV = dot(GradientUV.xzyw / 4.0, GradientUV.xzyw / 4.0) * 0.25;
        CenterGradient = rsqrt(SqGradientUV + (E * E));

        CenterAverage += ((SampleUV[0] + SampleUV[6] + SampleUV[2] + SampleUV[8]) * 1.0);
        CenterAverage += ((SampleUV[3] + SampleUV[1] + SampleUV[7] + SampleUV[5]) * 2.0);
        CenterAverage += (SampleUV[4] * 4.0);
        CenterAverage = CenterAverage / 16.0;

        // North-west gradient and average
        // 0 3 .
        // 1 4 .
        // . . .
        Gradient_Average(SampleUV[0], SampleUV[3], SampleUV[1], SampleUV[4], AreaGradient[0], AreaAverage[0]);

        // North-east gradient and average
        // . 3 6
        // . 4 7
        // . . .
        Gradient_Average(SampleUV[3], SampleUV[6], SampleUV[4], SampleUV[7], AreaGradient[1], AreaAverage[1]);

        // South-west gradient and average
        // . . .
        // 1 4 .
        // 2 5 .
        Gradient_Average(SampleUV[1], SampleUV[4], SampleUV[2], SampleUV[5], AreaGradient[2], AreaAverage[2]);

        // South-east and average
        // . . .
        // . 4 7
        // . 5 8
        Gradient_Average(SampleUV[4], SampleUV[7], SampleUV[5], SampleUV[8], AreaGradient[3], AreaAverage[3]);

        UVGradient = 0.5 * (CenterGradient + AreaGradient);
        UVAverage = (AreaGradient[0] * AreaAverage[0]) + (AreaGradient[1] * AreaAverage[1]) + (AreaGradient[2] * AreaAverage[2]) + (AreaGradient[3] * AreaAverage[3]);
    }

    void Optical_Flow_TV(in sampler2D SourceUV, in float4 TexCoords[3], in float Level, out float2 OpticalFlow)
    {
        OpticalFlow = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-4, Level - MaxLevel), 1e-7);

        // Load textures
        float2 Current = tex2Dlod(Shared_Resources_Datamosh::Sample_Common_1_A, float4(TexCoords[1].xz, 0.0, Level)).xy;
        float2 Previous = tex2Dlod(Sample_Common_1_P, float4(TexCoords[1].xz, 0.0, Level)).xy;

        // <Rx, Gx, Ry, Gy>
        float4 SD = tex2Dlod(Shared_Resources_Datamosh::Sample_Common_1_B, float4(TexCoords[1].xz, 0.0, Level));

        // <Rz, Gz>
        float2 TD = Current - Previous;

        // Optical flow calculation

        float2 SampleUV[9];
        float4 UVGradient = 0.0;
        float2 CenterAverage = 0.0;
        float2 UVAverage = 0.0;

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

        Process_Area(SampleUV, UVGradient, CenterAverage, UVAverage);

        float C = 0.0;
        float2 Aii = 0.0;
        float Aij = 0.0;
        float2 Bi = 0.0;

        // Calculate forward motion vectors

        C = dot(SD.xyzw, CenterAverage.xyxy) + dot(TD, 1.0);
        C = rsqrt(C * C + (E * E));

        Aii.x = 1.0 / (dot(UVGradient, 1.0) * Alpha + (C * dot(SD.xy, SD.xy)));
        Aii.y = 1.0 / (dot(UVGradient, 1.0) * Alpha + (C * dot(SD.zw, SD.zw)));

        Aij = C * dot(SD.xy, SD.zw);

        Bi.x = C * dot(SD.xy, TD);
        Bi.y = C * dot(SD.zw, TD);

        OpticalFlow.x = Aii.x * ((Alpha * UVAverage.x) - (Aij * CenterAverage.y) - Bi.x);
        OpticalFlow.y = Aii.y * ((Alpha * UVAverage.y) - (Aij * OpticalFlow.x) - Bi.y);
    }

    void Level_4_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float2 Color : SV_TARGET0)
    {
        Coarse_Optical_Flow_TV(TexCoord, 6.5, 0.0, Color);
    }

    void Level_3_PS(in float4 Position : SV_POSITION, in float4 TexCoords[3] : TEXCOORD0, out float2 Color : SV_TARGET0)
    {
        Optical_Flow_TV(Shared_Resources_Datamosh::Sample_Common_4, TexCoords, 4.5, Color);
    }

    void Level_2_PS(in float4 Position : SV_POSITION, in float4 TexCoords[3] : TEXCOORD0, out float2 Color : SV_TARGET0)
    {
        Optical_Flow_TV(Shared_Resources_Datamosh::Sample_Common_3, TexCoords, 2.5, Color);
    }

    void Level_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Optical_Flow_TV(Shared_Resources_Datamosh::Sample_Common_2, TexCoords, 0.5, OutputColor0.rg);
        OutputColor0.y *= -1.0;
        OutputColor0.ba = float2(0.0, _BlendFactor);
    }

    void Blit_Previous_PS(in float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD, out float4 OutputColor0 : SV_TARGET0)
    {
        OutputColor0 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, TexCoord);
    }

    void Post_Blur_0_PS(in float4 Position : SV_POSITION, in float4 TexCoords[8] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Sample_Optical_Flow, TexCoords, OutputColor0);
        OutputColor0.a = 1.0;
    }

    void Post_Blur_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[8] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Shared_Resources_Datamosh::Sample_Common_1_A, TexCoords, OutputColor0);
        OutputColor0.a = 1.0;
    }

    /*
        Color + BlendOp version of KinoDatamosh https://github.com/keijiro/KinoDatamosh

        This is free and unencumbered software released into the public domain.

        Anyone is free to copy, modify, publish, use, compile, sell, or
        distribute this software, either in source code form or as a compiled
        binary, for any purpose, commercial or non-commercial, and by any
        means.

        In jurisdictions that recognize copyright laws, the author or authors
        of this software dedicate any and all copyright interest in the
        software to the public domain. We make this dedication for the benefit
        of the public at large and to the detriment of our heirs and
        successors. We intend this dedication to be an overt act of
        relinquishment in perpetuity of all present and future rights to this
        software under copyright law.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
        EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
        MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
        IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
        OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
        ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
        OTHER DEALINGS IN THE SOFTWARE.

        For more information, please refer to <http://unlicense.org/>
    */

    float RandomNoise(float2 TexCoord)
    {
        float f = dot(float2(12.9898, 78.233), TexCoord);
        return frac(43758.5453 * sin(f));
    }

    void Accumulate_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        float Quality = 1.0 - _Entropy;
        float2 Time = float2(_Time, 0.0);

        // Random numbers
        float3 Random;
        Random.x = RandomNoise(TexCoord.xy + Time.xy);
        Random.y = RandomNoise(TexCoord.xy + Time.yx);
        Random.z = RandomNoise(TexCoord.yx - Time.xx);

        // Motion vector
        float2 MotionVectors = tex2Dlod(Sample_Optical_Flow_Post, float4(TexCoord, 0.0, _MipBias)).xy;
        MotionVectors = MotionVectors * BUFFER_SIZE_1; // Normalized screen space -> Pixel coordinates
        MotionVectors *= _Scale;
        MotionVectors += (Random.xy - 0.5)  * _Diffusion; // Small random displacement (diffusion)
        MotionVectors = round(MotionVectors); // Pixel perfect snapping

        // Accumulates the amount of motion.
        float MotionVectorLength = length(MotionVectors);

        // - Simple update
        float UpdateAccumulation = min(MotionVectorLength, _BlockSize) * 0.005;
        UpdateAccumulation = saturate(UpdateAccumulation + Random.z * lerp(-0.02, 0.02, Quality));

        // - Reset to random level
        float ResetAccumulation = saturate(Random.z * 0.5 + Quality);

        // - Reset if the amount of motion is larger than the block size.
        OutputColor0.rgb = MotionVectorLength > _BlockSize ? ResetAccumulation : UpdateAccumulation;
        OutputColor0.a = MotionVectorLength > _BlockSize ? 0.0 : 1.0;
    }

    void Datamosh_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        const float2 DisplacementTexel = 1.0 / BUFFER_SIZE_1;
        const float Quality = 1.0 - _Entropy;

        // Random numbers
        float2 Time = float2(_Time, 0.0);
        float3 Random;
        Random.x = RandomNoise(TexCoord.xy + Time.xy);
        Random.y = RandomNoise(TexCoord.xy + Time.yx);
        Random.z = RandomNoise(TexCoord.yx - Time.xx);

        float2 MotionVectors = tex2Dlod(Sample_Optical_Flow_Post, float4(TexCoord, 0.0, _MipBias)).xy;
        MotionVectors *= _Scale;

        float4 Source = tex2D(Sample_Color, TexCoord); // Color from the original image
        float Displacement = tex2D(Sample_Accumulation, TexCoord).r; // Displacement vector
        float4 Working = tex2D(Sample_Feedback, TexCoord - MotionVectors * DisplacementTexel);

        MotionVectors *= int2(BUFFER_WIDTH, BUFFER_HEIGHT); // Normalized screen space -> Pixel coordinates
        MotionVectors += (Random.xy - 0.5) * _Diffusion; // Small random displacement (diffusion)
        MotionVectors = round(MotionVectors); // Pixel perfect snapping
        MotionVectors *= (1.0 / int2(BUFFER_WIDTH, BUFFER_HEIGHT)); // Pixel coordinates -> Normalized screen space

        // Generate some pseudo random numbers.
        float RandomMotion = RandomNoise(TexCoord + length(MotionVectors));
        float4 RandomNumbers = frac(float4(1.0, 17.37135, 841.4272, 3305.121) * RandomMotion);

        // Generate noise patterns that look like DCT bases.
        float2 Frequency = TexCoord * DisplacementTexel * (RandomNumbers.x * 80.0 / _Contrast);
        // - Basis wave (vertical or horizontal)
        float DCT = cos(lerp(Frequency.x, Frequency.y, 0.5 < RandomNumbers.y));
        // - Random amplitude (the high freq, the less amp)
        DCT *= RandomNumbers.z * (1.0 - RandomNumbers.x) * _Contrast;

        // Conditional weighting
        // - DCT-ish noise: acc > 0.5
        float ConditionalWeight = (Displacement > 0.5) * DCT;
        // - Original image: rand < (Q * 0.8 + 0.2) && acc == 1.0
        ConditionalWeight = lerp(ConditionalWeight, 1.0, RandomNumbers.w < lerp(0.2, 1.0, Quality) * (Displacement > 1.0 - 1e-3));

        // - If the conditions above are not met, choose work.
        OutputColor0 = lerp(Working, Source, ConditionalWeight);
    }

    void Copy_0_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        OutputColor0 = tex2D(Sample_Color, TexCoord);
        OutputColor0.a = 1.0;
    }

    technique KinoDatamosh
    {
        // Normalize current frame
        PASS(Basic_VS, Normalize_Frame_PS, Shared_Resources_Datamosh::Render_Common_0)

        // Scale frame
        PASS(Basic_VS, Blit_Frame_PS, Shared_Resources_Datamosh::Render_Common_1_A)

        // Gaussian blur
        PASS(Blur_0_VS, Pre_Blur_0_PS, Shared_Resources_Datamosh::Render_Common_1_B)
        PASS(Blur_1_VS, Pre_Blur_1_PS, Shared_Resources_Datamosh::Render_Common_1_A) // Save this to store later

        // Calculate spatial derivative pyramid
        PASS(Derivatives_VS, Derivatives_PS, Shared_Resources_Datamosh::Render_Common_1_B)

        // Trilinear Optical Flow, calculate 2 levels at a time
        PASS(Basic_VS, Level_4_PS, Shared_Resources_Datamosh::Render_Common_4)
        PASS(Sample_3x3_4_VS, Level_3_PS, Shared_Resources_Datamosh::Render_Common_3)
        PASS(Sample_3x3_3_VS, Level_2_PS, Shared_Resources_Datamosh::Render_Common_2)

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

        // Store current convolved frame for next frame
        PASS(Basic_VS, Blit_Previous_PS, Render_Common_1_P)

        // Gaussian blur
        PASS(Blur_0_VS, Post_Blur_0_PS, Shared_Resources_Datamosh::Render_Common_1_A)
        PASS(Blur_1_VS, Post_Blur_1_PS, Shared_Resources_Datamosh::Render_Common_1_B)

        // Datamoshing

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Accumulate_PS;
            RenderTarget0 = Render_Accumulation;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = ONE;
            DestBlend = SRCALPHA; // The result about to accumulate
        }

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Datamosh_PS;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }

        // Copy frame for feedback

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Copy_0_PS;
            RenderTarget = Render_Feedback;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }
    }
}
