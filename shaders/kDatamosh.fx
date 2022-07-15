
/*
    Color datamoshing shader

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

namespace Datamosh
{
    /*
        [Shader properties]
    */

    #ifndef LINEAR_SAMPLING
        #define LINEAR_SAMPLING 0
    #endif

    #if LINEAR_SAMPLING == 1
        #define _FILTER LINEAR
    #else
        #define _FILTER POINT
    #endif

    #define OPTION(DATA_TYPE, NAME, TYPE, CATEGORY, LABEL, MINIMUM, MAXIMUM, DEFAULT) \
        uniform DATA_TYPE NAME <                                                      \
            ui_type = TYPE;                                                           \
            ui_category = CATEGORY;                                                   \
            ui_label = LABEL;                                                         \
            ui_min = MINIMUM;                                                         \
            ui_max = MAXIMUM;                                                         \
        > = DEFAULT;

    uniform float _Time < source = "timer"; >;

    OPTION(int, _BlockSize, "slider", "Datamosh", "Block Size", 4, 32, 16)
    OPTION(float, _Entropy, "slider", "Datamosh", "Entropy", 0.0, 1.0, 0.5)
    OPTION(float, _Contrast, "slider", "Datamosh", "Contrast of stripe-shaped noise", 0.0, 4.0, 2.0)
    OPTION(float, _Scale, "slider", "Datamosh", "Scale factor for velocity vectors", 0.0, 2.0, 1.0)
    OPTION(float, _Diffusion, "slider", "Datamosh", "Amount of random displacement", 0.0, 4.0, 2.0)

    OPTION(float, _MipBias, "slider", "Optical flow", "Optical flow mipmap bias", 0.0, 6.0, 2.0)
    OPTION(float, _BlendFactor, "slider", "Optical flow", "Temporal blending factor", 0.0, 0.9, 0.5)

    /*
        [Textures and samplers]
    */

    #define CREATE_TEXTURE(NAME, SIZE, FORMAT, LEVELS) \
    texture2D NAME \
    { \
        Width = SIZE.x; \
        Height = SIZE.y; \
        Format = FORMAT; \
        MipLevels = LEVELS; \
    };

    #define CREATE_SAMPLER(NAME, TEXTURE) \
        sampler2D NAME \
        { \
            Texture = TEXTURE; \
            AddressU = MIRROR; \
            AddressV = MIRROR; \
            MagFilter = LINEAR; \
            MinFilter = LINEAR; \
            MipFilter = LINEAR; \
        };

    CREATE_TEXTURE(Render_Common_0, int2(BUFFER_WIDTH >> 1, BUFFER_HEIGHT >> 1), R8, 4)
    CREATE_SAMPLER(Sample_Common_0, Render_Common_0)

    CREATE_TEXTURE(Render_Common_1_A, BUFFER_SIZE_1, RG16F, 9)
    CREATE_SAMPLER(Sample_Common_1_A, Render_Common_1_A)

    CREATE_TEXTURE(Render_Common_1_B, BUFFER_SIZE_1, RG16F, 9)
    CREATE_SAMPLER(Sample_Common_1_B, Render_Common_1_B)

    CREATE_TEXTURE(Render_Common_2_A, BUFFER_SIZE_2, RG16F, 7)
    CREATE_SAMPLER(Sample_Common_2_A, Render_Common_2_A)

    CREATE_TEXTURE(Render_Common_2_B, BUFFER_SIZE_2, RG16F, 1)
    CREATE_SAMPLER(Sample_Common_2_B, Render_Common_2_B)

    CREATE_TEXTURE(Render_Common_3, BUFFER_SIZE_3, RG16F, 1)
    CREATE_SAMPLER(Sample_Common_3, Render_Common_3)

    CREATE_TEXTURE(Render_Common_4, BUFFER_SIZE_4, RG16F, 1)
    CREATE_SAMPLER(Sample_Common_4, Render_Common_4)

    CREATE_TEXTURE(Render_Common_5, BUFFER_SIZE_5, RG16F, 1)
    CREATE_SAMPLER(Sample_Common_5, Render_Common_5)

    CREATE_TEXTURE(Render_Common_6, BUFFER_SIZE_6, RG16F, 1)
    CREATE_SAMPLER(Sample_Common_6, Render_Common_6)

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

    CREATE_TEXTURE(Render_Common_1_C, BUFFER_SIZE_1, RG16F, 9)
    CREATE_SAMPLER(Sample_Common_1_C, Render_Common_1_C)

    CREATE_TEXTURE(Render_Optical_Flow, BUFFER_SIZE_1, RG16F, 9)
    CREATE_SAMPLER(Sample_Optical_Flow, Render_Optical_Flow)

    sampler2D Sample_Optical_Flow_Post
    {
        Texture = Render_Common_2_A;
        MagFilter = _FILTER;
        MinFilter = _FILTER;
    };

    CREATE_TEXTURE(Render_Accumulation, BUFFER_SIZE_1, R16F, 1)

    sampler2D Sample_Accumulation
    {
        Texture = Render_Accumulation;
        MagFilter = _FILTER;
        MinFilter = _FILTER;
    };

    CREATE_TEXTURE(Render_Feedback, int2(BUFFER_WIDTH, BUFFER_HEIGHT), RGBA8, 1)

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

    /*
        [Vertex Shaders]
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

    void Blur_VS(in bool IsAlt, in float2 PixelSize, in uint ID, out float4 Position, out float4 TexCoords[7])
    {
        TexCoords[0] = 0.0;
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
        void NAME(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[7] : TEXCOORD0) \
        { \
            Blur_VS(IS_ALT, PIXEL_SIZE, ID, Position, TexCoords); \
        }

    BLUR_VS(Pre_Blur_0_VS, false, BUFFER_SIZE_1)
    BLUR_VS(Pre_Blur_1_VS, true, BUFFER_SIZE_1)
    BLUR_VS(Post_Blur_0_VS, false, BUFFER_SIZE_2)
    BLUR_VS(Post_Blur_1_VS, true, BUFFER_SIZE_2)

    void Level_VS(in uint ID, in float2 TexelSize, out float4 Position, out float2 Tex0, out float4 Tex1)
    {
        Basic_VS(ID, Position, Tex0);
        Tex1 = Tex0.xyxy + (float4(-0.5, -0.5, 0.5, 0.5) / TexelSize.xyxy);
    }

    #define CREATE_LEVEL_VS(NAME, BUFFER_SIZE) \
        void NAME(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 Tex0 : TEXCOORD0, out float4 Tex1 : TEXCOORD1) \
        { \
            Level_VS(ID, BUFFER_SIZE, Position, Tex0, Tex1); \
        }

    CREATE_LEVEL_VS(LK_Level_1_VS, BUFFER_SIZE_1)
    CREATE_LEVEL_VS(LK_Level_2_VS, BUFFER_SIZE_2)
    CREATE_LEVEL_VS(LK_Level_3_VS, BUFFER_SIZE_3)
    CREATE_LEVEL_VS(LK_Level_4_VS, BUFFER_SIZE_4)
    CREATE_LEVEL_VS(LK_Level_5_VS, BUFFER_SIZE_5)
    CREATE_LEVEL_VS(LK_Level_6_VS, BUFFER_SIZE_6)

    void Derivatives_Spatial_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 TexCoords[2] : TEXCOORD0)
    {
        float2 CoordVS = 0.0;
        Basic_VS(ID, Position, CoordVS);
        TexCoords[0] = CoordVS.xxyy + (float4(-1.5, 1.5, -0.5, 0.5) / BUFFER_SIZE_1.xxyy);
        TexCoords[1] = CoordVS.xxyy + (float4(-0.5, 0.5, -1.5, 1.5) / BUFFER_SIZE_1.xxyy);
    }

    /*
        [Pixel Shaders]

        [1] Color + BlendOp version of KinoDatamosh
            https://github.com/keijiro/KinoDatamosh

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

    void Saturate_Image_PS(in float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD, out float4 Color : SV_TARGET0)
    {
        float4 Frame = max(tex2D(Sample_Color, TexCoord), exp2(-10.0));
        // Normalize color vector to always be in [0,1] range with a sum of sqrt(3.0)
        Color.xyz = saturate(normalize(Frame.xyz));
        // Calculate the distance between the normalized chromaticity coordinates and its middle-gray
        // Middle-gray = (maximum normalized value, 1.0) / (sum of normalized components, sqrt(3.0))
        Color = saturate(distance(Color.xyz, 1.0 / sqrt(3.0)));
    }

    void Blit_Frame_PS(in float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD, out float4 OutputColor0 : SV_TARGET0)
    {
        OutputColor0 = tex2D(Sample_Common_0, TexCoord);
    }

    static const float BlurWeights[10] =
    {
        0.06299088,
        0.122137636, 0.10790718, 0.08633988,
        0.062565096, 0.04105926, 0.024403222,
        0.013135255, 0.006402994, 0.002826693
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
        Gaussian_Blur(Sample_Common_1_A, TexCoords, false, OutputColor0);
    }

    void Pre_Blur_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[7] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Sample_Common_1_B, TexCoords, true, OutputColor0);
    }

    void Derivatives_Temporal_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
    {
        float Current = tex2D(Sample_Common_1_A, TexCoord).x;
        float Previous = tex2D(Sample_Common_1_C, TexCoord).x;
        OutputColor0 = Current - Previous;
    }

    void Derivatives_Spatial_PS(in float4 Position : SV_POSITION, in float4 TexCoords[2] : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
    {
        // Bilinear 5x5 Sobel by CeeJayDK
        //   B1 B2
        // A0     A1
        // A2     B0
        //   C0 C1
        float A0 = tex2D(Sample_Common_1_A, TexCoords[0].xw).x * 4.0; // <-1.5, +0.5>
        float A1 = tex2D(Sample_Common_1_A, TexCoords[0].yw).x * 4.0; // <+1.5, +0.5>
        float A2 = tex2D(Sample_Common_1_A, TexCoords[0].xz).x * 4.0; // <-1.5, -0.5>
        float B0 = tex2D(Sample_Common_1_A, TexCoords[0].yz).x * 4.0; // <+1.5, -0.5>
        float B1 = tex2D(Sample_Common_1_A, TexCoords[1].xw).x * 4.0; // <-0.5, +1.5>
        float B2 = tex2D(Sample_Common_1_A, TexCoords[1].yw).x * 4.0; // <+0.5, +1.5>
        float C0 = tex2D(Sample_Common_1_A, TexCoords[1].xz).x * 4.0; // <-0.5, -1.5>
        float C1 = tex2D(Sample_Common_1_A, TexCoords[1].yz).x * 4.0; // <+0.5, -1.5>

        OutputColor0 = 0.0;
        OutputColor0.x = ((B2 + A1 + B0 + C1) - (B1 + A0 + A2 + C0)) / 12.0;
        OutputColor0.y = ((A0 + B1 + B2 + A1) - (A2 + C0 + C1 + B0)) / 12.0;
    }

    float2 Lucas_Kanade(int Level, float2 Vectors, float4 TexCoord)
    {
        // 3x3 Spatial derivative window in 4 bilinear fetches
        // [TexCoord.xw TexCoord.zw]
        // [TexCoord.xy TexCoord.zy]
        float2 S[4];
        S[0] = tex2D(Sample_Common_1_C, TexCoord.xw).xy;
        S[1] = tex2D(Sample_Common_1_C, TexCoord.zw).xy;
        S[2] = tex2D(Sample_Common_1_C, TexCoord.xy).xy;
        S[3] = tex2D(Sample_Common_1_C, TexCoord.zy).xy;

        // A.x = Ix^2 (A11); A.y = Iy^2 (A22); A.z = IxIy (A12)
        float3 A = float3(FP16_MINIMUM, FP16_MINIMUM, 0.0);
        A += (S[0].xyx * S[0].xyy);
        A += (S[1].xyx * S[1].xyy);
        A += (S[2].xyx * S[2].xyy);
        A += (S[3].xyx * S[3].xyy);
        A /= 4.0;

        // Determinant
        float D = (A.x * A.y - A.z * A.z);

        // Temporal derivative window in 4 bilinear fetches
        float T[4];
        T[0] = tex2D(Sample_Common_1_B, TexCoord.xw).x;
        T[1] = tex2D(Sample_Common_1_B, TexCoord.zw).x;
        T[2] = tex2D(Sample_Common_1_B, TexCoord.xy).x;
        T[3] = tex2D(Sample_Common_1_B, TexCoord.zy).x;

        // B.x = IxIt (Q1); B.y = IyIt (Q2)
        float2 B = 0.0;
        B += (S[0] * T[0]);
        B += (S[1] * T[1]);
        B += (S[2] * T[2]);
        B += (S[3] * T[3]);
        B /= 4.0;

        float2 UV = (D != 0.0) ? ((A.yx * B.xy - A.zz * B.yx) / D) + Vectors : 0.0;
        return UV;
    }

    #define CREATE_LK_LEVEL_PS(NAME, LEVEL, SAMPLER) \
        void NAME(in float4 Position : SV_POSITION, in float2 Tex0 : TEXCOORD0, in float4 Tex1 : TEXCOORD1, out float2 Color : SV_TARGET0) \
        { \
            Color = Lucas_Kanade(LEVEL, tex2D(SAMPLER, Tex0).xy, Tex1); \
        }

    void LK_Level_6_PS(in float4 Position : SV_POSITION, in float2 Tex0 : TEXCOORD0, in float4 Tex1 : TEXCOORD1, out float2 Color : SV_TARGET0)
    {
        Color = Lucas_Kanade(5, 0.0, Tex1);
    }

    CREATE_LK_LEVEL_PS(LK_Level_5_PS, 4, Sample_Common_6)
    CREATE_LK_LEVEL_PS(LK_Level_4_PS, 3, Sample_Common_5)
    CREATE_LK_LEVEL_PS(LK_Level_3_PS, 2, Sample_Common_4)
    CREATE_LK_LEVEL_PS(LK_Level_2_PS, 1, Sample_Common_3)

    void LK_Level_1_PS(in float4 Position : SV_POSITION, in float2 Tex0 : TEXCOORD0, in float4 Tex1 : TEXCOORD1, out float4 Color : SV_TARGET0)
    {
        Color = float4(Lucas_Kanade(0, tex2D(Sample_Common_2_A, Tex0).xy, Tex1), 0.0, _BlendFactor);
    }

    void Copy_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        OutputColor0 = tex2D(Sample_Common_1_A, TexCoord);
    }

    void Post_Blur_0_PS(in float4 Position : SV_POSITION, in float4 TexCoords[7] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Sample_Optical_Flow, TexCoords, false, OutputColor0);
        OutputColor0.a = 1.0;
    }

    void Post_Blur_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[7] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Sample_Common_2_B, TexCoords, true, OutputColor0);
        OutputColor0.a = 1.0;
    }

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
        MotionVectors = MotionVectors * BUFFER_SIZE_2; // Normalized screen space -> Pixel coordinates
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
        const float2 DisplacementTexel = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
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

    #define CREATE_PASS(VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
        pass \
        { \
            VertexShader = VERTEX_SHADER; \
            PixelShader = PIXEL_SHADER; \
            RenderTarget0 = RENDER_TARGET; \
        }

    technique KinoDatamosh
    {
        // Normalize current frame
        CREATE_PASS(Basic_VS, Saturate_Image_PS, Render_Common_0)

        // Scale frame
        CREATE_PASS(Basic_VS, Blit_Frame_PS, Render_Common_1_A)

        // Gaussian blur
        CREATE_PASS(Pre_Blur_0_VS, Pre_Blur_0_PS, Render_Common_1_B)
        CREATE_PASS(Pre_Blur_1_VS, Pre_Blur_1_PS, Render_Common_1_A) // Save this to store later

        // Calculate derivative pyramids
        CREATE_PASS(Basic_VS, Derivatives_Temporal_PS, Render_Common_1_B)
        CREATE_PASS(Derivatives_Spatial_VS, Derivatives_Spatial_PS, Render_Common_1_C)

        // Bilinear Optical Flow
        CREATE_PASS(LK_Level_6_VS, LK_Level_6_PS, Render_Common_6)
        CREATE_PASS(LK_Level_5_VS, LK_Level_5_PS, Render_Common_5)
        CREATE_PASS(LK_Level_4_VS, LK_Level_4_PS, Render_Common_4)
        CREATE_PASS(LK_Level_3_VS, LK_Level_3_PS, Render_Common_3)
        CREATE_PASS(LK_Level_2_VS, LK_Level_2_PS, Render_Common_2_A)

        pass
        {
            VertexShader = LK_Level_1_VS;
            PixelShader = LK_Level_1_PS;
            RenderTarget0 = Render_Optical_Flow;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        // Copy current convolved frame for next frame
        CREATE_PASS(Basic_VS, Copy_PS, Render_Common_1_C)

        // Gaussian blur
        CREATE_PASS(Post_Blur_0_VS, Post_Blur_0_PS, Render_Common_2_B)
        CREATE_PASS(Post_Blur_1_VS, Post_Blur_1_PS, Render_Common_2_A)

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
