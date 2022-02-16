
/*
    Optical flow motion blur

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

#define POW2SIZE_0 uint(256)
#define POW2SIZE_1 uint(POW2SIZE_0 >> 1)
#define POW2SIZE_2 uint(POW2SIZE_0 >> 2)
#define POW2SIZE_3 uint(POW2SIZE_0 >> 3)
#define POW2SIZE_4 uint(POW2SIZE_0 >> 4)
#define POW2SIZE_5 uint(POW2SIZE_0 >> 5)
#define POW2SIZE_6 uint(POW2SIZE_0 >> 6)
#define POW2SIZE_7 uint(POW2SIZE_0 >> 7)

namespace SharedResources
{
    namespace RG16F
    {
        texture2D _RenderTemporary1a
        {
            Width = BUFFER_WIDTH >> 1;
            Height = BUFFER_HEIGHT >> 1;
            Format = RG16F;
            MipLevels = 8;
        };

        namespace POW2
        {
            texture2D _RenderTemporary0a
            {
                Width = POW2SIZE_0;
                Height = POW2SIZE_0;
                Format = RG16F;
                MipLevels = 8;
            };

            texture2D _RenderTemporary0b
            {
                Width = POW2SIZE_0;
                Height = POW2SIZE_0;
                Format = RG16F;
                MipLevels = 8;
            };

            texture2D _RenderTemporary0c
            {
                Width = POW2SIZE_0;
                Height = POW2SIZE_0;
                Format = RG16F;
                MipLevels = 8;
            };

            texture2D _RenderTemporary1
            {
                Width = POW2SIZE_1;
                Height = POW2SIZE_1;
                Format = RG16F;
            };

            texture2D _RenderTemporary2
            {
                Width = POW2SIZE_2;
                Height = POW2SIZE_2;
                Format = RG16F;
            };

            texture2D _RenderTemporary3
            {
                Width = POW2SIZE_3;
                Height = POW2SIZE_3;
                Format = RG16F;
            };

            texture2D _RenderTemporary4
            {
                Width = POW2SIZE_4;
                Height = POW2SIZE_4;
                Format = RG16F;
            };

            texture2D _RenderTemporary5
            {
                Width = POW2SIZE_5;
                Height = POW2SIZE_5;
                Format = RG16F;
            };

            texture2D _RenderTemporary6
            {
                Width = POW2SIZE_6;
                Height = POW2SIZE_6;
                Format = RG16F;
            };

            texture2D _RenderTemporary7
            {
                Width = POW2SIZE_7;
                Height = POW2SIZE_7;
                Format = RG16F;
            };
        }
    }
}

namespace MotionBlur
{
    uniform float _Constraint <
        ui_type = "slider";
        ui_label = "Flow Smooth";
        ui_tooltip = "Higher = Smoother flow";
        ui_min = 0.0;
        ui_max = 2.0;
    > = 1.0;

    uniform float _Scale <
        ui_type = "slider";
        ui_label = "Flow Scale";
        ui_tooltip = "Higher = More motion blur";
        ui_min = 0.0;
        ui_max = 2.0;
    > = 1.0;

    uniform float _MipBias <
        ui_type = "slider";
        ui_label = "Mipmap Bias";
        ui_tooltip = "Higher = Less spatial noise";
        ui_min = 0.0;
        ui_max = 7.0;
    > = 3.5;

    uniform float _Blend <
        ui_type = "slider";
        ui_label = "Temporal Blending";
        ui_tooltip = "Higher = Less temporal noise";
        ui_min = 0.0;
        ui_max = 0.5;
    > = 0.25;

    uniform bool _FrameRateScaling <
        ui_type = "radio";
        ui_label = "Frame-Rate Scaling";
        ui_tooltip = "Enables frame-rate scaling";
    > = false;

    uniform float _TargetFrameRate <
        ui_type = "drag";
        ui_label = "Target Frame-Rate";
        ui_tooltip = "Targeted frame-rate";
    > = 60.00;

    uniform float _FrameTime < source = "frametime"; >;

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

    sampler2D _SampleTemporary1a
    {
        Texture = SharedResources::RG16F::_RenderTemporary1a;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SamplePOW2Temporary0a
    {
        Texture = SharedResources::RG16F::POW2::_RenderTemporary0a;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SamplePOW2Temporary0b
    {
        Texture = SharedResources::RG16F::POW2::_RenderTemporary0b;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SamplePOW2Temporary0c
    {
        Texture = SharedResources::RG16F::POW2::_RenderTemporary0c;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderData3
    {
        Width = POW2SIZE_0;
        Height = POW2SIZE_0;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D _SampleData3
    {
        Texture = _RenderData3;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SamplePOW2Temporary7
    {
        Texture = SharedResources::RG16F::POW2::_RenderTemporary7;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SamplePOW2Temporary6
    {
        Texture = SharedResources::RG16F::POW2::_RenderTemporary6;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SamplePOW2Temporary5
    {
        Texture = SharedResources::RG16F::POW2::_RenderTemporary5;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SamplePOW2Temporary4
    {
        Texture = SharedResources::RG16F::POW2::_RenderTemporary4;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SamplePOW2Temporary3
    {
        Texture = SharedResources::RG16F::POW2::_RenderTemporary3;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SamplePOW2Temporary2
    {
        Texture = SharedResources::RG16F::POW2::_RenderTemporary2;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SamplePOW2Temporary1
    {
        Texture = SharedResources::RG16F::POW2::_RenderTemporary1;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderTemporary0
    {
        Width = POW2SIZE_0;
        Height = POW2SIZE_0;
        Format = RG16F;
    };

    sampler2D _SamplePOW2Temporary0
    {
        Texture = _RenderTemporary0;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    // Vertex shaders

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

    void DownsampleOffsets(in float2 TexCoord, in float2 PixelSize, out float4 SampleOffsets[4])
    {
        // Sample locations:
        // [1].xy        [2].xy        [3].xy
        //        [0].xw        [0].zw
        // [1].xz        [2].xz        [3].xz
        //        [0].xy        [0].zy
        // [1].xw        [2].xw        [3].xw
        SampleOffsets[0] = TexCoord.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * PixelSize.xyxy;
        SampleOffsets[1] = TexCoord.xyyy + float4(-2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
        SampleOffsets[2] = TexCoord.xyyy + float4(0.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
        SampleOffsets[3] = TexCoord.xyyy + float4(2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
    }

    void UpsampleOffsets(in float2 TexCoord, in float2 PixelSize, out float4 SampleOffsets[3])
    {
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        SampleOffsets[0] = TexCoord.xyyy + (float4(-2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);
        SampleOffsets[1] = TexCoord.xyyy + (float4(0.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);
        SampleOffsets[2] = TexCoord.xyyy + (float4(2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);
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
        MedianOffsets(TexCoord0, 1.0 / uint2(BUFFER_WIDTH >> 1, BUFFER_HEIGHT >> 1), Offsets);
    }

    void DownsampleVS(in uint ID, in float2 PixelSize, out float4 Position, out float4 Offsets[4])
    {
        float2 TexCoord0 = 0.0;
        PostProcessVS(ID, Position, TexCoord0);
        DownsampleOffsets(TexCoord0, PixelSize, Offsets);
    }

    void UpsampleVS(in uint ID, in float2 PixelSize, out float4 Position, out float4 Offsets[3])
    {
        float2 TexCoord0 = 0.0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, PixelSize, Offsets);
    }

    void Downsample1VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 DownsampleCoords[4] : TEXCOORD0)
    {
        DownsampleVS(ID, 1.0 / POW2SIZE_0, Position, DownsampleCoords);
    }

    void Downsample2VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 DownsampleCoords[4] : TEXCOORD0)
    {
        DownsampleVS(ID, 1.0 / POW2SIZE_1, Position, DownsampleCoords);
    }

    void Downsample3VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 DownsampleCoords[4] : TEXCOORD0)
    {
        DownsampleVS(ID, 1.0 / POW2SIZE_2, Position, DownsampleCoords);
    }

    void Upsample2VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        UpsampleVS(ID, 1.0 / POW2SIZE_2, Position, UpsampleCoords);
    }

    void Upsample1VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        UpsampleVS(ID, 1.0 / POW2SIZE_1, Position, UpsampleCoords);
    }

    void Upsample0VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        UpsampleVS(ID, 1.0 / POW2SIZE_0, Position, UpsampleCoords);
    }

    void DerivativesVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        const float2 PixelSize = 1.0 / POW2SIZE_0;
        TexCoords[0] = TexCoord0.xyyy + float4(-1.5, 1.5, 0.0, -1.5) * PixelSize.xyyy;
        TexCoords[1] = TexCoord0.xyyy + float4( 0.0, 1.5, 0.0, -1.5) * PixelSize.xyyy;
        TexCoords[2] = TexCoord0.xyyy + float4( 1.5, 1.5, 0.0, -1.5) * PixelSize.xyyy;
    }

    void EstimateLevel6VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / POW2SIZE_6, UpsampleCoords);
    }

    void EstimateLevel5VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / POW2SIZE_5, UpsampleCoords);
    }

    void EstimateLevel4VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / POW2SIZE_4, UpsampleCoords);
    }

    void EstimateLevel3VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / POW2SIZE_3, UpsampleCoords);
    }

    void EstimateLevel2VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / POW2SIZE_2, UpsampleCoords);
    }

    void EstimateLevel1VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / POW2SIZE_1, UpsampleCoords);
    }

    void EstimateLevel0VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / POW2SIZE_0, UpsampleCoords);
    }

    // Pixel shaders

    float4 Downsample(sampler2D Source, float4 TexCoord[4])
    {
        // A0    B0    C0
        //    D0    D1
        // A1    B1    C1
        //    D2    D3
        // A2    B2    C2

        float4 D0 = tex2D(Source, TexCoord[0].xw);
        float4 D1 = tex2D(Source, TexCoord[0].zw);
        float4 D2 = tex2D(Source, TexCoord[0].xy);
        float4 D3 = tex2D(Source, TexCoord[0].zy);

        float4 A0 = tex2D(Source, TexCoord[1].xy);
        float4 A1 = tex2D(Source, TexCoord[1].xz);
        float4 A2 = tex2D(Source, TexCoord[1].xw);

        float4 B0 = tex2D(Source, TexCoord[2].xy);
        float4 B1 = tex2D(Source, TexCoord[2].xz);
        float4 B2 = tex2D(Source, TexCoord[2].xw);

        float4 C0 = tex2D(Source, TexCoord[3].xy);
        float4 C1 = tex2D(Source, TexCoord[3].xz);
        float4 C2 = tex2D(Source, TexCoord[3].xw);

        float4 Output;
        const float2 Weights = float2(0.5, 0.125) / 4.0;
        Output += (D0 + D1 + D2 + D3) * Weights.x;
        Output += (A0 + B0 + A1 + B1) * Weights.y;
        Output += (B0 + C0 + B1 + C1) * Weights.y;
        Output += (A1 + B1 + A2 + B2) * Weights.y;
        Output += (B1 + C1 + B2 + C2) * Weights.y;
        return Output;
    }

    float4 Upsample(sampler2D Source, float4 Offsets[3])
    {
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        float4 OutputColor = 0.0;
        float4 Sample[9];
        Sample[0] = tex2D(Source, Offsets[0].xy);
        Sample[1] = tex2D(Source, Offsets[1].xy);
        Sample[2] = tex2D(Source, Offsets[2].xy);
        Sample[3] = tex2D(Source, Offsets[0].xz);
        Sample[4] = tex2D(Source, Offsets[1].xz);
        Sample[5] = tex2D(Source, Offsets[2].xz);
        Sample[6] = tex2D(Source, Offsets[0].xw);
        Sample[7] = tex2D(Source, Offsets[1].xw);
        Sample[8] = tex2D(Source, Offsets[2].xw);

        return ((Sample[0] + Sample[2] + Sample[6] + Sample[8]) * 1.0
              + (Sample[1] + Sample[3] + Sample[5] + Sample[7]) * 2.0
              + (Sample[4]) * 4.0) / 16.0;
    }

    /*
        Pyramidal Horn-Schunck optical flow
            + Horn-Schunck: https://dspace.mit.edu/handle/1721.1/6337 (Page 8)
            + Pyramid process: https://www.youtube.com/watch?v=4v_keMNROv4

        Modifications
            + Compute averages with a 7x7 low-pass tent filter
            + Estimate features in 2-dimensional chromaticity
            + Use pyramid process to get initial values from neighboring pixels
            + Use symmetric Gauss-Seidel to solve linear equation at Page 8
    */

    static const int MaxLevel = 7;

    void OpticalFlow(in float2 TexCoord, in float2 UV, in float Level, out float2 DUV)
    {
        const float Alpha = max(ldexp(_Constraint * 1e-3, Level - MaxLevel), 1e-7);
        float2 SampleC = tex2D(_SamplePOW2Temporary0a, TexCoord).rg;
        float2 SampleP = tex2D(_SampleData3, TexCoord).rg;
        float2 It = SampleC - SampleP;
        float2 Ix = tex2D(_SamplePOW2Temporary0b, TexCoord).rg;
        float2 Iy = tex2D(_SamplePOW2Temporary0c, TexCoord).rg;

        /*
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

        // A11 = 1.0 / (Rx^2 + Gx^2 + a)
        // A22 = 1.0 / (Ry^2 + Gy^2 + a)
        // Aij = Rxy + Gxy
        float A11 = 1.0 / (dot(Ix, Ix) + Alpha);
        float A22 = 1.0 / (dot(Iy, Iy) + Alpha);
        float Aij = dot(Ix, Iy);

        // B1 = Rxt + Gxt
        // B2 = Ryt + Gyt
        float B1 = dot(Ix, It);
        float B2 = dot(Iy, It);

        // Symmetric Gauss-Seidel (forward sweep, from 1...N)
        DUV.x = A11 * ((Alpha * UV.x - B1) - (UV.y * Aij));
        DUV.y = A22 * ((Alpha * UV.y - B2) - (DUV.x * Aij));

        // Symmetric Gauss-Seidel (backward sweep, from N...1)
        DUV.y = A22 * ((Alpha * DUV.y - B2) - (DUV.x * Aij));
        DUV.x = A11 * ((Alpha * DUV.x - B1) - (DUV.y * Aij));
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

    float4 Chroma(in sampler2D Source, in float2 TexCoord)
    {
        float4 Color;
        Color = tex2D(Source, TexCoord);
        Color = max(Color, exp2(-10.0));
        return saturate(Color / dot(Color.rgb, 1.0));
    }

    void NormalizePS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        float4 OutputColor = 0.0;
        float4 Sample[9];
        Sample[0] = Chroma(_SampleColor, TexCoords[0].xy);
        Sample[1] = Chroma(_SampleColor, TexCoords[1].xy);
        Sample[2] = Chroma(_SampleColor, TexCoords[2].xy);
        Sample[3] = Chroma(_SampleColor, TexCoords[0].xz);
        Sample[4] = Chroma(_SampleColor, TexCoords[1].xz);
        Sample[5] = Chroma(_SampleColor, TexCoords[2].xz);
        Sample[6] = Chroma(_SampleColor, TexCoords[0].xw);
        Sample[7] = Chroma(_SampleColor, TexCoords[1].xw);
        Sample[8] = Chroma(_SampleColor, TexCoords[2].xw);
        OutputColor0 = Med9(Sample[0], Sample[1], Sample[2],
                            Sample[3], Sample[4], Sample[5],
                            Sample[6], Sample[7], Sample[8]);
    }

    void Copy0PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OutputColor0 = tex2D(_SampleTemporary1a, TexCoord).rg;
    }

    void PreDownsample1PS(in float4 Position : SV_Position, in float4 DownsampleCoords[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Downsample(_SamplePOW2Temporary0a, DownsampleCoords);
    }

    void PreDownsample2PS(in float4 Position : SV_Position, in float4 DownsampleCoords[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Downsample(_SamplePOW2Temporary1, DownsampleCoords);
    }

    void PreDownsample3PS(in float4 Position : SV_Position, in float4 DownsampleCoords[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Downsample(_SamplePOW2Temporary2, DownsampleCoords);
    }

    void PreUpsample2PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Upsample(_SamplePOW2Temporary3, UpsampleCoords);
    }

    void PreUpsample1PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Upsample(_SamplePOW2Temporary2, UpsampleCoords);
    }

    void PreUpsample0PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Upsample(_SamplePOW2Temporary1, UpsampleCoords);
    }

    void DerivativesPS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0, out float2 OutputColor1 : SV_Target1)
    {
        // Custom 5x5 bilinear derivatives, normalized to [-1, 1]
        // A0 B0 C0
        // A1    C1
        // A2 B2 C2
        float2 A0 = tex2D(_SamplePOW2Temporary0a, TexCoords[0].xy).xy;
        float2 A1 = tex2D(_SamplePOW2Temporary0a, TexCoords[0].xz).xy;
        float2 A2 = tex2D(_SamplePOW2Temporary0a, TexCoords[0].xw).xy;
        float2 B0 = tex2D(_SamplePOW2Temporary0a, TexCoords[1].xy).xy;
        float2 B2 = tex2D(_SamplePOW2Temporary0a, TexCoords[1].xw).xy;
        float2 C0 = tex2D(_SamplePOW2Temporary0a, TexCoords[2].xy).xy;
        float2 C1 = tex2D(_SamplePOW2Temporary0a, TexCoords[2].xz).xy;
        float2 C2 = tex2D(_SamplePOW2Temporary0a, TexCoords[2].xw).xy;

        // -1 -1  0  +1 +1
        // -1 -1  0  +1 +1
        // -1 -1  0  +1 +1
        // -1 -1  0  +1 +1
        // -1 -1  0  +1 +1
        OutputColor0 = (((C0 * 4.0) + (C1 * 2.0) + (C2 * 4.0)) - ((A0 * 4.0) + (A1 * 2.0) + (A2 * 4.0))) / 10.0;

        // +1 +1 +1 +1 +1
        // +1 +1 +1 +1 +1
        //  0  0  0  0  0
        // -1 -1 -1 -1 -1
        // -1 -1 -1 -1 -1
        OutputColor1 = (((A0 * 4.0) + (B0 * 2.0) + (C0 * 4.0)) - ((A2 * 4.0) + (B2 * 2.0) + (C2 * 4.0))) / 10.0;
    }

    void EstimateLevel7PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlow(TexCoord, 0.0, 7.0, OutputColor0);
    }

    void EstimateLevel6PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlow(UpsampleCoords[1].xz, Upsample(_SamplePOW2Temporary7, UpsampleCoords).xy, 6.0, OutputColor0);
    }

    void EstimateLevel5PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlow(UpsampleCoords[1].xz, Upsample(_SamplePOW2Temporary6, UpsampleCoords).xy, 5.0, OutputColor0);
    }

    void EstimateLevel4PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlow(UpsampleCoords[1].xz, Upsample(_SamplePOW2Temporary5, UpsampleCoords).xy, 4.0, OutputColor0);
    }

    void EstimateLevel3PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlow(UpsampleCoords[1].xz, Upsample(_SamplePOW2Temporary4, UpsampleCoords).xy, 3.0, OutputColor0);
    }

    void EstimateLevel2PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlow(UpsampleCoords[1].xz, Upsample(_SamplePOW2Temporary3, UpsampleCoords).xy, 2.0, OutputColor0);
    }

    void EstimateLevel1PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlow(UpsampleCoords[1].xz, Upsample(_SamplePOW2Temporary2, UpsampleCoords).xy, 1.0, OutputColor0);
    }

    void EstimateLevel0PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OpticalFlow(UpsampleCoords[1].xz, Upsample(_SamplePOW2Temporary1, UpsampleCoords).xy, 0.0, OutputColor0.xy);
        OutputColor0.ba = (0.0, _Blend);
    }

    void PostDownsample1PS(in float4 Position : SV_Position, in float4 DownsampleCoords[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Downsample(_SamplePOW2Temporary0, DownsampleCoords);
    }

    void PostDownsample2PS(in float4 Position : SV_Position, in float4 DownsampleCoords[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Downsample(_SamplePOW2Temporary1, DownsampleCoords);
    }

    void PostDownsample3PS(in float4 Position : SV_Position, in float4 DownsampleCoords[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Downsample(_SamplePOW2Temporary2, DownsampleCoords);
    }

    void PostUpsample2PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Upsample(_SamplePOW2Temporary3, UpsampleCoords);
    }

    void PostUpsample1PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Upsample(_SamplePOW2Temporary2, UpsampleCoords);
    }

    void PostUpsample0PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0, out float2 OutputColor1 : SV_Target1)
    {
        OutputColor0 = Upsample(_SamplePOW2Temporary1, UpsampleCoords);
        OutputColor1 = tex2D(_SamplePOW2Temporary0a, UpsampleCoords[1].xz).rg;
    }

    void MotionBlurPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
    {
        const int Samples = 4;
        float Noise = frac(52.9829189 * frac(dot(Position.xy, float2(0.06711056, 0.00583715))));
        float FrameTimeRatio = _TargetFrameRate / (1e+3 / _FrameTime);
        float2 Velocity = (tex2Dlod(_SamplePOW2Temporary0c, float4(TexCoord, 0.0, _MipBias)).xy / POW2SIZE_0) * _Scale;
        Velocity /= (_FrameRateScaling) ? FrameTimeRatio : 1.0;

        for(int k = 0; k < Samples; ++k)
        {
            float2 Offset = Velocity * (Noise + k);
            OutputColor0 += tex2D(_SampleColor, (TexCoord + Offset));
            OutputColor0 += tex2D(_SampleColor, (TexCoord - Offset));
        }

        OutputColor0 /= (Samples * 2.0);
    }

    technique cMotionBlur
    {
        // Normalize current frame

        pass
        {
            VertexShader = MedianVS;
            PixelShader = NormalizePS;
            RenderTarget0 = SharedResources::RG16F::_RenderTemporary1a;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = Copy0PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary0a;
        }

        // Pre-process dual-filter blur

        pass
        {
            VertexShader = Downsample1VS;
            PixelShader = PreDownsample1PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary1;
        }

        pass
        {
            VertexShader = Downsample2VS;
            PixelShader = PreDownsample2PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary2;
        }

        pass
        {
            VertexShader = Downsample3VS;
            PixelShader = PreDownsample3PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary3;
        }

        pass
        {
            VertexShader = Upsample2VS;
            PixelShader = PreUpsample2PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary2;
        }

        pass
        {
            VertexShader = Upsample1VS;
            PixelShader = PreUpsample1PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary1;
        }

        pass
        {
            VertexShader = Upsample0VS;
            PixelShader = PreUpsample0PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary0a;
        }

        // Calculate discrete derivative pyramid

        pass
        {
            VertexShader = DerivativesVS;
            PixelShader = DerivativesPS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary0b;
            RenderTarget1 = SharedResources::RG16F::POW2::_RenderTemporary0c;
        }

        // Calculate pyramidal estimation

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel7PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary7;
        }

        pass
        {
            VertexShader = EstimateLevel6VS;
            PixelShader = EstimateLevel6PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary6;
        }

        pass
        {
            VertexShader = EstimateLevel5VS;
            PixelShader = EstimateLevel5PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary5;
        }

        pass
        {
            VertexShader = EstimateLevel4VS;
            PixelShader = EstimateLevel4PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary4;
        }

        pass
        {
            VertexShader = EstimateLevel3VS;
            PixelShader = EstimateLevel3PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary3;
        }

        pass
        {
            VertexShader = EstimateLevel2VS;
            PixelShader = EstimateLevel2PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary2;
        }

        pass
        {
            VertexShader = EstimateLevel1VS;
            PixelShader = EstimateLevel1PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary1;
        }

        pass
        {
            VertexShader = EstimateLevel0VS;
            PixelShader = EstimateLevel0PS;
            RenderTarget0 = _RenderTemporary0;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        // Post-process dual-filter blur

        pass
        {
            VertexShader = Downsample1VS;
            PixelShader = PostDownsample1PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary1;
        }

        pass
        {
            VertexShader = Downsample2VS;
            PixelShader = PostDownsample2PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary2;
        }

        pass
        {
            VertexShader = Downsample3VS;
            PixelShader = PostDownsample3PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary3;
        }

        pass
        {
            VertexShader = Upsample2VS;
            PixelShader = PostUpsample2PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary2;
        }

        pass
        {
            VertexShader = Upsample1VS;
            PixelShader = PostUpsample1PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary1;
        }

        pass
        {
            VertexShader = Upsample0VS;
            PixelShader = PostUpsample0PS;
            RenderTarget0 = SharedResources::RG16F::POW2::_RenderTemporary0c;

            // Store previous frame
            RenderTarget1 = _RenderData3;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = MotionBlurPS;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }
    }
}
