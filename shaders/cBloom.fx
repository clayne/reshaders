
/*
    Dual-filtering Bloom

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
    namespace RGBA16F
    {
        texture2D RenderCommon1 < pooled = true; >
        {
            Width = BUFFER_SIZE_1.x;
            Height = BUFFER_SIZE_1.y;
            Format = RGBA16F;
            MipLevels = 8;
        };

        texture2D RenderCommon2 < pooled = true; >
        {
            Width = BUFFER_SIZE_2.x;
            Height = BUFFER_SIZE_2.y;
            Format = RGBA16F;
        };

        texture2D RenderCommon3 < pooled = true; >
        {
            Width = BUFFER_SIZE_3.x;
            Height = BUFFER_SIZE_3.y;
            Format = RGBA16F;
        };

        texture2D RenderCommon4 < pooled = true; >
        {
            Width = BUFFER_SIZE_4.x;
            Height = BUFFER_SIZE_4.y;
            Format = RGBA16F;
        };

        texture2D RenderCommon5 < pooled = true; >
        {
            Width = BUFFER_SIZE_5.x;
            Height = BUFFER_SIZE_5.y;
            Format = RGBA16F;
        };

        texture2D RenderCommon6 < pooled = true; >
        {
            Width = BUFFER_SIZE_6.x;
            Height = BUFFER_SIZE_6.y;
            Format = RGBA16F;
        };

        texture2D RenderCommon7 < pooled = true; >
        {
            Width = BUFFER_SIZE_7.x;
            Height = BUFFER_SIZE_7.y;
            Format = RGBA16F;
        };

        texture2D RenderCommon8 < pooled = true; >
        {
            Width = BUFFER_SIZE_8.x;
            Height = BUFFER_SIZE_8.y;
            Format = RGBA16F;
        };
    }
}

uniform float _Threshold <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Threshold";
> = 0.8;

uniform float _Smooth <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Smoothing";
    ui_max = 1.0;
> = 0.5;

uniform float _Saturation <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Saturation";
> = 1.0;

uniform float3 _ColorShift <
    ui_type = "color";
    ui_min = 0.0;
    ui_label = "Color Shift";
> = 1.0;

uniform float _Intensity <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Color Intensity";
> = 1.0;

uniform float _Level6Weight <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Level 6 Weight";
    ui_category = "Level Weights";
> = 1.0;

uniform float _Level5Weight <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Level 5 Weight";
    ui_category = "Level Weights";
> = 1.0;

uniform float _Level4Weight <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Level 4 Weight";
    ui_category = "Level Weights";
> = 1.0;

uniform float _Level3Weight <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Level 3 Weight";
    ui_category = "Level Weights";
> = 1.0;

uniform float _Level2Weight <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Level 2 Weight";
    ui_category = "Level Weights";
> = 1.0;

uniform float _Level1Weight <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Level 1 Weight";
    ui_category = "Level Weights";
> = 1.0;

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

sampler2D SampleCommon_RGBA16F_1
{
    Texture = SharedResources::RGBA16F::RenderCommon1;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D SampleCommon_RGBA16F_2
{
    Texture = SharedResources::RGBA16F::RenderCommon2;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D SampleCommon_RGBA16F_3
{
    Texture = SharedResources::RGBA16F::RenderCommon3;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D SampleCommon_RGBA16F_4
{
    Texture = SharedResources::RGBA16F::RenderCommon4;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D SampleCommon_RGBA16F_5
{
    Texture = SharedResources::RGBA16F::RenderCommon5;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D SampleCommon_RGBA16F_6
{
    Texture = SharedResources::RGBA16F::RenderCommon6;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D SampleCommon_RGBA16F_7
{
    Texture = SharedResources::RGBA16F::RenderCommon7;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D SampleCommon_RGBA16F_8
{
    Texture = SharedResources::RGBA16F::RenderCommon8;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

// Vertex shaders
// Sampling kernels: http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare

void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void DownsampleVS(in uint ID, out float4 Position, out float4 TexCoord[4], float2 PixelSize)
{
    float2 TexCoord0;
    PostProcessVS(ID, Position, TexCoord0);
    // Quadrant
    TexCoord[0] = TexCoord0.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * PixelSize.xyxy;
    // Left column
    TexCoord[1] = TexCoord0.xyyy + float4(-2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
    // Center column
    TexCoord[2] = TexCoord0.xyyy + float4(0.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
    // Right column
    TexCoord[3] = TexCoord0.xyyy + float4(2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
}

void UpsampleVS(in uint ID, out float4 Position, out float4 TexCoord[3], float2 PixelSize)
{
    float2 TexCoord0;
    PostProcessVS(ID, Position, TexCoord0);
    // Left column
    TexCoord[0] = TexCoord0.xyyy + float4(-2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
    // Center column
    TexCoord[1] = TexCoord0.xyyy + float4(0.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
    // Right column
    TexCoord[2] = TexCoord0.xyyy + float4(2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
}

void DownsampleVS1(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_1);
}

void DownsampleVS2(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_2);
}

void DownsampleVS3(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_3);
}

void DownsampleVS4(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_4);
}

void DownsampleVS5(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_5);
}

void DownsampleVS6(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_6);
}

void DownsampleVS7(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_7);
}

void UpsampleVS7(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_7);
}

void UpsampleVS6(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_6);
}

void UpsampleVS5(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_5);
}

void UpsampleVS4(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_4);
}

void UpsampleVS3(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_3);
}

void UpsampleVS2(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_2);
}

void UpsampleVS1(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float4 TexCoord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, TexCoord, 1.0 / BUFFER_SIZE_1);
}

// Pixel shaders
// Thresholding: https://github.com/keijiro/Kino [MIT]
// Tonemapping: https://github.com/TheRealMJP/BakingLab [MIT]

void Downsample(in sampler2D Source, in float4 TexCoord[4], out float4 Output)
{
    // A0    B0    C0
    //    D0    D1
    // A1    B1    C1
    //    D2    D3
    // A2    B2    C2

    float4 D0 = tex2D(Source, TexCoord[0].xw);
    float4 D1 = tex2D(Source, TexCoord[0].zw);
    float4 D2 = tex2D(Source, TexCoord[0].xy);
    float4 D3 = tex2D(Source, TexCoord[0].zy);

    float4 A0 = tex2D(Source, TexCoord[1].xy);
    float4 A1 = tex2D(Source, TexCoord[1].xz);
    float4 A2 = tex2D(Source, TexCoord[1].xw);

    float4 B0 = tex2D(Source, TexCoord[2].xy);
    float4 B1 = tex2D(Source, TexCoord[2].xz);
    float4 B2 = tex2D(Source, TexCoord[2].xw);

    float4 C0 = tex2D(Source, TexCoord[3].xy);
    float4 C1 = tex2D(Source, TexCoord[3].xz);
    float4 C2 = tex2D(Source, TexCoord[3].xw);

    const float2 Weights = float2(0.5, 0.125) / 4.0;
    Output  = (D0 + D1 + D2 + D3) * Weights.x;
    Output += (A0 + B0 + A1 + B1) * Weights.y;
    Output += (B0 + C0 + B1 + C1) * Weights.y;
    Output += (A1 + B1 + A2 + B2) * Weights.y;
    Output += (B1 + C1 + B2 + C2) * Weights.y;
}

void Upsample(in sampler2D Source, in float4 TexCoord[3], in float Weight, out float4 Output)
{
    // A0 B0 C0
    // A1 B1 C1
    // A2 B2 C2

    float4 A0 = tex2D(Source, TexCoord[0].xy);
    float4 A1 = tex2D(Source, TexCoord[0].xz);
    float4 A2 = tex2D(Source, TexCoord[0].xw);

    float4 B0 = tex2D(Source, TexCoord[1].xy);
    float4 B1 = tex2D(Source, TexCoord[1].xz);
    float4 B2 = tex2D(Source, TexCoord[1].xw);

    float4 C0 = tex2D(Source, TexCoord[2].xy);
    float4 C1 = tex2D(Source, TexCoord[2].xz);
    float4 C2 = tex2D(Source, TexCoord[2].xw);

    Output  = (A0 + C0 + A2 + C2) * 1.0;
    Output += (A1 + B0 + C1 + B2) * 2.0;
    Output += B1 * 4.0;
    Output *= (1.0 / 16.0);
    Output.a = abs(Weight);
}

float Med3(float x, float y, float z)
{
    return max(min(x, y), min(max(x, y), z));
}

void PrefilterPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    const float Knee = mad(_Threshold, _Smooth, 1e-5f);
    const float3 Curve = float3(_Threshold - Knee, Knee * 2.0, 0.25 / Knee);
    float4 Color = tex2D(SampleColor, TexCoord);

    // Under-threshold
    float Brightness = Med3(Color.r, Color.g, Color.b);
    float ResponseCurve = clamp(Brightness - Curve.x, 0.0, Curve.y);
    ResponseCurve = Curve.z * ResponseCurve * ResponseCurve;

    // Combine and apply the brightness response curve
    Color = Color * max(ResponseCurve, Brightness - _Threshold) / max(Brightness, 1e-10);
    Brightness = Med3(Color.r, Color.g, Color.b);
    OutputColor0 = saturate(lerp(Brightness, Color.rgb, _Saturation)) * _ColorShift;

    // Set alpha to 1.0 so we can see the complete results in ReShade's statistics
    OutputColor0.a = 1.0;
}

// sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
static const float3x3 ACESInputMat = float3x3(
    0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
static const float3x3 ACESOutputMat = float3x3(
     1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602
);

float3 RRTAndODTFit(float3 v)
{
    float3 a = v * (v + 0.0245786f) - 0.000090537f;
    float3 b = v * (0.983729f * v + 0.4329510f) + 0.238081f;
    return a / b;
}

void DownsamplePS1(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Downsample(SampleCommon_RGBA16F_1, TexCoord, OutputColor0);
}

void DownsamplePS2(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Downsample(SampleCommon_RGBA16F_2, TexCoord, OutputColor0);
}

void DownsamplePS3(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Downsample(SampleCommon_RGBA16F_3, TexCoord, OutputColor0);
}

void DownsamplePS4(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Downsample(SampleCommon_RGBA16F_4, TexCoord, OutputColor0);
}

void DownsamplePS5(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Downsample(SampleCommon_RGBA16F_5, TexCoord, OutputColor0);
}

void DownsamplePS6(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Downsample(SampleCommon_RGBA16F_6, TexCoord, OutputColor0);
}

void DownsamplePS7(in float4 Position : SV_Position, in float4 TexCoord[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Downsample(SampleCommon_RGBA16F_7, TexCoord, OutputColor0);
}

void UpsamplePS7(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Upsample(SampleCommon_RGBA16F_8, TexCoord, _Level6Weight, OutputColor0);
}

void UpsamplePS6(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Upsample(SampleCommon_RGBA16F_7, TexCoord, _Level5Weight, OutputColor0);
}

void UpsamplePS5(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Upsample(SampleCommon_RGBA16F_6, TexCoord, _Level4Weight, OutputColor0);
}

void UpsamplePS4(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Upsample(SampleCommon_RGBA16F_5, TexCoord, _Level3Weight, OutputColor0);
}

void UpsamplePS3(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Upsample(SampleCommon_RGBA16F_4, TexCoord, _Level2Weight, OutputColor0);
}

void UpsamplePS2(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Upsample(SampleCommon_RGBA16F_3, TexCoord, _Level1Weight, OutputColor0);
}

void UpsamplePS1(in float4 Position : SV_Position, in float4 TexCoord[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    Upsample(SampleCommon_RGBA16F_2, TexCoord, 0.0, OutputColor0);
}

void CompositePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    float4 Src = tex2D(SampleCommon_RGBA16F_1, TexCoord);
    Src *= _Intensity;
    Src = mul(ACESInputMat, Src.rgb);
    Src = RRTAndODTFit(Src.rgb);
    Src = saturate(mul(ACESOutputMat, Src.rgb));
    OutputColor0 = Src;
}

/* [ TECHNIQUE ] */

technique cBloom
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PrefilterPS;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon1;
    }

    pass
    {
        VertexShader = DownsampleVS1;
        PixelShader = DownsamplePS1;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon2;
    }

    pass
    {
        VertexShader = DownsampleVS2;
        PixelShader = DownsamplePS2;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon3;
    }

    pass
    {
        VertexShader = DownsampleVS3;
        PixelShader = DownsamplePS3;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon4;
    }

    pass
    {
        VertexShader = DownsampleVS4;
        PixelShader = DownsamplePS4;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon5;
    }

    pass
    {
        VertexShader = DownsampleVS5;
        PixelShader = DownsamplePS5;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon6;
    }

    pass
    {
        VertexShader = DownsampleVS6;
        PixelShader = DownsamplePS6;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon7;
    }

    pass
    {
        VertexShader = DownsampleVS7;
        PixelShader = DownsamplePS7;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon8;
    }

    pass
    {
        VertexShader = UpsampleVS7;
        PixelShader = UpsamplePS7;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon7;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = ONE;
    }

    pass
    {
        VertexShader = UpsampleVS6;
        PixelShader = UpsamplePS6;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon6;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = ONE;
    }

    pass
    {
        VertexShader = UpsampleVS5;
        PixelShader = UpsamplePS5;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon5;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = ONE;
    }

    pass
    {
        VertexShader = UpsampleVS4;
        PixelShader = UpsamplePS4;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon4;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = ONE;
    }

    pass
    {
        VertexShader = UpsampleVS3;
        PixelShader = UpsamplePS3;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon3;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = ONE;
    }

    pass
    {
        VertexShader = UpsampleVS2;
        PixelShader = UpsamplePS2;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon2;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = ONE;
    }

    pass
    {
        VertexShader = UpsampleVS1;
        PixelShader = UpsamplePS1;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon1;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = CompositePS;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = ONE;
        DestBlend = INVSRCCOLOR;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
