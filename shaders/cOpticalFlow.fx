
/*
    Optical flow visualization

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

    uniform float _Blend <
        ui_type = "slider";
        ui_category = "Optical flow";
        ui_label = "Blending";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.8;

    uniform float _Constraint <
        ui_type = "drag";
        ui_category = "Optical flow";
        ui_label = "Constraint";
        ui_tooltip = "Higher = Smoother flow";
    > = 1.0;

    uniform float _MipBias  <
        ui_type = "drag";
        ui_category = "Optical flow";
        ui_label = "Mipmap bias";
        ui_tooltip = "Higher = Less spatial noise";
    > = 0.0;

    uniform bool _NormalizedShading <
        ui_type = "radio";
        ui_category = "Velocity shading";
        ui_label = "Normalize velocity shading";
    > = true;

    uniform float3 _BaseColorShift <
        ui_type = "color";
        ui_category = "Velocity streaming";
        ui_label = "Background color shift";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.0;

    uniform float3 _LineColorShift <
        ui_type = "color";
        ui_category = "Velocity streaming";
        ui_label = "Line color shifting";
    > = 1.0;

    uniform float _LineOpacity <
        ui_type = "slider";
        ui_category = "Velocity streaming";
        ui_label = "Line opacity";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 1.0;

    uniform bool _BackgroundColor <
        ui_type = "radio";
        ui_category = "Velocity streaming";
        ui_label = "Plain base color";
    > = false;

    uniform bool _NormalDirection <
        ui_type = "radio";
        ui_category = "Velocity streaming";
        ui_label = "Normalize direction";
        ui_tooltip = "Normalize direction";
    > = false;

    uniform bool _ScaleLineVelocity <
        ui_type = "radio";
        ui_category = "Velocity streaming";
        ui_label = "Scale velocity color";
    > = false;

    #ifndef RENDER_VELOCITY_STREAMS
        #define RENDER_VELOCITY_STREAMS 1
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

    // Textures and samplers

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

    texture2D RenderCommon1d
    {
        Width = BUFFER_WIDTH / 2;
        Height = BUFFER_HEIGHT / 2;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D SampleCommon_RG16F_1d
    {
        Texture = RenderCommon1d;
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

    texture2D RenderCommon1e
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = RG16F;
    };

    sampler2D SampleCommon_RG16F_1e
    {
        Texture = RenderCommon1e;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    #if RENDER_VELOCITY_STREAMS
        texture2D RenderLines
        {
            Width = BUFFER_WIDTH;
            Height = BUFFER_HEIGHT;
            Format = RGBA8;
        };

        sampler2D SampleLines
        {
            Texture = RenderLines;
            MagFilter = LINEAR;
            MinFilter = LINEAR;
            MipFilter = LINEAR;
        };
    #endif

    sampler2D SampleColorGamma
    {
        Texture = RenderColor;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
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

    void DownsampleOffsets(in float2 TexCoord, in float2 PixelSize, inout float4 SampleOffsets[4])
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

    void UpsampleOffsets(in float2 TexCoord, in float2 PixelSize, inout float4 SampleOffsets[3])
    {
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        SampleOffsets[0] = TexCoord.xyyy + (float4(-2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);
        SampleOffsets[1] = TexCoord.xyyy + (float4(0.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);
        SampleOffsets[2] = TexCoord.xyyy + (float4(2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy);
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

    void DownsampleVS(in uint ID, in float2 PixelSize, inout float4 Position, inout float4 Offsets[4])
    {
        float2 TexCoord0 = 0.0;
        PostProcessVS(ID, Position, TexCoord0);
        DownsampleOffsets(TexCoord0, PixelSize, Offsets);
    }

    void UpsampleVS(in uint ID, in float2 PixelSize, inout float4 Position, inout float4 Offsets[3])
    {
        float2 TexCoord0 = 0.0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, PixelSize, Offsets);
    }

    void Downsample2VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 DownsampleCoords[4] : TEXCOORD0)
    {
        DownsampleVS(ID, 1.0 / BUFFER_SIZE_1, Position, DownsampleCoords);
    }

    void Downsample3VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 DownsampleCoords[4] : TEXCOORD0)
    {
        DownsampleVS(ID, 1.0 / BUFFER_SIZE_2, Position, DownsampleCoords);
    }

    void Downsample4VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 DownsampleCoords[4] : TEXCOORD0)
    {
        DownsampleVS(ID, 1.0 / BUFFER_SIZE_3, Position, DownsampleCoords);
    }

    void Upsample3VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoord[3] : TEXCOORD0)
    {
        UpsampleVS(ID, 1.0 / BUFFER_SIZE_3, Position, TexCoord);
    }

    void Upsample2VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoord[3] : TEXCOORD0)
    {
        UpsampleVS(ID, 1.0 / BUFFER_SIZE_2, Position, TexCoord);
    }

    void Upsample1VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoord[3] : TEXCOORD0)
    {
        UpsampleVS(ID, 1.0 / BUFFER_SIZE_1, Position, TexCoord);
    }

    void DerivativesVS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[2] : TEXCOORD0)
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        const float2 PixelSize = 1.0 / BUFFER_SIZE_1;
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
        TexCoords[4].xyz = TexCoord.xyy + (float3(0.0, 4.0, -4.0) * PixelSize.xxy);
    }

    void EstimateVS(in uint ID, in float2 PixelSize, inout float4 Position, inout float4 TexCoords[5])
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        GradientsVS(VSTexCoord, PixelSize, TexCoords);
    }

    void EstimateLevel7VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / BUFFER_SIZE_7, Position, TexCoords);
    }

    void EstimateLevel6VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / BUFFER_SIZE_6, Position, TexCoords);
    }

    void EstimateLevel5VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / BUFFER_SIZE_5, Position, TexCoords);
    }

    void EstimateLevel4VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / BUFFER_SIZE_4, Position, TexCoords);
    }

    void EstimateLevel3VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / BUFFER_SIZE_3, Position, TexCoords);
    }

    void EstimateLevel2VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / BUFFER_SIZE_2, Position, TexCoords);
    }

    void EstimateLevel1VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[5] : TEXCOORD0)
    {
        EstimateVS(ID, 1.0 / BUFFER_SIZE_1, Position, TexCoords);
    }

    void VelocityStreamsVS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float2 Velocity : TEXCOORD0)
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
        float2 VelocityCoord;
        VelocityCoord.xy = Origin.xy * PixelSize.xy;
        VelocityCoord.y = 1.0 - VelocityCoord.y;
        Velocity = tex2Dlod(SampleCommon_RGBA16F_1a, float4(VelocityCoord, 0.0, _MipBias)).xy;

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
        Color = saturate(Color / dot(Color.rgb, 1.0));
        return saturate(Color / max(max(Color.r, Color.g), Color.b));
    }

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
        const float Alpha = max(ldexp(_Constraint * 1e-3, Level - MaxLevel), 1e-7);

        float2 CurrentFrame = tex2D(SampleCommon_RG16F_1a, TexCoord).xy;
        float2 PreviousFrame = tex2D(SampleCommon_RG16F_1d, TexCoord).xy;

        // SpatialI = <Rx, Gx, Ry, Gy>
        float4 IxyRG = tex2D(SampleCommon_RGBA16F_1a, TexCoord);
        float2 IzRG = CurrentFrame - PreviousFrame;

        // Ix2 = 1.0 / (Rx^2 + Gx^2 + a)
        // Iy2 = 1.0 / (Ry^2 + Gy^2 + a)
        // Ixy = Rxy + Gxy
        float Ix2 = 1.0 / (dot(IxyRG.xy, IxyRG.xy) + Alpha);
        float Iy2 = 1.0 / (dot(IxyRG.zw, IxyRG.zw) + Alpha);
        float Ixy = dot(IxyRG.xy, IxyRG.zw);

        // Ixt = Rxt + Gxt
        // Iyt = Ryt + Gyt
        float Ixt = dot(IxyRG.xy, IzRG);
        float Iyt = dot(IxyRG.zw, IzRG);

        // Symmetric Gauss-Seidel (forward sweep, from 1...N)
        DUV.x = Ix2 * (-(DUV.y * Ixy) - Ixt);
        DUV.y = Iy2 * (-(DUV.x * Ixy) - Iyt);

        // Symmetric Gauss-Seidel (backward sweep, from N...1)
        DUV.y = Iy2 * (-(DUV.x * Ixy) - Iyt);
        DUV.x = Ix2 * (-(DUV.y * Ixy) - Ixt);
    }

    void OpticalFlowTV(in sampler2D Source, in float4 TexCoords[5], in float Level, out float2 DUV)
    {
        // Calculate TV
        const float E = 1e-3;
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

        // Center gradient
        GradUV.xy = D1 - B1; // <IxU, IxV>
        GradUV.zw = C1 - C3; // <IyU, IyV>
        SqGradUV = dot(GradUV.xzyw, GradUV.xzyw) * 0.25;
        Smoothness0 = rsqrt(SqGradUV + E * E);

        // Right gradient
        GradUV.xy = E0 - C2; // <IxU, IxV>
        GradUV.zw = D0 - D2; // <IyU, IyV>
        SqGradUV = dot(GradUV.xzyw, GradUV.xzyw) * 0.25;
        Smoothness1[0] = rsqrt(SqGradUV + E * E);

        // Left gradient
        GradUV.xy = C2 - A0; // <IxU, IxV>
        GradUV.zw = B0 - B2; // <IyU, IyV>
        SqGradUV = dot(GradUV.xzyw, GradUV.xzyw) * 0.25;
        Smoothness1[1] = rsqrt(SqGradUV + E * E);

        // Top gradient
        GradUV.xy = D0 - B0; // <IxU, IxV>
        GradUV.zw = C0 - C2; // <IyU, IyV>
        SqGradUV = dot(GradUV.xzyw, GradUV.xzyw) * 0.25;
        Smoothness1[2] = rsqrt(SqGradUV + E * E);

        // Bottom gradient
        GradUV.xy = D2 - B2; // <IxU, IxV>
        GradUV.zw = C2 - C4; // <IyU, IyV>
        SqGradUV = dot(GradUV.xzyw, GradUV.xzyw) * 0.25;
        Smoothness1[3] = rsqrt(SqGradUV + E * E);

        float4 Gradients = 0.5 * (Smoothness0 + Smoothness1.xyzw);

        // Calculate optical flow
        const float Alpha = max(ldexp(_Constraint * 1e-3, Level - MaxLevel), 1e-7);

        float2 CurrentFrame = tex2D(SampleCommon_RG16F_1a, TexCoords[1].xz).xy;
        float2 PreviousFrame = tex2D(SampleCommon_RG16F_1d, TexCoords[1].xz).xy;

        // IxyRG = <Rx, Gx, Ry, Gy>
        float4 IxyRG = tex2D(SampleCommon_RGBA16F_1a, TexCoords[1].xz);
        // ItRG = <Rt, Gt>
        float2 IzRG = CurrentFrame - PreviousFrame;
        
        float C = 0.0;
        C = dot(IxyRG.xyzw, C2.xxyy) + dot(IzRG, 1.0);
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

        float2 Aii = 0.0;
        float2 Bi = 0.0;

        Aii.x = 1.0 / (dot(Gradients, 1.0) * Alpha + I2.x);
        Aii.y = 1.0 / (dot(Gradients, 1.0) * Alpha + I2.y);
        Bi = Alpha * ((Gradients[0] * D1) + (Gradients[1] * B1) + (Gradients[2] * C1) + (Gradients[3] * C3));
        DUV.x = Aii.x * (Bi.x - (I2.z * C2.y) - It.x);
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

    void PreDownsample2PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = DownsamplePS(SampleCommon_RG16F_1a, TexCoord);
    }

    void PreDownsample3PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = DownsamplePS(SampleCommon_RG16F_2, TexCoord);
    }

    void PreDownsample4PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = DownsamplePS(SampleCommon_RG16F_3, TexCoord);
    }

    void PreUpsample3PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = UpsamplePS(SampleCommon_RG16F_4, TexCoord);
    }

    void PreUpsample2PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = UpsamplePS(SampleCommon_RG16F_3, TexCoord);
    }

    void PreUpsample1PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = UpsamplePS(SampleCommon_RG16F_2, TexCoord);
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
        OutputColor0.xy = ((B2 + A2 + B0 + C1) - (B1 + A0 + A2 + C0)) / 12.0;

        //    +1 +2 +1
        // +1 +2 +2 +2 +1
        //  0  0  0  0  0
        // -1 -2 -2 -2 -1
        //    -1 -2 -1
        OutputColor0.zw = ((A0 + B1 + B2 + A1) - (A2 + C0 + C1 + B0)) / 12.0;
    }

    void EstimateLevel8PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowCoarse(TexCoord, 7.0, OutputColor0);
    }

    void EstimateLevel7PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_8, TexCoords, 6.0, OutputColor0);
    }

    void EstimateLevel6PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_7, TexCoords, 5.0, OutputColor0);
    }

    void EstimateLevel5PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_6, TexCoords, 4.0, OutputColor0);
    }

    void EstimateLevel4PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_5, TexCoords, 3.0, OutputColor0);
    }

    void EstimateLevel3PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_4, TexCoords, 2.0, OutputColor0);
    }

    void EstimateLevel2PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_3, TexCoords, 1.0, OutputColor0);
    }

    void EstimateLevel1PS(in float4 Position : SV_Position, in float4 TexCoords[5] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OpticalFlowTV(SampleCommon_RG16F_2, TexCoords, 0.0, OutputColor0.xy);
        OutputColor0.xy *= float2(1.0, -1.0);
        OutputColor0.ba = (0.0, _Blend);
    }

    void PostDownsample2PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = DownsamplePS(SampleCommon_RG16F_1e, TexCoord);
    }

    void PostDownsample3PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = DownsamplePS(SampleCommon_RG16F_2, TexCoord);
    }

    void PostDownsample4PS(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = DownsamplePS(SampleCommon_RG16F_3, TexCoord);
    }

    void PostUpsample3PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = UpsamplePS(SampleCommon_RG16F_4, TexCoord);
    }

    void PostUpsample2PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = UpsamplePS(SampleCommon_RG16F_3, TexCoord);
    }

    void PostUpsample1PS(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0, out float4 OutputColor1 : SV_Target1)
    {
        OutputColor0 = UpsamplePS(SampleCommon_RG16F_2, TexCoord);

        // Copy current convolved result to use at next frame
        OutputColor1 = tex2D(SampleCommon_RG16F_1a, TexCoord[1].xz).rg;
    }

    void VelocityShadingPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
    {
        float2 Velocity = tex2Dlod(SampleCommon_RGBA16F_1a, float4(TexCoord, 0.0, _MipBias)).xy;

        if(_NormalizedShading)
        {
            float VelocityLength = saturate(rsqrt(dot(Velocity, Velocity)));
            OutputColor0.rg = (Velocity * VelocityLength) * 0.5 + 0.5;
            OutputColor0.b = -dot(OutputColor0.rg, 1.0) * 0.5 + 1.0;
            OutputColor0.a = 1.0;
        }
        else
        {
            OutputColor0 = float4(Velocity, 0.0, 1.0);
        }
    }

    #if RENDER_VELOCITY_STREAMS
        void VelocityStreamsPS(in float4 Position : SV_Position, in float2 Velocity : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
        {
            OutputColor0.rg = (_ScaleLineVelocity) ? (Velocity.xy / (length(Velocity) * VELOCITY_SCALE * 0.05)) : normalize(Velocity.xy);
            OutputColor0.rg = OutputColor0.xy * 0.5 + 0.5;
            OutputColor0.b = -dot(OutputColor0.rg, 1.0) * 0.5 + 1.0;
            OutputColor0.a = 1.0;
        }

        void VelocityStreamsDisplayPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float3 OutputColor0 : SV_Target0)
        {
            float4 Lines = tex2D(SampleLines, TexCoord);
            float3 MainColor = (_BackgroundColor) ? _BaseColorShift : tex2D(SampleColorGamma, TexCoord).rgb * _BaseColorShift;
            OutputColor0 = lerp(MainColor, Lines.rgb * _LineColorShift, Lines.aaa * _LineOpacity);
        }
    #endif

    technique cOpticalFlow
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
            VertexShader = Downsample2VS;
            PixelShader = PreDownsample2PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon2;
        }

        pass
        {
            VertexShader = Downsample3VS;
            PixelShader = PreDownsample3PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon3;
        }

        pass
        {
            VertexShader = Downsample4VS;
            PixelShader = PreDownsample4PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon4;
        }

        pass
        {
            VertexShader = Upsample3VS;
            PixelShader = PreUpsample3PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon3;
        }

        pass
        {
            VertexShader = Upsample2VS;
            PixelShader = PreUpsample2PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon2;
        }

        pass
        {
            VertexShader = Upsample1VS;
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
            VertexShader = EstimateLevel7VS;
            PixelShader = EstimateLevel7PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon7;
        }

        pass
        {
            VertexShader = EstimateLevel6VS;
            PixelShader = EstimateLevel6PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon6;
        }

        pass
        {
            VertexShader = EstimateLevel5VS;
            PixelShader = EstimateLevel5PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon5;
        }

        pass
        {
            VertexShader = EstimateLevel4VS;
            PixelShader = EstimateLevel4PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon4;
        }

        pass
        {
            VertexShader = EstimateLevel3VS;
            PixelShader = EstimateLevel3PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon3;
        }

        pass
        {
            VertexShader = EstimateLevel2VS;
            PixelShader = EstimateLevel2PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon2;
        }

        pass
        {
            VertexShader = EstimateLevel1VS;
            PixelShader = EstimateLevel1PS;
            RenderTarget0 = RenderCommon1e;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        // Post-process dual-filter blur

        pass
        {
            VertexShader = Downsample2VS;
            PixelShader = PostDownsample2PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon2;
        }

        pass
        {
            VertexShader = Downsample3VS;
            PixelShader = PostDownsample3PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon3;
        }

        pass
        {
            VertexShader = Downsample4VS;
            PixelShader = PostDownsample4PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon4;
        }

        pass
        {
            VertexShader = Upsample3VS;
            PixelShader = PostUpsample3PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon3;
        }

        pass
        {
            VertexShader = Upsample2VS;
            PixelShader = PostUpsample2PS;
            RenderTarget0 = SharedResources::RG16F::RenderCommon2;
        }

        pass
        {
            VertexShader = Upsample1VS;
            PixelShader = PostUpsample1PS;
            RenderTarget0 = SharedResources::RGBA16F::RenderCommon1;

            // Copy previous frame
            RenderTarget1 = RenderCommon1d;
        }

        // Render result

        #if RENDER_VELOCITY_STREAMS
            // Render to a fullscreen buffer (cringe!)
            pass
            {
                PrimitiveTopology = LINELIST;
                VertexCount = NUM_LINES * 2;
                VertexShader = VelocityStreamsVS;
                PixelShader = VelocityStreamsPS;
                ClearRenderTargets = TRUE;
                RenderTarget0 = RenderLines;
            }

            pass
            {
                VertexShader = PostProcessVS;
                PixelShader = VelocityStreamsDisplayPS;
                ClearRenderTargets = FALSE;
            }
        #else
            pass
            {
                VertexShader = PostProcessVS;
                PixelShader = VelocityShadingPS;
            }
        #endif
    }
}
