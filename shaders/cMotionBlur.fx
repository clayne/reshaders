
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

// Shared textures

texture2D _RenderTemporary1a < pooled = true; >
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RG16F;
    MipLevels = 8;
};

texture2D _RenderTemporary1b < pooled = true; >
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RG16F;
    MipLevels = 8;
};

texture2D _RenderTemporary1c < pooled = true; >
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RG16F;
    MipLevels = 8;
};

texture2D _RenderTemporary2 < pooled = true; >
{
    Width = BUFFER_WIDTH / 4;
    Height = BUFFER_HEIGHT / 4;
    Format = RG16F;
};

texture2D _RenderTemporary3 < pooled = true; >
{
    Width = BUFFER_WIDTH / 8;
    Height = BUFFER_HEIGHT / 8;
    Format = RG16F;
};

texture2D _RenderTemporary4 < pooled = true; >
{
    Width = BUFFER_WIDTH / 16;
    Height = BUFFER_HEIGHT / 16;
    Format = RG16F;
};

texture2D _RenderTemporary5 < pooled = true; >
{
    Width = BUFFER_WIDTH / 32;
    Height = BUFFER_HEIGHT / 32;
    Format = RG16F;
};

texture2D _RenderTemporary6 < pooled = true; >
{
    Width = BUFFER_WIDTH / 64;
    Height = BUFFER_HEIGHT / 64;
    Format = RG16F;
};

texture2D _RenderTemporary7 < pooled = true; >
{
    Width = BUFFER_WIDTH / 128;
    Height = BUFFER_HEIGHT / 128;
    Format = RG16F;
};

texture2D _RenderTemporary8 < pooled = true; >
{
    Width = BUFFER_WIDTH / 256;
    Height = BUFFER_HEIGHT / 256;
    Format = RG16F;
};

namespace MotionBlur
{
    //Shader properties

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
    > = 1.5;

    uniform float _MipBias <
        ui_type = "slider";
        ui_label = "Mipmap Bias";
        ui_tooltip = "Higher = Less spatial noise";
        ui_min = 0.0;
        ui_max = 8.0;
    > = 5.5;

    uniform float _Blend <
        ui_type = "slider";
        ui_label = "Temporal Blending";
        ui_tooltip = "Higher = Less temporal noise";
        ui_min = 0.0;
        ui_max = 0.5;
    > = 0.1;

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

    // Textures and samplers

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
        Texture = _RenderTemporary1a;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SampleTemporary1b
    {
        Texture = _RenderTemporary1b;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SampleTemporary1c
    {
        Texture = _RenderTemporary1c;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderTemporary1d
    {
        Width = BUFFER_WIDTH / 2;
        Height = BUFFER_HEIGHT / 2;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D _SampleTemporary1d
    {
        Texture = _RenderTemporary1d;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SampleTemporary8
    {
        Texture = _RenderTemporary8;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SampleTemporary7
    {
        Texture = _RenderTemporary7;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SampleTemporary6
    {
        Texture = _RenderTemporary6;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SampleTemporary5
    {
        Texture = _RenderTemporary5;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SampleTemporary4
    {
        Texture = _RenderTemporary4;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SampleTemporary3
    {
        Texture = _RenderTemporary3;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D _SampleTemporary2
    {
        Texture = _RenderTemporary2;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderTemporary1e
    {
        Width = BUFFER_WIDTH / 2;
        Height = BUFFER_HEIGHT / 2;
        Format = RG16F;
    };

    sampler2D _SampleTemporary1e
    {
        Texture = _RenderTemporary1e;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    #if RENDER_VELOCITY_STREAMS
        texture2D _RenderLines
        {
            Width = BUFFER_WIDTH;
            Height = BUFFER_HEIGHT;
            Format = RGBA8;
        };

        sampler2D _SampleLines
        {
            Texture = _RenderLines;
            MagFilter = LINEAR;
            MinFilter = LINEAR;
            MipFilter = LINEAR;
        };
    #endif

    sampler2D _SampleColorGamma
    {
        Texture = _RenderColor;
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
        DownsampleVS(ID, 1.0 / uint2(ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -1.0)), Position, DownsampleCoords);
    }

    void Downsample2VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 DownsampleCoords[4] : TEXCOORD0)
    {
        DownsampleVS(ID, 1.0 / uint2(ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -2.0)), Position, DownsampleCoords);
    }

    void Downsample3VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 DownsampleCoords[4] : TEXCOORD0)
    {
        DownsampleVS(ID, 1.0 / uint2(ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -3.0)), Position, DownsampleCoords);
    }

    void Upsample2VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        UpsampleVS(ID, 1.0 / uint2(ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -3.0)), Position, UpsampleCoords);
    }

    void Upsample1VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        UpsampleVS(ID, 1.0 / uint2(ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -2.0)), Position, UpsampleCoords);
    }

    void Upsample0VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 UpsampleCoords[3] : TEXCOORD0)
    {
        UpsampleVS(ID, 1.0 / uint2(ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -1.0)), Position, UpsampleCoords);
    }

    void DerivativesVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        const float2 PixelSize = 1.0 / uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2);
        Offsets = TexCoord0.xyxy + (float4(0.5, 0.5, -0.5, -0.5) * PixelSize.xyxy);
    }

    void EstimateVS(in uint ID, in float2 PixelSize, out float4 Position, out float4 TentFilterOffsets[3])
    {
        float2 TexCoord0 = 0.0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, PixelSize, TentFilterOffsets);
    }

    void EstimateLevel7VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / uint2(ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -7.0)), Position, Offsets);
    }

    void EstimateLevel6VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / uint2(ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -6.0)), Position, Offsets);
    }

    void EstimateLevel5VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / uint2(ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -5.0)), Position, Offsets);
    }

    void EstimateLevel4VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / uint2(ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -4.0)), Position, Offsets);
    }

    void EstimateLevel3VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / uint2(ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -3.0)), Position, Offsets);
    }

    void EstimateLevel2VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / uint2(ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -2.0)), Position, Offsets);
    }

    void EstimateLevel1VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / uint2(ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -1.0)), Position, Offsets);
    }

    // Pixel shaders

    float4 DownsamplePS(sampler2D Source, float4 TexCoord[4])
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

    float4 UpsamplePS(sampler2D Source, float4 Offsets[3])
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
        const float Alpha = max(ldexp(_Constraint * 1e-5, Level - MaxLevel), 1e-7);
        float2 Iz = tex2D(_SampleTemporary1b, TexCoord).rg;
        float2 Ix = tex2D(_SampleTemporary1c, TexCoord).rg;
        float2 Iy = tex2D(_SampleTemporary1d, TexCoord).rg;

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
        const float Minima = ldexp(1.0, -8.0);
        float3 Color = max(tex2D(_SampleColor, TexCoord).rgb, Minima);
        OutputColor0 = saturate(Color.xy / dot(Color, 1.0));
    }

    void PreDownsample1PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = DownsamplePS(_SampleTemporary1a, TexCoord);
    }

    void PreDownsample2PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = DownsamplePS(_SampleTemporary2, TexCoord);
    }

    void PreDownsample3PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = DownsamplePS(_SampleTemporary3, TexCoord);
    }

    void PreUpsample2PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = UpsamplePS(_SampleTemporary4, TexCoord);
    }

    void PreUpsample1PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = UpsamplePS(_SampleTemporary3, TexCoord);
    }

    void PreUpsample0PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = UpsamplePS(_SampleTemporary2, TexCoord);
    }

    void DerivativesZPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        float2 CurrentFrame = tex2D(_SampleTemporary1a, TexCoord).xy;
        float2 PreviousFrame = tex2D(_SampleTemporary1d, TexCoord).xy;
        OutputColor0 = CurrentFrame - PreviousFrame;
    }

    void DerivativesXYPS(in float4 Position : SV_Position, in float4 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0, out float2 OutputColor1 : SV_Target1)
    {
        float2 Sample0 = tex2D(_SampleTemporary1a, TexCoord.zy).xy; // (-x, +y)
        float2 Sample1 = tex2D(_SampleTemporary1a, TexCoord.xy).xy; // (+x, +y)
        float2 Sample2 = tex2D(_SampleTemporary1a, TexCoord.zw).xy; // (-x, -y)
        float2 Sample3 = tex2D(_SampleTemporary1a, TexCoord.xw).xy; // (+x, -y)
        OutputColor0 = ((Sample3 + Sample1) - (Sample2 + Sample0)) * 4.0;
        OutputColor1 = ((Sample2 + Sample3) - (Sample0 + Sample1)) * 4.0;
    }

    void EstimateLevel8PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, 0.0, 7.0, OutputEstimation);
    }

    void EstimateLevel7PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, UpsamplePS(_SampleTemporary8, UpsampleOffsets).xy, 6.0, OutputEstimation);
    }

    void EstimateLevel6PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, UpsamplePS(_SampleTemporary7, UpsampleOffsets).xy, 5.0, OutputEstimation);
    }

    void EstimateLevel5PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, UpsamplePS(_SampleTemporary6, UpsampleOffsets).xy, 4.0, OutputEstimation);
    }

    void EstimateLevel4PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, UpsamplePS(_SampleTemporary5, UpsampleOffsets).xy, 3.0, OutputEstimation);
    }

    void EstimateLevel3PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, UpsamplePS(_SampleTemporary4, UpsampleOffsets).xy, 2.0, OutputEstimation);
    }

    void EstimateLevel2PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, UpsamplePS(_SampleTemporary3, UpsampleOffsets).xy, 1.0, OutputEstimation);
    }

    void EstimateLevel1PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float4 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, UpsamplePS(_SampleTemporary2, UpsampleOffsets).xy, 0.0, OutputEstimation.xy);
        OutputEstimation.ba = (0.0, _Blend);
    }

    void PostDownsample1PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = DownsamplePS(_SampleTemporary1e, TexCoord);
    }

    void PostDownsample2PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = DownsamplePS(_SampleTemporary2, TexCoord);
    }

    void PostDownsample3PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = DownsamplePS(_SampleTemporary3, TexCoord);
    }

    void PostUpsample2PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = UpsamplePS(_SampleTemporary4, TexCoord);
    }

    void PostUpsample1PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = UpsamplePS(_SampleTemporary3, TexCoord);
    }

    void PostUpsample0PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0, out float4 OutputColor1 : SV_Target1)
    {
        OutputColor0 = UpsamplePS(_SampleTemporary2, TexCoord);

        // Copy current convolved result to use at next frame
        OutputColor1 = tex2D(_SampleTemporary1a, TexCoord[1].xz).rg;
    }

    void MotionBlurPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
    {
        const int Samples = 4;
        const float2 PixelSize = 1.0 / uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT /2);

        float Noise = frac(52.9829189 * frac(dot(Position.xy, float2(0.06711056, 0.00583715))));
        float FrameTimeRatio = _TargetFrameRate / (1e+3 / _FrameTime);

        float2 Velocity = (tex2Dlod(_SampleTemporary1b, float4(TexCoord, 0.0, _MipBias)).xy * PixelSize) * _Scale;

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
            RenderTarget0 = _RenderTemporary1a;
        }

        // Pre-process dual-filter blur

        pass
        {
            VertexShader = Downsample1VS;
            PixelShader = PreDownsample1PS;
            RenderTarget0 = _RenderTemporary2;
        }

        pass
        {
            VertexShader = Downsample2VS;
            PixelShader = PreDownsample2PS;
            RenderTarget0 = _RenderTemporary3;
        }

        pass
        {
            VertexShader = Downsample3VS;
            PixelShader = PreDownsample3PS;
            RenderTarget0 = _RenderTemporary4;
        }

        pass
        {
            VertexShader = Upsample2VS;
            PixelShader = PreUpsample2PS;
            RenderTarget0 = _RenderTemporary3;
        }

        pass
        {
            VertexShader = Upsample1VS;
            PixelShader = PreUpsample1PS;
            RenderTarget0 = _RenderTemporary2;
        }

        pass
        {
            VertexShader = Upsample0VS;
            PixelShader = PreUpsample0PS;
            RenderTarget0 = _RenderTemporary1a;
        }

        // Construct pyramids

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = DerivativesZPS;
            RenderTarget0 = _RenderTemporary1b;
        }

        pass
        {
            VertexShader = DerivativesVS;
            PixelShader = DerivativesXYPS;
            RenderTarget0 = _RenderTemporary1c;
            RenderTarget1 = _RenderTemporary1d;
        }

        // Pyramidal estimation

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel8PS;
            RenderTarget0 = _RenderTemporary8;
        }

        pass
        {
            VertexShader = EstimateLevel7VS;
            PixelShader = EstimateLevel7PS;
            RenderTarget0 = _RenderTemporary7;
        }

        pass
        {
            VertexShader = EstimateLevel6VS;
            PixelShader = EstimateLevel6PS;
            RenderTarget0 = _RenderTemporary6;
        }

        pass
        {
            VertexShader = EstimateLevel5VS;
            PixelShader = EstimateLevel5PS;
            RenderTarget0 = _RenderTemporary5;
        }

        pass
        {
            VertexShader = EstimateLevel4VS;
            PixelShader = EstimateLevel4PS;
            RenderTarget0 = _RenderTemporary4;
        }

        pass
        {
            VertexShader = EstimateLevel3VS;
            PixelShader = EstimateLevel3PS;
            RenderTarget0 = _RenderTemporary3;
        }

        pass
        {
            VertexShader = EstimateLevel2VS;
            PixelShader = EstimateLevel2PS;
            RenderTarget0 = _RenderTemporary2;
        }

        pass
        {
            VertexShader = EstimateLevel1VS;
            PixelShader = EstimateLevel1PS;
            RenderTarget0 = _RenderTemporary1e;
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
            RenderTarget0 = _RenderTemporary2;
        }

        pass
        {
            VertexShader = Downsample2VS;
            PixelShader = PostDownsample2PS;
            RenderTarget0 = _RenderTemporary3;
        }

        pass
        {
            VertexShader = Downsample3VS;
            PixelShader = PostDownsample3PS;
            RenderTarget0 = _RenderTemporary4;
        }

        pass
        {
            VertexShader = Upsample2VS;
            PixelShader = PostUpsample2PS;
            RenderTarget0 = _RenderTemporary3;
        }

        pass
        {
            VertexShader = Upsample1VS;
            PixelShader = PostUpsample1PS;
            RenderTarget0 = _RenderTemporary2;
        }

        pass
        {
            VertexShader = Upsample0VS;
            PixelShader = PostUpsample0PS;
            RenderTarget0 = _RenderTemporary1b;

            // Copy previous frame
            RenderTarget1 = _RenderTemporary1d;
        }

        // Render result

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
