
/*
    Basic pyramidal Horn Schunck without pre and post filtering

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

namespace HornSchunck
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

    #ifndef RENDER_HIGH_QUALITY
        #define RENDER_HIGH_QUALITY 0
    #endif

    #if RENDER_HIGH_QUALITY == 1
        #define SCREEN_SIZE uint2(BUFFER_WIDTH * 2, BUFFER_HEIGHT * 2)
    #else
        #define SCREEN_SIZE uint2(BUFFER_WIDTH, BUFFER_HEIGHT)
    #endif

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

    texture2D _RenderData0
    {
        Width = SCREEN_SIZE.x / 2;
        Height = SCREEN_SIZE.y / 2;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D _SampleData0
    {
        Texture = _RenderData0;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderData1
    {
        Width = SCREEN_SIZE.x / 2;
        Height = SCREEN_SIZE.y / 2;
        Format = RGBA16F;
        MipLevels = 8;
    };

    sampler2D _SampleData1
    {
        Texture = _RenderData1;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderData2
    {
        Width = SCREEN_SIZE.x / 2;
        Height = SCREEN_SIZE.y / 2;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D _SampleData2
    {
        Texture = _RenderData2;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderTemporary7
    {
        Width = SCREEN_SIZE.x / 256;
        Height = SCREEN_SIZE.y / 256;
        Format = RG16F;
    };

    sampler2D _SampleTemporary7
    {
        Texture = _RenderTemporary7;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderTemporary6
    {
        Width = SCREEN_SIZE.x / 128;
        Height = SCREEN_SIZE.y / 128;
        Format = RG16F;
    };

    sampler2D _SampleTemporary6
    {
        Texture = _RenderTemporary6;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderTemporary5
    {
        Width = SCREEN_SIZE.x / 64;
        Height = SCREEN_SIZE.y / 64;
        Format = RG16F;
    };

    sampler2D _SampleTemporary5
    {
        Texture = _RenderTemporary5;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderTemporary4
    {
        Width = SCREEN_SIZE.x / 32;
        Height = SCREEN_SIZE.y / 32;
        Format = RG16F;
    };

    sampler2D _SampleTemporary4
    {
        Texture = _RenderTemporary4;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderTemporary3
    {
        Width = SCREEN_SIZE.x / 16;
        Height = SCREEN_SIZE.y / 16;
        Format = RG16F;
    };

    sampler2D _SampleTemporary3
    {
        Texture = _RenderTemporary3;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderTemporary2
    {
        Width = SCREEN_SIZE.x / 8;
        Height = SCREEN_SIZE.y / 8;
        Format = RG16F;
    };

    sampler2D _SampleTemporary2
    {
        Texture = _RenderTemporary2;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderTemporary1
    {
        Width = SCREEN_SIZE.x / 4;
        Height = SCREEN_SIZE.y / 4;
        Format = RG16F;
    };

    sampler2D _SampleTemporary1
    {
        Texture = _RenderTemporary1;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderTemporary0
    {
        Width = SCREEN_SIZE.x / 2;
        Height = SCREEN_SIZE.y / 2;
        Format = RG16F;
    };

    sampler2D _SampleTemporary0
    {
        Texture = _RenderTemporary0;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    // Vertex shaders

    void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
    {
        TexCoord.x = (ID == 2) ? 2.0 : 0.0;
        TexCoord.y = (ID == 1) ? 2.0 : 0.0;
        Position = TexCoord.xyxy * float4(2.0, -2.0, 0.0, 0.0) + float4(-1.0, 1.0, 0.0, 1.0);
    }

    void DerivativesVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 Offsets : TEXCOORD0)
    {
        const float2 PixelSize = 0.5 / float2(SCREEN_SIZE.x / 2, SCREEN_SIZE.y / 2);
        const float4 PixelOffset = float4(PixelSize, -PixelSize);
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        Offsets = TexCoord0.xyxy + PixelOffset;
    }

    // Pixel shaders

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
        float3 Color = max(tex2D(_SampleColor, TexCoord).rgb, 1e-7);
        OutputColor0 = saturate(Color.xy / dot(Color, 1.0));
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

    void EstimateLevel6PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, tex2D(_SampleTemporary7, TexCoord).xy, 6.0, OutputEstimation);
    }

    void EstimateLevel5PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, tex2D(_SampleTemporary6, TexCoord).xy, 5.0, OutputEstimation);
    }

    void EstimateLevel4PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, tex2D(_SampleTemporary5, TexCoord).xy, 4.0, OutputEstimation);
    }

    void EstimateLevel3PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, tex2D(_SampleTemporary4, TexCoord).xy, 3.0, OutputEstimation);
    }

    void EstimateLevel2PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, tex2D(_SampleTemporary3, TexCoord).xy, 2.0, OutputEstimation);
    }

    void EstimateLevel1PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, tex2D(_SampleTemporary2, TexCoord).xy, 1.0, OutputEstimation);
    }

    void EstimateLevel0PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, tex2D(_SampleTemporary1, TexCoord).xy, 0.0, OutputEstimation.xy);
        OutputEstimation.ba = (0.0, _Blend);
    }

    void VelocityShadingPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
    {
        float2 Velocity = tex2Dlod(_SampleTemporary0, float4(TexCoord, 0.0, _MipBias)).xy;

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

    technique cHornSchunck
    {
        // Copy previous frame

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = CopyPS;
            RenderTarget0 = _RenderData2;
        }

        // Normalize current frame

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = NormalizePS;
            RenderTarget0 = _RenderData0;
        }

        // Calculate derivative pyramid (to be removed)

        pass
        {
            VertexShader = DerivativesVS;
            PixelShader = DerivativesPS;
            RenderTarget0 = _RenderData1;
        }

        // Begin pyramidal estimation

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel7PS;
            RenderTarget0 = _RenderTemporary7;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel6PS;
            RenderTarget0 = _RenderTemporary6;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel5PS;
            RenderTarget0 = _RenderTemporary5;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel4PS;
            RenderTarget0 = _RenderTemporary4;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel3PS;
            RenderTarget0 = _RenderTemporary3;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel2PS;
            RenderTarget0 = _RenderTemporary2;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel1PS;
            RenderTarget0 = _RenderTemporary1;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel0PS;
            RenderTarget0 = _RenderTemporary0;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = VelocityShadingPS;
        }
    }
}
