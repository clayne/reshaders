
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

#if RENDER_HIGH_QUALITY == 1
    #define SCREEN_SIZE uint2(BUFFER_WIDTH * 2, BUFFER_HEIGHT * 2)
#else
    #define SCREEN_SIZE uint2(BUFFER_WIDTH, BUFFER_HEIGHT)
#endif

namespace HornSchunck
{
    //Shader properties

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

    texture2D RenderCommon1a < pooled = true; >
    {
        Width = SCREEN_SIZE.x / 2;
        Height = SCREEN_SIZE.y / 2;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D SampleCommon1a
    {
        Texture = RenderCommon1a;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon1b < pooled = true; >
    {
        Width = SCREEN_SIZE.x / 2;
        Height = SCREEN_SIZE.y / 2;
        Format = RGBA16F;
        MipLevels = 8;
    };

    sampler2D SampleCommon1b
    {
        Texture = RenderCommon1b;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon1d < pooled = false; >
    {
        Width = SCREEN_SIZE.x / 2;
        Height = SCREEN_SIZE.y / 2;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D SampleCommon1d
    {
        Texture = RenderCommon1d;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon8 < pooled = true; >
    {
        Width = SCREEN_SIZE.x / 256;
        Height = SCREEN_SIZE.y / 256;
        Format = RG16F;
    };

    sampler2D SampleCommon8
    {
        Texture = RenderCommon8;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon7 < pooled = true; >
    {
        Width = SCREEN_SIZE.x / 128;
        Height = SCREEN_SIZE.y / 128;
        Format = RG16F;
    };

    sampler2D SampleCommon7
    {
        Texture = RenderCommon7;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon6 < pooled = true; >
    {
        Width = SCREEN_SIZE.x / 64;
        Height = SCREEN_SIZE.y / 64;
        Format = RG16F;
    };

    sampler2D SampleCommon6
    {
        Texture = RenderCommon6;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon5 < pooled = true; >
    {
        Width = SCREEN_SIZE.x / 32;
        Height = SCREEN_SIZE.y / 32;
        Format = RG16F;
    };

    sampler2D SampleCommon5
    {
        Texture = RenderCommon5;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon4 < pooled = true; >
    {
        Width = SCREEN_SIZE.x / 16;
        Height = SCREEN_SIZE.y / 16;
        Format = RG16F;
    };

    sampler2D SampleCommon4
    {
        Texture = RenderCommon4;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon3 < pooled = true; >
    {
        Width = SCREEN_SIZE.x / 8;
        Height = SCREEN_SIZE.y / 8;
        Format = RG16F;
    };

    sampler2D SampleCommon3
    {
        Texture = RenderCommon3;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon2 < pooled = true; >
    {
        Width = SCREEN_SIZE.x / 4;
        Height = SCREEN_SIZE.y / 4;
        Format = RG16F;
    };

    sampler2D SampleCommon2
    {
        Texture = RenderCommon2;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D RenderCommon1c
    {
        Width = SCREEN_SIZE.x / 2;
        Height = SCREEN_SIZE.y / 2;
        Format = RG16F;
    };

    sampler2D SampleCommon1c
    {
        Texture = RenderCommon1c;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    sampler2D SampleColorGamma
    {
        Texture = RenderColor;
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
        float2 TexCoord0;
        PostProcessVS(ID, Position, TexCoord0);
        const float2 PixelSize = 1.0 / uint2(SCREEN_SIZE.x / 2, SCREEN_SIZE.y / 2);
        Offsets = TexCoord0.xyxy + (float4(0.5, 0.5, -0.5, -0.5) * PixelSize.xyxy);
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
        const float Alpha = max(ldexp(_Constraint * 1e-5, Level - MaxLevel), 1e-7);
        float2 CurrentFrame = tex2D(SampleCommon1a, TexCoord).xy;
        float2 PreviousFrame = tex2D(SampleCommon1d, TexCoord).xy;

        // SpatialI = <Rx, Gx, Ry, Gy>
        float4 SpatialI = tex2D(SampleCommon1b, TexCoord);
        float2 TemporalI = CurrentFrame - PreviousFrame;

        /*
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

        // A11 = 1.0 / (Rx^2 + Gx^2 + a)
        // A22 = 1.0 / (Ry^2 + Gy^2 + a)
        // Aij = Rxy + Gxy
        float A11 = 1.0 / (dot(SpatialI.xy, SpatialI.xy) + Alpha);
        float A22 = 1.0 / (dot(SpatialI.zw, SpatialI.zw) + Alpha);
        float Aij = dot(SpatialI.xy, SpatialI.zw);

        // B1 = Rxt + Gxt
        // B2 = Ryt + Gyt
        float B1 = dot(SpatialI.xy, TemporalI);
        float B2 = dot(SpatialI.zw, TemporalI);

        // Gauss-Seidel (forward sweep, from 1...N)
        DUV.x = A11 * ((Alpha * UV.x - B1) - (UV.y * Aij));
        DUV.y = A22 * ((Alpha * UV.y - B2) - (DUV.x * Aij));
    }

    void NormalizePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        const float Minima = exp2(-10.0);
        float3 Color = max(tex2D(SampleColor, TexCoord).rgb, Minima);
        OutputColor0 = saturate(Color.xy / dot(Color, 1.0));
    }

    void DerivativesZPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        float2 CurrentFrame = tex2D(SampleCommon1a, TexCoord).xy;
        float2 PreviousFrame = tex2D(SampleCommon1d, TexCoord).xy;
        OutputColor0 = CurrentFrame - PreviousFrame;
    }

    void DerivativesXYPS(in float4 Position : SV_Position, in float4 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        float2 Sample0 = tex2D(SampleCommon1a, TexCoord.zy).xy; // (-x, +y)
        float2 Sample1 = tex2D(SampleCommon1a, TexCoord.xy).xy; // (+x, +y)
        float2 Sample2 = tex2D(SampleCommon1a, TexCoord.zw).xy; // (-x, -y)
        float2 Sample3 = tex2D(SampleCommon1a, TexCoord.xw).xy; // (+x, -y)
        OutputColor0.xy = ((Sample3 + Sample1) - (Sample2 + Sample0));
        OutputColor0.zw = ((Sample2 + Sample3) - (Sample0 + Sample1));
        OutputColor0 = OutputColor0 * 4.0;
    }

    void EstimateLevel8PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, 0.0, 7.0, OutputEstimation);
    }

    void EstimateLevel7PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, tex2D(SampleCommon8, TexCoord).xy, 6.0, OutputEstimation);
    }

    void EstimateLevel6PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, tex2D(SampleCommon7, TexCoord).xy, 5.0, OutputEstimation);
    }

    void EstimateLevel5PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, tex2D(SampleCommon6, TexCoord).xy, 4.0, OutputEstimation);
    }

    void EstimateLevel4PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, tex2D(SampleCommon5, TexCoord).xy, 3.0, OutputEstimation);
    }

    void EstimateLevel3PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, tex2D(SampleCommon4, TexCoord).xy, 2.0, OutputEstimation);
    }

    void EstimateLevel2PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputEstimation : SV_Target0)
    {
        OpticalFlow(TexCoord, tex2D(SampleCommon3, TexCoord).xy, 1.0, OutputEstimation);
    }

    void EstimateLevel1PS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0, out float4 OutputColor1 : SV_Target1)
    {
        OpticalFlow(TexCoord, tex2D(SampleCommon2, TexCoord).xy, 0.0, OutputColor0.xy);
        OutputColor0.ba = (0.0, _Blend);

        // Copy current convolved result to use at next frame
        OutputColor1 = tex2D(SampleCommon1a, TexCoord).rg;
        OutputColor1.ba = 0.0;
    }

    void VelocityShadingPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
    {
        float2 Velocity = tex2Dlod(SampleCommon1c, float4(TexCoord, 0.0, _MipBias)).xy;

        if(_NormalizedShading)
        {
            float VelocityLength = saturate(rsqrt(dot(Velocity, Velocity)));
            OutputColor0.rg = (Velocity * VelocityLength) * 0.5 + 0.5;
            OutputColor0.b = -dot(OutputColor0.rg, 1.0) * 0.5 + 1.0;
            OutputColor0.rgb /= max(max(OutputColor0.x, OutputColor0.y), OutputColor0.z);
            OutputColor0.a = 1.0;
        }
        else
        {
            OutputColor0 = float4(Velocity, 0.0, 1.0);
        }
    }

    technique cHornSchunck
    {
        // Normalize current frame

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = NormalizePS;
            RenderTarget0 = RenderCommon1a;
        }

        // Construct pyramids

        pass
        {
            VertexShader = DerivativesVS;
            PixelShader = DerivativesXYPS;
            RenderTarget0 = RenderCommon1b;
        }

        // Pyramidal estimation

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel8PS;
            RenderTarget0 = RenderCommon8;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel7PS;
            RenderTarget0 = RenderCommon7;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel6PS;
            RenderTarget0 = RenderCommon6;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel5PS;
            RenderTarget0 = RenderCommon5;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel4PS;
            RenderTarget0 = RenderCommon4;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel3PS;
            RenderTarget0 = RenderCommon3;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel2PS;
            RenderTarget0 = RenderCommon2;
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = EstimateLevel1PS;
            RenderTarget0 = RenderCommon1c;

            // Copy previous frame
            RenderTarget1 = RenderCommon1d;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        // Render result

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = VelocityShadingPS;
        }
    }
}
