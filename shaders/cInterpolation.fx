
/*
    Three-point estimation shader

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

namespace SharedResources
{
    // Store convoluted normalized frame 1 and 3

    texture2D Render_Common_1
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = RGBA16F;
        MipLevels = 8;
    };

    sampler2D Sample_Common_1
    {
        Texture = Render_Common_1;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Common_2
    {
        Width = BUFFER_SIZE_2.x;
        Height = BUFFER_SIZE_2.y;
        Format = RG16F;
    };

    sampler2D Sample_Common_2
    {
        Texture = Render_Common_2;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Common_3
    {
        Width = BUFFER_SIZE_3.x;
        Height = BUFFER_SIZE_3.y;
        Format = RG16F;
    };

    sampler2D Sample_Common_3
    {
        Texture = Render_Common_3;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Common_4
    {
        Width = BUFFER_SIZE_4.x;
        Height = BUFFER_SIZE_4.y;
        Format = RG16F;
    };

    sampler2D Sample_Common_4
    {
        Texture = Render_Common_4;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };
}

namespace cInterpolation
{
    // Shader properties

    uniform float _Constraint <
        ui_type = "slider";
        ui_category = "Optical flow";
        ui_label = "Motion Threshold";
        ui_min = 0.0;
        ui_max = 2.0;
    > = 1.0;

    uniform float _MipBias  <
        ui_type = "drag";
        ui_category = "Optical flow";
        ui_label = "Optical flow mipmap bias";
        ui_min = 0.0;
    > = 0.0;

    // Consideration: Use A8 channel for difference requirement (normalize BW image)

    texture2D Render_Color : COLOR;

    sampler2D Sample_Color
    {
        Texture = Render_Color;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    // Three-point backbuffer storage for interpolation

    texture2D Render_Frame_3
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
        MipLevels = 4;
    };

    sampler2D Sample_Frame_3
    {
        Texture = Render_Frame_3;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Frame_2
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
    };

    sampler2D Sample_Frame_2
    {
        Texture = Render_Frame_2;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Frame_1
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
        MipLevels = 4;
    };

    sampler2D Sample_Frame_1
    {
        Texture = Render_Frame_1;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    // Normalized, prefiltered frames for processing

    texture2D Render_Normalized_Frame
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = RGBA16F;
        MipLevels = 8;
    };

    sampler2D Sample_Normalized_Frame
    {
        Texture = Render_Normalized_Frame;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    // Optical flow shader that can optionally blend within itself

    texture2D Render_Interpolated_Frame
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
    };

    sampler2D Sample_Interpolated_Frame
    {
        Texture = Render_Interpolated_Frame;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    // Vertex Shaders

    void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
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

    void Blur_0_VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[8] : TEXCOORD0)
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        TexCoords[0] = VSTexCoord.xyxy;

        for(int i = 1; i < 8; i++)
        {
            TexCoords[i].xy = VSTexCoord.xy - (BlurOffsets[i].yx / BUFFER_SIZE_1);
            TexCoords[i].zw = VSTexCoord.xy + (BlurOffsets[i].yx / BUFFER_SIZE_1);
        }
    }

    void Blur_1_VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[8] : TEXCOORD0)
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        TexCoords[0] = VSTexCoord.xyxy;

        for(int i = 1; i < 8; i++)
        {
            TexCoords[i].xy = VSTexCoord.xy - (BlurOffsets[i].xy / BUFFER_SIZE_1);
            TexCoords[i].zw = VSTexCoord.xy + (BlurOffsets[i].xy / BUFFER_SIZE_1);
        }
    }

    void Sample_3x3_VS(in uint ID : SV_VertexID, in float2 TexelSize, out float4 Position : SV_Position, out float4 TexCoords[3] : TEXCOORD0)
    {
        float2 VS_TexCoord = 0.0;
        PostProcessVS(ID, Position, VS_TexCoord);
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        TexCoords[0] = VS_TexCoord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) / TexelSize.xyyy);
        TexCoords[1] = VS_TexCoord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) / TexelSize.xyyy);
        TexCoords[2] = VS_TexCoord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) / TexelSize.xyyy);
    }

    void Sample_3x3_1_VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_1, Position, TexCoords);
    }

    void Sample_3x3_2_VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_2, Position, TexCoords);
    }

    void Sample_3x3_3_VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_3, Position, TexCoords);
    }

    void Sample_3x3_4_VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_4, Position, TexCoords);
    }

    void Derivatives_VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[2] : TEXCOORD0)
    {
        float2 VSTexCoord = 0.0;
        PostProcessVS(ID, Position, VSTexCoord);
        TexCoords[0] = VSTexCoord.xxyy + (float4(-1.5, 1.5, -0.5, 0.5) / BUFFER_SIZE_1.xxyy);
        TexCoords[1] = VSTexCoord.xxyy + (float4(-0.5, 0.5, -1.5, 1.5) / BUFFER_SIZE_1.xxyy);
    }

    // Pixel Shaders

    /*
        BlueSkyDefender's three-frame storage

        [Frame_1] [Frame_2] [Frame_3]

        Scenario: Three Frames
        Frame 0: [Frame_1 (new back buffer data)] [Frame_2 (no data yet)] [Frame_3 (no data yet)]
        Frame 1: [Frame_1 (new back buffer data)] [Frame_2 (sample Frame_1 data)] [Frame_3 (no data yet)]
        Frame 2: [Frame_1 (new back buffer data)] [Frame_2 (sample Frame_1 data)] [Frame_3 (sample Frame_2 data)]
        ... and so forth
    */

    void Store_Frame_3_PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD, out float4 Color : SV_Target0)
    {
        Color = tex2D(Sample_Frame_2, TexCoord);
    }

    void Store_Frame_2_PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD, out float4 Color : SV_Target0)
    {
        Color = tex2D(Sample_Frame_1, TexCoord);
    }

    void Current_Frame_1_PS(float4 Position : SV_Position, in float2 TexCoord : TEXCOORD, out float4 Color : SV_Target0)
    {
        Color = tex2D(Sample_Color, TexCoord);
    }

    /*
        1. Store previous filtered frames into their respective buffers
        2. Filter incoming frame
    */

    void Normalize_Frame_PS(in float4 Position : SV_Position, float2 TexCoord : TEXCOORD, out float4 Color : SV_Target0)
    {
        float4 Frame1 = tex2D(Sample_Frame_1, TexCoord);
        float4 Frame3 = tex2D(Sample_Frame_3, TexCoord);
        Color.xy = saturate(Frame1.xy / dot(Frame1.rgb, 1.0));
        Color.zw = saturate(Frame3.xy / dot(Frame3.rgb, 1.0));
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

    void GaussianBlur(in sampler2D Source, in float4 TexCoords[8], out float4 Color)
    {
        float TotalWeights = BlurWeights[0];
        Color = (tex2D(Source, TexCoords[0].xy) * BlurWeights[0]);

        for(int i = 1; i < 8; i++)
        {
            Color += (tex2D(Source, TexCoords[i].xy) * BlurWeights[i]);
            Color += (tex2D(Source, TexCoords[i].zw) * BlurWeights[i]);
            TotalWeights += (BlurWeights[i] * 2.0);
        }

        Color = Color / TotalWeights;
    }

    void Pre_Blur_0_PS(in float4 Position : SV_Position, in float4 TexCoords[8] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        GaussianBlur(Sample_Normalized_Frame, TexCoords, Color);
    }

    void Pre_Blur_1_PS(in float4 Position : SV_Position, in float4 TexCoords[8] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        GaussianBlur(SharedResources::Sample_Common_1, TexCoords, Color);
    }

    void Derivatives_PS(in float4 Position : SV_Position, in float4 TexCoords[2] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        // Bilinear 5x5 Sobel by CeeJayDK
        //   B1 B2
        // A0     A1
        // A2     B0
        //   C0 C1
        float2 A0 = tex2D(Sample_Normalized_Frame, TexCoords[0].xw).xy * 4.0; // <-1.5, +0.5>
        float2 A1 = tex2D(Sample_Normalized_Frame, TexCoords[0].yw).xy * 4.0; // <+1.5, +0.5>
        float2 A2 = tex2D(Sample_Normalized_Frame, TexCoords[0].xz).xy * 4.0; // <-1.5, -0.5>
        float2 B0 = tex2D(Sample_Normalized_Frame, TexCoords[0].yz).xy * 4.0; // <+1.5, -0.5>
        float2 B1 = tex2D(Sample_Normalized_Frame, TexCoords[1].xw).xy * 4.0; // <-0.5, +1.5>
        float2 B2 = tex2D(Sample_Normalized_Frame, TexCoords[1].yw).xy * 4.0; // <+0.5, +1.5>
        float2 C0 = tex2D(Sample_Normalized_Frame, TexCoords[1].xz).xy * 4.0; // <-0.5, -1.5>
        float2 C1 = tex2D(Sample_Normalized_Frame, TexCoords[1].yz).xy * 4.0; // <+0.5, -1.5>

        //    -1 0 +1
        // -1 -2 0 +2 +1
        // -2 -2 0 +2 +2
        // -1 -2 0 +2 +1
        //    -1 0 +1
        Color.xy = ((B2 + A1 + B0 + C1) - (B1 + A0 + A2 + C0)) / 12.0;

        //    +1 +2 +1
        // +1 +2 +2 +2 +1
        //  0  0  0  0  0
        // -1 -2 -2 -2 -1
        //    -1 -2 -1
        Color.zw = ((A0 + B1 + B2 + A1) - (A2 + C0 + C1 + B0)) / 12.0;
        Color.xz *= rsqrt(dot(Color.xz, Color.xz) + 1.0);
        Color.yw *= rsqrt(dot(Color.yw, Color.yw) + 1.0);
    }

    #define MaxLevel 7
    #define E 1e-2

    void CoarseOpticalFlowTV(in float2 TexCoord, in float Level, in float2 UV, out float2 OpticalFlow)
    {
        OpticalFlow = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-5, Level - MaxLevel), 1e-7);

        float4 Frames = tex2Dlod(Sample_Normalized_Frame, float4(TexCoord, 0.0, Level));

        // <Rx, Gx, Ry, Gy>
        float4 SD = tex2Dlod(SharedResources::Sample_Common_1, float4(TexCoord, 0.0, Level));

        // <Rz, Gz>
        float2 TD = Frames.xy - Frames.zw;

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

    void OpticalFlowTV(in sampler2D SourceUV, in float4 TexCoords[3], in float Level, out float2 OpticalFlow)
    {
        OpticalFlow = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-5, Level - MaxLevel), 1e-7);

        // Load textures

        float4 Frames = tex2Dlod(Sample_Normalized_Frame, float4(TexCoords[1].xz, 0.0, Level));

        // <Rx, Gx, Ry, Gy>
        float4 SD = tex2Dlod(SharedResources::Sample_Common_1, float4(TexCoords[1].xz, 0.0, Level));

        // <Rz, Gz>
        float2 TD = Frames.xy - Frames.zw;

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

        float C = 0.0;
        float2 Aii = 0.0;
        float Aij = 0.0;
        float2 Bi = 0.0;

        // Calculate forward motion vectors

        C = dot(SD.xyzw, CenterAvg.xyxy) + dot(TD, 1.0);
        C = rsqrt(C * C + (E * E));

        Aii.x = 1.0 / (dot(UVGrad, 1.0) * Alpha + (C * dot(SD.xy, SD.xy)));
        Aii.y = 1.0 / (dot(UVGrad, 1.0) * Alpha + (C * dot(SD.zw, SD.zw)));

        Aij = C * dot(SD.xy, SD.zw);

        Bi.x = C * dot(SD.xy, TD);
        Bi.y = C * dot(SD.zw, TD);

        OpticalFlow.x = Aii.x * ((Alpha * UVAvg.x) - (Aij * CenterAvg.y) - Bi.x);
        OpticalFlow.y = Aii.y * ((Alpha * UVAvg.y) - (Aij * OpticalFlow.x) - Bi.y);
    }

    void Level_4_PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 Color : SV_Target0)
    {
        CoarseOpticalFlowTV(TexCoord, 6.5, 0.0, Color);
    }

    void Level_3_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float2 Color : SV_Target0)
    {
        OpticalFlowTV(SharedResources::Sample_Common_4, TexCoords, 4.5, Color);
    }

    void Level_2_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float2 Color : SV_Target0)
    {
        OpticalFlowTV(SharedResources::Sample_Common_3, TexCoords, 2.5, Color);
    }

    void Level_1_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        OpticalFlowTV(SharedResources::Sample_Common_2, TexCoords, 0.5, Color.rg);
        Color.ba = float2(0.0, 1.0);
    }

    void Post_Blur_0_PS(in float4 Position : SV_Position, in float4 TexCoords[8] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        GaussianBlur(SharedResources::Sample_Common_1, TexCoords, Color);
        Color.a = 1.0;
    }

    void Post_Blur_1_PS(in float4 Position : SV_Position, in float4 TexCoords[8] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        GaussianBlur(Sample_Normalized_Frame, TexCoords, Color);
        Color.a = 1.0;
    }

    /*
        Cascaded median algorithm (Fig. 3.)
        Link: http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.64.7794&rep=rep1&type=pdf
        Title: Temporal video up-conversion on a next generation media-processor
        Authors: Jan-Willem van de Waerdt, Stamatis Vassiliadis, Erwin B. Bellers, and Johan G. Janssen
    */

    float4 Median(float4 a, float4 b, float4 c)
    {
        return min(max(min(a, b), c), max(a, b));
    }

    void Interpolate_PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 Color : SV_Target0)
    {
        float2 TexelSize = 1.0 / BUFFER_SIZE_1;
        float2 MotionVectors = tex2Dlod(SharedResources::Sample_Common_1, float4(TexCoord, 0.0, _MipBias)).xy * TexelSize.xy;

        float4 StaticLeft = tex2D(Sample_Frame_3, TexCoord);
        float4 StaticRight = tex2D(Sample_Frame_1, TexCoord);
        float4 DynamicLeft = tex2D(Sample_Frame_3, TexCoord + MotionVectors);
        float4 DynamicRight = tex2D(Sample_Frame_1, TexCoord - MotionVectors);

        float4 StaticAverage = lerp(StaticLeft, StaticRight, 0.5);
        float4 DynamicAverage = lerp(DynamicLeft, DynamicRight, 0.5);

        float4 StaticMedian = Median(StaticLeft, StaticRight, DynamicAverage);
        float4 DynamicMedian = Median(StaticAverage, DynamicLeft, DynamicRight);
        float4 MotionFilter = lerp(StaticAverage, DynamicAverage, DynamicMedian);

        float4 CascadedMedian = Median(StaticMedian, MotionFilter, DynamicMedian);

        Color = lerp(CascadedMedian, DynamicAverage, 0.5);
        Color.a = 1.0;
    }

    /*
        TODO (bottom text)
        - Calculate vectors on Frame 3 and Frame 1 (can use pyramidal method via MipMaps)
        - Calculate warp Frame 3 and Frame 1 to Frame 2
    */

    technique cInterpolation
    {
        // Store frames

        pass Store_Frame_3
        {
            VertexShader = PostProcessVS;
            PixelShader = Store_Frame_3_PS;
            RenderTarget = Render_Frame_3;
        }

        pass Store_Frame_2
        {
            VertexShader = PostProcessVS;
            PixelShader = Store_Frame_2_PS;
            RenderTarget = Render_Frame_2;
        }

        pass Store_Frame_1
        {
            VertexShader = PostProcessVS;
            PixelShader = Current_Frame_1_PS;
            RenderTarget = Render_Frame_1;
        }

        // Store previous frames, normalize current

        pass Normalize_Frame
        {
            VertexShader = PostProcessVS;
            PixelShader = Normalize_Frame_PS;
            RenderTarget0 = Render_Normalized_Frame;
        }

        // Gaussian blur

        pass Blur0
        {
            VertexShader = Blur_0_VS;
            PixelShader = Pre_Blur_0_PS;
            RenderTarget0 = SharedResources::Render_Common_1;
        }

        pass Blur1
        {
            VertexShader = Blur_1_VS;
            PixelShader = Pre_Blur_1_PS;
            RenderTarget0 = Render_Normalized_Frame;
        }

        // Calculate spatial derivative pyramid

        pass Derivatives
        {
            VertexShader = Derivatives_VS;
            PixelShader = Derivatives_PS;
            RenderTarget0 = SharedResources::Render_Common_1;
        }

        // Trilinear Optical Flow, calculate 2 levels at a time

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = Level_4_PS;
            RenderTarget0 = SharedResources::Render_Common_4;
        }

        pass
        {
            VertexShader = Sample_3x3_4_VS;
            PixelShader = Level_3_PS;
            RenderTarget0 = SharedResources::Render_Common_3;
        }

        pass
        {
            VertexShader = Sample_3x3_3_VS;
            PixelShader = Level_2_PS;
            RenderTarget0 = SharedResources::Render_Common_2;
        }

        pass
        {
            VertexShader = Sample_3x3_2_VS;
            PixelShader = Level_1_PS;
            RenderTarget0 = SharedResources::Render_Common_1;
        }

        // Gaussian blur

        pass Blur0
        {
            VertexShader = Blur_0_VS;
            PixelShader = Post_Blur_0_PS;
            RenderTarget0 = Render_Normalized_Frame;
        }

        pass Blur1
        {
            VertexShader = Blur_1_VS;
            PixelShader = Post_Blur_1_PS;
            RenderTarget0 = SharedResources::Render_Common_1;
        }

        // Interpolate

        pass Interpolate
        {
            VertexShader = PostProcessVS;
            PixelShader = Interpolate_PS;
            RenderTarget0 = Render_Interpolated_Frame;
        }
    }
}
