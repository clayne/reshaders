
/*
    Color Datamoshing

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

// Shared textures

#define BUFFER_SIZE_0 uint2(BUFFER_WIDTH >> 0, BUFFER_HEIGHT >> 0)
#define BUFFER_SIZE_1 uint2(BUFFER_WIDTH >> 1, BUFFER_HEIGHT >> 1)
#define BUFFER_SIZE_2 uint2(BUFFER_WIDTH >> 2, BUFFER_HEIGHT >> 2)
#define BUFFER_SIZE_3 uint2(BUFFER_WIDTH >> 3, BUFFER_HEIGHT >> 3)
#define BUFFER_SIZE_4 uint2(BUFFER_WIDTH >> 4, BUFFER_HEIGHT >> 4)
#define BUFFER_SIZE_5 uint2(BUFFER_WIDTH >> 5, BUFFER_HEIGHT >> 5)
#define BUFFER_SIZE_6 uint2(BUFFER_WIDTH >> 6, BUFFER_HEIGHT >> 6)
#define BUFFER_SIZE_7 uint2(BUFFER_WIDTH >> 7, BUFFER_HEIGHT >> 7)
#define BUFFER_SIZE_8 uint2(BUFFER_WIDTH >> 8, BUFFER_HEIGHT >> 8)

namespace SharedResources
{
    namespace RGBA16F
    {
        texture2D RenderCommon1 < pooled = true; >
        {
            Width = BUFFER_SIZE_1.x;
            Height = BUFFER_SIZE_1.y;
            Format = RGBA16F;
            MipLevels = 8;
        };
    }

    namespace RG16F
    {
        texture2D RenderCommon1 < pooled = true; >
        {
            Width = BUFFER_SIZE_1.x;
            Height = BUFFER_SIZE_1.y;
            Format = RG16F;
            MipLevels = 8;
        };

        texture2D RenderCommon2 < pooled = true; >
        {
            Width = BUFFER_SIZE_2.x;
            Height = BUFFER_SIZE_2.y;
            Format = RG16F;
        };

        texture2D RenderCommon3 < pooled = true; >
        {
            Width = BUFFER_SIZE_3.x;
            Height = BUFFER_SIZE_3.y;
            Format = RG16F;
        };

        texture2D RenderCommon4 < pooled = true; >
        {
            Width = BUFFER_SIZE_4.x;
            Height = BUFFER_SIZE_4.y;
            Format = RG16F;
        };

        texture2D RenderCommon5 < pooled = true; >
        {
            Width = BUFFER_SIZE_5.x;
            Height = BUFFER_SIZE_5.y;
            Format = RG16F;
        };

        texture2D RenderCommon6 < pooled = true; >
        {
            Width = BUFFER_SIZE_6.x;
            Height = BUFFER_SIZE_6.y;
            Format = RG16F;
        };

        texture2D RenderCommon7 < pooled = true; >
        {
            Width = BUFFER_SIZE_7.x;
            Height = BUFFER_SIZE_7.y;
            Format = RG16F;
        };

        texture2D RenderCommon8 < pooled = true; >
        {
            Width = BUFFER_SIZE_8.x;
            Height = BUFFER_SIZE_8.y;
            Format = RG16F;
        };
    }
}

namespace OpticalFlow
{
    // Shader properties

    uniform float _Time < source = "timer"; >;

    uniform int _BlockSize <
        ui_category = "Datamosh";
        ui_type = "slider";
        ui_label = "Block Size";
        ui_min = 4;
        ui_max = 32;
    > = 16;

    uniform float _Entropy <
        ui_category = "Datamosh";
        ui_type = "slider";
        ui_label = "Entropy";
        ui_tooltip = "The larger value stronger noise and makes mosh last longer.";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.5;

    uniform float _Contrast <
        ui_category = "Datamosh";
        ui_type = "slider";
        ui_label = "Contrast";
        ui_tooltip = "Contrast of stripe-shaped noise.";
        ui_min = 0.0;
        ui_max = 4.0;
    > = 2.0;

    uniform float _Scale <
        ui_category = "Datamosh";
        ui_type = "slider";
        ui_label = "Scale";
        ui_tooltip = "Scale factor for velocity vectors.";
        ui_min = 0.0;
        ui_max = 4.0;
    > = 2.0;

    uniform float _Diffusion <
        ui_category = "Datamosh";
        ui_type = "slider";
        ui_label = "Diffusion";
        ui_tooltip = "Amount of random displacement.";
        ui_min = 0.0;
        ui_max = 4.0;
    > = 2.0;

    uniform float _Constraint <
        ui_category = "Motion Vectors";
        ui_type = "drag";
        ui_label = "Constraint";
        ui_tooltip = "Higher = Smoother flow";
        ui_min = 0.0;
    > = 1.0;

    uniform float _Smoothness <
        ui_category = "Motion Vectors";
        ui_type = "drag";
        ui_label = "Motion Smoothness";
        ui_min = 0.0;
    > = 1.0;

    uniform float _BlendFactor <
        ui_category = "Motion Vectors";
        ui_type = "drag";
        ui_label = "Temporal Smoothing";
        ui_tooltip = "Higher = Less temporal noise";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.25;

    uniform float _MipBias <
        ui_category = "Motion Vectors";
        ui_type = "drag";
        ui_label = "Blockiness";
        ui_tooltip = "How blocky the motion vectors should be.";
        ui_min = 0.0;
    > = 3.5;

    #ifndef LINEAR_SAMPLING
        #define LINEAR_SAMPLING 0
    #endif

    #if LINEAR_SAMPLING == 1
        #define _FILTER LINEAR
    #else
        #define _FILTER POINT
    #endif

    // Textures and samplers

    texture2D RenderColor : COLOR;

    sampler2D SampleColor
    {
        Texture = RenderColor;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBTexture = TRUE;
        #endif
    };

    sampler2D SampleCommon_RG16F_1a
    {
        Texture = SharedResources::RG16F::RenderCommon1;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SampleCommon_RGBA16F_1a
    {
        Texture = SharedResources::RGBA16F::RenderCommon1;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderPreviousBuffer
    {
        Width = BUFFER_WIDTH / 2;
        Height = BUFFER_HEIGHT / 2;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D SamplePreviousBuffer
    {
        Texture = RenderPreviousBuffer;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SampleCommon_RG16F_8
    {
        Texture = SharedResources::RG16F::RenderCommon8;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SampleCommon_RG16F_7
    {
        Texture = SharedResources::RG16F::RenderCommon7;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SampleCommon_RG16F_6
    {
        Texture = SharedResources::RG16F::RenderCommon6;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SampleCommon_RG16F_5
    {
        Texture = SharedResources::RG16F::RenderCommon5;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SampleCommon_RG16F_4
    {
        Texture = SharedResources::RG16F::RenderCommon4;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SampleCommon_RG16F_3
    {
        Texture = SharedResources::RG16F::RenderCommon3;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SampleCommon_RG16F_2
    {
        Texture = SharedResources::RG16F::RenderCommon2;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderVectors
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = RG16F;
    };

    sampler2D SampleVectors
    {
        Texture = RenderVectors;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
    };

    sampler2D SampleVectorsPost
    {
        Texture = SharedResources::RGBA16F::RenderCommon1;
        MagFilter = _FILTER;
        MinFilter = _FILTER;
    };

    texture2D RenderAccumulation
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = R16F;
    };

    sampler2D SampleAccumulation
    {
        Texture = RenderAccumulation;
        MagFilter = _FILTER;
        MinFilter = _FILTER;
    };

    texture2D RenderFeedback
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
    };

    sampler2D SampleFeedback
    {
        Texture = RenderFeedback;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBTexture = TRUE;
        #endif
    };

    // Vertex shaders

    void MedianOffsets(in float2 TexCoord, in float2 PixelSize, inout float4 SampleOffsets[3])
    {
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        SampleOffsets[0] = TexCoord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
        SampleOffsets[1] = TexCoord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
        SampleOffsets[2] = TexCoord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
    }

    void TentOffsets(in float2 TexCoord, in float2 TexelSize, inout float4 SampleOffsets[3])
    {
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        SampleOffsets[0] = TexCoord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * TexelSize.xyyy);
        SampleOffsets[1] = TexCoord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * TexelSize.xyyy);
        SampleOffsets[2] = TexCoord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * TexelSize.xyyy);
    }

    void PostProcessVS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float2 TexCoord : TEXCOORD0)
    {
        TexCoord.x = (ID == 2) ? 2.0 : 0.0;
        TexCoord.y = (ID == 1) ? 2.0 : 0.0;
        Position = TexCoord.xyxy * float4(2.0, -2.0, 0.0, 0.0) + float4(-1.0, 1.0, 0.0, 1.0);
    }

    void MedianVS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        MedianOffsets(TexCoord0, 1.0 / uint2(BUFFER_WIDTH >> 1, BUFFER_HEIGHT >> 1), Offsets);
    }

    void TentFilterVS(in uint ID, in float2 TexelSize, inout float4 Position, inout float4 Offsets[3])
    {
        float2 TexCoord0 = 0.0;
        PostProcessVS(ID, Position, TexCoord0);
        TentOffsets(TexCoord0, TexelSize, Offsets);
    }

    void TentFilter0VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_0, Position, TexCoord);
    }

    void TentFilter1VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_1, Position, TexCoord);
    }

    void TentFilter2VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_2, Position, TexCoord);
    }

    void TentFilter3VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_3, Position, TexCoord);
    }

    void TentFilter4VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_4, Position, TexCoord);
    }

    void TentFilter5VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_5, Position, TexCoord);
    }

    void TentFilter6VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_6, Position, TexCoord);
    }

    void TentFilter7VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_7, Position, TexCoord);
    }

    void TentFilter8VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_8, Position, TexCoord);
    }

    void DerivativesVS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[2] : TEXCOORD0)
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        const float2 PixelSize = 1.0 / BUFFER_SIZE_1;
        TexCoords[0] = VSTexCoord.xxyy + (float4(-1.5, 1.5, -0.5, 0.5) * PixelSize.xxyy);
        TexCoords[1] = VSTexCoord.xxyy + (float4(-0.5, 0.5, -1.5, 1.5) * PixelSize.xxyy);
    }

    // Pixel shaders

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

    float4 Chroma(in sampler2D Source, in float2 TexCoord)
    {
        float4 Color;
        Color = tex2D(Source, TexCoord);
        Color = max(Color, exp2(-10.0));
        return saturate(Color / dot(Color.rgb, 1.0));
    }

    float4 TentFilterPS(sampler2D Source, float4 Offsets[3])
    {
        // Sample locations:
        // A0 B0 C0
        // A1 B1 C1
        // A2 B2 C2
        float4 A0 = tex2D(Source, Offsets[0].xy);
        float4 A1 = tex2D(Source, Offsets[0].xz);
        float4 A2 = tex2D(Source, Offsets[0].xw);
        float4 B0 = tex2D(Source, Offsets[1].xy);
        float4 B1 = tex2D(Source, Offsets[1].xz);
        float4 B2 = tex2D(Source, Offsets[1].xw);
        float4 C0 = tex2D(Source, Offsets[2].xy);
        float4 C1 = tex2D(Source, Offsets[2].xz);
        float4 C2 = tex2D(Source, Offsets[2].xw);
        return (((A0 + C0 + A2 + C2) * 1.0) + ((B0 + A1 + C1 + B2) * 2.0) + (B1 * 4.0)) / 16.0;
    }

    /*
        Pyramidal Horn-Schunck Total-Variation optical flow
            + Horn-Schunck: https://dspace.mit.edu/handle/1721.1/6337 (Page 8)
            + Pyramid process: https://www.youtube.com/watch?v=4v_keMNROv4

        Modifications
            + Compute averages with a 7x7 low-pass tent filter
            + Estimate features in 2-dimensional chromaticity
            + Use pyramid process to get initial values from neighboring pixels
            + Use symmetric Gauss-Seidel to solve linear equation at Page 8

        We solve for X[N] (UV)
        Matrix => Horn–Schunck Matrix => Horn–Schunck Equation => Solving Equation

        Matrix
            [A11 A12] [X1] = [B1]
            [A21 A22] [X2] = [B2]

        Horn–Schunck Matrix
            [(Ix^2 + a) (IxIy)] [U] = [aU - IxIt]
            [(IxIy) (Iy^2 + a)] [V] = [aV - IyIt]

        Horn–Schunck Equation
            (Ix^2 + a)U + IxIyV = aU - IxIt
            IxIyU + (Iy^2 + a)V = aV - IyIt

        Solving Equation
            U = ((aU - IxIt) - IxIyV) / (Ix^2 + a)
            V = ((aV - IxIt) - IxIyu) / (Iy^2 + a)
    */

    /*
        https://github.com/Dtananaev/cv_opticalFlow

        Copyright (c) 2014-2015, Denis Tananaev All rights reserved.

        Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

        Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

        Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    */

    #define MaxLevel 7
    #define E _Smoothness * 2e-2

    void CoarseOpticalFlowTV(in float2 TexCoord, in float Level, in float2 UV, out float2 DUV)
    {
        DUV = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-4, Level - MaxLevel), 1e-7);

        float2 CurrentFrame = tex2D(SampleCommon_RG16F_1a, TexCoord).xy;
        float2 PreviousFrame = tex2D(SamplePreviousBuffer, TexCoord).xy;

        // <Rx, Gx, Ry, Gy>
        float4 SD = tex2D(SampleCommon_RGBA16F_1a, TexCoord);

        // <Rz, Gz>
        float2 TD = CurrentFrame - PreviousFrame;

        // Calculate constancy term
        float C = 0.0;
        C = dot(TD, 1.0);
        C = rsqrt(C * C + (E * E));

        float2 Aii = 0.0;
        Aii.x = 1.0 / (C * dot(SD.xy, SD.xy) + Alpha);
        Aii.y = 1.0 / (C * dot(SD.zw, SD.zw) + Alpha);
        float Aij = C * dot(SD.xy, SD.zw);

        float2 Bi = 0.0;
        Bi.x = C * dot(SD.xy, TD);
        Bi.y = C * dot(SD.zw, TD);

        // Gauss-Seidel (forward sweep, from 1...N)
        DUV.x = Aii.x * ((Alpha * UV.x) - (Aij * UV.y) - Bi.x);
        DUV.y = Aii.y * ((Alpha * UV.y) - (Aij * DUV.x) - Bi.y);
    }

    void ProcessGradAvg(in float2 SampleNW,
                        in float2 SampleNE,
                        in float2 SampleSW,
                        in float2 SampleSE,
                        out float Grad,
                        out float2 Avg)
    {
        // NW NE
        // SW SE
        float4 GradUV = 0.0;
        GradUV.xy = (SampleNW + SampleSW) - (SampleNE + SampleSE); // <IxU, IxV>
        GradUV.zw = (SampleNW + SampleNE) - (SampleSW + SampleSE); // <IyU, IyV>
        GradUV = GradUV * 0.5;
        Grad = rsqrt((dot(GradUV.xzyw, GradUV.xzyw) * 0.25) + (E * E));
        Avg = (SampleNW + SampleNE + SampleSW + SampleSE) * 0.25;
    }

    void ProcessArea(in float2 SampleUV[9],
                     inout float4 UVGrad,
                     inout float2 CenterAvg,
                     inout float2 UVAvg)
    {
        float CenterGrad = 0.0;
        float4 AreaGrad = 0.0;
        float2 AreaAvg[4];
        float4 GradUV = 0.0;
        float SqGradUV = 0.0;

        // Center smoothness gradient and average
        // 0 3 6
        // 1 4 7
        // 2 5 8
        GradUV.xy = (SampleUV[0] + (SampleUV[1] * 2.0) + SampleUV[2]) - (SampleUV[6] + (SampleUV[7] * 2.0) + SampleUV[8]); // <IxU, IxV>
        GradUV.zw = (SampleUV[0] + (SampleUV[3] * 2.0) + SampleUV[6]) - (SampleUV[2] + (SampleUV[5] * 2.0) + SampleUV[8]); // <IxU, IxV>
        SqGradUV = dot(GradUV.xzyw / 4.0, GradUV.xzyw / 4.0) * 0.25;
        CenterGrad = rsqrt(SqGradUV + (E * E));

        CenterAvg += ((SampleUV[0] + SampleUV[6] + SampleUV[2] + SampleUV[8]) * 1.0);
        CenterAvg += ((SampleUV[3] + SampleUV[1] + SampleUV[7] + SampleUV[5]) * 2.0);
        CenterAvg += (SampleUV[4] * 4.0);
        CenterAvg = CenterAvg / 16.0;

        // North-west gradient and average
        // 0 3 .
        // 1 4 .
        // . . .
        ProcessGradAvg(SampleUV[0], SampleUV[3], SampleUV[1], SampleUV[4], AreaGrad[0], AreaAvg[0]);

        // North-east gradient and average
        // . 3 6
        // . 4 7
        // . . .
        ProcessGradAvg(SampleUV[3], SampleUV[6], SampleUV[4], SampleUV[7], AreaGrad[1], AreaAvg[1]);

        // South-west gradient and average
        // . . .
        // 1 4 .
        // 2 5 .
        ProcessGradAvg(SampleUV[1], SampleUV[4], SampleUV[2], SampleUV[5], AreaGrad[2], AreaAvg[2]);

        // South-east and average
        // . . .
        // . 4 7
        // . 5 8
        ProcessGradAvg(SampleUV[4], SampleUV[7], SampleUV[5], SampleUV[8], AreaGrad[3], AreaAvg[3]);

        UVGrad = 0.5 * (CenterGrad + AreaGrad);
        UVAvg = (AreaGrad[0] * AreaAvg[0]) + (AreaGrad[1] * AreaAvg[1]) + (AreaGrad[2] * AreaAvg[2]) + (AreaGrad[3] * AreaAvg[3]);
    }

    void OpticalFlowTV(in sampler2D SourceUV, in float4 TexCoords[3], in float Level, out float2 DUV)
    {
        DUV = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-4, Level - MaxLevel), 1e-7);

        // Load textures

        float2 CurrentFrame = tex2D(SampleCommon_RG16F_1a, TexCoords[1].xz).xy;
        float2 PreviousFrame = tex2D(SamplePreviousBuffer, TexCoords[1].xz).xy;
        float4 SD = tex2D(SampleCommon_RGBA16F_1a, TexCoords[1].xz); // <Rx, Gx, Ry, Gy>
        float2 TD = CurrentFrame - PreviousFrame; // <Rz, Gz>

        // Optical flow calculation

        float2 SampleUV[9];
        float4 UVGrad = 0.0;
        float2 CenterAvg = 0.0;
        float2 UVAvg = 0.0;

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

        ProcessArea(SampleUV, UVGrad, CenterAvg, UVAvg);

        // Calculate constancy term
        float C = 0.0;
        C = dot(SD, CenterAvg.xyxy) + dot(TD, 1.0);
        C = rsqrt(C * C + (E * E));

        float2 Aii = 0.0;
        Aii.x = 1.0 / (dot(UVGrad, 1.0) * Alpha + (C * dot(SD.xy, SD.xy)));
        Aii.y = 1.0 / (dot(UVGrad, 1.0) * Alpha + (C * dot(SD.zw, SD.zw)));
        float Aij = dot(SD.xy, SD.zw);

        float2 Bi = 0.0;
        Bi.x = C * dot(SD.xy, TD);
        Bi.y = C * dot(SD.zw, TD);

        // Gauss-Seidel (forward sweep, from 1...N)
        DUV.x = Aii.x * ((Alpha * UVAvg.x) - (C * Aij * CenterAvg.y) - Bi.x);
        DUV.y = Aii.y * ((Alpha * UVAvg.y) - (C * Aij * DUV.x) - Bi.y);
    }

    void NormalizePS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        // Sample locations:
        // A0 B0 C0
        // A1 B1 C1
        // A2 B2 C2
        float4 A0 = Chroma(SampleColor, TexCoords[0].xy);
        float4 A1 = Chroma(SampleColor, TexCoords[0].xz);
        float4 A2 = Chroma(SampleColor, TexCoords[0].xw);
        float4 B0 = Chroma(SampleColor, TexCoords[1].xy);
        float4 B1 = Chroma(SampleColor, TexCoords[1].xz);
        float4 B2 = Chroma(SampleColor, TexCoords[1].xw);
        float4 C0 = Chroma(SampleColor, TexCoords[2].xy);
        float4 C1 = Chroma(SampleColor, TexCoords[2].xz);
        float4 C2 = Chroma(SampleColor, TexCoords[2].xw);
        OutputColor0 = Med9(A0, B0, C0,
                            A1, B1, C1,
                            A2, B2, C2);
    }

    void PreDownsample2PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilterPS(SampleCommon_RG16F_1a, TexCoord);
    }

    void PreDownsample3PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilterPS(SampleCommon_RG16F_2, TexCoord);
    }

    void PreDownsample4PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilterPS(SampleCommon_RG16F_3, TexCoord);
    }

    void PreUpsample3PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilterPS(SampleCommon_RG16F_4, TexCoord);
    }

    void PreUpsample2PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilterPS(SampleCommon_RG16F_3, TexCoord);
    }

    void PreUpsample1PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilterPS(SampleCommon_RG16F_2, TexCoord);
    }

    void DerivativesPS(in float4 Position : SV_Position, in float4 TexCoords[2] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        // Bilinear 5x5 Sobel by CeeJayDK
        //   B1 B2
        // A0     A1
        // A2     B0
        //   C0 C1
        float2 A0 = tex2D(SampleCommon_RG16F_1a, TexCoords[0].xw).xy * 4.0; // <-1.5, +0.5>
        float2 A1 = tex2D(SampleCommon_RG16F_1a, TexCoords[0].yw).xy * 4.0; // <+1.5, +0.5>
        float2 A2 = tex2D(SampleCommon_RG16F_1a, TexCoords[0].xz).xy * 4.0; // <-1.5, -0.5>
        float2 B0 = tex2D(SampleCommon_RG16F_1a, TexCoords[0].yz).xy * 4.0; // <+1.5, -0.5>
        float2 B1 = tex2D(SampleCommon_RG16F_1a, TexCoords[1].xw).xy * 4.0; // <-0.5, +1.5>
        float2 B2 = tex2D(SampleCommon_RG16F_1a, TexCoords[1].yw).xy * 4.0; // <+0.5, +1.5>
        float2 C0 = tex2D(SampleCommon_RG16F_1a, TexCoords[1].xz).xy * 4.0; // <-0.5, -1.5>
        float2 C1 = tex2D(SampleCommon_RG16F_1a, TexCoords[1].yz).xy * 4.0; // <+0.5, -1.5>

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

    void EstimateLevel8PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        CoarseOpticalFlowTV(TexCoord, 7.0, 0.0, OutputColor0);
    }

    void EstimateLevel7PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_8, TexCoords, 6.0, OutputColor0);
    }

    void EstimateLevel6PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_7, TexCoords, 5.0, OutputColor0);
    }

    void EstimateLevel5PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_6, TexCoords, 4.0, OutputColor0);
    }

    void EstimateLevel4PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_5, TexCoords, 3.0, OutputColor0);
    }

    void EstimateLevel3PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_4, TexCoords, 2.0, OutputColor0);
    }

    void EstimateLevel2PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_3, TexCoords, 1.0, OutputColor0);
    }

    void EstimateLevel1PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_2, TexCoords, 0.0, OutputColor0.xy);
        OutputColor0.xy *= float2(1.0, -1.0);
        OutputColor0.ba = (0.0, _BlendFactor);
    }

    void PostDownsample2PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilterPS(SampleVectors, TexCoords);
    }

    void PostDownsample3PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilterPS(SampleCommon_RG16F_2, TexCoords);
    }

    void PostDownsample4PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilterPS(SampleCommon_RG16F_3, TexCoords);
    }

    void PostUpsample3PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilterPS(SampleCommon_RG16F_4, TexCoords);
    }

    void PostUpsample2PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilterPS(SampleCommon_RG16F_3, TexCoords);
    }

    void PostUpsample1PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0, out float4 OutputColor1 : SV_Target1)
    {
        OutputColor0 = TentFilterPS(SampleCommon_RG16F_2, TexCoords);

        // Copy current convolved result to use at next frame
        OutputColor1 = tex2D(SampleCommon_RG16F_1a, TexCoords[1].xz).rg;
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

    void AccumulatePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        float Quality = 1.0 - _Entropy;
        float2 Time = float2(_Time, 0.0);

        // Random numbers
        float3 Random;
        Random.x = RandomNoise(TexCoord.xy + Time.xy);
        Random.y = RandomNoise(TexCoord.xy + Time.yx);
        Random.z = RandomNoise(TexCoord.yx - Time.xx);

        // Motion vector
        float2 MotionVectors = tex2Dlod(SampleVectorsPost, float4(TexCoord, 0.0, _MipBias)).xy;
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

    void DatamoshPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        const float2 DisplacementTexel = 1.0 / BUFFER_SIZE_1;
        const float Quality = 1.0 - _Entropy;

        // Random numbers
        float2 Time = float2(_Time, 0.0);
        float3 Random;
        Random.x = RandomNoise(TexCoord.xy + Time.xy);
        Random.y = RandomNoise(TexCoord.xy + Time.yx);
        Random.z = RandomNoise(TexCoord.yx - Time.xx);

        float2 MotionVectors = tex2Dlod(SampleVectorsPost, float4(TexCoord, 0.0, _MipBias)).xy;
        MotionVectors *= _Scale;

        float4 Source = tex2D(SampleColor, TexCoord); // Color from the original image
        float Displacement = tex2D(SampleAccumulation, TexCoord).r; // Displacement vector
        float4 Working = tex2D(SampleFeedback, TexCoord - MotionVectors * DisplacementTexel);

        MotionVectors *= uint2(BUFFER_WIDTH, BUFFER_HEIGHT); // Normalized screen space -> Pixel coordinates
        MotionVectors += (Random.xy - 0.5) * _Diffusion; // Small random displacement (diffusion)
        MotionVectors = round(MotionVectors); // Pixel perfect snapping
        MotionVectors *= (1.0 / uint2(BUFFER_WIDTH, BUFFER_HEIGHT)); // Pixel coordinates -> Normalized screen space

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

    void Copy0PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = tex2D(SampleColor, TexCoord);
    }

    technique KinoDatamosh
    {
        // Normalize current frame

        pass
        {
            VertexShader = MedianVS;
            PixelShader = NormalizePS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon1;
        }

        // Pre-process dual-filter blur

        pass
        {
            VertexShader = TentFilter1VS;
            PixelShader = PreDownsample2PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = PreDownsample3PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon3;
        }

        pass
        {
            VertexShader = TentFilter3VS;
            PixelShader = PreDownsample4PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon4;
        }

        pass
        {
            VertexShader = TentFilter4VS;
            PixelShader = PreUpsample3PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon3;
        }

        pass
        {
            VertexShader = TentFilter3VS;
            PixelShader = PreUpsample2PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = PreUpsample1PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon1;
        }

        // Construct pyramids

        pass
        {
            VertexShader = DerivativesVS;
            PixelShader = DerivativesPS;
            RenderTarget0 = SharedResources::RGBA16F::RenderCommon1;
        }

        // Pyramidal estimation

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel8PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon8;
        }

        pass
        {
            VertexShader = TentFilter8VS;
            PixelShader = EstimateLevel7PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon7;
        }

        pass
        {
            VertexShader = TentFilter7VS;
            PixelShader = EstimateLevel6PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon6;
        }

        pass
        {
            VertexShader = TentFilter6VS;
            PixelShader = EstimateLevel5PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon5;
        }

        pass
        {
            VertexShader = TentFilter5VS;
            PixelShader = EstimateLevel4PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon4;
        }

        pass
        {
            VertexShader = TentFilter4VS;
            PixelShader = EstimateLevel3PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon3;
        }

        pass
        {
            VertexShader = TentFilter3VS;
            PixelShader = EstimateLevel2PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = EstimateLevel1PS;
            RenderTarget0 = RenderVectors;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        // Post-process dual-filter blur

        pass
        {
            VertexShader = TentFilter1VS;
            PixelShader = PostDownsample2PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = PostDownsample3PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon3;
        }

        pass
        {
            VertexShader = TentFilter3VS;
            PixelShader = PostDownsample4PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon4;
        }

        pass
        {
            VertexShader = TentFilter4VS;
            PixelShader = PostUpsample3PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon3;
        }

        pass
        {
            VertexShader = TentFilter3VS;
            PixelShader = PostUpsample2PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = PostUpsample1PS;
            RenderTarget0 = SharedResources::RGBA16F::RenderCommon1;

            // Copy previous frame
            RenderTarget1 = RenderPreviousBuffer;
        }

        // Datamoshing

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = AccumulatePS;
            RenderTarget0 = RenderAccumulation;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = ONE;
            DestBlend = SRCALPHA; // The result about to accumulate
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = DatamoshPS;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }

        // Copy frame for feedback

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = Copy0PS;
            RenderTarget = RenderFeedback;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }
    }
}
