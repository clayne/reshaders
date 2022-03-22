
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
        texture2D RenderCommon1a
        {
            Width = BUFFER_WIDTH >> 1;
            Height = BUFFER_HEIGHT >> 1;
            Format = RG16F;
            MipLevels = 8;
        };

        namespace POW2
        {
            texture2D RenderCommon0a
            {
                Width = POW2SIZE_0;
                Height = POW2SIZE_0;
                Format = RG16F;
                MipLevels = 8;
            };

            texture2D RenderCommon0b
            {
                Width = POW2SIZE_0;
                Height = POW2SIZE_0;
                Format = RG16F;
                MipLevels = 8;
            };

            texture2D RenderCommon0c
            {
                Width = POW2SIZE_0;
                Height = POW2SIZE_0;
                Format = RG16F;
                MipLevels = 8;
            };

            texture2D RenderCommon1
            {
                Width = POW2SIZE_1;
                Height = POW2SIZE_1;
                Format = RG16F;
            };

            texture2D RenderCommon2
            {
                Width = POW2SIZE_2;
                Height = POW2SIZE_2;
                Format = RG16F;
            };

            texture2D RenderCommon3
            {
                Width = POW2SIZE_3;
                Height = POW2SIZE_3;
                Format = RG16F;
            };

            texture2D RenderCommon4
            {
                Width = POW2SIZE_4;
                Height = POW2SIZE_4;
                Format = RG16F;
            };

            texture2D RenderCommon5
            {
                Width = POW2SIZE_5;
                Height = POW2SIZE_5;
                Format = RG16F;
            };

            texture2D RenderCommon6
            {
                Width = POW2SIZE_6;
                Height = POW2SIZE_6;
                Format = RG16F;
            };

            texture2D RenderCommon7
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
    uniform float _Scale <
        ui_type = "slider";
        ui_category = "Main";
        ui_label = "Flow Scale";
        ui_tooltip = "Higher = More motion blur";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.5;

    uniform bool _FrameRateScaling <
        ui_type = "radio";
        ui_category = "Main";
        ui_label = "Frame-Rate Scaling";
        ui_tooltip = "Enables frame-rate scaling";
    > = false;

    uniform float _TargetFrameRate <
        ui_type = "drag";
        ui_category = "Main";
        ui_label = "Target Frame-Rate";
        ui_tooltip = "Targeted frame-rate";
    > = 60.00;

    uniform float _Constraint <
        ui_type = "slider";
        ui_category = "Optical flow";
        ui_label = "Motion Threshold";
        ui_min = 0.0;
        ui_max = 2.0;
    > = 1.0;

    uniform float _Smoothness <
        ui_type = "slider";
        ui_category = "Optical flow";
        ui_label = "Motion Smoothness";
        ui_min = 0.0;
        ui_max = 8.0;
    > = 4.0;

    uniform float _MipBias <
        ui_type = "slider";
        ui_category = "Optical flow";
        ui_label = "Mipmap Bias";
        ui_tooltip = "Higher = Less spatial noise";
        ui_min = 0.0;
        ui_max = 7.0;
    > = 3.5;

    uniform float _Blend <
        ui_type = "slider";
        ui_category = "Optical flow";
        ui_label = "Temporal Blending";
        ui_tooltip = "Higher = Less temporal noise";
        ui_min = 0.0;
        ui_max = 0.5;
    > = 0.125;

    uniform float _FrameTime < source = "frametime"; >;

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

    sampler2D SampleCommon1a
    {
        Texture = SharedResources::RG16F::RenderCommon1a;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SamplePOW2Common0a
    {
        Texture = SharedResources::RG16F::POW2::RenderCommon0a;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SamplePOW2Common0b
    {
        Texture = SharedResources::RG16F::POW2::RenderCommon0b;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SamplePOW2Common0c
    {
        Texture = SharedResources::RG16F::POW2::RenderCommon0c;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderData3
    {
        Width = POW2SIZE_0;
        Height = POW2SIZE_0;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D SampleData3
    {
        Texture = RenderData3;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SamplePOW2Common7
    {
        Texture = SharedResources::RG16F::POW2::RenderCommon7;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SamplePOW2Common6
    {
        Texture = SharedResources::RG16F::POW2::RenderCommon6;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SamplePOW2Common5
    {
        Texture = SharedResources::RG16F::POW2::RenderCommon5;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SamplePOW2Common4
    {
        Texture = SharedResources::RG16F::POW2::RenderCommon4;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SamplePOW2Common3
    {
        Texture = SharedResources::RG16F::POW2::RenderCommon3;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SamplePOW2Common2
    {
        Texture = SharedResources::RG16F::POW2::RenderCommon2;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SamplePOW2Common1
    {
        Texture = SharedResources::RG16F::POW2::RenderCommon1;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon0
    {
        Width = POW2SIZE_0;
        Height = POW2SIZE_0;
        Format = RG16F;
    };

    sampler2D SamplePOW2Common0
    {
        Texture = RenderCommon0;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    // Vertex shaders

    void MedianOffsets(in float2 TexCoord, in float2 TexelSize, inout float4 SampleOffsets[3])
    {
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        SampleOffsets[0] = TexCoord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * TexelSize.xyyy);
        SampleOffsets[1] = TexCoord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * TexelSize.xyyy);
        SampleOffsets[2] = TexCoord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * TexelSize.xyyy);
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
        float2 VSTexCoord;
        PostProcessVS(ID, Position, VSTexCoord);
        MedianOffsets(VSTexCoord, 1.0 / uint2(BUFFER_WIDTH >> 1, BUFFER_HEIGHT >> 1), Offsets);
    }

    void TentFilterVS(in uint ID, in float2 TexelSize, inout float4 Position, inout float4 Offsets[3])
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        TentOffsets(VSTexCoord, TexelSize, Offsets);
    }

    void TentFilter0VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TentCoords[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / POW2SIZE_0, Position, TentCoords);
    }

    void TentFilter1VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TentCoords[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / POW2SIZE_1, Position, TentCoords);
    }

    void TentFilter2VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TentCoords[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / POW2SIZE_2, Position, TentCoords);
    }

    void TentFilter3VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TentCoords[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / POW2SIZE_3, Position, TentCoords);
    }

    void DerivativesVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[2] : TEXCOORD0)
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        const float2 PixelSize = 1.0 / POW2SIZE_0;
        TexCoords[0] = VSTexCoord.xxyy + (float4(-1.5, 1.5, -0.5, 0.5) * PixelSize.xxyy);
        TexCoords[1] = VSTexCoord.xxyy + (float4(-0.5, 0.5, -1.5, 1.5) * PixelSize.xxyy);
    }

    void GradientsVS(in float2 TexCoord, in float2 PixelSize, inout float4 TexCoords[5])
    {
        // Sample locations:
        //               [4].xy
        //        [0].xy [1].xy [2].xy
        // [3].xz [0].xz [1].xz [2].xz [3].yz
        //        [0].xw [1].xw [2].xw
        //               [4].xz
        TexCoords[0] = TexCoord.xyyy + (float4(-2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);
        TexCoords[1] = TexCoord.xyyy + (float4(0.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);
        TexCoords[2] = TexCoord.xyyy + (float4(2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);
        TexCoords[3].xyz = TexCoord.xxy + (float3(-4.0, 4.0, 0.0) * PixelSize.xxy);
        TexCoords[4].xyz = TexCoord.xyy + (float3(0.0, 4.0, -4.0) * PixelSize.xyy);
    }

    void EstimateVS(in uint ID, in float2 PixelSize, inout float4 Position, inout float4 TexCoords[5])
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        GradientsVS(VSTexCoord, PixelSize, TexCoords);
    }

    void EstimateLevel6VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        GradientsVS(VSTexCoord, 1.0 / POW2SIZE_6, TexCoords);
    }

    void EstimateLevel5VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        GradientsVS(VSTexCoord, 1.0 / POW2SIZE_5, TexCoords);
    }

    void EstimateLevel4VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        GradientsVS(VSTexCoord, 1.0 / POW2SIZE_4, TexCoords);
    }

    void EstimateLevel3VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        GradientsVS(VSTexCoord, 1.0 / POW2SIZE_3, TexCoords);
    }

    void EstimateLevel2VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        GradientsVS(VSTexCoord, 1.0 / POW2SIZE_2, TexCoords);
    }

    void EstimateLevel1VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        GradientsVS(VSTexCoord, 1.0 / POW2SIZE_1, TexCoords);
    }

    void EstimateLevel0VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        GradientsVS(VSTexCoord, 1.0 / POW2SIZE_0, TexCoords);
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

    float4 TentFilter(sampler2D Source, float4 Offsets[3])
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
        Pyramidal Horn-Schunck optical flow
            + Horn-Schunck: https://dspace.mit.edu/handle/1721.1/6337 (Page 8)
            + Pyramid process: https://www.youtube.com/watch?v=4v_keMNROv4

        Modifications
            + Compute averages with a 7x7 low-pass tent filter
            + Estimate features in 2-dimensional chromaticity
            + Use pyramid process to get initial values from neighboring pixels
            + Use symmetric Gauss-Seidel to solve linear equation at Page 8
    */

    /*
        https://github.com/Dtananaev/cv_opticalFlow

        Copyright (c) 2014-2015, Denis Tananaev All rights reserved.

        Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

        Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

        Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    */

    static const int MaxLevel = 7;

    void OpticalFlowCoarse(in float2 TexCoord, in float Level, out float2 DUV)
    {
        DUV = 0.0;
        const float E = _Smoothness * 1e-3;
        const float Alpha = max(ldexp(_Constraint * 1e-3, Level - MaxLevel), 1e-7);

        float2 CurrentFrame = tex2D(SamplePOW2Common0a, TexCoord).xy;
        float2 PreviousFrame = tex2D(SampleData3, TexCoord).xy;

        // IxyRG = <Rx, Gx, Ry, Gy>
        float4 IxyRG = 0.0;
        IxyRG.xy = tex2D(SamplePOW2Common0b, TexCoord).rg;
        IxyRG.zw = tex2D(SamplePOW2Common0c, TexCoord).rg;

        // IzRG = <Rz, Gz>
        float2 IzRG = CurrentFrame - PreviousFrame;

        // Calculate constancy term
        float C = 0.0;
        C = dot(IzRG, 1.0);
        C = rsqrt(C * C + (E * E));

        // Ix2 = 1.0 / (Rx^2 + Gx^2 + a)
        // Iy2 = 1.0 / (Ry^2 + Gy^2 + a)
        // Ixy = Rxy + Gxy
        float Ix2 = 1.0 / (C * dot(IxyRG.xy, IxyRG.xy) + Alpha);
        float Iy2 = 1.0 / (C * dot(IxyRG.zw, IxyRG.zw) + Alpha);
        float Ixy = dot(IxyRG.xy, IxyRG.zw);

        // Ixt = Rxt + Gxt
        // Iyt = Ryt + Gyt
        float Ixt = C * dot(IxyRG.xy, IzRG);
        float Iyt = C * dot(IxyRG.zw, IzRG);

        // Gauss-Seidel (forward sweep, from 1...N)
        DUV.x = Ix2 * (-(C * Ixy * DUV.y) - Ixt);
        DUV.y = Iy2 * (-(C * Ixy * DUV.x) - Iyt);
    }

    void OpticalFlowTV(in sampler2D Source, in float4 TexCoords[5], in float Level, out float2 DUV)
    {
        // Calculate TV
        const float E = _Smoothness * 2e-2;
        const float Alpha = max(ldexp(_Constraint * 1e-4, Level - MaxLevel), 1e-7);

        float4 GradUV = 0.0;
        float SqGradUV = 0.0;
        float Smoothness0 = 0.0;
        float4 Smoothness1 = 0.0;

        // TexCoord locations:
        //               [4].xy
        //        [0].xy [1].xy [2].xy
        // [3].xz [0].xz [1].xz [2].xz [3].yz
        //        [0].xw [1].xw [2].xw
        //               [4].xz
        //
        // Sampler locations:
        //       C0
        //    B0 C1 D0
        // A0 B1 C2 D1 E0
        //    B2 C3 D2
        //       C4

        float2 A0 = tex2D(Source, TexCoords[3].xz).xy;

        float2 B0 = tex2D(Source, TexCoords[0].xy).xy;
        float2 B1 = tex2D(Source, TexCoords[0].xz).xy;
        float2 B2 = tex2D(Source, TexCoords[0].xw).xy;

        float2 C0 = tex2D(Source, TexCoords[4].xy).xy;
        float2 C1 = tex2D(Source, TexCoords[1].xy).xy;
        float2 C2 = tex2D(Source, TexCoords[1].xz).xy;
        float2 C3 = tex2D(Source, TexCoords[1].xw).xy;
        float2 C4 = tex2D(Source, TexCoords[4].xz).xy;

        float2 D0 = tex2D(Source, TexCoords[2].xy).xy;
        float2 D1 = tex2D(Source, TexCoords[2].xz).xy;
        float2 D2 = tex2D(Source, TexCoords[2].xw).xy;

        float2 E0 = tex2D(Source, TexCoords[3].yz).xy;

        float2 CurrentFrame = tex2D(SamplePOW2Common0a, TexCoords[1].xz).xy;
        float2 PreviousFrame = tex2D(SampleData3, TexCoords[1].xz).xy;

        // IxyRG = <Rx, Gx, Ry, Gy>
        // IxyRG = <Rx, Gx, Ry, Gy>
        float4 IxyRG = 0.0;
        IxyRG.xy = tex2D(SamplePOW2Common0b, TexCoords[1].xz).rg;
        IxyRG.zw = tex2D(SamplePOW2Common0c, TexCoords[1].xz).rg;

        // ItRG = <Rt, Gt>
        float2 IzRG = CurrentFrame - PreviousFrame;

        // Calculate optical flow

        //    A0
        // A1 A2 A3 -> A5
        //    A4

        float2 Avg[6];
        Avg[0] = (((C0 + B0 + D0 + C2) * 0.125) + (C1 * 0.5));
        Avg[1] = (((B0 + A0 + C2 + B2) * 0.125) + (B1 * 0.5));
        Avg[2] = (((C1 + B1 + D1 + C3) * 0.125) + (C2 * 0.5));
        Avg[3] = (((D0 + C2 + E0 + D2) * 0.125) + (D1 * 0.5));
        Avg[4] = (((C2 + B2 + D2 + C4) * 0.125) + (C3 * 0.5));
        Avg[5] = (((Avg[0] + Avg[1] + Avg[3] + Avg[4]) * 0.125) + (Avg[2] * 0.5));

        // Center smoothness gradient and average
        GradUV.xy = (D0 + (D1 * 2.0) + D2 + E0) - (B0 + (B1 * 2.0) + B2 + A0); // <IxU, IxV>
        GradUV.zw = (C0 + B0 + (C1 * 2.0) + D0) - (B2 + (C3 * 2.0) + D2 + C4); // <IyU, IyV>
        SqGradUV = dot(GradUV.xzyw / 5.0, GradUV.xzyw / 5.0) * 0.25;
        Smoothness0 = rsqrt(SqGradUV + (E * E));

        // Right gradient
        GradUV.xy = E0 - C2; // <IxU, IxV>
        GradUV.zw = D0 - D2; // <IyU, IyV>
        SqGradUV = dot(GradUV.xzyw, GradUV.xzyw) * 0.25;
        Smoothness1[0] = rsqrt(SqGradUV + (E * E));

        // Left gradient
        GradUV.xy = C2 - A0; // <IxU, IxV>
        GradUV.zw = B0 - B2; // <IyU, IyV>
        SqGradUV = dot(GradUV.xzyw, GradUV.xzyw) * 0.25;
        Smoothness1[1] = rsqrt(SqGradUV + (E * E));

        // Top gradient
        GradUV.xy = D0 - B0; // <IxU, IxV>
        GradUV.zw = C0 - C2; // <IyU, IyV>
        SqGradUV = dot(GradUV.xzyw, GradUV.xzyw) * 0.25;
        Smoothness1[2] = rsqrt(SqGradUV + (E * E));

        // Bottom gradient
        GradUV.xy = D2 - B2; // <IxU, IxV>
        GradUV.zw = C2 - C4; // <IyU, IyV>
        SqGradUV = dot(GradUV.xzyw, GradUV.xzyw) * 0.25;
        Smoothness1[3] = rsqrt(SqGradUV + (E * E));

        float4 Gradients = 0.5 * (Smoothness0 + Smoothness1.xyzw);

        // Calculate constancy term
        float C = 0.0;
        C = dot(IxyRG.xyzw, Avg[5].xxyy) + dot(IzRG, 1.0);
        C = rsqrt(C * C + (E * E));

        // Ix2 = 1.0 / (Rx^2 + Gx^2 + a)
        // Iy2 = 1.0 / (Ry^2 + Gy^2 + a)
        // Ixy = Rxy + Gxy
        float3 I2 = 0.0;
        I2.x = dot(IxyRG.xy, IxyRG.xy);
        I2.y = dot(IxyRG.zw, IxyRG.zw);
        I2.z = dot(IxyRG.xy, IxyRG.zw);
        I2.xyz = C * I2.xyz;

        // Ixyt[0] = Rxt + Gxt
        // Ixyt[1] = Ryt + Gyt
        float2 It = 0.0;
        It.x = dot(IxyRG.xy, IzRG);
        It.y = dot(IxyRG.zw, IzRG);
        It.xy = C * It.xy;

        float2 Aii = 1.0 / (dot(Gradients, 1.0) * Alpha + I2.xy);
        float2 Bi = Alpha * ((Gradients[0] * Avg[3]) + (Gradients[1] * Avg[1]) + (Gradients[2] * Avg[0]) + (Gradients[3] * Avg[4]));

        // Gauss-Seidel (forward sweep, from 1...N)
        DUV.x = Aii.x * (Bi.x - (I2.z * Avg[5].y) - It.x);
        DUV.y = Aii.y * (Bi.y - (I2.z * DUV.x) - It.y);
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

    void Copy0PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OutputColor0 = tex2D(SampleCommon1a, TexCoord).rg;
    }

    void PreDownsample1PS(in float4 Position : SV_Position, in float4 TentCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilter(SamplePOW2Common0a, TentCoords);
    }

    void PreDownsample2PS(in float4 Position : SV_Position, in float4 TentCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilter(SamplePOW2Common1, TentCoords);
    }

    void PreDownsample3PS(in float4 Position : SV_Position, in float4 TentCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilter(SamplePOW2Common2, TentCoords);
    }

    void PreUpsample2PS(in float4 Position : SV_Position, in float4 TentCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilter(SamplePOW2Common3, TentCoords);
    }

    void PreUpsample1PS(in float4 Position : SV_Position, in float4 TentCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilter(SamplePOW2Common2, TentCoords);
    }

    void PreUpsample0PS(in float4 Position : SV_Position, in float4 TentCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilter(SamplePOW2Common1, TentCoords);
    }

    void DerivativesPS(in float4 Position : SV_Position, in float4 TexCoords[2] : TEXCOORD0, out float2 OutputColor0 : SV_Target0, out float2 OutputColor1 : SV_Target1)
    {
        // Bilinear 5x5 Sobel by CeeJayDK
        //   B1 B2
        // A0     A1
        // A2     B0
        //   C0 C1
        float2 A0 = tex2D(SamplePOW2Common0a, TexCoords[0].xw).xy * 4.0; // <-1.5, +0.5>
        float2 A1 = tex2D(SamplePOW2Common0a, TexCoords[0].yw).xy * 4.0; // <+1.5, +0.5>
        float2 A2 = tex2D(SamplePOW2Common0a, TexCoords[0].xz).xy * 4.0; // <-1.5, -0.5>
        float2 B0 = tex2D(SamplePOW2Common0a, TexCoords[0].yz).xy * 4.0; // <+1.5, -0.5>
        float2 B1 = tex2D(SamplePOW2Common0a, TexCoords[1].xw).xy * 4.0; // <-0.5, +1.5>
        float2 B2 = tex2D(SamplePOW2Common0a, TexCoords[1].yw).xy * 4.0; // <+0.5, +1.5>
        float2 C0 = tex2D(SamplePOW2Common0a, TexCoords[1].xz).xy * 4.0; // <-0.5, -1.5>
        float2 C1 = tex2D(SamplePOW2Common0a, TexCoords[1].yz).xy * 4.0; // <+0.5, -1.5>

        float4 I = 0.0;

        //    -1 0 +1
        // -1 -2 0 +2 +1
        // -2 -2 0 +2 +2
        // -1 -2 0 +2 +1
        //    -1 0 +1
        I.xy = ((B2 + A1 + B0 + C1) - (B1 + A0 + A2 + C0)) / 12.0;

        //    +1 +2 +1
        // +1 +2 +2 +2 +1
        //  0  0  0  0  0
        // -1 -2 -2 -2 -1
        //    -1 -2 -1
        I.zw = ((A0 + B1 + B2 + A1) - (A2 + C0 + C1 + B0)) / 12.0;

        I.xz *= rsqrt(dot(I.xz, I.xz) + 1.0);
        I.yw *= rsqrt(dot(I.yw, I.yw) + 1.0);

        OutputColor0 = I.xy;
        OutputColor1 = I.zw;
    }

    void EstimateLevel7PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowCoarse(TexCoord, 7.0, OutputColor0);
    }

    void EstimateLevel6PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SamplePOW2Common7, TexCoords, 6.0, OutputColor0);
    }

    void EstimateLevel5PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SamplePOW2Common6, TexCoords, 5.0, OutputColor0);
    }

    void EstimateLevel4PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SamplePOW2Common5, TexCoords, 4.0, OutputColor0);
    }

    void EstimateLevel3PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SamplePOW2Common4, TexCoords, 3.0, OutputColor0);
    }

    void EstimateLevel2PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SamplePOW2Common3, TexCoords, 2.0, OutputColor0);
    }

    void EstimateLevel1PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SamplePOW2Common2, TexCoords, 1.0, OutputColor0);
    }

    void EstimateLevel0PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SamplePOW2Common1, TexCoords, 0.0, OutputColor0.xy);
        OutputColor0.xy *= float2(1.0, -1.0);
        OutputColor0.ba = (0.0, _Blend);
    }

    void PostDownsample1PS(in float4 Position : SV_Position, in float4 TentCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilter(SamplePOW2Common0, TentCoords);
    }

    void PostDownsample2PS(in float4 Position : SV_Position, in float4 TentCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilter(SamplePOW2Common1, TentCoords);
    }

    void PostDownsample3PS(in float4 Position : SV_Position, in float4 TentCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilter(SamplePOW2Common2, TentCoords);
    }

    void PostUpsample2PS(in float4 Position : SV_Position, in float4 TentCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilter(SamplePOW2Common3, TentCoords);
    }

    void PostUpsample1PS(in float4 Position : SV_Position, in float4 TentCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = TentFilter(SamplePOW2Common2, TentCoords);
    }

    void PostUpsample0PS(in float4 Position : SV_Position, in float4 TentCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0, out float2 OutputColor1 : SV_Target1)
    {
        OutputColor0 = TentFilter(SamplePOW2Common1, TentCoords);
        OutputColor1 = tex2D(SamplePOW2Common0a, TentCoords[1].xz).rg;
    }

    void MotionBlurPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
    {
        OutputColor0 = 0.0;
        const int Samples = 4;
        float Noise = frac(52.9829189 * frac(dot(Position.xy, float2(0.06711056, 0.00583715))));
        float FrameTimeRatio = _TargetFrameRate / (1e+3 / _FrameTime);
        float2 Velocity = (tex2Dlod(SamplePOW2Common0c, float4(TexCoord, 0.0, _MipBias)).xy / POW2SIZE_1) * _Scale;
        Velocity /= (_FrameRateScaling) ? FrameTimeRatio : 1.0;

        for(int k = 0; k < Samples; ++k)
        {
            float2 Offset = Velocity * (Noise + k);
            OutputColor0 += tex2D(SampleColor, (TexCoord + Offset));
            OutputColor0 += tex2D(SampleColor, (TexCoord - Offset));
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
            RenderTarget0 = SharedResources::RG16F::RenderCommon1a;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = Copy0PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon0a;
        }

        // Pre-process dual-filter blur

        pass
        {
            VertexShader = TentFilter0VS;
            PixelShader = PreDownsample1PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon1;
        }

        pass
        {
            VertexShader = TentFilter1VS;
            PixelShader = PreDownsample2PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = PreDownsample3PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon3;
        }

        pass
        {
            VertexShader = TentFilter3VS;
            PixelShader = PreUpsample2PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = PreUpsample1PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon1;
        }

        pass
        {
            VertexShader = TentFilter1VS;
            PixelShader = PreUpsample0PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon0a;
        }

        // Calculate discrete derivative pyramid

        pass
        {
            VertexShader = DerivativesVS;
            PixelShader = DerivativesPS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon0b;
            RenderTarget1 = SharedResources::RG16F::POW2::RenderCommon0c;
        }

        // Calculate pyramidal estimation

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel7PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon7;
        }

        pass
        {
            VertexShader = EstimateLevel6VS;
            PixelShader = EstimateLevel6PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon6;
        }

        pass
        {
            VertexShader = EstimateLevel5VS;
            PixelShader = EstimateLevel5PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon5;
        }

        pass
        {
            VertexShader = EstimateLevel4VS;
            PixelShader = EstimateLevel4PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon4;
        }

        pass
        {
            VertexShader = EstimateLevel3VS;
            PixelShader = EstimateLevel3PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon3;
        }

        pass
        {
            VertexShader = EstimateLevel2VS;
            PixelShader = EstimateLevel2PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon2;
        }

        pass
        {
            VertexShader = EstimateLevel1VS;
            PixelShader = EstimateLevel1PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon1;
        }

        pass
        {
            VertexShader = EstimateLevel0VS;
            PixelShader = EstimateLevel0PS;
            RenderTarget0 = RenderCommon0;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        // Post-process dual-filter blur

        pass
        {
            VertexShader = TentFilter0VS;
            PixelShader = PostDownsample1PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon1;
        }

        pass
        {
            VertexShader = TentFilter1VS;
            PixelShader = PostDownsample2PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = PostDownsample3PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon3;
        }

        pass
        {
            VertexShader = TentFilter3VS;
            PixelShader = PostUpsample2PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = PostUpsample1PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon1;
        }

        pass
        {
            VertexShader = TentFilter1VS;
            PixelShader = PostUpsample0PS;
            RenderTarget0 = SharedResources::RG16F::POW2::RenderCommon0c;

            // Store previous frame
            RenderTarget1 = RenderData3;
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
