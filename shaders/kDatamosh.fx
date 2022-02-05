
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

namespace DataMosh
{
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
        ui_min = 0.5;
        ui_max = 4.0;
    > = 1.0;

    uniform float _Scale <
        ui_category = "Datamosh";
        ui_type = "slider";
        ui_label = "Scale";
        ui_tooltip = "Scale factor for velocity vectors.";
        ui_min = 0.0;
        ui_max = 2.0;
    > = 0.8;

    uniform float _Diffusion <
        ui_category = "Datamosh";
        ui_type = "slider";
        ui_label = "Diffusion";
        ui_tooltip = "Amount of random displacement.";
        ui_min = 0.0;
        ui_max = 2.0;
    > = 0.4;

    uniform float _Detail <
        ui_category = "Motion Vectors";
        ui_type = "drag";
        ui_label = "Blockiness";
        ui_tooltip = "How blocky the motion vectors should be.";
        ui_min = 0.0;
    > = 4.5;

    uniform float _Constraint <
        ui_category = "Motion Vectors";
        ui_type = "drag";
        ui_label = "Constraint";
        ui_tooltip = "Higher = Smoother flow";
        ui_min = 0.0;
    > = 1.0;

    uniform float _BlendFactor <
        ui_category = "Motion Vectors";
        ui_type = "drag";
        ui_label = "Temporal Smoothing";
        ui_tooltip = "Higher = Less temporal noise";
        ui_min = 0.0;
        ui_max = 1.0;
    > = 0.25;

    #ifndef LINEAR_SAMPLING
        #define LINEAR_SAMPLING 0
    #endif

    #if LINEAR_SAMPLING == 1
        #define _FILTER LINEAR
    #else
        #define _FILTER POINT
    #endif

    #define _HALFSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)

    texture2D _RenderColor : COLOR;

    sampler2D _SampleColor
    {
        Texture = _RenderColor;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBTexture = TRUE;
        #endif
    };

    texture2D _RenderFrame0
    {
        Width = _HALFSIZE.x;
        Height = _HALFSIZE.y;
        Format = RG8;
        MipLevels = 8;
    };

    sampler2D _SampleFrame0
    {
        Texture = _RenderFrame0;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderDerivatives
    {
        Width = _HALFSIZE.x;
        Height = _HALFSIZE.y;
        Format = RGBA16F;
        MipLevels = 8;
    };

    sampler2D _SampleDerivatives
    {
        Texture = _RenderDerivatives;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderOpticalFlow
    {
        Width = _HALFSIZE.x;
        Height = _HALFSIZE.y;
        Format = RG16F;
        MipLevels = 8;
    };

    sampler2D _SampleOpticalFlow
    {
        Texture = _RenderOpticalFlow;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MinFilter = _FILTER;
        MagFilter = _FILTER;
    };

    texture2D _RenderAccumulation
    {
        Width = _HALFSIZE.x;
        Height = _HALFSIZE.y;
        Format = R16F;
    };

    sampler2D _SampleAccumulation
    {
        Texture = _RenderAccumulation;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MinFilter = _FILTER;
        MagFilter = _FILTER;
    };

    texture2D _RenderFrame1
    {
        Width = _HALFSIZE.x;
        Height = _HALFSIZE.y;
        Format = RG8;
        MipLevels = 8;
    };

    sampler2D _SampleFrame1
    {
        Texture = _RenderFrame1;
        AddressU = MIRROR;
        AddressV = MIRROR;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D _RenderFeedback
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
    };

    sampler2D _SampleFeedback
    {
        Texture = _RenderFeedback;
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

    void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
    {
        TexCoord.x = (ID == 2) ? 2.0 : 0.0;
        TexCoord.y = (ID == 1) ? 2.0 : 0.0;
        Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    }

    void DerivativesVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord : TEXCOORD0)
    {
        const float2 PixelSize = 0.5 / _HALFSIZE;
        const float4 PixelOffset = float4(PixelSize, -PixelSize);
        float2 TexCoord0 = 0.0;
        PostProcessVS(ID, Position, TexCoord0);
        TexCoord = TexCoord0.xyxy + PixelOffset;
    }

    /* [Pixel Shaders ] */

    void ConvertPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_Target0)
    {
        float3 Color = tex2D(_SampleColor, TexCoord).rgb;
        OutputColor0 = saturate(Color.xy / dot(Color, 1.0));
    }

    void DerivativesPS(in float4 Position : SV_Position, in float4 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        float2 Sample0 = tex2D(_SampleFrame0, TexCoord.zy).xy; // (-x, +y)
        float2 Sample1 = tex2D(_SampleFrame0, TexCoord.xy).xy; // (+x, +y)
        float2 Sample2 = tex2D(_SampleFrame0, TexCoord.zw).xy; // (-x, -y)
        float2 Sample3 = tex2D(_SampleFrame0, TexCoord.xw).xy; // (+x, -y)
        OutputColor0.xz = (Sample3 + Sample1) - (Sample2 + Sample0);
        OutputColor0.yw = (Sample0 + Sample1) - (Sample2 + Sample3);
        OutputColor0 *= 4.0;
    }

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

    void OpticalFlowPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        const float2 PixelSize = 2.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
        const float MaxLevel = 6.5;
        float2 UV;

        for(float Level = MaxLevel; Level > 0.0; Level--)
        {
            // .xy = Normalized Red Channel (x, y)
            // .zw = Normalized Green Channel (x, y)
            float4 SampleI = tex2Dlod(_SampleDerivatives, float4(TexCoord, 0.0, Level));

            // .xy = Current frame (r, g)
            // .zw = Previous frame (r, g)
            float4 SampleFrames;
            SampleFrames.xy = tex2Dlod(_SampleFrame0, float4(TexCoord, 0.0, Level)).rg;
            SampleFrames.zw = tex2Dlod(_SampleFrame1, float4(TexCoord, 0.0, Level)).rg;
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
            UV.x = Aii.x * ((Alpha * UV.x) - RHS.x - (UV.y * Aij));
            UV.y = Aii.y * ((Alpha * UV.y) - RHS.y - (UV.x * Aij));

            // Symmetric Gauss-Seidel (backward sweep, from N...1)
            UV.y = Aii.y * ((Alpha * UV.y) - RHS.y - (UV.x * Aij));
            UV.x = Aii.x * ((Alpha * UV.x) - RHS.x - (UV.y * Aij));
        }

        OutputColor0.xy = UV.xy;
        OutputColor0.ba = float2(1.0, _BlendFactor);
    }

    float RandomNoise(float2 TexCoord)
    {
        float f = dot(float2(12.9898, 78.233), TexCoord);
        return frac(43758.5453 * sin(f));
    }

    void AccumulatePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0, out float4 OutputColor1 : SV_Target1)
    {
        float Quality = 1.0 - _Entropy;
        float2 Time = float2(_Time, 0.0);

        // Random numbers
        float3 Random;
        Random.x = RandomNoise(TexCoord.xy + Time.xy);
        Random.y = RandomNoise(TexCoord.xy + Time.yx);
        Random.z = RandomNoise(TexCoord.yx - Time.xx);

        // Motion vector
        float2 MotionVectors = tex2Dlod(_SampleOpticalFlow, float4(TexCoord, 0.0, _Detail)).xy;
        MotionVectors *= _Scale;
        MotionVectors = MotionVectors * _HALFSIZE; // Normalized screen space -> Pixel coordinates
        MotionVectors += (Random.xy - 0.5)  * _Diffusion; // Small random displacement (diffusion)
        MotionVectors = round(MotionVectors); // Pixel perfect snapping

        // Accumulates the amount of motion.
        float MotionVectorLength = length(MotionVectors);

        // - Simple update
        float UpdateAccumulation = min(MotionVectorLength, _BlockSize) * 0.005;
        UpdateAccumulation = saturate(UpdateAccumulation + Random.z * lerp(-0.02, 0.02, Quality));

        // - Reset to random level
        float ResetAccumulation = saturate(Random.z * 0.5 + Quality);

        // - Reset if the amount of motion is larger than the block size.
        OutputColor0.rgb = MotionVectorLength > _BlockSize ? ResetAccumulation : UpdateAccumulation;
        OutputColor0.a = MotionVectorLength > _BlockSize ? 0.0 : 1.0;
        OutputColor1 = float4(tex2D(_SampleFrame0, TexCoord).rgb, 0.0);
    }

    void OutputPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        const float2 DisplacementTexel = 1.0 / _HALFSIZE;
        const float Quality = 1.0 - _Entropy;

        // Random numbers
        float2 Time = float2(_Time, 0.0);
        float3 Random;
        Random.x = RandomNoise(TexCoord.xy + Time.xy);
        Random.y = RandomNoise(TexCoord.xy + Time.yx);
        Random.z = RandomNoise(TexCoord.yx - Time.xx);

        float2 MotionVectors = tex2Dlod(_SampleOpticalFlow, float4(TexCoord, 0.0, _Detail)).xy;
        MotionVectors *= _Scale;

        float4 Source = tex2D(_SampleColor, TexCoord); // Color from the original image
        float Displacement = tex2D(_SampleAccumulation, TexCoord).r; // Displacement vector
        float4 Working = tex2D(_SampleFeedback, TexCoord - MotionVectors * DisplacementTexel);

        MotionVectors *= float2(BUFFER_WIDTH, BUFFER_HEIGHT); // Normalized screen space -> Pixel coordinates
        MotionVectors += (Random.xy - 0.5) * _Diffusion; // Small random displacement (diffusion)
        MotionVectors = round(MotionVectors); // Pixel perfect snapping
        MotionVectors *= float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT); // Pixel coordinates -> Normalized screen space

        // Generate some pseudo random numbers.
        float RandomMotion = RandomNoise(TexCoord + length(MotionVectors));
        float4 RandomNumbers = frac(float4(1.0, 17.37135, 841.4272, 3305.121) * RandomMotion);

        // Generate noise patterns that look like DCT bases.
        float2 Frequency = TexCoord * DisplacementTexel * (RandomNumbers.x * 80.0 / _Contrast);
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
        OutputColor0 = lerp(Working, Source, ConditionalWeight);
    }

    void BlitPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
    {
        OutputColor0 = tex2D(_SampleColor, TexCoord);
    }

    technique KinoDatamosh
    {
        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = ConvertPS;
            RenderTarget0 = _RenderFrame0;
        }

        pass
        {
            VertexShader = DerivativesVS;
            PixelShader = DerivativesPS;
            RenderTarget0 = _RenderDerivatives;
        }

        /*
            Smooth optical flow with BlendOps
            How it works:
                Src = Current optical flow
                Dest = Previous optical flow
                SRCALPHA = Blending weight between Src and Dest
                If SRCALPHA = 0.25, the blending would be
                Src * (1.0 - 0.25) + Dest * 0.25
                The previous flow's output gets quartered every frame
            Note:
                Disable ClearRenderTargets to blend with existing
                data in r_cflow before rendering
        */

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = OpticalFlowPS;
            RenderTarget0 = _RenderOpticalFlow;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = INVSRCALPHA;
            DestBlend = SRCALPHA;
        }

        /*
            I rewrote the last code so the GPU's ROP handles the accumulation:
                saturate(mv_len > _BlockSize ? acc_reset : acc_update);

            Remember...
                Src = PixelShader result
                Dest = Data from pointed RenderTarget
                (Src * SrcBlend) BlendOp (Dest * DestBlend)

            Therefore, pseudocode:
                if(mv_len > _BlockSize)
                {
                    // Clear previous result, but output the reset
                    (OUTPUT * ONE) + (Previous * ZERO);
                }
                else
                {
                    // Accumulate if false
                    (OUTPUT * ONE) + (Previous * ONE);
                }
        */

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = AccumulatePS;
            RenderTarget0 = _RenderAccumulation;
            RenderTarget1 = _RenderFrame1;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = ONE;
            DestBlend = SRCALPHA; // The result about to accumulate
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = OutputPS;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }

        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = BlitPS;
            RenderTarget = _RenderFeedback;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }
    }
}
