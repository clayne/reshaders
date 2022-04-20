
/*
    Optical flow motion blur shader

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

#include "ReShade.fxh"

#ifndef USER_BUFFER_WIDTH
    #define USER_BUFFER_WIDTH 256
#endif

#ifndef USER_BUFFER_HEIGHT
    #define USER_BUFFER_HEIGHT 256
#endif

#if USER_BUFFER_WIDTH > (BUFFER_WIDTH >> 1)
    #error
#endif

#if USER_BUFFER_HEIGHT > (BUFFER_HEIGHT >> 1)
    #error
#endif

#define SIZE int2(USER_BUFFER_WIDTH, USER_BUFFER_HEIGHT)
#define BUFFER_SIZE_1 int2(SIZE >> 0)
#define BUFFER_SIZE_2 int2(SIZE >> 2)
#define BUFFER_SIZE_3 int2(SIZE >> 4)
#define BUFFER_SIZE_4 int2(SIZE >> 6)

#define TEXTURE(NAME, SIZE, FORMAT, LEVELS) \
    texture2D NAME                          \
    {                                       \
        Width = SIZE.x;                     \
        Height = SIZE.y;                    \
        Format = FORMAT;                    \
        MipLevels = LEVELS;                 \
    };

#define SAMPLER(NAME, TEXTURE) \
    sampler2D NAME             \
    {                          \
        Texture = TEXTURE;     \
        AddressU = MIRROR;     \
        AddressV = MIRROR;     \
        MagFilter = LINEAR;    \
        MinFilter = LINEAR;    \
        MipFilter = LINEAR;    \
    };

#define OPTION(DATA_TYPE, NAME, TYPE, CATEGORY, LABEL, MINIMUM, MAXIMUM, DEFAULT) \
    uniform DATA_TYPE NAME <                                                      \
        ui_type = TYPE;                                                           \
        ui_category = CATEGORY;                                                   \
        ui_label = LABEL;                                                         \
        ui_min = MINIMUM;                                                         \
        ui_max = MAXIMUM;                                                         \
    > = DEFAULT;

#define PASS(VERTEX_SHADER, PIXEL_SHADER, RENDER_TARGET) \
    pass                                                 \
    {                                                    \
        VertexShader = VERTEX_SHADER;                    \
        PixelShader = PIXEL_SHADER;                      \
        RenderTarget0 = RENDER_TARGET;                   \
    }

namespace Shared_Resources_Motion_Blur
{
    // Store convoluted normalized frame 1 and 3

    TEXTURE(Render_Common_0, int2(BUFFER_WIDTH >> 1, BUFFER_HEIGHT >> 1), RG16F, 4)
    SAMPLER(Sample_Common_0, Render_Common_0)

    // Normalized, prefiltered frames for processing

    TEXTURE(Render_Common_1_A, BUFFER_SIZE_1, RG16F, 8)
    SAMPLER(Sample_Common_1_A, Render_Common_1_A)

    TEXTURE(Render_Common_1_B, BUFFER_SIZE_1, RGBA16F, 8)
    SAMPLER(Sample_Common_1_B, Render_Common_1_B)

    TEXTURE(Render_Common_2, BUFFER_SIZE_2, RGBA16F, 1)
    SAMPLER(Sample_Common_2, Render_Common_2)

    TEXTURE(Render_Common_3, BUFFER_SIZE_3, RGBA16F, 1)
    SAMPLER(Sample_Common_3, Render_Common_3)

    TEXTURE(Render_Common_4, BUFFER_SIZE_4, RGBA16F, 1)
    SAMPLER(Sample_Common_4, Render_Common_4)
}

namespace Motion_Blur
{
    // Shader properties

    OPTION(float, _Constraint, "slider", "Optical flow", "Motion threshold", 0.0, 2.0, 1.0)
    OPTION(float, _Smoothness, "slider", "Optical flow", "Motion smoothness", 0.0, 2.0, 1.0)
    OPTION(float, _MipBias, "slider", "Optical flow", "Optical flow mipmap bias", 0.0, 7.0, 3.5)
    OPTION(float, _BlendFactor, "slider", "Optical flow", "Temporal blending factor", 0.0, 0.9, 0.1)

    OPTION(bool, _NormalMode, "radio", "Main", "Estimate normals", 0.0, 1.0, false)
    OPTION(float, _Scale, "slider", "Main", "Higher = more motion blur", 0.0, 1.0, 0.5)

    OPTION(bool, _FrameRateScaling, "radio", "Other", "Enable frame-rate scaling", 0.0, 1.0, false)
    OPTION(float, _TargetFrameRate, "drag", "Other", "Target frame-rate", 0.0, 144.0, 60.0)

    uniform int _DebugDisplay <
        ui_type = "combo";
        ui_category = "Debug";
        ui_items = " None\0 Display input color\0 Display velocity\0";
        ui_label = "Method";
        ui_tooltip = "Method Edge Detection";
    > = 0;

    uniform float _FrameTime < source = "frametime"; >;

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

    TEXTURE(Render_Common_1_P, BUFFER_SIZE_1, RG16F, 8)
    SAMPLER(Sample_Common_1_P, Render_Common_1_P)

    TEXTURE(Render_Optical_Flow, BUFFER_SIZE_1, RG16F, 1)
    SAMPLER(Sample_Optical_Flow, Render_Optical_Flow)

    // Vertex Shaders

    void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
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

    void Blur_0_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[8] : TEXCOORD0)
    {
        float2 CoordVS = 0.0;
        Basic_VS(ID, Position, CoordVS);
        TexCoords[0] = CoordVS.xyxy;

        for(int i = 1; i < 8; i++)
        {
            TexCoords[i].xy = CoordVS.xy - (BlurOffsets[i].yx / BUFFER_SIZE_1);
            TexCoords[i].zw = CoordVS.xy + (BlurOffsets[i].yx / BUFFER_SIZE_1);
        }
    }

    void Blur_1_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[8] : TEXCOORD0)
    {
        float2 CoordVS = 0.0;
        Basic_VS(ID, Position, CoordVS);
        TexCoords[0] = CoordVS.xyxy;

        for(int i = 1; i < 8; i++)
        {
            TexCoords[i].xy = CoordVS.xy - (BlurOffsets[i].xy / BUFFER_SIZE_1);
            TexCoords[i].zw = CoordVS.xy + (BlurOffsets[i].xy / BUFFER_SIZE_1);
        }
    }

    void Sample_3x3_VS(in uint ID : SV_VERTEXID, in float2 TexelSize, out float4 Position : SV_POSITION, out float4 TexCoords[3] : TEXCOORD0)
    {
        float2 CoordVS = 0.0;
        Basic_VS(ID, Position, CoordVS);
        // Sample locations:
        // [0].xy [1].xy [2].xy
        // [0].xz [1].xz [2].xz
        // [0].xw [1].xw [2].xw
        TexCoords[0] = CoordVS.xyyy + (float4(-1.0, 1.0, 0.0, -1.0) / TexelSize.xyyy);
        TexCoords[1] = CoordVS.xyyy + (float4(0.0, 1.0, 0.0, -1.0) / TexelSize.xyyy);
        TexCoords[2] = CoordVS.xyyy + (float4(1.0, 1.0, 0.0, -1.0) / TexelSize.xyyy);
    }

    void Sample_3x3_1_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_1, Position, TexCoords);
    }

    void Sample_3x3_2_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_2, Position, TexCoords);
    }

    void Sample_3x3_3_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_3, Position, TexCoords);
    }

    void Sample_3x3_4_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 TexCoords[3] : TEXCOORD0)
    {
        Sample_3x3_VS(ID, BUFFER_SIZE_4, Position, TexCoords);
    }

    void Derivatives_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 TexCoords[2] : TEXCOORD0)
    {
        float2 CoordVS = 0.0;
        Basic_VS(ID, Position, CoordVS);
        TexCoords[0] = CoordVS.xxyy + (float4(-1.5, 1.5, -0.5, 0.5) / BUFFER_SIZE_1.xxyy);
        TexCoords[1] = CoordVS.xxyy + (float4(-0.5, 0.5, -1.5, 1.5) / BUFFER_SIZE_1.xxyy);
    }

    // Pixel Shaders

    // Generate normals: https://github.com/crosire/reshade-shaders/blob/slim/Shaders/DisplayDepth.fx [MIT]
    // Normal encodes: https://knarkowicz.wordpress.com/2014/04/16/octahedron-normal-vector-encoding/
    // Contour pass: https://github.com/keijiro/KinoContour [MIT]

    float3 Get_Screen_Space_Normal(float2 TexCoord)
    {
        float3 Offset = float3(BUFFER_PIXEL_SIZE, 0.0);
        float2 PosCenter = TexCoord.xy;
        float2 PosNorth = PosCenter - Offset.zy;
        float2 PosEast = PosCenter + Offset.xz;

        float3 VertCenter = float3(PosCenter - 0.5, 1.0) * ReShade::GetLinearizedDepth(PosCenter);
        float3 VertNorth = float3(PosNorth - 0.5,  1.0) * ReShade::GetLinearizedDepth(PosNorth);
        float3 VertEast = float3(PosEast - 0.5,   1.0) * ReShade::GetLinearizedDepth(PosEast);

        return normalize(cross(VertCenter - VertNorth, VertCenter - VertEast));
    }

    float2 OctWrap(float2 V)
    {
        return (1.0 - abs(V.yx)) * (V.xy >= 0.0 ? 1.0 : -1.0);
    }

    float2 Encode(float3 Normal)
    {
        // max() divide based on
        Normal /= max(max(abs(Normal.x), abs(Normal.y)), abs(Normal.z));
        Normal.xy = Normal.z >= 0.0 ? Normal.xy : OctWrap(Normal.xy);
        Normal.xy = saturate(Normal.xy * 0.5 + 0.5);
        return Normal.xy;
    }

    float3 Decode(float2 f)
    {
        f = f * 2.0 - 1.0;
        // https://twitter.com/Stubbesaurus/status/937994790553227264
        float3 Normal = float3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
        float T = saturate(-Normal.z);
        Normal.xy += Normal.xy >= 0.0 ? -T : T;
        return normalize(Normal);
    }

    void Normalize_Frame_PS(in float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD, out float2 Color : SV_TARGET0)
    {
        if(_NormalMode)
        {
            Color.xy = Encode(Get_Screen_Space_Normal(TexCoord));
        }
        else
        {
            float4 Frame = max(tex2D(Sample_Color, TexCoord), exp2(-10.0));
            Color.xy = saturate(Frame.xy / dot(Frame.rgb, 1.0));
        }
    }

    void Blit_Frame_PS(in float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD, out float4 OutputColor0 : SV_TARGET0)
    {
        OutputColor0 = tex2D(Shared_Resources_Motion_Blur::Sample_Common_0, TexCoord);
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

    void Gaussian_Blur(in sampler2D Source, in float4 TexCoords[8], out float4 OutputColor0)
    {
        float TotalWeights = BlurWeights[0];
        OutputColor0 = (tex2D(Source, TexCoords[0].xy) * BlurWeights[0]);

        for(int i = 1; i < 8; i++)
        {
            OutputColor0 += (tex2D(Source, TexCoords[i].xy) * BlurWeights[i]);
            OutputColor0 += (tex2D(Source, TexCoords[i].zw) * BlurWeights[i]);
            TotalWeights += (BlurWeights[i] * 2.0);
        }

        OutputColor0  = OutputColor0 / TotalWeights;
    }

    void Pre_Blur_0_PS(in float4 Position : SV_POSITION, in float4 TexCoords[8] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Shared_Resources_Motion_Blur::Sample_Common_1_A, TexCoords, OutputColor0);
    }

    void Pre_Blur_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[8] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Shared_Resources_Motion_Blur::Sample_Common_1_B, TexCoords, OutputColor0);
    }

    void Derivatives_PS(in float4 Position : SV_POSITION, in float4 TexCoords[2] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        // Bilinear 5x5 Sobel by CeeJayDK
        //   B1 B2
        // A0     A1
        // A2     B0
        //   C0 C1
        float2 A0 = tex2D(Shared_Resources_Motion_Blur::Sample_Common_1_A, TexCoords[0].xw).xy * 4.0; // <-1.5, +0.5>
        float2 A1 = tex2D(Shared_Resources_Motion_Blur::Sample_Common_1_A, TexCoords[0].yw).xy * 4.0; // <+1.5, +0.5>
        float2 A2 = tex2D(Shared_Resources_Motion_Blur::Sample_Common_1_A, TexCoords[0].xz).xy * 4.0; // <-1.5, -0.5>
        float2 B0 = tex2D(Shared_Resources_Motion_Blur::Sample_Common_1_A, TexCoords[0].yz).xy * 4.0; // <+1.5, -0.5>
        float2 B1 = tex2D(Shared_Resources_Motion_Blur::Sample_Common_1_A, TexCoords[1].xw).xy * 4.0; // <-0.5, +1.5>
        float2 B2 = tex2D(Shared_Resources_Motion_Blur::Sample_Common_1_A, TexCoords[1].yw).xy * 4.0; // <+0.5, +1.5>
        float2 C0 = tex2D(Shared_Resources_Motion_Blur::Sample_Common_1_A, TexCoords[1].xz).xy * 4.0; // <-0.5, -1.5>
        float2 C1 = tex2D(Shared_Resources_Motion_Blur::Sample_Common_1_A, TexCoords[1].yz).xy * 4.0; // <+0.5, -1.5>

        //    -1 0 +1
        // -1 -2 0 +2 +1
        // -2 -2 0 +2 +2
        // -1 -2 0 +2 +1
        //    -1 0 +1
        float2 Ix = ((B2 + A1 + B0 + C1) - (B1 + A0 + A2 + C0)) / 12.0;

        //    +1 +2 +1
        // +1 +2 +2 +2 +1
        //  0  0  0  0  0
        // -1 -2 -2 -2 -1
        //    -1 -2 -1
        float2 Iy = ((A0 + B1 + B2 + A1) - (A2 + C0 + C1 + B0)) / 12.0;

        OutputColor0.xz = Ix;
        OutputColor0.yw = Iy;
        OutputColor0.xy = OutputColor0.xy * rsqrt(dot(OutputColor0.xy, OutputColor0.xy) + 1.0);
        OutputColor0.zw = OutputColor0.zw * rsqrt(dot(OutputColor0.zw, OutputColor0.zw) + 1.0);
    }

    /*
        https://github.com/Dtananaev/cv_opticalFlow

        Copyright (c) 2014-2015, Denis Tananaev All rights reserved.
        
        Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
        
        Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
        
        Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
        
        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    */

    #define MaxLevel 7
    #define E 1e-4 * _Smoothness

    void Coarse_Optical_Flow_TV(in float2 TexCoord, in float Level, in float4 UV, out float4 OpticalFlow)
    {
        OpticalFlow = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-3, Level - MaxLevel), 1e-7);

        // Load textures
        float2 Current = tex2Dlod(Shared_Resources_Motion_Blur::Sample_Common_1_A, float4(TexCoord, 0.0, Level)).xy;
        float2 Previous = tex2Dlod(Sample_Common_1_P, float4(TexCoord, 0.0, Level)).xy;

        // <Rx, Gx, Ry, Gy>
        float4 SD = tex2Dlod(Shared_Resources_Motion_Blur::Sample_Common_1_B, float4(TexCoord, 0.0, Level));

        // <Rz, Gz>
        float2 TD = Current - Previous;

        // Calculate constancy term
        float2 C = 0.0;
        float4 Aii = 0.0;
        float2 Aij = 0.0;
        float4 Bi = 0.0;

        // Calculate forward motion vectors
        C = rsqrt(TD.rg * TD.rg + (E * E));
        Aii = 1.0 / (C.rrgg * (SD.xyzw * SD.xyzw) + Alpha);
        Aij = C.rg * (SD.xz * SD.yw);
        Bi = C.rrgg * (SD.xyzw * TD.rrgg);

        OpticalFlow.xz = Aii.xz * ((Alpha * UV.xz) - (Aij.rg * UV.yw) - Bi.xz);
        OpticalFlow.yw = Aii.yw * ((Alpha * UV.yw) - (Aij.rg * OpticalFlow.xz) - Bi.yw);
    }

    void Gradient(in float2 SampleNW, in float2 SampleNE, in float2 SampleSW, in float2 SampleSE, out float Gradient)
    {
        // NW NE
        // SW SE
        float4 SqGradientUV[2];
        SqGradientUV[0].xy = (SampleNW + SampleSW) - (SampleNE + SampleSE); // <IxU, IxV>
        SqGradientUV[0].zw = (SampleNW + SampleNE) - (SampleSW + SampleSE); // <IyU, IyV>
        SqGradientUV[0] = SqGradientUV[0] * 0.5;
        Gradient = rsqrt((dot(SqGradientUV[0], SqGradientUV[0]) * 0.25) + (E * E));
    }

    void Area_Average(in float4 SampleNW, in float4 SampleNE, in float4 SampleSW, in float4 SampleSE, out float4 Color)
    {
        Color = (SampleNW + SampleNE + SampleSW + SampleSE) * 0.25;
    }

    void Process_Gradients(in float2 SampleUV[9], inout float4 AreaGrad, inout float4 UVGradient)
    {
        // Center smoothness gradient using compass
        // 0.xy  | 0.zw  | 1.xy  | 1.zw  | 2.xy  | 2.zw  | 3.xy  | 3.zw
        // .............................................................
        // 0 3 6 | - 3 6 | 0 - 6 | 0 3 - | 0 3 6 | - 3 6 | 0 - 6 | 0 3 -
        // - - - | 1 - 7 | 1 - 7 | 1 - 7 | - - - | 1 - 7 | 1 - 7 | 1 - 7
        // 2 5 8 | 2 5 - | 2 - 8 | - 5 8 | 2 5 8 | 2 5 - | 2 - 8 | - 5 8

        float4 PrewittUV[4];
        PrewittUV[0].xy = (SampleUV[0] + SampleUV[3] + SampleUV[6]) - (SampleUV[2] + SampleUV[5] + SampleUV[8]);
        PrewittUV[0].zw = (SampleUV[3] + SampleUV[6] + SampleUV[7]) - (SampleUV[1] + SampleUV[2] + SampleUV[5]);
        PrewittUV[1].xy = (SampleUV[0] + SampleUV[1] + SampleUV[2]) - (SampleUV[6] + SampleUV[7] + SampleUV[8]);
        PrewittUV[1].zw = (SampleUV[0] + SampleUV[3] + SampleUV[1]) - (SampleUV[7] + SampleUV[5] + SampleUV[8]);
        PrewittUV[2].xy = (SampleUV[2] + SampleUV[5] + SampleUV[8]) - (SampleUV[0] + SampleUV[3] + SampleUV[6]);
        PrewittUV[2].zw = (SampleUV[1] + SampleUV[2] + SampleUV[5]) - (SampleUV[3] + SampleUV[6] + SampleUV[7]);
        PrewittUV[3].xy = (SampleUV[6] + SampleUV[7] + SampleUV[8]) - (SampleUV[0] + SampleUV[1] + SampleUV[2]);
        PrewittUV[3].zw = (SampleUV[7] + SampleUV[5] + SampleUV[8]) - (SampleUV[0] + SampleUV[3] + SampleUV[1]);

        PrewittUV[0] = PrewittUV[0] / 3.0;
        PrewittUV[1] = PrewittUV[1] / 3.0;
        PrewittUV[2] = PrewittUV[2] / 3.0;
        PrewittUV[3] = PrewittUV[3] / 3.0;
        
        float2 MaxGradient[3];
        MaxGradient[0] = max(max(PrewittUV[0].xy, PrewittUV[0].zw), max(PrewittUV[1].xy, PrewittUV[1].zw));
        MaxGradient[1] = max(max(PrewittUV[2].xy, PrewittUV[2].zw), max(PrewittUV[3].xy, PrewittUV[3].zw));
        MaxGradient[2] = max(MaxGradient[0], MaxGradient[1]);
        float CenterGradient = rsqrt((dot(MaxGradient[2], MaxGradient[2]) * 0.25) + (E * E));

        // Area smoothness gradients
        // .............................
        //  [0]     [1]     [2]     [3]
        // 0 3 . | . 3 6 | . . . | . . .
        // 1 4 . | . 4 7 | 1 4 . | . 4 7
        // . . . | . . . | 2 5 . | . 5 8
        Gradient(SampleUV[0], SampleUV[3], SampleUV[1], SampleUV[4], AreaGrad[0]);
        Gradient(SampleUV[3], SampleUV[6], SampleUV[4], SampleUV[7], AreaGrad[1]);
        Gradient(SampleUV[1], SampleUV[4], SampleUV[2], SampleUV[5], AreaGrad[2]);
        Gradient(SampleUV[4], SampleUV[7], SampleUV[5], SampleUV[8], AreaGrad[3]);
        UVGradient = 0.5 * (CenterGradient + AreaGrad);
    }

    void Optical_Flow_TV(in sampler2D SourceUV, in float4 TexCoords[3], in float Level, out float4 OpticalFlow)
    {
        OpticalFlow = 0.0;
        const float Alpha = max(ldexp(_Constraint * 1e-3, Level - MaxLevel), 1e-7);

        // Load textures
        float2 Current = tex2Dlod(Shared_Resources_Motion_Blur::Sample_Common_1_A, float4(TexCoords[1].xz, 0.0, Level)).xy;
        float2 Previous = tex2Dlod(Sample_Common_1_P, float4(TexCoords[1].xz, 0.0, Level)).xy;

        // <Rx, Ry, Gx, Gy>
        float4 SD = tex2Dlod(Shared_Resources_Motion_Blur::Sample_Common_1_B, float4(TexCoords[1].xz, 0.0, Level));

        // <Rz, Gz>
        float2 TD = Current - Previous;

        // Optical flow calculation

        // <Ru, Rv, Gu, Gv>
        float4 SampleUV[9];
        float2 SampleUVR[9];
        float2 SampleUVG[9];

        // [0] = Red, [1] = Green
        float4 AreaGrad[2];
        float4 UVGradient[2];

        // <Ru, Rv, Gu, Gv>
        float4 AreaAvg[4];
        float4 CenterAverage;
        float4 UVAverage;

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

        [unroll]for(int i = 0; i < 9; i++)
        {
            SampleUVR[i] = SampleUV[i].xy;
            SampleUVG[i] = SampleUV[i].zw;
        }

        // Process area gradients in each patch, per plane

        Process_Gradients(SampleUVR, AreaGrad[0], UVGradient[0]);
        Process_Gradients(SampleUVG, AreaGrad[1], UVGradient[1]);

        // Calculate area + center averages of estimated vectors

        Area_Average(SampleUV[0], SampleUV[3], SampleUV[1], SampleUV[4], AreaAvg[0]);
        Area_Average(SampleUV[3], SampleUV[6], SampleUV[4], SampleUV[7], AreaAvg[1]);
        Area_Average(SampleUV[1], SampleUV[4], SampleUV[2], SampleUV[5], AreaAvg[2]);
        Area_Average(SampleUV[4], SampleUV[7], SampleUV[5], SampleUV[8], AreaAvg[3]);

        CenterAverage += ((SampleUV[0] + SampleUV[6] + SampleUV[2] + SampleUV[8]) * 1.0);
        CenterAverage += ((SampleUV[3] + SampleUV[1] + SampleUV[7] + SampleUV[5]) * 2.0);
        CenterAverage += (SampleUV[4] * 4.0);
        CenterAverage = CenterAverage / 16.0;

        // Calculate motion vectors

        float2 C = 0.0;
        float4 Aii = 0.0;
        float2 Aij = 0.0;
        float4 Bi = 0.0;

        C.r = dot(SD.xy, CenterAverage.xy) + TD.r;
        C.g = dot(SD.zw, CenterAverage.zw) + TD.g;
        C.rg = rsqrt(C.rg * C.rg + (E * E));

        Aii.xy = 1.0 / (dot(UVGradient[0], 1.0) * Alpha + (C.rr * (SD.xy * SD.xy)));
        Aii.zw = 1.0 / (dot(UVGradient[1], 1.0) * Alpha + (C.gg * (SD.zw * SD.zw)));

        Aij.xy = C.rg * (SD.xz * SD.yw);
        Bi = C.rrgg * (SD.xyzw * TD.rrgg);

        UVAverage.xy = (AreaGrad[0].xx * AreaAvg[0].xy) + (AreaGrad[0].yy * AreaAvg[1].xy) + (AreaGrad[0].zz * AreaAvg[2].xy) + (AreaGrad[0].ww * AreaAvg[3].xy);
        UVAverage.zw = (AreaGrad[1].xx * AreaAvg[0].zw) + (AreaGrad[1].yy * AreaAvg[1].zw) + (AreaGrad[1].zz * AreaAvg[2].zw) + (AreaGrad[1].ww * AreaAvg[3].zw);

        OpticalFlow.xz = Aii.xz * ((Alpha * UVAverage.xz) - (Aij.rg * CenterAverage.yw) - Bi.xz);
        OpticalFlow.yw = Aii.yw * ((Alpha * UVAverage.yw) - (Aij.rg * OpticalFlow.xz) - Bi.yw);
    }

    void Level_4_PS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 Color : SV_TARGET0)
    {
        Coarse_Optical_Flow_TV(TexCoord, 6.5, 0.0, Color);
    }

    void Level_3_PS(in float4 Position : SV_POSITION, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_TARGET0)
    {
        Optical_Flow_TV(Shared_Resources_Motion_Blur::Sample_Common_4, TexCoords, 4.5, Color);
    }

    void Level_2_PS(in float4 Position : SV_POSITION, in float4 TexCoords[3] : TEXCOORD0, out float4 Color : SV_TARGET0)
    {
        Optical_Flow_TV(Shared_Resources_Motion_Blur::Sample_Common_3, TexCoords, 2.5, Color);
    }

    void Level_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        float4 OpticalFlow = 0.0;
        Optical_Flow_TV(Shared_Resources_Motion_Blur::Sample_Common_2, TexCoords, 0.5, OpticalFlow);
        OutputColor0.rg = OpticalFlow.xy + OpticalFlow.zw;
        OutputColor0.ba = float2(0.0, _BlendFactor);
    }

    void Blit_Previous_PS(in float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD, out float4 OutputColor0 : SV_TARGET0)
    {
        OutputColor0 = tex2D(Shared_Resources_Motion_Blur::Sample_Common_1_A, TexCoord);
    }

    void Post_Blur_0_PS(in float4 Position : SV_POSITION, in float4 TexCoords[8] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Sample_Optical_Flow, TexCoords, OutputColor0);
        OutputColor0.a = 1.0;
    }

    void Post_Blur_1_PS(in float4 Position : SV_POSITION, in float4 TexCoords[8] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
    {
        Gaussian_Blur(Shared_Resources_Motion_Blur::Sample_Common_1_A, TexCoords, OutputColor0);
        OutputColor0.a = 1.0;
    }

    void Motion_BlurPS(in float4 Position : SV_POSITION, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
    {
        OutputColor0 = 0.0;
        const int Samples = 4;
        float Noise = frac(52.9829189 * frac(dot(Position.xy, float2(0.06711056, 0.00583715))));

        float FrameRate = 1e+3 / _FrameTime;
        float FrameTimeRatio = _TargetFrameRate / FrameRate;

        float2 Velocity = tex2Dlod(Shared_Resources_Motion_Blur::Sample_Common_1_B, float4(TexCoord, 0.0, _MipBias)).xy;

        float2 ScaledVelocity = (Velocity / BUFFER_SIZE_1) * _Scale;
        ScaledVelocity = (_FrameRateScaling) ?  ScaledVelocity / FrameTimeRatio : ScaledVelocity;

        for(int k = 0; k < Samples; ++k)
        {
            float2 Offset = ScaledVelocity * (Noise + k);
            OutputColor0 += tex2D(Sample_Color, (TexCoord + Offset));
            OutputColor0 += tex2D(Sample_Color, (TexCoord - Offset));
        }

        switch(_DebugDisplay)
        {
            case 0: // No debug
                OutputColor0 /= (Samples * 2.0);
                break;
            case 1: // Display input color
                OutputColor0 = tex2D(Shared_Resources_Motion_Blur::Sample_Common_0, TexCoord);
                break;
            case 2: // Display velocity
                OutputColor0 = float4(Velocity * 0.5 + 0.5, 0.0, 1.0);
                break;
        }
    }

    technique cMotionBlur
    {
        // Normalize current frame
        PASS(Basic_VS, Normalize_Frame_PS, Shared_Resources_Motion_Blur::Render_Common_0)

        // Scale frame
        PASS(Basic_VS, Blit_Frame_PS, Shared_Resources_Motion_Blur::Render_Common_1_A)

        // Gaussian blur
        PASS(Blur_0_VS, Pre_Blur_0_PS, Shared_Resources_Motion_Blur::Render_Common_1_B)
        PASS(Blur_1_VS, Pre_Blur_1_PS, Shared_Resources_Motion_Blur::Render_Common_1_A) // Save this to store later

        // Calculate spatial derivative pyramid
        PASS(Derivatives_VS, Derivatives_PS, Shared_Resources_Motion_Blur::Render_Common_1_B)

        // Trilinear Optical Flow, calculate 2 levels at a time
        PASS(Basic_VS, Level_4_PS, Shared_Resources_Motion_Blur::Render_Common_4)
        PASS(Sample_3x3_4_VS, Level_3_PS, Shared_Resources_Motion_Blur::Render_Common_3)
        PASS(Sample_3x3_3_VS, Level_2_PS, Shared_Resources_Motion_Blur::Render_Common_2)

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
        PASS(Basic_VS, Blit_Previous_PS, Render_Common_1_P)

        // Gaussian blur
        PASS(Blur_0_VS, Post_Blur_0_PS, Shared_Resources_Motion_Blur::Render_Common_1_A)
        PASS(Blur_1_VS, Post_Blur_1_PS, Shared_Resources_Motion_Blur::Render_Common_1_B)

        // Motion blur

        pass
        {
            VertexShader = Basic_VS;
            PixelShader = Motion_BlurPS;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }
    }
}