
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
        Format = RGBA16F;
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
        Format = RGBA16F;
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
        Format = RGBA16F;
    };

    sampler2D Sample_Common_4
    {
        Texture = Render_Common_4;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Common_5
    {
        Width = BUFFER_SIZE_5.x;
        Height = BUFFER_SIZE_5.y;
        Format = RGBA16F;
    };

    sampler2D Sample_Common_5
    {
        Texture = Render_Common_5;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Common_6
    {
        Width = BUFFER_SIZE_6.x;
        Height = BUFFER_SIZE_6.y;
        Format = RGBA16F;
    };

    sampler2D Sample_Common_6
    {
        Texture = Render_Common_6;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Common_7
    {
        Width = BUFFER_SIZE_7.x;
        Height = BUFFER_SIZE_7.y;
        Format = RGBA16F;
    };

    sampler2D Sample_Common_7
    {
        Texture = Render_Common_7;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Common_8
    {
        Width = BUFFER_SIZE_8.x;
        Height = BUFFER_SIZE_8.y;
        Format = RGBA16F;
    };

    sampler2D Sample_Common_8
    {
        Texture = Render_Common_8;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };
}

namespace Interpolation
{
    // Shader properties

    uniform float _Blend <
        ui_type = "slider";
        ui_category = "Optical flow";
        ui_label = "Blending";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.0;

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
    };

    sampler2D Sample_Frame_1
    {
        Texture = Render_Frame_1;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    // Normalized, prefiltered frames for processing

    texture2D Render_Normalized_Frame_3
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = RG16F;
        MipLevels = 9;
    };

    sampler2D Sample_Normalized_Frame_3
    {
        Texture = Render_Normalized_Frame_3;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Normalized_Frame_2
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = RG16F;
        MipLevels = 9;
    };

    sampler2D Sample_Normalized_Frame_2
    {
        Texture = Render_Normalized_Frame_2;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Normalized_Frame_1
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = RG16F;
        MipLevels = 9;
    };

    sampler2D Sample_Normalized_Frame_1
    {
        Texture = Render_Normalized_Frame_1;
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

    void PostProcessVS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
    {
        TexCoord.x = (ID == 2) ? 2.0 : 0.0;
        TexCoord.y = (ID == 1) ? 2.0 : 0.0;
        Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
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

    void Sample_3x3_5_VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_5, Position, TexCoords);
    }

    void Sample_3x3_6_VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_6, Position, TexCoords);
    }

    void Sample_3x3_7_VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_7, Position, TexCoords);
    }

    void Sample_3x3_8_VS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_8, Position, TexCoords);
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

    void Store_Normalized_Frame_3_PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD, out float4 Color : SV_Target0)
    {
        Color = tex2D(Sample_Normalized_Frame_2, TexCoord);
    }

    void Store_Normalized_Frame_2_PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD, out float4 Color : SV_Target0)
    {
        Color = tex2D(Sample_Normalized_Frame_1, TexCoord);
    }

    void Normalize_Frame_1_PS(in float4 Position : SV_Position, float2 TexCoord : TEXCOORD, out float3 Color : SV_Target0)
    {
        Color = tex2D(Sample_Frame_1, TexCoord).rgb;
        Color = Color.xy / dot(Color.rgb, 1.0);
    }

    float4 Filter_3x3(in sampler2D Source, in float4 TexCoords[3])
    {
        // Sample locations:
        // A0 B0 C0
        // A1 B1 C1
        // A2 B2 C2
        float4 A0 = tex2D(Source, TexCoords[0].xy);
        float4 A1 = tex2D(Source, TexCoords[0].xz);
        float4 A2 = tex2D(Source, TexCoords[0].xw);
        float4 B0 = tex2D(Source, TexCoords[1].xy);
        float4 B1 = tex2D(Source, TexCoords[1].xz);
        float4 B2 = tex2D(Source, TexCoords[1].xw);
        float4 C0 = tex2D(Source, TexCoords[2].xy);
        float4 C1 = tex2D(Source, TexCoords[2].xz);
        float4 C2 = tex2D(Source, TexCoords[2].xw);
        return (((A0 + C0 + A2 + C2) * 1.0) + ((B0 + A1 + C1 + B2) * 2.0) + (B1 * 4.0)) / 16.0;
    }

    void Prefilter_Downsample_2_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        Color = Filter_3x3(Sample_Normalized_Frame_1, TexCoords);
    }

    void Prefilter_Downsample_3_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        Color = Filter_3x3(SharedResources::Sample_Common_2, TexCoords);
    }

    void Prefilter_Downsample_4_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        Color = Filter_3x3(SharedResources::Sample_Common_3, TexCoords);
    }

    void Prefilter_Upsample_3_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        Color = Filter_3x3(SharedResources::Sample_Common_4, TexCoords);
    }

    void Prefilter_Upsample_2_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        Color = Filter_3x3(SharedResources::Sample_Common_3, TexCoords);
    }

    void Prefilter_Upsample_1_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        Color = Filter_3x3(SharedResources::Sample_Common_2, TexCoords);
    }

    void Derivatives_PS(in float4 Position : SV_Position, in float4 TexCoords[2] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        // Bilinear 5x5 Sobel by CeeJayDK
        //   B1 B2
        // A0     A1
        // A2     B0
        //   C0 C1
        float2 A0 = tex2D(Sample_Normalized_Frame_2, TexCoords[0].xw).xy * 4.0; // <-1.5, +0.5>
        float2 A1 = tex2D(Sample_Normalized_Frame_2, TexCoords[0].yw).xy * 4.0; // <+1.5, +0.5>
        float2 A2 = tex2D(Sample_Normalized_Frame_2, TexCoords[0].xz).xy * 4.0; // <-1.5, -0.5>
        float2 B0 = tex2D(Sample_Normalized_Frame_2, TexCoords[0].yz).xy * 4.0; // <+1.5, -0.5>
        float2 B1 = tex2D(Sample_Normalized_Frame_2, TexCoords[1].xw).xy * 4.0; // <-0.5, +1.5>
        float2 B2 = tex2D(Sample_Normalized_Frame_2, TexCoords[1].yw).xy * 4.0; // <+0.5, +1.5>
        float2 C0 = tex2D(Sample_Normalized_Frame_2, TexCoords[1].xz).xy * 4.0; // <-0.5, -1.5>
        float2 C1 = tex2D(Sample_Normalized_Frame_2, TexCoords[1].yz).xy * 4.0; // <+0.5, -1.5>

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
    #define E 1e-4

    void CoarseOpticalFlowTV(in float2 TexCoord, in float Level, in float2 UV, out float4 MotionVectors)
    {
        MotionVectors = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-4, Level - MaxLevel), 1e-7);

        float2 Frame_1 = tex2D(Sample_Normalized_Frame_1, TexCoord).xy;
        float2 Frame_2 = tex2D(Sample_Normalized_Frame_2, TexCoord).xy;
		float2 Frame_3 = tex2D(Sample_Normalized_Frame_3, TexCoord).xy;
		
        // <Rx, Gx, Ry, Gy>
        float4 SD = tex2D(SharedResources::Sample_Common_1, TexCoord);

        // <Rz, Gz>
        float2 TD_Backward = Frame_2 - Frame_1;
        float2 TD_Forward = Frame_3 - Frame_2;

        // Calculate constancy term
        float C = 0.0;
        float2 Aii = 0.0;
        float Aij = 0.0;
        float2 Bi = 0.0;

		// Calculate backward motion vectors
        // Gauss-Seidel (forward sweep, from 1...N)
        
        C = dot(TD_Backward, 1.0);
        C = rsqrt(C * C + (E * E));
        Aii.x = 1.0 / (C * dot(SD.xy, SD.xy) + Alpha);
        Aii.y = 1.0 / (C * dot(SD.zw, SD.zw) + Alpha);
        Aij = C * dot(SD.xy, SD.zw);
        Bi.x = C * dot(SD.xy, TD_Backward);
        Bi.y = C * dot(SD.zw, TD_Backward);
        
        MotionVectors.x = Aii.x * ((Alpha * UV.x) - (Aij * UV.y) - Bi.x);
        MotionVectors.y = Aii.y * ((Alpha * UV.y) - (Aij * MotionVectors.x) - Bi.y);
        
		// Calculate forward motion vectors
        // Gauss-Seidel (forward sweep, from 1...N)
        
        C = dot(TD_Forward, 1.0);
        C = rsqrt(C * C + (E * E));
        Aii.x = 1.0 / (C * dot(SD.xy, SD.xy) + Alpha);
        Aii.y = 1.0 / (C * dot(SD.zw, SD.zw) + Alpha);
        Aij = C * dot(SD.xy, SD.zw);
        Bi.x = C * dot(SD.xy, TD_Forward);
        Bi.y = C * dot(SD.zw, TD_Forward);
        
        MotionVectors.z = Aii.x * ((Alpha * UV.x) - (Aij * UV.y) - Bi.x);
        MotionVectors.w = Aii.y * ((Alpha * UV.y) - (Aij * MotionVectors.z) - Bi.y);
    }

    void ProcessGradAvg(in float2 SampleNW,
                        in float2 SampleNE,
                        in float2 SampleSW,
                        in float2 SampleSE,
                        out float Grad,
                        out float2 Avg)
    {
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

    void OpticalFlowTV(in sampler2D SourceUV, in float4 TexCoords[3], in float Level, out float4 MotionVectors)
    {
        MotionVectors = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-4, Level - MaxLevel), 1e-7);

        // Load textures
        
        float2 Frame_1 = tex2D(Sample_Normalized_Frame_1, TexCoords[1].xz).xy;
        float2 Frame_2 = tex2D(Sample_Normalized_Frame_2, TexCoords[1].xz).xy;
		float2 Frame_3 = tex2D(Sample_Normalized_Frame_3, TexCoords[1].xz).xy;
		
        // <Rx, Gx, Ry, Gy>
        float4 SD = tex2D(SharedResources::Sample_Common_1, TexCoords[1].xz);

        // <Rz, Gz>
        float2 TD_Backward = Frame_2 - Frame_1;
        float2 TD_Forward = Frame_3 - Frame_2;

        // Optical flow calculation

        float4 SampleUV[9];
        float2 SampleBackwardUV[9];
        float2 SampleForwardUV[9];
        
        float4 UVGradBackward = 0.0;
        float2 CenterAvgBackward = 0.0;
        float2 UVAvgBackward = 0.0;
        
        float4 UVGradForward = 0.0;
        float2 CenterAvgForward = 0.0;
        float2 UVAvgForward = 0.0;

        // SampleUV[i]
        // 0 3 6
        // 1 4 7
        // 2 5 8
        SampleUV[0] = tex2D(SourceUV, TexCoords[0].xy);
        SampleUV[1] = tex2D(SourceUV, TexCoords[0].xz);
        SampleUV[2] = tex2D(SourceUV, TexCoords[0].xw);
        SampleUV[3] = tex2D(SourceUV, TexCoords[1].xy);
        SampleUV[4] = tex2D(SourceUV, TexCoords[1].xz);
        SampleUV[5] = tex2D(SourceUV, TexCoords[1].xw);
        SampleUV[6] = tex2D(SourceUV, TexCoords[2].xy);
        SampleUV[7] = tex2D(SourceUV, TexCoords[2].xz);
        SampleUV[8] = tex2D(SourceUV, TexCoords[2].xw);
        
        for(int i = 0; i < 9; i++)
        {
        	SampleBackwardUV[i] = SampleUV[i].xy;
        	SampleForwardUV[i] = SampleUV[i].zw;
        }

        ProcessArea(SampleBackwardUV, UVGradBackward, CenterAvgBackward, UVAvgBackward);
        ProcessArea(SampleForwardUV, UVGradForward, CenterAvgForward, UVAvgForward);
        
        float C = 0.0;
        float2 Aii = 0.0;
        float Aij = 0.0;
        float2 Bi = 0.0;

        // Calculate backward motion vectors

        C = dot(SD.xyzw, CenterAvgBackward.xyxy) + dot(TD_Backward, 1.0);
        C = rsqrt(C * C + (E * E));

        Aii.x = 1.0 / (dot(UVGradBackward, 1.0) * Alpha + (C * dot(SD.xy, SD.xy)));
        Aii.y = 1.0 / (dot(UVGradBackward, 1.0) * Alpha + (C * dot(SD.zw, SD.zw)));
        Aij = dot(SD.xy, SD.zw);

        Bi.x = C * dot(SD.xy, TD_Backward);
        Bi.y = C * dot(SD.zw, TD_Backward);

        MotionVectors.x = Aii.x * ((Alpha * UVAvgBackward.x) - (C * Aij * CenterAvgBackward.y) - Bi.x);
        MotionVectors.y = Aii.y * ((Alpha * UVAvgBackward.y) - (C * Aij * MotionVectors.x) - Bi.y);
        
        // Calculate forward motion vectors

        C = dot(SD.xyzw, CenterAvgForward.xyxy) + dot(TD_Forward, 1.0);
        C = rsqrt(C * C + (E * E));

        Aii.x = 1.0 / (dot(UVGradForward, 1.0) * Alpha + (C * dot(SD.xy, SD.xy)));
        Aii.y = 1.0 / (dot(UVGradForward, 1.0) * Alpha + (C * dot(SD.zw, SD.zw)));
        Aij = dot(SD.xy, SD.zw);

        Bi.x = C * dot(SD.xy, TD_Forward);
        Bi.y = C * dot(SD.zw, TD_Forward);

        MotionVectors.z = Aii.x * ((Alpha * UVAvgForward.x) - (C * Aij * CenterAvgForward.y) - Bi.x);
        MotionVectors.w = Aii.y * ((Alpha * UVAvgForward.y) - (C * Aij * MotionVectors.z) - Bi.y);
    }

    void Level_8_PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 Color : SV_Target0)
    {
        CoarseOpticalFlowTV(TexCoord, 7.0, 0.0, Color);
    }

    void Level_7_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        OpticalFlowTV(SharedResources::Sample_Common_8, TexCoords, 6.0, Color);
    }

    void Level_6_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        OpticalFlowTV(SharedResources::Sample_Common_7, TexCoords, 5.0, Color);
    }

    void Level_5_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        OpticalFlowTV(SharedResources::Sample_Common_6, TexCoords, 4.0, Color);
    }

    void Level_4_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        OpticalFlowTV(SharedResources::Sample_Common_5, TexCoords, 3.0, Color);
    }

    void Level_3_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        OpticalFlowTV(SharedResources::Sample_Common_4, TexCoords, 2.0, Color);
    }

    void Level_2_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        OpticalFlowTV(SharedResources::Sample_Common_3, TexCoords, 1.0, Color);
    }

    void Level_1_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        OpticalFlowTV(SharedResources::Sample_Common_2, TexCoords, 0.0, Color);
    }

    void Postfilter_Downsample_2_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        Color = Filter_3x3(SharedResources::Sample_Common_1, TexCoords);
    }

    void Postfilter_Downsample_3_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        Color = Filter_3x3(SharedResources::Sample_Common_2, TexCoords);
    }

    void Postfilter_Downsample_4_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        Color = Filter_3x3(SharedResources::Sample_Common_3, TexCoords);
    }

    void Postfilter_Upsample_3_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        Color = Filter_3x3(SharedResources::Sample_Common_4, TexCoords);
    }

    void Postfilter_Upsample_2_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        Color = Filter_3x3(SharedResources::Sample_Common_3, TexCoords);
    }

    void Postfilter_Upsample_1_PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_Target0)
    {
        Color = Filter_3x3(SharedResources::Sample_Common_2, TexCoords);
    }

    float4 Med3(float4 a, float4 b, float4 c)
    {
        return clamp(a, min(b, c), max(b, c));
    }

    void Interpolate_PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 Color : SV_Target0)
    {
        float2 TexelSize = 1.0 / BUFFER_SIZE_1;
        float4 MotionVectors = tex2Dlod(SharedResources::Sample_Common_1, float4(TexCoord, 0.0, _MipBias)) * TexelSize.xyxy;
        float4 Frame1 = tex2D(Sample_Frame_1, TexCoord);
        float4 Frame3 = tex2D(Sample_Frame_3, TexCoord);
        float4 Frame1_Warped = tex2D(Sample_Frame_1, TexCoord + MotionVectors.xy);
        float4 Frame3_Warped = tex2D(Sample_Frame_3, TexCoord - MotionVectors.zw);
        Color = Med3(Frame1, lerp(Frame1_Warped, Frame3_Warped, 0.125), Frame3);
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

        pass Store_Frame_3
        {
            VertexShader = PostProcessVS;
            PixelShader = Store_Normalized_Frame_3_PS;
            RenderTarget = Render_Normalized_Frame_3;
        }

        pass Store_Frame_2
        {
            VertexShader = PostProcessVS;
            PixelShader = Store_Normalized_Frame_2_PS;
            RenderTarget = Render_Normalized_Frame_2;
        }

        pass Normalize_Frame_1
        {
            VertexShader = PostProcessVS;
            PixelShader = Normalize_Frame_1_PS;
            RenderTarget0 = Render_Normalized_Frame_1;
        }

        // Pyramid Prefilter

        pass Downsample_2
        {
            VertexShader = Sample_3x3_1_VS;
            PixelShader = Prefilter_Downsample_2_PS;
            RenderTarget0 = SharedResources::Render_Common_2;
        }

        pass Downsample_3
        {
            VertexShader = Sample_3x3_2_VS;
            PixelShader = Prefilter_Downsample_3_PS;
            RenderTarget0 = SharedResources::Render_Common_3;
        }

        pass Downsample_4
        {
            VertexShader = Sample_3x3_3_VS;
            PixelShader = Prefilter_Downsample_4_PS;
            RenderTarget0 = SharedResources::Render_Common_4;
        }

        pass Upsample_3
        {
            VertexShader = Sample_3x3_4_VS;
            PixelShader = Prefilter_Upsample_3_PS;
            RenderTarget0 = SharedResources::Render_Common_3;
        }

        pass Upsample_2
        {
            VertexShader = Sample_3x3_3_VS;
            PixelShader = Prefilter_Upsample_2_PS;
            RenderTarget0 = SharedResources::Render_Common_2;
        }

        pass Upsample_1
        {
            VertexShader = Sample_3x3_2_VS;
            PixelShader = Prefilter_Upsample_1_PS;
            RenderTarget0 = Render_Normalized_Frame_1;
        }

        // Calculate spatial derivative pyramid

        pass Derivatives
        {
            VertexShader = Derivatives_VS;
            PixelShader = Derivatives_PS;
            RenderTarget0 = SharedResources::Render_Common_1;
        }

        // Optical Flow

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = Level_8_PS;
            RenderTarget0 = SharedResources::Render_Common_8;
        }

        pass
        {
            VertexShader = Sample_3x3_8_VS;
            PixelShader = Level_7_PS;
            RenderTarget0 = SharedResources::Render_Common_7;
        }

        pass
        {
            VertexShader = Sample_3x3_7_VS;
            PixelShader = Level_6_PS;
            RenderTarget0 = SharedResources::Render_Common_6;
        }

        pass
        {
            VertexShader = Sample_3x3_6_VS;
            PixelShader = Level_5_PS;
            RenderTarget0 = SharedResources::Render_Common_5;
        }

        pass
        {
            VertexShader = Sample_3x3_5_VS;
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

        // Pyramid Postfilter

        pass Downsample_2
        {
            VertexShader = Sample_3x3_1_VS;
            PixelShader = Postfilter_Downsample_2_PS;
            RenderTarget0 = SharedResources::Render_Common_2;
        }

        pass Downsample_3
        {
            VertexShader = Sample_3x3_2_VS;
            PixelShader = Postfilter_Downsample_3_PS;
            RenderTarget0 = SharedResources::Render_Common_3;
        }

        pass Downsample_4
        {
            VertexShader = Sample_3x3_3_VS;
            PixelShader = Postfilter_Downsample_4_PS;
            RenderTarget0 = SharedResources::Render_Common_4;
        }

        pass Upsample_3
        {
            VertexShader = Sample_3x3_4_VS;
            PixelShader = Postfilter_Upsample_3_PS;
            RenderTarget0 = SharedResources::Render_Common_3;
        }

        pass Upsample_2
        {
            VertexShader = Sample_3x3_3_VS;
            PixelShader = Postfilter_Upsample_2_PS;
            RenderTarget0 = SharedResources::Render_Common_2;
        }

        pass Upsample_1
        {
            VertexShader = Sample_3x3_2_VS;
            PixelShader = Postfilter_Upsample_1_PS;
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
