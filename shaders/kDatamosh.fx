
/*
    Color Datamoshing

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

#define BUFFER_SIZE_0 int2(BUFFER_WIDTH >> 0, BUFFER_HEIGHT >> 0)
#define BUFFER_SIZE_1 int2(BUFFER_WIDTH >> 1, BUFFER_HEIGHT >> 1)
#define BUFFER_SIZE_2 int2(BUFFER_WIDTH >> 2, BUFFER_HEIGHT >> 2)
#define BUFFER_SIZE_3 int2(BUFFER_WIDTH >> 3, BUFFER_HEIGHT >> 3)
#define BUFFER_SIZE_4 int2(BUFFER_WIDTH >> 4, BUFFER_HEIGHT >> 4)
#define BUFFER_SIZE_5 int2(BUFFER_WIDTH >> 5, BUFFER_HEIGHT >> 5)
#define BUFFER_SIZE_6 int2(BUFFER_WIDTH >> 6, BUFFER_HEIGHT >> 6)
#define BUFFER_SIZE_7 int2(BUFFER_WIDTH >> 7, BUFFER_HEIGHT >> 7)
#define BUFFER_SIZE_8 int2(BUFFER_WIDTH >> 8, BUFFER_HEIGHT >> 8)

namespace Shared_Resources
{
    namespace RGBA16F
    {
        texture2D Render_Common_1 < pooled = true; >
        {
            Width = BUFFER_SIZE_1.x;
            Height = BUFFER_SIZE_1.y;
            Format = RGBA16F;
            MipLevels = 8;
        };
    }

    namespace RG16F
    {
        texture2D Render_Common_1 < pooled = true; >
        {
            Width = BUFFER_SIZE_1.x;
            Height = BUFFER_SIZE_1.y;
            Format = RG16F;
            MipLevels = 8;
        };

        texture2D Render_Common_2 < pooled = true; >
        {
            Width = BUFFER_SIZE_2.x;
            Height = BUFFER_SIZE_2.y;
            Format = RG16F;
        };

        texture2D Render_Common_3 < pooled = true; >
        {
            Width = BUFFER_SIZE_3.x;
            Height = BUFFER_SIZE_3.y;
            Format = RG16F;
        };

        texture2D Render_Common_4 < pooled = true; >
        {
            Width = BUFFER_SIZE_4.x;
            Height = BUFFER_SIZE_4.y;
            Format = RG16F;
        };

        texture2D Render_Common_5 < pooled = true; >
        {
            Width = BUFFER_SIZE_5.x;
            Height = BUFFER_SIZE_5.y;
            Format = RG16F;
        };

        texture2D Render_Common_6 < pooled = true; >
        {
            Width = BUFFER_SIZE_6.x;
            Height = BUFFER_SIZE_6.y;
            Format = RG16F;
        };

        texture2D Render_Common_7 < pooled = true; >
        {
            Width = BUFFER_SIZE_7.x;
            Height = BUFFER_SIZE_7.y;
            Format = RG16F;
        };

        texture2D Render_Common_8 < pooled = true; >
        {
            Width = BUFFER_SIZE_8.x;
            Height = BUFFER_SIZE_8.y;
            Format = RG16F;
        };
    }
}

namespace Optical_Flow
{
    // Shader properties

    uniform float _Time < source = "timer"; >;

    uniform int _BlockSize <
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
        ui_category = "Motion Vectors";
        ui_type = "drag";
        ui_label = "Constraint";
        ui_tooltip = "Higher = Smoother flow";
        ui_min = 0.0;
    > = 1.0;

    uniform float _Smoothness <
        ui_category = "Motion Vectors";
        ui_type = "drag";
        ui_label = "Motion Smoothness";
        ui_min = 0.0;
    > = 1.0;

    uniform float _Blend_Factor <
        ui_category = "Motion Vectors";
        ui_type = "drag";
        ui_label = "Temporal Smoothing";
        ui_tooltip = "Higher = Less temporal noise";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.25;

    uniform float _Mip_Bias <
        ui_category = "Motion Vectors";
        ui_type = "drag";
        ui_label = "Blockiness";
        ui_tooltip = "How blocky the motion vectors should be.";
        ui_min = 0.0;
    > = 3.5;

    #ifndef LINEAR_SAMPLING
        #define LINEAR_SAMPLING 0
    #endif

    #if LINEAR_SAMPLING == 1
        #define _FILTER LINEAR
    #else
        #define _FILTER POINT
    #endif

    // Textures and samplers

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

    sampler2D Sample_Common_RG16F_1a
    {
        Texture = Shared_Resources::RG16F::Render_Common_1;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D Sample_Common_RGBA16F_1a
    {
        Texture = Shared_Resources::RGBA16F::Render_Common_1;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderPreviousBuffer
    {
        Width = BUFFER_WIDTH / 2;
        Height = BUFFER_HEIGHT / 2;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D SamplePreviousBuffer
    {
        Texture = RenderPreviousBuffer;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D Sample_Common_RG16F_8
    {
        Texture = Shared_Resources::RG16F::Render_Common_8;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D Sample_Common_RG16F_7
    {
        Texture = Shared_Resources::RG16F::Render_Common_7;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D Sample_Common_RG16F_6
    {
        Texture = Shared_Resources::RG16F::Render_Common_6;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D Sample_Common_RG16F_5
    {
        Texture = Shared_Resources::RG16F::Render_Common_5;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D Sample_Common_RG16F_4
    {
        Texture = Shared_Resources::RG16F::Render_Common_4;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D Sample_Common_RG16F_3
    {
        Texture = Shared_Resources::RG16F::Render_Common_3;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D Sample_Common_RG16F_2
    {
        Texture = Shared_Resources::RG16F::Render_Common_2;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderVectors
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = RG16F;
    };

    sampler2D SampleVectors
    {
        Texture = RenderVectors;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
    };

    sampler2D SampleVectorsPost
    {
        Texture = Shared_Resources::RGBA16F::Render_Common_1;
        MagFilter = _FILTER;
        MinFilter = _FILTER;
    };

    texture2D RenderAccumulation
    {
        Width = BUFFER_SIZE_1.x;
        Height = BUFFER_SIZE_1.y;
        Format = R16F;
    };

    sampler2D SampleAccumulation
    {
        Texture = RenderAccumulation;
        MagFilter = _FILTER;
        MinFilter = _FILTER;
    };

    texture2D RenderFeedback
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
    };

    sampler2D SampleFeedback
    {
        Texture = RenderFeedback;
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

    void Median_Offsets(in float2 Coord, in float2 Pixel_Size, inout float4 Sample_Offsets[3])
    {
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        Sample_Offsets[0] = Coord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * Pixel_Size.xyyy);
        Sample_Offsets[1] = Coord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * Pixel_Size.xyyy);
        Sample_Offsets[2] = Coord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * Pixel_Size.xyyy);
    }

    void TentOffsets(in float2 Coord, in float2 Texel_Size, inout float4 Sample_Offsets[3])
    {
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        Sample_Offsets[0] = Coord.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) * Texel_Size.xyyy);
        Sample_Offsets[1] = Coord.xyyy + (float4(0.0, 1.0, 0.0, -1.0) * Texel_Size.xyyy);
        Sample_Offsets[2] = Coord.xyyy + (float4(1.0, 1.0, 0.0, -1.0) * Texel_Size.xyyy);
    }

    void Basic_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 Coord : TEXCOORD0)
    {
        Coord.x = (ID == 2) ? 2.0 : 0.0;
        Coord.y = (ID == 1) ? 2.0 : 0.0;
        Position = Coord.xyxy * float4(2.0, -2.0, 0.0, 0.0) + float4(-1.0, 1.0, 0.0, 1.0);
    }

    void Median_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Offsets[3] : TEXCOORD0)
    {
        float2 VS_Coord = 0.0;
        Basic_VS(ID, Position, VS_Coord);
        Median_Offsets(VS_Coord, 1.0 / int2(BUFFER_WIDTH >> 1, BUFFER_HEIGHT >> 1), Offsets);
    }

    void TentFilterVS(in uint ID, in float2 Texel_Size, inout float4 Position, inout float4 Offsets[3])
    {
        float2 VS_Coord = 0.0;
        Basic_VS(ID, Position, VS_Coord);
        TentOffsets(VS_Coord, Texel_Size, Offsets);
    }

    void TentFilter0VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_0, Position, Coord);
    }

    void TentFilter1VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_1, Position, Coord);
    }

    void TentFilter2VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_2, Position, Coord);
    }

    void TentFilter3VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_3, Position, Coord);
    }

    void TentFilter4VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_4, Position, Coord);
    }

    void TentFilter5VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_5, Position, Coord);
    }

    void TentFilter6VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_6, Position, Coord);
    }

    void TentFilter7VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_7, Position, Coord);
    }

    void TentFilter8VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coord[3] : TEXCOORD0)
    {
        TentFilterVS(ID, 1.0 / BUFFER_SIZE_8, Position, Coord);
    }

    void DerivativesVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coords[2] : TEXCOORD0)
    {
        float2 VS_Coord = 0.0;
        Basic_VS(ID, Position, VS_Coord);
        const float2 Pixel_Size = 1.0 / BUFFER_SIZE_1;
        Coords[0] = VS_Coord.xxyy + (float4(-1.5, 1.5, -0.5, 0.5) * Pixel_Size.xxyy);
        Coords[1] = VS_Coord.xxyy + (float4(-0.5, 0.5, -1.5, 1.5) * Pixel_Size.xxyy);
    }

    // Pixel shaders

    // Math functions: https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/MiniEngine/Core/Shaders/DoFMedianFilterCS.hlsl

    float4 Max_3(float4 a, float4 b, float4 c)
    {
        return max(max(a, b), c);
    }

    float4 Min_3(float4 a, float4 b, float4 c)
    {
        return min(min(a, b), c);
    }

    float4 Median_3(float4 a, float4 b, float4 c)
    {
        return clamp(a, min(b, c), max(b, c));
    }

    float4 Median_9(float4 x0, float4 x1, float4 x2,
                float4 x3, float4 x4, float4 x5,
                float4 x6, float4 x7, float4 x8)
    {
        float4 A = Max_3(Min_3(x0, x1, x2), Min_3(x3, x4, x5), Min_3(x6, x7, x8));
        float4 B = Min_3(Max_3(x0, x1, x2), Max_3(x3, x4, x5), Max_3(x6, x7, x8));
        float4 C = Median_3(Median_3(x0, x1, x2), Median_3(x3, x4, x5), Median_3(x6, x7, x8));
        return Median_3(A, B, C);
    }

    float4 Chroma(in sampler2D Source, in float2 Coord)
    {
        float4 Color;
        Color = tex2D(Source, Coord);
        Color = max(Color, exp2(-10.0));
        return saturate(Color / dot(Color.rgb, 1.0));
    }

    float4 TentFilterPS(sampler2D Source, float4 Offsets[3])
    {
        // Sample locations:
        // A_0 B_0 C_0
        // A_1 B_1 C_1
        // A_2 B_2 C_2
        float4 A_0 = tex2D(Source, Offsets[0].xy);
        float4 A_1 = tex2D(Source, Offsets[0].xz);
        float4 A_2 = tex2D(Source, Offsets[0].xw);
        float4 B_0 = tex2D(Source, Offsets[1].xy);
        float4 B_1 = tex2D(Source, Offsets[1].xz);
        float4 B_2 = tex2D(Source, Offsets[1].xw);
        float4 C_0 = tex2D(Source, Offsets[2].xy);
        float4 C_1 = tex2D(Source, Offsets[2].xz);
        float4 C_2 = tex2D(Source, Offsets[2].xw);
        return (((A_0 + C_0 + A_2 + C_2) * 1.0) + ((B_0 + A_1 + C_1 + B_2) * 2.0) + (B_1 * 4.0)) / 16.0;
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
            [A11 A12] [X1] = [B_1]
            [A21 A22] [X2] = [B_2]

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
        https://github.com/Dtananaev/cv_opticalFlow

        Copyright (c) 2014-2015, Denis Tananaev All rights reserved.

        Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

        Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

        Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    */

    #define Max_Level 7
    #define E _Smoothness * 2e-2

    void Coarse_Optical_Flow_TV(in float2 Coord, in float Level, in float2 UV, out float2 DUV)
    {
        DUV = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-4, Level - Max_Level), 1e-7);

        float2 CurrentFrame = tex2D(Sample_Common_RG16F_1a, Coord).xy;
        float2 PreviousFrame = tex2D(SamplePreviousBuffer, Coord).xy;

        // <Rx, Gx, Ry, Gy>
        float4 S_D = tex2D(Sample_Common_RGBA16F_1a, Coord);

        // <Rz, Gz>
        float2 T_D = CurrentFrame - PreviousFrame;

        // Calculate constancy term
        float C = 0.0;
        C = dot(T_D, 1.0);
        C = rsqrt(C * C + (E * E));

        float2 Aii = 0.0;
        Aii.x = 1.0 / (C * dot(S_D.xy, S_D.xy) + Alpha);
        Aii.y = 1.0 / (C * dot(S_D.zw, S_D.zw) + Alpha);
        float Aij = C * dot(S_D.xy, S_D.zw);

        float2 Bi = 0.0;
        Bi.x = C * dot(S_D.xy, T_D);
        Bi.y = C * dot(S_D.zw, T_D);

        // Gauss-Seidel (forward sweep, from 1...N)
        DUV.x = Aii.x * ((Alpha * UV.x) - (Aij * UV.y) - Bi.x);
        DUV.y = Aii.y * ((Alpha * UV.y) - (Aij * DUV.x) - Bi.y);
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

    void Optical_Flow_TV(in sampler2D SourceUV, in float4 Coords[3], in float Level, out float2 DUV)
    {
        DUV = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-4, Level - Max_Level), 1e-7);

        // Load textures

        float2 CurrentFrame = tex2D(Sample_Common_RG16F_1a, Coords[1].xz).xy;
        float2 PreviousFrame = tex2D(SamplePreviousBuffer, Coords[1].xz).xy;
        float4 S_D = tex2D(Sample_Common_RGBA16F_1a, Coords[1].xz); // <Rx, Gx, Ry, Gy>
        float2 T_D = CurrentFrame - PreviousFrame; // <Rz, Gz>

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

        // Calculate constancy term
        float C = 0.0;
        C = dot(S_D, Center_Average.xyxy) + dot(T_D, 1.0);
        C = rsqrt(C * C + (E * E));

        float2 Aii = 0.0;
        Aii.x = 1.0 / (dot(UV_Gradient, 1.0) * Alpha + (C * dot(S_D.xy, S_D.xy)));
        Aii.y = 1.0 / (dot(UV_Gradient, 1.0) * Alpha + (C * dot(S_D.zw, S_D.zw)));
        float Aij = dot(S_D.xy, S_D.zw);

        float2 Bi = 0.0;
        Bi.x = C * dot(S_D.xy, T_D);
        Bi.y = C * dot(S_D.zw, T_D);

        // Gauss-Seidel (forward sweep, from 1...N)
        DUV.x = Aii.x * ((Alpha * UV_Average.x) - (C * Aij * Center_Average.y) - Bi.x);
        DUV.y = Aii.y * ((Alpha * UV_Average.y) - (C * Aij * DUV.x) - Bi.y);
    }

    void NormalizePS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        // Sample locations:
        // A_0 B_0 C_0
        // A_1 B_1 C_1
        // A_2 B_2 C_2
        float4 A_0 = Chroma(Sample_Color, Coords[0].xy);
        float4 A_1 = Chroma(Sample_Color, Coords[0].xz);
        float4 A_2 = Chroma(Sample_Color, Coords[0].xw);
        float4 B_0 = Chroma(Sample_Color, Coords[1].xy);
        float4 B_1 = Chroma(Sample_Color, Coords[1].xz);
        float4 B_2 = Chroma(Sample_Color, Coords[1].xw);
        float4 C_0 = Chroma(Sample_Color, Coords[2].xy);
        float4 C_1 = Chroma(Sample_Color, Coords[2].xz);
        float4 C_2 = Chroma(Sample_Color, Coords[2].xw);
        Output_Color_0 = Median_9(A_0, B_0, C_0,
                            A_1, B_1, C_1,
                            A_2, B_2, C_2);
    }

    void PreDownsample2PS(in float4 Position : SV_POSITION, in float4 Coord[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = TentFilterPS(Sample_Common_RG16F_1a, Coord);
    }

    void PreDownsample3PS(in float4 Position : SV_POSITION, in float4 Coord[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = TentFilterPS(Sample_Common_RG16F_2, Coord);
    }

    void PreDownsample4PS(in float4 Position : SV_POSITION, in float4 Coord[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = TentFilterPS(Sample_Common_RG16F_3, Coord);
    }

    void PreUpsample3PS(in float4 Position : SV_POSITION, in float4 Coord[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = TentFilterPS(Sample_Common_RG16F_4, Coord);
    }

    void PreUpsample2PS(in float4 Position : SV_POSITION, in float4 Coord[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = TentFilterPS(Sample_Common_RG16F_3, Coord);
    }

    void PreUpsample1PS(in float4 Position : SV_POSITION, in float4 Coord[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = TentFilterPS(Sample_Common_RG16F_2, Coord);
    }

    void DerivativesPS(in float4 Position : SV_POSITION, in float4 Coords[2] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        // Bilinear 5x5 Sobel by CeeJayDK
        //   B_1 B_2
        // A_0     A_1
        // A_2     B_0
        //   C_0 C_1
        float2 A_0 = tex2D(Sample_Common_RG16F_1a, Coords[0].xw).xy * 4.0; // <-1.5, +0.5>
        float2 A_1 = tex2D(Sample_Common_RG16F_1a, Coords[0].yw).xy * 4.0; // <+1.5, +0.5>
        float2 A_2 = tex2D(Sample_Common_RG16F_1a, Coords[0].xz).xy * 4.0; // <-1.5, -0.5>
        float2 B_0 = tex2D(Sample_Common_RG16F_1a, Coords[0].yz).xy * 4.0; // <+1.5, -0.5>
        float2 B_1 = tex2D(Sample_Common_RG16F_1a, Coords[1].xw).xy * 4.0; // <-0.5, +1.5>
        float2 B_2 = tex2D(Sample_Common_RG16F_1a, Coords[1].yw).xy * 4.0; // <+0.5, +1.5>
        float2 C_0 = tex2D(Sample_Common_RG16F_1a, Coords[1].xz).xy * 4.0; // <-0.5, -1.5>
        float2 C_1 = tex2D(Sample_Common_RG16F_1a, Coords[1].yz).xy * 4.0; // <+0.5, -1.5>

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

    void EstimateLevel8PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float2 Output_Color_0 : SV_TARGET0)
    {
        Coarse_Optical_Flow_TV(Coord, 7.0, 0.0, Output_Color_0);
    }

    void EstimateLevel7PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float2 Output_Color_0 : SV_TARGET0)
    {
        Optical_Flow_TV(Sample_Common_RG16F_8, Coords, 6.0, Output_Color_0);
    }

    void EstimateLevel6PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float2 Output_Color_0 : SV_TARGET0)
    {
        Optical_Flow_TV(Sample_Common_RG16F_7, Coords, 5.0, Output_Color_0);
    }

    void EstimateLevel5PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float2 Output_Color_0 : SV_TARGET0)
    {
        Optical_Flow_TV(Sample_Common_RG16F_6, Coords, 4.0, Output_Color_0);
    }

    void EstimateLevel4PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float2 Output_Color_0 : SV_TARGET0)
    {
        Optical_Flow_TV(Sample_Common_RG16F_5, Coords, 3.0, Output_Color_0);
    }

    void EstimateLevel3PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float2 Output_Color_0 : SV_TARGET0)
    {
        Optical_Flow_TV(Sample_Common_RG16F_4, Coords, 2.0, Output_Color_0);
    }

    void EstimateLevel2PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float2 Output_Color_0 : SV_TARGET0)
    {
        Optical_Flow_TV(Sample_Common_RG16F_3, Coords, 1.0, Output_Color_0);
    }

    void EstimateLevel1PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Optical_Flow_TV(Sample_Common_RG16F_2, Coords, 0.0, Output_Color_0.xy);
        Output_Color_0.xy *= float2(1.0, -1.0);
        Output_Color_0.ba = (0.0, _Blend_Factor);
    }

    void PostDownsample2PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = TentFilterPS(SampleVectors, Coords);
    }

    void PostDownsample3PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = TentFilterPS(Sample_Common_RG16F_2, Coords);
    }

    void PostDownsample4PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = TentFilterPS(Sample_Common_RG16F_3, Coords);
    }

    void PostUpsample3PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = TentFilterPS(Sample_Common_RG16F_4, Coords);
    }

    void PostUpsample2PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = TentFilterPS(Sample_Common_RG16F_3, Coords);
    }

    void PostUpsample1PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0, out float4 Output_Color_1 : SV_TARGET1)
    {
        Output_Color_0 = TentFilterPS(Sample_Common_RG16F_2, Coords);

        // Copy current convolved result to use at next frame
        Output_Color_1 = tex2D(Sample_Common_RG16F_1a, Coords[1].xz).rg;
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

    void AccumulatePS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        float Quality = 1.0 - _Entropy;
        float2 Time = float2(_Time, 0.0);

        // Random numbers
        float3 Random;
        Random.x = RandomNoise(Coord.xy + Time.xy);
        Random.y = RandomNoise(Coord.xy + Time.yx);
        Random.z = RandomNoise(Coord.yx - Time.xx);

        // Motion vector
        float2 Motion_Vectors = tex2Dlod(SampleVectorsPost, float4(Coord, 0.0, _Mip_Bias)).xy;
        Motion_Vectors = Motion_Vectors * BUFFER_SIZE_1; // Normalized screen space -> Pixel coordinates
        Motion_Vectors *= _Scale;
        Motion_Vectors += (Random.xy - 0.5)  * _Diffusion; // Small random displacement (diffusion)
        Motion_Vectors = round(Motion_Vectors); // Pixel perfect snapping

        // Accumulates the amount of motion.
        float MotionVectorLength = length(Motion_Vectors);

        // - Simple update
        float UpdateAccumulation = min(MotionVectorLength, _BlockSize) * 0.005;
        UpdateAccumulation = saturate(UpdateAccumulation + Random.z * lerp(-0.02, 0.02, Quality));

        // - Reset to random level
        float ResetAccumulation = saturate(Random.z * 0.5 + Quality);

        // - Reset if the amount of motion is larger than the block size.
        Output_Color_0.rgb = MotionVectorLength > _BlockSize ? ResetAccumulation : UpdateAccumulation;
        Output_Color_0.a = MotionVectorLength > _BlockSize ? 0.0 : 1.0;
    }

    void DatamoshPS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        const float2 DisplacementTexel = 1.0 / BUFFER_SIZE_1;
        const float Quality = 1.0 - _Entropy;

        // Random numbers
        float2 Time = float2(_Time, 0.0);
        float3 Random;
        Random.x = RandomNoise(Coord.xy + Time.xy);
        Random.y = RandomNoise(Coord.xy + Time.yx);
        Random.z = RandomNoise(Coord.yx - Time.xx);

        float2 Motion_Vectors = tex2Dlod(SampleVectorsPost, float4(Coord, 0.0, _Mip_Bias)).xy;
        Motion_Vectors *= _Scale;

        float4 Source = tex2D(Sample_Color, Coord); // Color from the original image
        float Displacement = tex2D(SampleAccumulation, Coord).r; // Displacement vector
        float4 Working = tex2D(SampleFeedback, Coord - Motion_Vectors * DisplacementTexel);

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

    void Copy0PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
    {
        Output_Color_0 = tex2D(Sample_Color, Coord);
    }

    technique KinoDatamosh
    {
        // Normalize current frame

        pass
        {
            VertexShader = Median_VS;
            PixelShader = NormalizePS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_1;
        }

        // Pre-process dual-filter blur

        pass
        {
            VertexShader = TentFilter1VS;
            PixelShader = PreDownsample2PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = PreDownsample3PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_3;
        }

        pass
        {
            VertexShader = TentFilter3VS;
            PixelShader = PreDownsample4PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_4;
        }

        pass
        {
            VertexShader = TentFilter4VS;
            PixelShader = PreUpsample3PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_3;
        }

        pass
        {
            VertexShader = TentFilter3VS;
            PixelShader = PreUpsample2PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = PreUpsample1PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_1;
        }

        // Construct pyramids

        pass
        {
            VertexShader = DerivativesVS;
            PixelShader = DerivativesPS;
            RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_1;
        }

        // Pyramidal estimation

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = EstimateLevel8PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_8;
        }

        pass
        {
            VertexShader = TentFilter8VS;
            PixelShader = EstimateLevel7PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_7;
        }

        pass
        {
            VertexShader = TentFilter7VS;
            PixelShader = EstimateLevel6PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_6;
        }

        pass
        {
            VertexShader = TentFilter6VS;
            PixelShader = EstimateLevel5PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_5;
        }

        pass
        {
            VertexShader = TentFilter5VS;
            PixelShader = EstimateLevel4PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_4;
        }

        pass
        {
            VertexShader = TentFilter4VS;
            PixelShader = EstimateLevel3PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_3;
        }

        pass
        {
            VertexShader = TentFilter3VS;
            PixelShader = EstimateLevel2PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = EstimateLevel1PS;
            RenderTarget0 = RenderVectors;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        // Post-process dual-filter blur

        pass
        {
            VertexShader = TentFilter1VS;
            PixelShader = PostDownsample2PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = PostDownsample3PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_3;
        }

        pass
        {
            VertexShader = TentFilter3VS;
            PixelShader = PostDownsample4PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_4;
        }

        pass
        {
            VertexShader = TentFilter4VS;
            PixelShader = PostUpsample3PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_3;
        }

        pass
        {
            VertexShader = TentFilter3VS;
            PixelShader = PostUpsample2PS;
            RenderTarget0 = Shared_Resources::RG16F::Render_Common_2;
        }

        pass
        {
            VertexShader = TentFilter2VS;
            PixelShader = PostUpsample1PS;
            RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_1;

            // Copy previous frame
            RenderTarget1 = RenderPreviousBuffer;
        }

        // Datamoshing

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = AccumulatePS;
            RenderTarget0 = RenderAccumulation;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = ONE;
            DestBlend = SRCALPHA; // The result about to accumulate
        }

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = DatamoshPS;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }

        // Copy frame for feedback

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Copy0PS;
            RenderTarget = RenderFeedback;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }
    }
}
