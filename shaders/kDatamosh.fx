
/*
    Color datamoshing shader

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

namespace Shared_Resources_Datamosh
{
    // Store convoluted normalized frame 1 and 3

    texture2D Render_Common_0
    {
        Width = BUFFER_WIDTH >> 1;
        Height = BUFFER_HEIGHT >> 1;
        Format = RG16F;
        MipLevels = 4;
    };

    sampler2D Sample_Common_0
    {
        Texture = Render_Common_0;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    // Normalized, prefiltered frames for processing

    texture2D Render_Common_1_A
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = RGBA16F;
        MipLevels = 8;
    };

    sampler2D Sample_Common_1_A
    {
        Texture = Render_Common_1_A;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Common_1_B
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = RGBA16F;
        MipLevels = 8;
    };

    sampler2D Sample_Common_1_B
    {
        Texture = Render_Common_1_B;
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

namespace Datamosh
{
    // Shader properties

    uniform float _Time < source = "timer"; >;

    uniform int _Block_Size <
        ui_category = "Datamosh";
        ui_type = "slider";
        ui_label = "Block Size";
        ui_min = 4;
        ui_max = 32;
    > = 16;

    uniform float _Entropy <
        ui_category = "Datamosh";
        ui_type = "slider";
        ui_label = "Entropy";
        ui_tooltip = "The larger value stronger noise and makes mosh last longer.";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.5;

    uniform float _Contrast <
        ui_category = "Datamosh";
        ui_type = "slider";
        ui_label = "Contrast";
        ui_tooltip = "Contrast of stripe-shaped noise.";
        ui_min = 0.0;
        ui_max = 4.0;
    > = 2.0;

    uniform float _Scale <
        ui_category = "Datamosh";
        ui_type = "slider";
        ui_label = "Scale";
        ui_tooltip = "Scale factor for velocity vectors.";
        ui_min = 0.0;
        ui_max = 4.0;
    > = 2.0;

    uniform float _Diffusion <
        ui_category = "Datamosh";
        ui_type = "slider";
        ui_label = "Diffusion";
        ui_tooltip = "Amount of random displacement.";
        ui_min = 0.0;
        ui_max = 4.0;
    > = 2.0;

    uniform float _Constraint <
        ui_type = "slider";
        ui_category = "Optical flow";
        ui_label = "Motion Threshold";
        ui_min = 0.0;
        ui_max = 2.0;
    > = 1.0;

    uniform float _Mip_Bias <
        ui_type = "drag";
        ui_category = "Optical flow";
        ui_label = "Optical flow mipmap bias";
        ui_min = 0.0;
    > = 0.0;

    uniform float _Blend_Factor <
        ui_type = "slider";
        ui_category = "Optical flow";
        ui_label = "Temporal Blending Factor";
        ui_min = 0.0;
        ui_Max = 0.9;
    > = 0.1;

    #ifndef LINEAR_SAMPLING
        #define LINEAR_SAMPLING 0
    #endif

    #if LINEAR_SAMPLING == 1
        #define _FILTER LINEAR
    #else
        #define _FILTER POINT
    #endif

    texture2D Render_Color : COLOR;

    sampler2D Sample_Color
    {
        Texture = Render_Color;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBTexture = TRUE;
        #endif
    };

    texture2D Render_Common_1_P
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D Sample_Common_1_P
    {
        Texture = Render_Common_1_P;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Optical_Flow
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = RG16F;
    };

    sampler2D Sample_Optical_Flow
    {
        Texture = Render_Optical_Flow;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };
    
    sampler2D Sample_Optical_Flow_Post
    {
        Texture = Shared_Resources_Datamosh::Render_Common_1_B;
        MagFilter = _FILTER;
        MinFilter = _FILTER;
    };

    texture2D Render_Accumulation
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = R16F;
    };

    sampler2D Sample_Accumulation
    {
        Texture = Render_Accumulation;
        MagFilter = _FILTER;
        MinFilter = _FILTER;
    };

    texture2D Render_Feedback
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
    };

    sampler2D Sample_Feedback
    {
        Texture = Render_Feedback;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBTexture = TRUE;
        #endif
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

    void Normalize_Frame_PS(in float4 Position : SV_POSITION, float2 Coord : TEXCOORD, out float2 Color : SV_TARGET0)
    {
        float4 Frame = max(tex2D(Sample_Color, Coord), exp2(-10.0));
        Color.xy = saturate(Frame.xy / dot(Frame.rgb, 1.0));
    }

    void Blit_Frame_PS(in float4 Position : SV_POSITION, float2 Coord : TEXCOORD, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = tex2D(Shared_Resources_Datamosh::Sample_Common_0, Coord);
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
        Gaussian_Blur(Shared_Resources_Datamosh::Sample_Common_1_A, Coords, Output_Color_0);
    }

    void Pre_Blur_1_PS(in float4 Position : SV_POSITION, in float4 Coords[8] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Gaussian_Blur(Shared_Resources_Datamosh::Sample_Common_1_B, Coords, Output_Color_0);
    }

    void Derivatives_PS(in float4 Position : SV_POSITION, in float4 Coords[2] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        // Bilinear 5x5 Sobel by CeeJayDK
        //   B_1 B_2
        // A_0     A_1
        // A_2     B_0
        //   C_0 C_1
        float2 A_0 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, Coords[0].xw).xy * 4.0; // <-1.5, +0.5>
        float2 A_1 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, Coords[0].yw).xy * 4.0; // <+1.5, +0.5>
        float2 A_2 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, Coords[0].xz).xy * 4.0; // <-1.5, -0.5>
        float2 B_0 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, Coords[0].yz).xy * 4.0; // <+1.5, -0.5>
        float2 B_1 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, Coords[1].xw).xy * 4.0; // <-0.5, +1.5>
        float2 B_2 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, Coords[1].yw).xy * 4.0; // <+0.5, +1.5>
        float2 C_0 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, Coords[1].xz).xy * 4.0; // <-0.5, -1.5>
        float2 C_1 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, Coords[1].yz).xy * 4.0; // <+0.5, -1.5>

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

        // Load textures
        float2 Current = tex2Dlod(Shared_Resources_Datamosh::Sample_Common_1_A, float4(Coord, 0.0, Level)).xy;
        float2 Previous = tex2Dlod(Sample_Common_1_P, float4(Coord, 0.0, Level)).xy;

        // <Rx, Gx, Ry, Gy>
        float4 S_D = tex2Dlod(Shared_Resources_Datamosh::Sample_Common_1_B, float4(Coord, 0.0, Level));

        // <Rz, Gz>
        float2 T_D = Current - Previous;

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
        float2 Current = tex2Dlod(Shared_Resources_Datamosh::Sample_Common_1_A, float4(Coords[1].xz, 0.0, Level)).xy;
        float2 Previous = tex2Dlod(Sample_Common_1_P, float4(Coords[1].xz, 0.0, Level)).xy;

        // <Rx, Gx, Ry, Gy>
        float4 S_D = tex2Dlod(Shared_Resources_Datamosh::Sample_Common_1_B, float4(Coords[1].xz, 0.0, Level));

        // <Rz, Gz>
        float2 T_D = Current - Previous;

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
        Optical_Flow_TV(Shared_Resources_Datamosh::Sample_Common_4, Coords, 4.5, Color);
    }

    void Level_2_PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float2 Color : SV_TARGET0)
    {
        Optical_Flow_TV(Shared_Resources_Datamosh::Sample_Common_3, Coords, 2.5, Color);
    }

    void Level_1_PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Optical_Flow_TV(Shared_Resources_Datamosh::Sample_Common_2, Coords, 0.5, Output_Color_0.rg);
        Output_Color_0.y *= -1.0;
        Output_Color_0.ba = float2(0.0, _Blend_Factor);
    }

    void Blit_Previous_PS(in float4 Position : SV_POSITION, float2 Coord : TEXCOORD, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = tex2D(Shared_Resources_Datamosh::Sample_Common_1_A, Coord);
    }

    void Post_Blur_0_PS(in float4 Position : SV_POSITION, in float4 Coords[8] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Gaussian_Blur(Sample_Optical_Flow, Coords, Output_Color_0);
        Output_Color_0.a = 1.0;
    }

    void Post_Blur_1_PS(in float4 Position : SV_POSITION, in float4 Coords[8] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Gaussian_Blur(Shared_Resources_Datamosh::Sample_Common_1_A, Coords, Output_Color_0);
        Output_Color_0.a = 1.0;
    }

    /*
        Color + BlendOp version of KinoDatamosh https://github.com/keijiro/KinoDatamosh

        This is free and unencumbered software released into the public domain.

        Anyone is free to copy, modify, publish, use, compile, sell, or
        distribute this software, either in source code form or as a compiled
        binary, for any purpose, commercial or non-commercial, and by any
        means.

        In jurisdictions that recognize copyright laws, the author or authors
        of this software dedicate any and all copyright interest in the
        software to the public domain. We make this dedication for the benefit
        of the public at large and to the detriment of our heirs and
        successors. We intend this dedication to be an overt act of
        relinquishment in perpetuity of all present and future rights to this
        software under copyright law.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
        EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
        MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
        IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
        OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
        ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
        OTHER DEALINGS IN THE SOFTWARE.

        For more information, please refer to <http://unlicense.org/>
    */

    float RandomNoise(float2 Coord)
    {
        float f = dot(float2(12.9898, 78.233), Coord);
        return frac(43758.5453 * sin(f));
    }

    void Accumulate_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        float Quality = 1.0 - _Entropy;
        float2 Time = float2(_Time, 0.0);

        // Random numbers
        float3 Random;
        Random.x = RandomNoise(Coord.xy + Time.xy);
        Random.y = RandomNoise(Coord.xy + Time.yx);
        Random.z = RandomNoise(Coord.yx - Time.xx);

        // Motion vector
        float2 Motion_Vectors = tex2Dlod(Sample_Optical_Flow_Post, float4(Coord, 0.0, _Mip_Bias)).xy;
        Motion_Vectors = Motion_Vectors * BUFFER_SIZE_1; // Normalized screen space -> Pixel coordinates
        Motion_Vectors *= _Scale;
        Motion_Vectors += (Random.xy - 0.5)  * _Diffusion; // Small random displacement (diffusion)
        Motion_Vectors = round(Motion_Vectors); // Pixel perfect snapping

        // Accumulates the amount of motion.
        float MotionVectorLength = length(Motion_Vectors);

        // - Simple update
        float UpdateAccumulation = min(MotionVectorLength, _Block_Size) * 0.005;
        UpdateAccumulation = saturate(UpdateAccumulation + Random.z * lerp(-0.02, 0.02, Quality));

        // - Reset to random level
        float ResetAccumulation = saturate(Random.z * 0.5 + Quality);

        // - Reset if the amount of motion is larger than the block size.
        Output_Color_0.rgb = MotionVectorLength > _Block_Size ? ResetAccumulation : UpdateAccumulation;
        Output_Color_0.a = MotionVectorLength > _Block_Size ? 0.0 : 1.0;
    }

    void Datamosh_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        const float2 DisplacementTexel = 1.0 / BUFFER_SIZE_1;
        const float Quality = 1.0 - _Entropy;

        // Random numbers
        float2 Time = float2(_Time, 0.0);
        float3 Random;
        Random.x = RandomNoise(Coord.xy + Time.xy);
        Random.y = RandomNoise(Coord.xy + Time.yx);
        Random.z = RandomNoise(Coord.yx - Time.xx);

        float2 Motion_Vectors = tex2Dlod(Sample_Optical_Flow_Post, float4(Coord, 0.0, _Mip_Bias)).xy;
        Motion_Vectors *= _Scale;

        float4 Source = tex2D(Sample_Color, Coord); // Color from the original image
        float Displacement = tex2D(Sample_Accumulation, Coord).r; // Displacement vector
        float4 Working = tex2D(Sample_Feedback, Coord - Motion_Vectors * DisplacementTexel);

        Motion_Vectors *= int2(BUFFER_WIDTH, BUFFER_HEIGHT); // Normalized screen space -> Pixel coordinates
        Motion_Vectors += (Random.xy - 0.5) * _Diffusion; // Small random displacement (diffusion)
        Motion_Vectors = round(Motion_Vectors); // Pixel perfect snapping
        Motion_Vectors *= (1.0 / int2(BUFFER_WIDTH, BUFFER_HEIGHT)); // Pixel coordinates -> Normalized screen space

        // Generate some pseudo random numbers.
        float RandomMotion = RandomNoise(Coord + length(Motion_Vectors));
        float4 RandomNumbers = frac(float4(1.0, 17.37135, 841.4272, 3305.121) * RandomMotion);

        // Generate noise patterns that look like DCT bases.
        float2 Frequency = Coord * DisplacementTexel * (RandomNumbers.x * 80.0 / _Contrast);
        // - Basis wave (vertical or horizontal)
        float DCT = cos(lerp(Frequency.x, Frequency.y, 0.5 < RandomNumbers.y));
        // - Random amplitude (the high freq, the less amp)
        DCT *= RandomNumbers.z * (1.0 - RandomNumbers.x) * _Contrast;

        // Conditional weighting
        // - DCT-ish noise: acc > 0.5
        float ConditionalWeight = (Displacement > 0.5) * DCT;
        // - Original image: rand < (Q * 0.8 + 0.2) && acc == 1.0
        ConditionalWeight = lerp(ConditionalWeight, 1.0, RandomNumbers.w < lerp(0.2, 1.0, Quality) * (Displacement > 1.0 - 1e-3));

        // - If the conditions above are not met, choose work.
        Output_Color_0 = lerp(Working, Source, ConditionalWeight);
    }

    void Copy_0_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = tex2D(Sample_Color, Coord);
        Output_Color_0.a = 1.0;
    }

    technique KinoDatamosh
    {
        // Normalize current frame

        pass Normalize_Frame
        {
            VertexShader = Basic_VS;
            PixelShader = Normalize_Frame_PS;
            RenderTarget0 = Shared_Resources_Datamosh::Render_Common_0;
        }

        pass Blit
        {
            VertexShader = Basic_VS;
            PixelShader = Blit_Frame_PS;
            RenderTarget = Shared_Resources_Datamosh::Render_Common_1_A;
        }

        // Gaussian blur

        pass Blur0
        {
            VertexShader = Blur_0_VS;
            PixelShader = Pre_Blur_0_PS;
            RenderTarget0 = Shared_Resources_Datamosh::Render_Common_1_B;
        }

        pass Blur1
        {
            VertexShader = Blur_1_VS;
            PixelShader = Pre_Blur_1_PS;
            RenderTarget0 = Shared_Resources_Datamosh::Render_Common_1_A; // Save this to store later
        }

        // Calculate spatial derivative pyramid

        pass Derivatives
        {
            VertexShader = Derivatives_VS;
            PixelShader = Derivatives_PS;
            RenderTarget0 = Shared_Resources_Datamosh::Render_Common_1_B;
        }

        // Trilinear Optical Flow, calculate 2 levels at a time

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Level_4_PS;
            RenderTarget0 = Shared_Resources_Datamosh::Render_Common_4;
        }

        pass
        {
            VertexShader = Sample_3x3_4_VS;
            PixelShader = Level_3_PS;
            RenderTarget0 = Shared_Resources_Datamosh::Render_Common_3;
        }

        pass
        {
            VertexShader = Sample_3x3_3_VS;
            PixelShader = Level_2_PS;
            RenderTarget0 = Shared_Resources_Datamosh::Render_Common_2;
        }

        pass
        {
            VertexShader = Sample_3x3_2_VS;
            PixelShader = Level_1_PS;
            RenderTarget0 = Render_Optical_Flow;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        // Store current convolved frame for next frame

        pass Blit
        {
            VertexShader = Basic_VS;
            PixelShader = Blit_Previous_PS;
            RenderTarget = Render_Common_1_P;
        }

        // Gaussian blur

        pass Blur0
        {
            VertexShader = Blur_0_VS;
            PixelShader = Post_Blur_0_PS;
            RenderTarget0 = Shared_Resources_Datamosh::Render_Common_1_A;
        }

        pass Blur1
        {
            VertexShader = Blur_1_VS;
            PixelShader = Post_Blur_1_PS;
            RenderTarget0 = Shared_Resources_Datamosh::Render_Common_1_B;
        }

        // Datamoshing

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Accumulate_PS;
            RenderTarget0 = Render_Accumulation;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = ONE;
            DestBlend = SRCALPHA; // The result about to accumulate
        }

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Datamosh_PS;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }

        // Copy frame for feedback

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Copy_0_PS;
            RenderTarget = Render_Feedback;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }
    }
}