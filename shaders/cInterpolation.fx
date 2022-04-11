
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

namespace Shared_Resources
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
        AddressU = MIRROR;
        AddressV = MIRROR;
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
        AddressU = MIRROR;
        AddressV = MIRROR;
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
        AddressU = MIRROR;
        AddressV = MIRROR;
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
        AddressU = MIRROR;
        AddressV = MIRROR;
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

    uniform float _Mip_Bias  <
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
        AddressU = MIRROR;
        AddressV = MIRROR;
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
        AddressU = MIRROR;
        AddressV = MIRROR;
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
        AddressU = MIRROR;
        AddressV = MIRROR;
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
        AddressU = MIRROR;
        AddressV = MIRROR;
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
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    // Vertex Shaders

    void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 Coord : TEXCOORD0)
    {
        Coord.x = (ID == 2) ? 2.0 : 0.0;
        Coord.y = (ID == 1) ? 2.0 : 0.0;
        Position = float4(Coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    }

    static const float2 Blur_Offsets[8] =
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

    void Blur_0_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coords[8] : TEXCOORD0)
    {
        float2 VS_Coord = 0.0;
        Basic_VS(ID, Position, VS_Coord);
        Coords[0] = VS_Coord.xyxy;

        for(int i = 1; i < 8; i++)
        {
            Coords[i].xy = VS_Coord.xy - (Blur_Offsets[i].yx / BUFFER_SIZE_1);
            Coords[i].zw = VS_Coord.xy + (Blur_Offsets[i].yx / BUFFER_SIZE_1);
        }
    }

    void Blur_1_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coords[8] : TEXCOORD0)
    {
        float2 VS_Coord = 0.0;
        Basic_VS(ID, Position, VS_Coord);
        Coords[0] = VS_Coord.xyxy;

        for(int i = 1; i < 8; i++)
        {
            Coords[i].xy = VS_Coord.xy - (Blur_Offsets[i].xy / BUFFER_SIZE_1);
            Coords[i].zw = VS_Coord.xy + (Blur_Offsets[i].xy / BUFFER_SIZE_1);
        }
    }

    void Sample_3x3_VS(in uint ID : SV_VERTEXID, in float2 Texel_Size, out float4 Position : SV_POSITION, out float4 Coords[3] : TEXCOORD0)
    {
        float2 VS_Coord = 0.0;
        Basic_VS(ID, Position, VS_Coord);
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        Coords[0] = VS_Coord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) / Texel_Size.xyyy);
        Coords[1] = VS_Coord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) / Texel_Size.xyyy);
        Coords[2] = VS_Coord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) / Texel_Size.xyyy);
    }

    void Sample_3x3_1_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_1, Position, Coords);
    }

    void Sample_3x3_2_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_2, Position, Coords);
    }

    void Sample_3x3_3_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_3, Position, Coords);
    }

    void Sample_3x3_4_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_4, Position, Coords);
    }

    void Derivatives_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coords[2] : TEXCOORD0)
    {
        float2 VS_Coord = 0.0;
        Basic_VS(ID, Position, VS_Coord);
        Coords[0] = VS_Coord.xxyy + (float4(-1.5, 1.5, -0.5, 0.5) / BUFFER_SIZE_1.xxyy);
        Coords[1] = VS_Coord.xxyy + (float4(-0.5, 0.5, -1.5, 1.5) / BUFFER_SIZE_1.xxyy);
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

    void Store_Frame_3_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = tex2D(Sample_Frame_2, Coord);
    }

    void Store_Frame_2_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = tex2D(Sample_Frame_1, Coord);
    }

    void Current_Frame_1_PS(float4 Position : SV_POSITION, in float2 Coord : TEXCOORD, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = tex2D(Sample_Color, Coord);
    }

    /*
        1. Store previous filtered frames into their respective buffers
        2. Filter incoming frame
    */

    void Normalize_Frame_PS(in float4 Position : SV_POSITION, float2 Coord : TEXCOORD, out float4 Output_Color_0 : SV_TARGET0)
    {
        float4 Frame_1 = tex2D(Sample_Frame_1, Coord);
        float4 Frame_3 = tex2D(Sample_Frame_3, Coord);
        Output_Color_0.xy = saturate(Frame_1.xy / dot(Frame_1.rgb, 1.0));
        Output_Color_0.zw = saturate(Frame_3.xy / dot(Frame_3.rgb, 1.0));
    }

    static const float Blur_Weights[8] =
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

    void Gaussian_Blur(in sampler2D Source, in float4 Coords[8], out float4 Output_Color_0)
    {
        float Total_Weights = Blur_Weights[0];
        Output_Color_0 = (tex2D(Source, Coords[0].xy) * Blur_Weights[0]);

        for(int i = 1; i < 8; i++)
        {
            Output_Color_0 += (tex2D(Source, Coords[i].xy) * Blur_Weights[i]);
            Output_Color_0 += (tex2D(Source, Coords[i].zw) * Blur_Weights[i]);
            Total_Weights += (Blur_Weights[i] * 2.0);
        }

        Output_Color_0 = Output_Color_0 / Total_Weights;
    }

    void Pre_Blur_0_PS(in float4 Position : SV_POSITION, in float4 Coords[8] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Gaussian_Blur(Sample_Normalized_Frame, Coords, Output_Color_0);
    }

    void Pre_Blur_1_PS(in float4 Position : SV_POSITION, in float4 Coords[8] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Gaussian_Blur(Shared_Resources::Sample_Common_1, Coords, Output_Color_0);
    }

    void Derivatives_PS(in float4 Position : SV_POSITION, in float4 Coords[2] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        // Bilinear 5x5 Sobel by CeeJayDK
        //   B_1 B_2
        // A_0     A_1
        // A_2     B_0
        //   C_0 C_1
        float2 A_0 = tex2D(Sample_Normalized_Frame, Coords[0].xw).xy * 4.0; // <-1.5, +0.5>
        float2 A_1 = tex2D(Sample_Normalized_Frame, Coords[0].yw).xy * 4.0; // <+1.5, +0.5>
        float2 A_2 = tex2D(Sample_Normalized_Frame, Coords[0].xz).xy * 4.0; // <-1.5, -0.5>
        float2 B_0 = tex2D(Sample_Normalized_Frame, Coords[0].yz).xy * 4.0; // <+1.5, -0.5>
        float2 B_1 = tex2D(Sample_Normalized_Frame, Coords[1].xw).xy * 4.0; // <-0.5, +1.5>
        float2 B_2 = tex2D(Sample_Normalized_Frame, Coords[1].yw).xy * 4.0; // <+0.5, +1.5>
        float2 C_0 = tex2D(Sample_Normalized_Frame, Coords[1].xz).xy * 4.0; // <-0.5, -1.5>
        float2 C_1 = tex2D(Sample_Normalized_Frame, Coords[1].yz).xy * 4.0; // <+0.5, -1.5>

        //    -1 0 +1
        // -1 -2 0 +2 +1
        // -2 -2 0 +2 +2
        // -1 -2 0 +2 +1
        //    -1 0 +1
        Output_Color_0.xy = ((B_2 + A_1 + B_0 + C_1) - (B_1 + A_0 + A_2 + C_0)) / 12.0;

        //    +1 +2 +1
        // +1 +2 +2 +2 +1
        //  0  0  0  0  0
        // -1 -2 -2 -2 -1
        //    -1 -2 -1
        Output_Color_0.zw = ((A_0 + B_1 + B_2 + A_1) - (A_2 + C_0 + C_1 + B_0)) / 12.0;
        Output_Color_0.xz *= rsqrt(dot(Output_Color_0.xz, Output_Color_0.xz) + 1.0);
        Output_Color_0.yw *= rsqrt(dot(Output_Color_0.yw, Output_Color_0.yw) + 1.0);
    }

    #define Max_Level 7
    #define E 1e-4

    void Coarse_Optical_Flow_TV(in float2 Coord, in float Level, in float2 UV, out float2 Optical_Flow)
    {
        Optical_Flow = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-4, Level - Max_Level), 1e-7);

        float4 Frames = tex2Dlod(Sample_Normalized_Frame, float4(Coord, 0.0, Level));

        // <Rx, Gx, Ry, Gy>
        float4 S_D = tex2Dlod(Shared_Resources::Sample_Common_1, float4(Coord, 0.0, Level));

        // <Rz, Gz>
        float2 T_D = Frames.xy - Frames.zw;

        // Calculate constancy term
        float C = 0.0;
        float2 Aii = 0.0;
        float Aij = 0.0;
        float2 Bi = 0.0;

        // Calculate forward motion vectors

        C = dot(T_D, 1.0);
        C = rsqrt(C * C + (E * E));

        Aii.x = 1.0 / (C * dot(S_D.xy, S_D.xy) + Alpha);
        Aii.y = 1.0 / (C * dot(S_D.zw, S_D.zw) + Alpha);

        Aij = C * dot(S_D.xy, S_D.zw);

        Bi.x = C * dot(S_D.xy, T_D);
        Bi.y = C * dot(S_D.zw, T_D);

        Optical_Flow.x = Aii.x * ((Alpha * UV.x) - (Aij * UV.y) - Bi.x);
        Optical_Flow.y = Aii.y * ((Alpha * UV.y) - (Aij * Optical_Flow.x) - Bi.y);
    }

    void Gradient_Average(in float2 Sample_NW,
                          in float2 Sample_NE,
                          in float2 Sample_SW,
                          in float2 Sample_SE,
                          out float Gradient,
                          out float2 Average)
    {
        // NW NE
        // SW SE
        float4 Sq_Gradient_UV = 0.0;
        Sq_Gradient_UV.xy = (Sample_NW + Sample_SW) - (Sample_NE + Sample_SE); // <IxU, IxV>
        Sq_Gradient_UV.zw = (Sample_NW + Sample_NE) - (Sample_SW + Sample_SE); // <IyU, IyV>
        Sq_Gradient_UV = Sq_Gradient_UV * 0.5;
        Gradient = rsqrt((dot(Sq_Gradient_UV.xzyw, Sq_Gradient_UV.xzyw) * 0.25) + (E * E));
        Average = (Sample_NW + Sample_NE + Sample_SW + Sample_SE) * 0.25;
    }

    void Process_Area(in float2 Sample_UV[9],
                      inout float4 UV_Gradient,
                      inout float2 Center_Average,
                      inout float2 UV_Average)
    {
        float Center_Gradient = 0.0;
        float4 Area_Gradient = 0.0;
        float2 Area_Average[4];
        float4 Gradient_UV = 0.0;
        float Sq_Gradient_UV = 0.0;

        // Center smoothness gradient and average
        // 0 3 6
        // 1 4 7
        // 2 5 8
        Gradient_UV.xy = (Sample_UV[0] + (Sample_UV[1] * 2.0) + Sample_UV[2]) - (Sample_UV[6] + (Sample_UV[7] * 2.0) + Sample_UV[8]); // <IxU, IxV>
        Gradient_UV.zw = (Sample_UV[0] + (Sample_UV[3] * 2.0) + Sample_UV[6]) - (Sample_UV[2] + (Sample_UV[5] * 2.0) + Sample_UV[8]); // <IxU, IxV>
        Sq_Gradient_UV = dot(Gradient_UV.xzyw / 4.0, Gradient_UV.xzyw / 4.0) * 0.25;
        Center_Gradient = rsqrt(Sq_Gradient_UV + (E * E));

        Center_Average += ((Sample_UV[0] + Sample_UV[6] + Sample_UV[2] + Sample_UV[8]) * 1.0);
        Center_Average += ((Sample_UV[3] + Sample_UV[1] + Sample_UV[7] + Sample_UV[5]) * 2.0);
        Center_Average += (Sample_UV[4] * 4.0);
        Center_Average = Center_Average / 16.0;

        // North-west gradient and average
        // 0 3 .
        // 1 4 .
        // . . .
        Gradient_Average(Sample_UV[0], Sample_UV[3], Sample_UV[1], Sample_UV[4], Area_Gradient[0], Area_Average[0]);

        // North-east gradient and average
        // . 3 6
        // . 4 7
        // . . .
        Gradient_Average(Sample_UV[3], Sample_UV[6], Sample_UV[4], Sample_UV[7], Area_Gradient[1], Area_Average[1]);

        // South-west gradient and average
        // . . .
        // 1 4 .
        // 2 5 .
        Gradient_Average(Sample_UV[1], Sample_UV[4], Sample_UV[2], Sample_UV[5], Area_Gradient[2], Area_Average[2]);

        // South-east and average
        // . . .
        // . 4 7
        // . 5 8
        Gradient_Average(Sample_UV[4], Sample_UV[7], Sample_UV[5], Sample_UV[8], Area_Gradient[3], Area_Average[3]);

        UV_Gradient = 0.5 * (Center_Gradient + Area_Gradient);
        UV_Average = (Area_Gradient[0] * Area_Average[0]) + (Area_Gradient[1] * Area_Average[1]) + (Area_Gradient[2] * Area_Average[2]) + (Area_Gradient[3] * Area_Average[3]);
    }

    void Optical_Flow_TV(in sampler2D SourceUV, in float4 Coords[3], in float Level, out float2 Optical_Flow)
    {
        Optical_Flow = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-4, Level - Max_Level), 1e-7);

        // Load textures

        float4 Frames = tex2Dlod(Sample_Normalized_Frame, float4(Coords[1].xz, 0.0, Level));

        // <Rx, Gx, Ry, Gy>
        float4 S_D = tex2Dlod(Shared_Resources::Sample_Common_1, float4(Coords[1].xz, 0.0, Level));

        // <Rz, Gz>
        float2 T_D = Frames.xy - Frames.zw;

        // Optical flow calculation

        float2 Sample_UV[9];
        float4 UV_Gradient = 0.0;
        float2 Center_Average = 0.0;
        float2 UV_Average = 0.0;

        // Sample_UV[i]
        // 0 3 6
        // 1 4 7
        // 2 5 8
        Sample_UV[0] = tex2D(SourceUV, Coords[0].xy).xy;
        Sample_UV[1] = tex2D(SourceUV, Coords[0].xz).xy;
        Sample_UV[2] = tex2D(SourceUV, Coords[0].xw).xy;
        Sample_UV[3] = tex2D(SourceUV, Coords[1].xy).xy;
        Sample_UV[4] = tex2D(SourceUV, Coords[1].xz).xy;
        Sample_UV[5] = tex2D(SourceUV, Coords[1].xw).xy;
        Sample_UV[6] = tex2D(SourceUV, Coords[2].xy).xy;
        Sample_UV[7] = tex2D(SourceUV, Coords[2].xz).xy;
        Sample_UV[8] = tex2D(SourceUV, Coords[2].xw).xy;

        Process_Area(Sample_UV, UV_Gradient, Center_Average, UV_Average);

        float C = 0.0;
        float2 Aii = 0.0;
        float Aij = 0.0;
        float2 Bi = 0.0;

        // Calculate forward motion vectors

        C = dot(S_D.xyzw, Center_Average.xyxy) + dot(T_D, 1.0);
        C = rsqrt(C * C + (E * E));

        Aii.x = 1.0 / (dot(UV_Gradient, 1.0) * Alpha + (C * dot(S_D.xy, S_D.xy)));
        Aii.y = 1.0 / (dot(UV_Gradient, 1.0) * Alpha + (C * dot(S_D.zw, S_D.zw)));

        Aij = C * dot(S_D.xy, S_D.zw);

        Bi.x = C * dot(S_D.xy, T_D);
        Bi.y = C * dot(S_D.zw, T_D);

        Optical_Flow.x = Aii.x * ((Alpha * UV_Average.x) - (Aij * Center_Average.y) - Bi.x);
        Optical_Flow.y = Aii.y * ((Alpha * UV_Average.y) - (Aij * Optical_Flow.x) - Bi.y);
    }

    void Level_4_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float2 Color : SV_TARGET0)
    {
        Coarse_Optical_Flow_TV(Coord, 6.5, 0.0, Color);
    }

    void Level_3_PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float2 Color : SV_TARGET0)
    {
        Optical_Flow_TV(Shared_Resources::Sample_Common_4, Coords, 4.5, Color);
    }

    void Level_2_PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float2 Color : SV_TARGET0)
    {
        Optical_Flow_TV(Shared_Resources::Sample_Common_3, Coords, 2.5, Color);
    }

    void Level_1_PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Optical_Flow_TV(Shared_Resources::Sample_Common_2, Coords, 0.5, Output_Color_0.rg);
        Output_Color_0.y *= -1.0;
        Output_Color_0.ba = float2(0.0, 1.0);
    }

    void Post_Blur_0_PS(in float4 Position : SV_POSITION, in float4 Coords[8] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Gaussian_Blur(Shared_Resources::Sample_Common_1, Coords, Output_Color_0);
        Output_Color_0.a = 1.0;
    }

    void Post_Blur_1_PS(in float4 Position : SV_POSITION, in float4 Coords[8] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Gaussian_Blur(Sample_Normalized_Frame, Coords, Output_Color_0);
        Output_Color_0.a = 1.0;
    }

    /*
        Cascaded median algorithm (Fig. 3.)
        Link: http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.64.7794&rep=rep1&type=pdf
        Title: Temporal video up-conversion on a next generation media-processor
        Authors: Jan-Willem van de Waerdt, Stamatis Vassiliadis, Erwin B. Bellers, and Johan G. Janssen
    */

    float4 Median(float4 A, float4 B, float4 C)
    {
        return min(max(min(A, B), C), max(A, B));
    }

    void Interpolate_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        float2 Texel_Size = 1.0 / BUFFER_SIZE_1;
        float2 Motion_Vectors = tex2Dlod(Shared_Resources::Sample_Common_1, float4(Coord, 0.0, _Mip_Bias)).xy * Texel_Size.xy;

        float4 Static_Left = tex2D(Sample_Frame_3, Coord);
        float4 Static_Right = tex2D(Sample_Frame_1, Coord);
        float4 Dynamic_Left = tex2D(Sample_Frame_3, Coord + Motion_Vectors);
        float4 Dynamic_Right = tex2D(Sample_Frame_1, Coord - Motion_Vectors);

        float4 Static_Average = lerp(Static_Left, Static_Right, 0.5);
        float4 Dynamic_Average = lerp(Dynamic_Left, Dynamic_Right, 0.5);

        float4 Static_Median = Median(Static_Left, Static_Right, Dynamic_Average);
        float4 Dynamic_Median = Median(Static_Average, Dynamic_Left, Dynamic_Right);
        float4 Motion_Filter = lerp(Static_Average, Dynamic_Average, Dynamic_Median);

        float4 Cascaded_Median = Median(Static_Median, Motion_Filter, Dynamic_Median);

        Output_Color_0 = lerp(Cascaded_Median, Dynamic_Average, 0.5);
        Output_Color_0.a = 1.0;
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
            VertexShader = Basic_VS;
            PixelShader = Store_Frame_3_PS;
            RenderTarget = Render_Frame_3;
        }

        pass Store_Frame_2
        {
            VertexShader = Basic_VS;
            PixelShader = Store_Frame_2_PS;
            RenderTarget = Render_Frame_2;
        }

        pass Store_Frame_1
        {
            VertexShader = Basic_VS;
            PixelShader = Current_Frame_1_PS;
            RenderTarget = Render_Frame_1;
        }

        // Store previous frames, normalize current

        pass Normalize_Frame
        {
            VertexShader = Basic_VS;
            PixelShader = Normalize_Frame_PS;
            RenderTarget0 = Render_Normalized_Frame;
        }

        // Gaussian blur

        pass Blur0
        {
            VertexShader = Blur_0_VS;
            PixelShader = Pre_Blur_0_PS;
            RenderTarget0 = Shared_Resources::Render_Common_1;
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
            RenderTarget0 = Shared_Resources::Render_Common_1;
        }

        // Trilinear Optical Flow, calculate 2 levels at a time

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Level_4_PS;
            RenderTarget0 = Shared_Resources::Render_Common_4;
        }

        pass
        {
            VertexShader = Sample_3x3_4_VS;
            PixelShader = Level_3_PS;
            RenderTarget0 = Shared_Resources::Render_Common_3;
        }

        pass
        {
            VertexShader = Sample_3x3_3_VS;
            PixelShader = Level_2_PS;
            RenderTarget0 = Shared_Resources::Render_Common_2;
        }

        pass
        {
            VertexShader = Sample_3x3_2_VS;
            PixelShader = Level_1_PS;
            RenderTarget0 = Shared_Resources::Render_Common_1;
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
            RenderTarget0 = Shared_Resources::Render_Common_1;
        }

        // Interpolate

        pass Interpolate
        {
            VertexShader = Basic_VS;
            PixelShader = Interpolate_PS;
            RenderTarget0 = Render_Interpolated_Frame;
        }
    }
}
