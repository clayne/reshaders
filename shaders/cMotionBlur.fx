
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

#define POW2SIZE uint(256)

namespace SharedResources
{
    namespace RG16F
    {
        texture2D _RenderTemporary1a
        {
            Width = BUFFER_WIDTH / 2;
            Height = BUFFER_HEIGHT / 2;
            Format = RG16F;
            MipLevels = 8;
        };

        namespace POW2
        {
            texture2D _RenderTemporary0a
            {
                Width = POW2SIZE;
                Height = POW2SIZE;
                Format = RG16F;
                MipLevels = 8;
            };

            texture2D _RenderTemporary0b
            {
                Width = POW2SIZE;
                Height = POW2SIZE;
                Format = RG16F;
                MipLevels = 8;
            };

            texture2D _RenderTemporary0c
            {
                Width = POW2SIZE;
                Height = POW2SIZE;
                Format = RG16F;
                MipLevels = 8;
            };

            texture2D _RenderTemporary1
            {
                Width = POW2SIZE / 2;
                Height = POW2SIZE / 2;
                Format = RG16F;
            };

            texture2D _RenderTemporary2
            {
                Width = POW2SIZE / 4;
                Height = POW2SIZE / 4;
                Format = RG16F;
            };

            texture2D _RenderTemporary3
            {
                Width = POW2SIZE / 8;
                Height = POW2SIZE / 8;
                Format = RG16F;
            };

            texture2D _RenderTemporary4
            {
                Width = POW2SIZE / 16;
                Height = POW2SIZE / 16;
                Format = RG16F;
            };

            texture2D _RenderTemporary5
            {
                Width = POW2SIZE / 32;
                Height = POW2SIZE / 32;
                Format = RG16F;
            };

            texture2D _RenderTemporary6
            {
                Width = POW2SIZE / 64;
                Height = POW2SIZE / 64;
                Format = RG16F;
            };

            texture2D _RenderTemporary7
            {
                Width = POW2SIZE / 128;
                Height = POW2SIZE / 128;
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
        Width = POW2SIZE;
        Height = POW2SIZE;
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
        Width = POW2SIZE / 1;
        Height = POW2SIZE / 1;
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
        DownsampleVS(ID, 1.0 / ldexp(POW2SIZE, -1.0), Position, DownsampleCoords);
    }

    void Downsample2VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 DownsampleCoords[4] : TEXCOORD0)
    {
        DownsampleVS(ID, 1.0 / ldexp(POW2SIZE, -2.0), Position, DownsampleCoords);
    }

    void Upsample1VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        UpsampleVS(ID, 1.0 / ldexp(POW2SIZE, -1.0), Position, UpsampleCoords);
    }

    void Upsample0VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        UpsampleVS(ID, 1.0 / ldexp(POW2SIZE, 0.0), Position, UpsampleCoords);
    }

    void DerivativesVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord : TEXCOORD0)
    {
        const float2 PixelSize = 0.5 / POW2SIZE;
        const float4 PixelOffset = float4(PixelSize, -PixelSize);
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        TexCoord = TexCoord0.xyxy + PixelOffset;
    }

    void EstimateLevel6VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(POW2SIZE, -6.0), UpsampleCoords);
    }

    void EstimateLevel5VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(POW2SIZE, -5.0), UpsampleCoords);
    }

    void EstimateLevel4VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(POW2SIZE, -4.0), UpsampleCoords);
    }

    void EstimateLevel3VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(POW2SIZE, -3.0), UpsampleCoords);
    }

    void EstimateLevel2VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(POW2SIZE, -2.0), UpsampleCoords);
    }

    void EstimateLevel1VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(POW2SIZE, -1.0), UpsampleCoords);
    }

    void EstimateLevel0VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(POW2SIZE, 0.0), UpsampleCoords);
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
        float2 Iz = SampleC - SampleP;
        float2 Ix = tex2D(_SamplePOW2Temporary0b, TexCoord).rg;
        float2 Iy = tex2D(_SamplePOW2Temporary0c, TexCoord).rg;

        // Compute diagonal
        float2 Aii;
        Aii.x = dot(Ix, Ix) + Alpha;
        Aii.y = dot(Iy, Iy) + Alpha;
        Aii.xy = 1.0 / Aii.xy;

        // Compute right-hand side
        float2 RHS;
        RHS.x = dot(Ix, Iz);
        RHS.y = dot(Iy, Iz);

        // Compute triangle
        float Aij = dot(Ix, Iy);

        // Symmetric Gauss-Seidel (forward sweep, from 1...N)
        DUV.x = Aii.x * ((Alpha * UV.x) - RHS.x - (UV.y * Aij));
        DUV.y = Aii.y * ((Alpha * UV.y) - RHS.y - (DUV.x * Aij));

        // Symmetric Gauss-Seidel (backward sweep, from N...1)
        DUV.y = Aii.y * ((Alpha * DUV.y) - RHS.y - (DUV.x * Aij));
        DUV.x = Aii.x * ((Alpha * DUV.x) - RHS.x - (DUV.y * Aij));
    }

    void NormalizePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        float3 Color = tex2D(_SampleColor, TexCoord).rgb;
        OutputColor0 = saturate(Color.xy / dot(Color, 1.0));
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

    void PreUpsample1PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Upsample(_SamplePOW2Temporary2, UpsampleCoords);
    }

    void PreUpsample0PS(in float4 Position : SV_Position, in float4 UpsampleCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Upsample(_SamplePOW2Temporary1, UpsampleCoords);
    }

    void DerivativesPS(in float4 Position : SV_Position, in float4 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0, out float2 OutputColor1 : SV_Target1)
    {
        float2 Sample0 = tex2D(_SamplePOW2Temporary0a, TexCoord.zy).xy; // (-x, +y)
        float2 Sample1 = tex2D(_SamplePOW2Temporary0a, TexCoord.xy).xy; // (+x, +y)
        float2 Sample2 = tex2D(_SamplePOW2Temporary0a, TexCoord.zw).xy; // (-x, -y)
        float2 Sample3 = tex2D(_SamplePOW2Temporary0a, TexCoord.xw).xy; // (+x, -y)
        OutputColor0 = ((Sample3 + Sample1) - (Sample2 + Sample0)) * 4.0;
        OutputColor1 = ((Sample2 + Sample3) - (Sample0 + Sample1)) * 4.0;
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
        float2 Velocity = (tex2Dlod(_SamplePOW2Temporary0c, float4(TexCoord, 0.0, _MipBias)).xy / POW2SIZE) * _Scale;
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
            VertexShader = PostProcessVS;
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
