
/*
    Quasi frame interpolation shader

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

namespace Interpolation
{
    uniform float _Constraint <
        ui_type = "slider";
        ui_label = "Flow Smooth";
        ui_tooltip = "Higher = Smoother flow";
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
    #define BUFFER_SIZE uint2(256, 256)

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

    texture2D RenderFrame0
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
        MipLevels = 8;
    };

    sampler2D SampleFrame0
    {
        Texture = RenderFrame0;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBTexture = TRUE;
        #endif
    };

    texture2D RenderData0
    {
        Width = BUFFER_SIZE.x;
        Height = BUFFER_SIZE.y;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D SampleData0
    {
        Texture = RenderData0;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderData1
    {
        Width = BUFFER_SIZE.x;
        Height = BUFFER_SIZE.y;
        Format = RGBA16F;
        MipLevels = 8;
    };

    sampler2D SampleData1
    {
        Texture = RenderData1;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderData2
    {
        Width = BUFFER_SIZE.x;
        Height = BUFFER_SIZE.y;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D SampleData2
    {
        Texture = RenderData2;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon7
    {
        Width = BUFFER_SIZE.x / 128;
        Height = BUFFER_SIZE.y / 128;
        Format = RG16F;
    };

    sampler2D SampleCommon7
    {
        Texture = RenderCommon7;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon6
    {
        Width = BUFFER_SIZE.x / 64;
        Height = BUFFER_SIZE.y / 64;
        Format = RG16F;
    };

    sampler2D SampleCommon6
    {
        Texture = RenderCommon6;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon5
    {
        Width = BUFFER_SIZE.x / 32;
        Height = BUFFER_SIZE.y / 32;
        Format = RG16F;
    };

    sampler2D SampleCommon5
    {
        Texture = RenderCommon5;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon4
    {
        Width = BUFFER_SIZE.x / 16;
        Height = BUFFER_SIZE.y / 16;
        Format = RG16F;
    };

    sampler2D SampleCommon4
    {
        Texture = RenderCommon4;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon3
    {
        Width = BUFFER_SIZE.x / 8;
        Height = BUFFER_SIZE.y / 8;
        Format = RG16F;
    };

    sampler2D SampleCommon3
    {
        Texture = RenderCommon3;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon2
    {
        Width = BUFFER_SIZE.x / 4;
        Height = BUFFER_SIZE.y / 4;
        Format = RG16F;
    };

    sampler2D SampleCommon2
    {
        Texture = RenderCommon2;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon1
    {
        Width = BUFFER_SIZE.x / 2;
        Height = BUFFER_SIZE.y / 2;
        Format = RG16F;
    };

    sampler2D SampleCommon1
    {
        Texture = RenderCommon1;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon0
    {
        Width = BUFFER_SIZE.x / 1;
        Height = BUFFER_SIZE.y / 1;
        Format = RG16F;
    };

    sampler2D SampleCommon0
    {
        Texture = RenderCommon0;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderFrame1
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
    };

    sampler2D SampleFrame1
    {
        Texture = RenderFrame1;
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

    void Downsample1VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 DownsampleOffsets[4] : TEXCOORD0)
    {
        DownsampleVS(ID, 1.0 / uint2(ldexp(BUFFER_SIZE, -1.0)), Position, DownsampleOffsets);
    }

    void Downsample2VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 DownsampleOffsets[4] : TEXCOORD0)
    {
        DownsampleVS(ID, 1.0 / uint2(ldexp(BUFFER_SIZE, -2.0)), Position, DownsampleOffsets);
    }

    void Upsample1VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleOffsets[3] : TEXCOORD0)
    {
        UpsampleVS(ID, 1.0 / uint2(ldexp(BUFFER_SIZE, -1.0)), Position, UpsampleOffsets);
    }

    void Upsample0VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleOffsets[3] : TEXCOORD0)
    {
        UpsampleVS(ID, 1.0 / uint2(ldexp(BUFFER_SIZE, 0.0)), Position, UpsampleOffsets);
    }

    void DerivativesVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets : TEXCOORD0)
    {
        const float2 PixelSize = 0.5 / BUFFER_SIZE;
        const float4 PixelOffset = float4(PixelSize, -PixelSize);
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        Offsets = TexCoord0.xyxy + PixelOffset;
    }

    void EstimateLevel6VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / uint2(ldexp(BUFFER_SIZE, -7.0)), Offsets);
    }

    void EstimateLevel5VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / uint2(ldexp(BUFFER_SIZE, -6.0)), Offsets);
    }

    void EstimateLevel4VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / uint2(ldexp(BUFFER_SIZE, -5.0)), Offsets);
    }

    void EstimateLevel3VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / uint2(ldexp(BUFFER_SIZE, -4.0)), Offsets);
    }

    void EstimateLevel2VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / uint2(ldexp(BUFFER_SIZE, -3.0)), Offsets);
    }

    void EstimateLevel1VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / uint2(ldexp(BUFFER_SIZE, -2.0)), Offsets);
    }

    void EstimateLevel0VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / uint2(ldexp(BUFFER_SIZE, -1.0)), Offsets);
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
        // .xy = Normalized Red Channel (x, y)
        // .zw = Normalized Green Channel (x, y)
        float4 SampleI = tex2D(SampleData1, TexCoord).xyzw;

        // .xy = Current frame (r, g)
        // .zw = Previous frame (r, g)
        float4 SampleFrames;
        SampleFrames.xy = tex2D(SampleData0, TexCoord).rg;
        SampleFrames.zw = tex2D(SampleData2, TexCoord).rg;
        float2 Iz = SampleFrames.xy - SampleFrames.zw;

        const float Alpha = max(ldexp(_Constraint * 1e-3, Level - MaxLevel), 1e-7);

        // Compute diagonal
        float2 Aii;
        Aii.x = dot(SampleI.xz, SampleI.xz) + Alpha;
        Aii.y = dot(SampleI.yw, SampleI.yw) + Alpha;
        Aii.xy = 1.0 / Aii.xy;

        // Compute right-hand side
        float2 RHS;
        RHS.x = dot(SampleI.xz, Iz.rg);
        RHS.y = dot(SampleI.yw, Iz.rg);

        // Compute triangle
        float Aij = dot(SampleI.xz, SampleI.yw);

        // Symmetric Gauss-Seidel (forward sweep, from 1...N)
        DUV.x = Aii.x * ((Alpha * UV.x) - RHS.x - (UV.y * Aij));
        DUV.y = Aii.y * ((Alpha * UV.y) - RHS.y - (DUV.x * Aij));

        // Symmetric Gauss-Seidel (backward sweep, from N...1)
        DUV.y = Aii.y * ((Alpha * DUV.y) - RHS.y - (DUV.x * Aij));
        DUV.x = Aii.x * ((Alpha * DUV.x) - RHS.x - (DUV.y * Aij));
    }

    void Copy0PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = tex2D(SampleColor, TexCoord);
    }

    void NormalizePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        const float Minima = exp2(-10.0);
        float3 Color = max(tex2D(SampleFrame0, TexCoord).rgb, Minima);
        OutputColor0 = saturate(Color.xy / dot(Color, 1.0));
    }

    void PreDownsample1PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Downsample(SampleData0, TexCoord);
    }

    void PreDownsample2PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Downsample(SampleCommon1, TexCoord);
    }

    void PreUpsample1PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Upsample(SampleCommon2, TexCoord);
    }

    void PreUpsample0PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Upsample(SampleCommon1, TexCoord);
    }

    void DerivativesPS(in float4 Position : SV_Position, in float4 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        float2 Sample0 = tex2D(SampleData0, TexCoord.zy).xy; // (-x, +y)
        float2 Sample1 = tex2D(SampleData0, TexCoord.xy).xy; // (+x, +y)
        float2 Sample2 = tex2D(SampleData0, TexCoord.zw).xy; // (-x, -y)
        float2 Sample3 = tex2D(SampleData0, TexCoord.xw).xy; // (+x, -y)
        OutputColor0.xz = (Sample3 + Sample1) - (Sample2 + Sample0);
        OutputColor0.yw = (Sample2 + Sample3) - (Sample0 + Sample1);
        OutputColor0 *= 4.0;
    }

    void EstimateLevel7PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, 0.0, 7.0, OutputEstimation);
    }

    void EstimateLevel6PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(SampleCommon7, UpsampleOffsets).xy, 6.0, OutputEstimation);
    }

    void EstimateLevel5PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(SampleCommon6, UpsampleOffsets).xy, 5.0, OutputEstimation);
    }

    void EstimateLevel4PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(SampleCommon5, UpsampleOffsets).xy, 4.0, OutputEstimation);
    }

    void EstimateLevel3PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(SampleCommon4, UpsampleOffsets).xy, 3.0, OutputEstimation);
    }

    void EstimateLevel2PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(SampleCommon3, UpsampleOffsets).xy, 2.0, OutputEstimation);
    }

    void EstimateLevel1PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(SampleCommon2, UpsampleOffsets).xy, 1.0, OutputEstimation);
    }

    void EstimateLevel0PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float4 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(SampleCommon1, UpsampleOffsets).xy, 0.0, OutputEstimation.xy);
        OutputEstimation.ba = (0.0, _Blend);
    }

    void PostDownsample1PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Downsample(SampleCommon0, TexCoord);
    }

    void PostDownsample2PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Downsample(SampleCommon1, TexCoord);
    }

    void PostUpsample1PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Upsample(SampleCommon2, TexCoord);
    }

    void PostUpsample0PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = Upsample(SampleCommon1, TexCoord);
    }

    float4 Med3(float4 a, float4 b, float4 c)
    {
        return clamp(a, min(b, c), max(b, c));
    }

    void InterpolatePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        float2 MotionVectors = tex2Dlod(SampleData2, float4(TexCoord, 0.0, _MipBias)).xy / BUFFER_SIZE;
        float4 FrameF = tex2D(SampleFrame1, TexCoord + MotionVectors);
        float4 FrameB = tex2D(SampleFrame0, TexCoord - MotionVectors);
        float4 FrameP = tex2D(SampleFrame1, TexCoord);
        float4 FrameC = tex2D(SampleFrame0, TexCoord);
        float4 FrameA = lerp(FrameC, FrameP, 64.0 / 256.0);
        // Note: Make better masking
        OutputColor0 = Med3(FrameA, FrameF, FrameB);
    }

    void Copy1PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = tex2D(SampleFrame0, TexCoord);
    }

    void Copy2PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OutputColor0 = tex2D(SampleData0, TexCoord).rg;
    }

    technique cInterpolation
    {
        // Normalize current frame

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = Copy0PS;
            RenderTarget0 = RenderFrame0;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = NormalizePS;
            RenderTarget0 = RenderData0;
        }

        // Pre-process dual-filter blur

        pass
        {
            VertexShader = Downsample1VS;
            PixelShader = PreDownsample1PS;
            RenderTarget0 = RenderCommon1;
        }

        pass
        {
            VertexShader = Downsample2VS;
            PixelShader = PreDownsample2PS;
            RenderTarget0 = RenderCommon2;
        }

        pass
        {
            VertexShader = Upsample1VS;
            PixelShader = PreUpsample1PS;
            RenderTarget0 = RenderCommon1;
        }

        pass
        {
            VertexShader = Upsample0VS;
            PixelShader = PreUpsample0PS;
            RenderTarget0 = RenderData0;
        }

        // Calculate derivative pyramid (to be removed)

        pass
        {
            VertexShader = DerivativesVS;
            PixelShader = DerivativesPS;
            RenderTarget0 = RenderData1;
        }

        // Calculate pyramidal estimation

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel7PS;
            RenderTarget0 = RenderCommon7;
        }

        pass
        {
            VertexShader = EstimateLevel6VS;
            PixelShader = EstimateLevel6PS;
            RenderTarget0 = RenderCommon6;
        }

        pass
        {
            VertexShader = EstimateLevel5VS;
            PixelShader = EstimateLevel5PS;
            RenderTarget0 = RenderCommon5;
        }

        pass
        {
            VertexShader = EstimateLevel4VS;
            PixelShader = EstimateLevel4PS;
            RenderTarget0 = RenderCommon4;
        }

        pass
        {
            VertexShader = EstimateLevel3VS;
            PixelShader = EstimateLevel3PS;
            RenderTarget0 = RenderCommon3;
        }

        pass
        {
            VertexShader = EstimateLevel2VS;
            PixelShader = EstimateLevel2PS;
            RenderTarget0 = RenderCommon2;
        }

        pass
        {
            VertexShader = EstimateLevel1VS;
            PixelShader = EstimateLevel1PS;
            RenderTarget0 = RenderCommon1;
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
            VertexShader = Downsample1VS;
            PixelShader = PostDownsample1PS;
            RenderTarget0 = RenderCommon1;
        }

        pass
        {
            VertexShader = Downsample2VS;
            PixelShader = PostDownsample2PS;
            RenderTarget0 = RenderCommon2;
        }

        pass
        {
            VertexShader = Upsample1VS;
            PixelShader = PostUpsample1PS;
            RenderTarget0 = RenderCommon1;
        }

        pass
        {
            VertexShader = Upsample0VS;
            PixelShader = PostUpsample0PS;
            RenderTarget0 = RenderData2;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = InterpolatePS;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }

        // Store previous frames

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = Copy1PS;
            RenderTarget0 = RenderFrame1;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = Copy2PS;
            RenderTarget0 = RenderData2;
        }
    }
}
