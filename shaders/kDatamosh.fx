
/*
    Color + BlendOp version of KinoDatamosh https://github.com/keijiro/KinoDatamosh

    Copyright (C) 2016 Keijiro Takahashi

    Permission is hereby granted, free of charge, to any person obtaining a copy of
    this software and associated documentation files (the "Software"), to deal in
    the Software without restriction, including without limitation the rights to
    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
    the Software, and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
    FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
    COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
    IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

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
> = 0.0;

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
> = 0.5;

#ifndef LINEAR_SAMPLING
    #define LINEAR_SAMPLING 0
#endif

#if LINEAR_SAMPLING == 1
    #define MFILTER MinFilter = LINEAR; MagFilter = LINEAR
#else
    #define MFILTER MinFilter = POINT; MagFilter = POINT
#endif

#define CONST_LOG2(x) (\
    (uint((x)  & 0xAAAAAAAA) != 0) | \
    (uint(((x) & 0xFFFF0000) != 0) << 4) | \
    (uint(((x) & 0xFF00FF00) != 0) << 3) | \
    (uint(((x) & 0xF0F0F0F0) != 0) << 2) | \
    (uint(((x) & 0xCCCCCCCC) != 0) << 1))

#define BIT2_LOG2(x)  ((x) | (x) >> 1)
#define BIT4_LOG2(x)  (BIT2_LOG2(x) | BIT2_LOG2(x) >> 2)
#define BIT8_LOG2(x)  (BIT4_LOG2(x) | BIT4_LOG2(x) >> 4)
#define BIT16_LOG2(x) (BIT8_LOG2(x) | BIT8_LOG2(x) >> 8)
#define LOG2(x)       (CONST_LOG2((BIT16_LOG2(x) >> 1) + 1))
#define RMAX(x, y)     x ^ ((x ^ y) & -(x < y)) // max(x, y)

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1

texture2D _RenderColor : COLOR;

texture2D _RenderPreviousBuffer
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    Format = RG16F;
    MipLevels = RSIZE;
};

texture2D _RenderCurrentBuffer
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    Format = R16F;
    MipLevels = RSIZE;
};

texture2D _RenderDataMoshDerivatives
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    Format = RG16F;
    MipLevels = RSIZE;
};

texture2D _RenderDataMoshOpticalFlow
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    Format = RG16F;
    MipLevels = RSIZE;
};

texture2D _RenderAccumulation
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    Format = R16F;
};

texture2D _RenderCopy
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA8;
};

sampler2D _SampleColor
{
    Texture = _RenderColor;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = TRUE;
};

sampler2D _SamplePreviousBuffer
{
    Texture = _RenderPreviousBuffer;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D _SampleCurrentBuffer
{
    Texture = _RenderCurrentBuffer;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D _SampleDerivatives
{
    Texture = _RenderDataMoshDerivatives;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D _SampleOpticalFlow
{
    Texture = _RenderDataMoshOpticalFlow;
    MFILTER;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D _SampleAccumulation
{
    Texture = _RenderAccumulation;
    MFILTER;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D _SampleCopy
{
    Texture = _RenderCopy;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = TRUE;
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void DerivativesVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets : TEXCOORD1)
{
    const float2 PixelSize = 0.5 / DSIZE;
    const float4 PixelOffset = float4(PixelSize, -PixelSize);
    PostProcessVS(ID, Position, TexCoord);
    Offsets = TexCoord.xyxy + PixelOffset;
}

/* [Pixel Shaders ] */

void ConvertPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
{
    // r0.x = normalize current frame
    // r0.y = copy normalized frame from last run
    float3 Color = max(tex2D(_SampleColor, TexCoord).rgb, 1e-7);
    Color /= dot(Color, 1.0);
    Color /= max(max(Color.r, Color.g), Color.b);
    OutputColor0.x = dot(Color, 1.0 / 3.0);
    OutputColor0.y = tex2D(_SampleCurrentBuffer, TexCoord).x;
}

void DerivativesPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets : TEXCOORD1, out float OutputColor0 : SV_TARGET0, out float2 OutputColor1 : SV_TARGET1)
{
    float2 Sample0 = tex2D(_SamplePreviousBuffer, Offsets.zy).xy; // (-x, +y)
    float2 Sample1 = tex2D(_SamplePreviousBuffer, Offsets.xy).xy; // (+x, +y)
    float2 Sample2 = tex2D(_SamplePreviousBuffer, Offsets.zw).xy; // (-x, -y)
    float2 Sample3 = tex2D(_SamplePreviousBuffer, Offsets.xw).xy; // (+x, -y)
    float2 _ddx = -(Sample2 + Sample0) + (Sample3 + Sample1);
    float2 _ddy = -(Sample2 + Sample3) + (Sample0 + Sample1);
    OutputColor1.x = dot(_ddx, 0.5);
    OutputColor1.y = dot(_ddy, 0.5);
    OutputColor0 = tex2D(_SamplePreviousBuffer, TexCoord).x;
}

/*
    https://www.cs.auckland.ac.nz/~rklette/CCV-CIMAT/pdfs/B08-HornSchunck.pdf
    - Use a regular image pyramid for input frames I(., .,t)
    - Processing starts at a selected level (of lower resolution)
    - Obtained results are used for initializing optic flow values at a
      lower level (of higher resolution)
    - Repeat until full resolution level of original frames is reached
*/

void OpticalFlowPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    const float Lambda = max(4.0 * pow(_Constraint * 1e-2, 2.0), 1e-10);
    float Levels = (RSIZE - 1) - 0.5;
    float2 Flow = 0.0;

    while(Levels >= 0)
    {
        float4 CalculateUV = float4(TexCoord, 0.0, Levels);
        float CurrentFrame = tex2Dlod(_SampleCurrentBuffer, CalculateUV).x;
        float PreviousFrame = tex2Dlod(_SamplePreviousBuffer, CalculateUV).y;
        float2 _Ixy = tex2Dlod(_SampleDerivatives, CalculateUV).xy;
        float _It = CurrentFrame - PreviousFrame;

        float Linear = dot(_Ixy, Flow) + _It;
        float Smoothness = rcp(dot(_Ixy, _Ixy) + Lambda);
        Flow -= ((_Ixy * Linear) * Smoothness);
        Levels = Levels - 1.0;
    }

    OutputColor0 = float4(Flow.xy, 0.0, _BlendFactor);
}

float RandomNoise(float2 TexCoord)
{
    float f = dot(float2(12.9898, 78.233), TexCoord);
    return frac(43758.5453 * sin(f));
}

void AccumulatePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float Quality = 1.0 - _Entropy;
    float2 Time = float2(_Time, 0.0);

    // Random numbers
    float3 Random;
    Random.x = RandomNoise(TexCoord.xy + Time.xy);
    Random.y = RandomNoise(TexCoord.xy + Time.yx);
    Random.z = RandomNoise(TexCoord.yx - Time.xx);

    // Motion vector
    float2 MotionVector = tex2Dlod(_SampleOpticalFlow, float4(TexCoord, 0.0, _Detail)).xy;
    MotionVector *= _Scale;

    // Normalized screen space -> Pixel coordinates
    MotionVector = MotionVector * (DSIZE / 2);

    // Small random displacement (diffusion)
    MotionVector += (Random.xy - 0.5)  * _Diffusion;

    // Pixel perfect snapping
    MotionVector = round(MotionVector);

    // Accumulates the amount of motion.
    float MotionVectorLength = length(MotionVector);

    // - Simple update
    float UpdateAccumulation = min(MotionVectorLength, _BlockSize) * 0.005;
    UpdateAccumulation = saturate(UpdateAccumulation + Random.z * lerp(-0.02, 0.02, Quality));

    // - Reset to random level
    float ResetAccumulation = saturate(Random.z * 0.5 + Quality);

    // - Reset if the amount of motion is larger than the block size.
    if(MotionVectorLength > _BlockSize)
    {
        OutputColor0.rgb = ResetAccumulation;
        OutputColor0.a = 0.0;
    } else {
        // This should work given law of addition
        OutputColor0.rgb = UpdateAccumulation;
        OutputColor0.a = 1.0;
    }
}

void OutputPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    const float2 DisplacementTexel = 1.0 / (DSIZE.xy / 2.0);
    const float Quality = 1.0 - _Entropy;

    float2 MotionVectors = tex2Dlod(_SampleOpticalFlow, float4(TexCoord, 0.0, _Detail)).xy * DisplacementTexel;
    float4 Source = tex2D(_SampleColor, TexCoord); // Color from the original image
    float Displacement = tex2D(_SampleAccumulation, TexCoord).r; // Displacement vector
    float4 Working = tex2D(_SampleCopy, TexCoord - MotionVectors * 0.98);

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

void CopyPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    OutputColor0 = float4(tex2D(_SampleColor, TexCoord).rgb, 1.0);
}

technique KinoDatamosh
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ConvertPS;
        RenderTarget0 = _RenderPreviousBuffer;
    }

    pass
    {
        VertexShader = DerivativesVS;
        PixelShader = DerivativesPS;
        RenderTarget0 = _RenderCurrentBuffer;
        RenderTarget1 = _RenderDataMoshDerivatives;
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
        RenderTarget0 = _RenderDataMoshOpticalFlow;
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
            } else {
                // Accumulate if false
                (OUTPUT * ONE) + (Previous * ONE);
            }
    */

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = AccumulatePS;
        RenderTarget0 = _RenderAccumulation;
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
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = CopyPS;
        RenderTarget = _RenderCopy;
        SRGBWriteEnable = TRUE;
    }
}
