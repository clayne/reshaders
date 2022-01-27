
/*
    Optical flow visualization

    BSD 3-Clause License

    Copyright (c) 2022, brimson
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

namespace PyramidalHornSchunck
{
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
        #define VERTEX_SPACING 16
    #endif

    #ifndef VELOCITY_SCALE_FACTOR
        #define VELOCITY_SCALE_FACTOR 16
    #endif

    #define LINES_X uint(BUFFER_WIDTH / VERTEX_SPACING)
    #define LINES_Y uint(BUFFER_HEIGHT / VERTEX_SPACING)
    #define NUM_LINES (LINES_X * LINES_Y)
    #define SPACE_X (BUFFER_WIDTH / LINES_X)
    #define SPACE_Y (BUFFER_HEIGHT / LINES_Y)
    #define VELOCITY_SCALE (SPACE_X + SPACE_Y) * VELOCITY_SCALE_FACTOR

    texture2D _RenderColor : COLOR;

    sampler2D _SampleColor
    {
        Texture = _RenderColor;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBTexture = TRUE;
        #endif
    };

    texture2D _RenderData0
    {
        Width = BUFFER_WIDTH / 2;
        Height = BUFFER_HEIGHT / 2;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D _SampleData0
    {
        Texture = _RenderData0;
    };

    texture2D _RenderData1
    {
        Width = BUFFER_WIDTH / 2;
        Height = BUFFER_HEIGHT / 2;
        Format = RGBA16F;
        MipLevels = 8;
    };

    sampler2D _SampleData1
    {
        Texture = _RenderData1;
    };

    texture2D _RenderData2
    {
        Width = BUFFER_WIDTH / 2;
        Height = BUFFER_HEIGHT / 2;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D _SampleData2
    {
        Texture = _RenderData2;
    };

    texture2D _RenderLevel7
    {
        Width = BUFFER_WIDTH / 256;
        Height = BUFFER_HEIGHT / 256;
        Format = RG16F;
    };

    sampler2D _SampleLevel7
    {
        Texture = _RenderLevel7;
    };

    texture2D _RenderLevel6
    {
        Width = BUFFER_WIDTH / 128;
        Height = BUFFER_HEIGHT / 128;
        Format = RG16F;
    };

    sampler2D _SampleLevel6
    {
        Texture = _RenderLevel6;
    };

    texture2D _RenderLevel5
    {
        Width = BUFFER_WIDTH / 64;
        Height = BUFFER_HEIGHT / 64;
        Format = RG16F;
    };

    sampler2D _SampleLevel5
    {
        Texture = _RenderLevel5;
    };

    texture2D _RenderLevel4
    {
        Width = BUFFER_WIDTH / 32;
        Height = BUFFER_HEIGHT / 32;
        Format = RG16F;
    };

    sampler2D _SampleLevel4
    {
        Texture = _RenderLevel4;
    };

    texture2D _RenderLevel3
    {
        Width = BUFFER_WIDTH / 16;
        Height = BUFFER_HEIGHT / 16;
        Format = RG16F;
    };

    sampler2D _SampleLevel3
    {
        Texture = _RenderLevel3;
    };

    texture2D _RenderLevel2
    {
        Width = BUFFER_WIDTH / 8;
        Height = BUFFER_HEIGHT / 8;
        Format = RG16F;
    };

    sampler2D _SampleLevel2
    {
        Texture = _RenderLevel2;
    };

    texture2D _RenderLevel1
    {
        Width = BUFFER_WIDTH / 4;
        Height = BUFFER_HEIGHT / 4;
        Format = RG16F;
    };

    sampler2D _SampleLevel1
    {
        Texture = _RenderLevel1;
    };

    texture2D _RenderLevel0
    {
        Width = BUFFER_WIDTH / 2;
        Height = BUFFER_HEIGHT / 2;
        Format = RG16F;
    };

    sampler2D _SampleLevel0
    {
        Texture = _RenderLevel0;
    };

    texture2D _RenderLines
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
    };

    sampler2D _SampleLines
    {
        Texture = _RenderLines;
    };

    sampler2D _SampleColorGamma
    {
        Texture = _RenderColor;
    };

    // Vertex shaders

    static const float SampleOffsets[8] =
    {
        0.0,
        1.4850044983805901,
        3.4650570548417856,
        5.4452207648927855,
        7.425557483188341,
        9.406126897065857,
        11.386985823860664,
        13.368187582263898
    };

    void BlurOffsets(in float2 TexCoord, in float2 PixelSize, out float4 Offsets[7])
    {
        int OffsetIndex = 0;
        int SampleIndex = 1;

        while(OffsetIndex < 7)
        {
            Offsets[OffsetIndex].xy = TexCoord.xy - (SampleOffsets[SampleIndex] * PixelSize.xy);
            Offsets[OffsetIndex].zw = TexCoord.xy + (SampleOffsets[SampleIndex] * PixelSize.xy);
            OffsetIndex = OffsetIndex + 1;
            SampleIndex = SampleIndex + 1;
        }
    }

    void UpsampleOffsets(in float2 TexCoord, in float2 PixelSize, out float4 SampleOffsets[3])
    {
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        SampleOffsets[0] = TexCoord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
        SampleOffsets[1] = TexCoord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
        SampleOffsets[2] = TexCoord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * PixelSize.xyyy);
    }

    void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
    {
        TexCoord.x = (ID == 2) ? 2.0 : 0.0;
        TexCoord.y = (ID == 1) ? 2.0 : 0.0;
        Position = TexCoord.xyxy * float4(2.0, -2.0, 0.0, 0.0) + float4(-1.0, 1.0, 0.0, 1.0);
    }

    void HorizontalBlurVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0, out float4 Offsets[7] : TEXCOORD1)
    {
        PostProcessVS(ID, Position, TexCoord);
        BlurOffsets(TexCoord, float2(2.0 / BUFFER_WIDTH, 0.0), Offsets);
    }

    void VerticalBlurVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0, out float4 Offsets[7] : TEXCOORD1)
    {
        PostProcessVS(ID, Position, TexCoord);
        BlurOffsets(TexCoord, float2(0.0, 2.0 / BUFFER_HEIGHT), Offsets);
    }

    void DerivativesVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets : TEXCOORD0)
    {
        const float2 PixelSize = 0.5 / float2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2);
        const float4 PixelOffset = float4(PixelSize, -PixelSize);
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        Offsets = TexCoord0.xyxy + PixelOffset;
    }

    void EstimateLevel6VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -8.0), Offsets);
    }

    void EstimateLevel5VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -7.0), Offsets);
    }

    void EstimateLevel4VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -6.0), Offsets);
    }

    void EstimateLevel3VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -5.0), Offsets);
    }

    void EstimateLevel2VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -4.0), Offsets);
    }

    void EstimateLevel1VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -3.0), Offsets);
    }

    void EstimateLevel0VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets[3] : TEXCOORD0)
    {
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        UpsampleOffsets(TexCoord0, 1.0 / ldexp(float2(BUFFER_WIDTH, BUFFER_HEIGHT), -2.0), Offsets);
    }

    void VelocityStreamsVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 Velocity : TEXCOORD0)
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
        Velocity = tex2Dlod(_SampleData2, float4(VelocityCoord, 0.0, _MipBias)).xy;

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

    static const float SampleWeights[8] =
    {
        0.07978845608028654,
        0.15186256685575583,
        0.12458323113065647,
        0.08723135590047126,
        0.05212966006304008,
        0.02658822496281644,
        0.011573824628214867,
        0.004299684163333117
    };

    float4 GaussianBlur(sampler2D Source, float2 TexCoord, float4 Offsets[7])
    {
        float TotalSampleWeights = SampleWeights[0];
        float4 OutputColor = tex2D(Source, TexCoord) * SampleWeights[0];

        int SampleIndex = 0;
        int WeightIndex = 1;

        while(SampleIndex < 7)
        {
            OutputColor += (tex2D(Source, Offsets[SampleIndex].xy) * SampleWeights[WeightIndex]);
            OutputColor += (tex2D(Source, Offsets[SampleIndex].zw) * SampleWeights[WeightIndex]);
            TotalSampleWeights += (SampleWeights[WeightIndex] * 2.0);
            SampleIndex = SampleIndex + 1;
            WeightIndex = WeightIndex + 1;
        }

        return OutputColor / TotalSampleWeights;
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
        Horn Schunck
            http://6.869.csail.mit.edu/fa12/lectures/lecture16/MotionEstimation1.pdf
            - Use Gauss-Seidel at slide 52
            - Use additional constraint (normalized RG)

        Pyramid
            https://www.cs.auckland.ac.nz/~rklette/CCV-CIMAT/pdfs/B08-HornSchunck.pdf
            - Use a regular image pyramid for input frames I(., .,t)
            - Processing starts at a selected level (of lower resolution)
            - Obtained results are used for initializing optic flow values at a
            lower level (of higher resolution)
            - Repeat until full resolution level of original frames is reached
    */

    static const int MaxLevel = 7;

    void OpticalFlow(in float2 TexCoord, in float2 UV, in float Level, out float2 DUV)
    {
        // .xy = Normalized Red Channel (x, y)
        // .zw = Normalized Green Channel (x, y)
        float4 SampleI = tex2Dlod(_SampleData1, float4(TexCoord, 0.0, Level)).xyzw;

        // .xy = Current frame (r, g)
        // .zw = Previous frame (r, g)
        float4 SampleFrames;
        SampleFrames.xy = tex2Dlod(_SampleData0, float4(TexCoord, 0.0, Level)).rg;
        SampleFrames.zw = tex2Dlod(_SampleData2, float4(TexCoord, 0.0, Level)).rg;
        float2 Iz = SampleFrames.xy - SampleFrames.zw;

        const float Alpha = max(ldexp(_Constraint * 1e-5, Level - MaxLevel), 1e-7);

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

    void CopyPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        OutputColor0 = tex2D(_SampleData0, TexCoord).rg;
    }

    void NormalizePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        float3 Color = tex2D(_SampleColor, TexCoord).rgb;
        OutputColor0 = saturate(Color.xy / dot(Color, 1.0));
    }

    void HorizontalBlurPS0(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, in float4 Offsets[7] : TEXCOORD1, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = GaussianBlur(_SampleData0, TexCoord, Offsets);
    }

    void VerticalBlurPS0(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, in float4 Offsets[7] : TEXCOORD1, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = GaussianBlur(_SampleData1, TexCoord, Offsets);
    }

    void DerivativesPS(in float4 Position : SV_Position, in float4 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        float2 Sample0 = tex2D(_SampleData0, TexCoord.zy).xy; // (-x, +y)
        float2 Sample1 = tex2D(_SampleData0, TexCoord.xy).xy; // (+x, +y)
        float2 Sample2 = tex2D(_SampleData0, TexCoord.zw).xy; // (-x, -y)
        float2 Sample3 = tex2D(_SampleData0, TexCoord.xw).xy; // (+x, -y)
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
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(_SampleLevel7, UpsampleOffsets).xy, 6.0, OutputEstimation);
    }

    void EstimateLevel5PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(_SampleLevel6, UpsampleOffsets).xy, 5.0, OutputEstimation);
    }

    void EstimateLevel4PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(_SampleLevel5, UpsampleOffsets).xy, 4.0, OutputEstimation);
    }

    void EstimateLevel3PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(_SampleLevel4, UpsampleOffsets).xy, 3.0, OutputEstimation);
    }

    void EstimateLevel2PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(_SampleLevel3, UpsampleOffsets).xy, 2.0, OutputEstimation);
    }

    void EstimateLevel1PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(_SampleLevel2, UpsampleOffsets).xy, 1.0, OutputEstimation);
    }

    void EstimateLevel0PS(in float4 Position : SV_Position, in float4 UpsampleOffsets[3] : TEXCOORD0, out float4 OutputEstimation : SV_Target0)
    {
        OpticalFlow(UpsampleOffsets[1].xz, Upsample(_SampleLevel1, UpsampleOffsets).xy, 0.0, OutputEstimation.xy);
        OutputEstimation.ba = (0.0, _Blend);
    }

    void HorizontalBlurPS1(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, in float4 Offsets[7] : TEXCOORD1, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = GaussianBlur(_SampleLevel0, TexCoord, Offsets);
    }

    void VerticalBlurPS1(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, in float4 Offsets[7] : TEXCOORD1, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = GaussianBlur(_SampleData1, TexCoord, Offsets);
    }

    void VelocityShadingPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
    {
        float2 Velocity = tex2Dlod(_SampleData2, float4(TexCoord, 0.0, _MipBias)).xy;

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

    void VelocityStreamsPS(in float4 Position : SV_Position, in float2 Velocity : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0.rg = (_ScaleLineVelocity) ? (Velocity.xy / (length(Velocity) * VELOCITY_SCALE * 0.05)) : normalize(Velocity.xy);
        OutputColor0.rg = OutputColor0.xy * 0.5 + 0.5;
        OutputColor0.b = -dot(OutputColor0.rg, 1.0) * 0.5 + 1.0;
        OutputColor0.a = 1.0;
    }

    void VelocityStreamsDisplayPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float3 OutputColor0 : SV_Target0)
    {
        float4 Lines = tex2D(_SampleLines, TexCoord);
        float3 MainColor = (_BackgroundColor) ? _BaseColorShift : tex2D(_SampleColorGamma, TexCoord).rgb * _BaseColorShift;
        OutputColor0 = lerp(MainColor, Lines.rgb * _LineColorShift, Lines.aaa * _LineOpacity);
    }

    technique cOpticalFlow
    {
        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = CopyPS;
            RenderTarget0 = _RenderData2;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = NormalizePS;
            RenderTarget0 = _RenderData0;
        }

        pass
        {
            VertexShader = HorizontalBlurVS;
            PixelShader = HorizontalBlurPS0;
            RenderTarget0 = _RenderData1;
        }

        pass
        {
            VertexShader = VerticalBlurVS;
            PixelShader = VerticalBlurPS0;
            RenderTarget0 = _RenderData0;
        }

        pass
        {
            VertexShader = DerivativesVS;
            PixelShader = DerivativesPS;
            RenderTarget0 = _RenderData1;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel7PS;
            RenderTarget0 = _RenderLevel7;
        }

        pass
        {
            VertexShader = EstimateLevel6VS;
            PixelShader = EstimateLevel6PS;
            RenderTarget0 = _RenderLevel6;
        }

        pass
        {
            VertexShader = EstimateLevel5VS;
            PixelShader = EstimateLevel5PS;
            RenderTarget0 = _RenderLevel5;
        }

        pass
        {
            VertexShader = EstimateLevel4VS;
            PixelShader = EstimateLevel4PS;
            RenderTarget0 = _RenderLevel4;
        }

        pass
        {
            VertexShader = EstimateLevel3VS;
            PixelShader = EstimateLevel3PS;
            RenderTarget0 = _RenderLevel3;
        }

        pass
        {
            VertexShader = EstimateLevel2VS;
            PixelShader = EstimateLevel2PS;
            RenderTarget0 = _RenderLevel2;
        }

        pass
        {
            VertexShader = EstimateLevel1VS;
            PixelShader = EstimateLevel1PS;
            RenderTarget0 = _RenderLevel1;
        }

        pass
        {
            VertexShader = EstimateLevel0VS;
            PixelShader = EstimateLevel0PS;
            RenderTarget0 = _RenderLevel0;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        pass
        {
            VertexShader = HorizontalBlurVS;
            PixelShader = HorizontalBlurPS1;
            RenderTarget0 = _RenderData1;
        }

        pass
        {
            VertexShader = VerticalBlurVS;
            PixelShader = VerticalBlurPS1;
            RenderTarget0 = _RenderData2;
        }

        #if RENDER_VELOCITY_STREAMS
            // Render to a fullscreen buffer (cringe!)
            pass
            {
                PrimitiveTopology = LINELIST;
                VertexCount = NUM_LINES * 2;
                VertexShader = VelocityStreamsVS;
                PixelShader = VelocityStreamsPS;
                ClearRenderTargets = TRUE;
                RenderTarget0 = _RenderLines;
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
