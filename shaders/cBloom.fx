
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

        texture2D Render_Common_2 < pooled = true; >
        {
            Width = BUFFER_SIZE_2.x;
            Height = BUFFER_SIZE_2.y;
            Format = RGBA16F;
        };

        texture2D Render_Common_3 < pooled = true; >
        {
            Width = BUFFER_SIZE_3.x;
            Height = BUFFER_SIZE_3.y;
            Format = RGBA16F;
        };

        texture2D Render_Common_4 < pooled = true; >
        {
            Width = BUFFER_SIZE_4.x;
            Height = BUFFER_SIZE_4.y;
            Format = RGBA16F;
        };

        texture2D Render_Common_5 < pooled = true; >
        {
            Width = BUFFER_SIZE_5.x;
            Height = BUFFER_SIZE_5.y;
            Format = RGBA16F;
        };

        texture2D Render_Common_6 < pooled = true; >
        {
            Width = BUFFER_SIZE_6.x;
            Height = BUFFER_SIZE_6.y;
            Format = RGBA16F;
        };

        texture2D Render_Common_7 < pooled = true; >
        {
            Width = BUFFER_SIZE_7.x;
            Height = BUFFER_SIZE_7.y;
            Format = RGBA16F;
        };

        texture2D Render_Common_8 < pooled = true; >
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

uniform float3 _Color_Shift <
    ui_type = "color";
    ui_min = 0.0;
    ui_label = "Color Shift";
> = 1.0;

uniform float _Intensity <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Color Intensity";
> = 1.0;

uniform float _Level_6_Weight <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Level 6 Weight";
    ui_category = "Level Weights";
> = 1.0;

uniform float _Level_5_Weight <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Level 5 Weight";
    ui_category = "Level Weights";
> = 1.0;

uniform float _Level_4_Weight <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Level 4 Weight";
    ui_category = "Level Weights";
> = 1.0;

uniform float _Level_3_Weight <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Level 3 Weight";
    ui_category = "Level Weights";
> = 1.0;

uniform float _Level_2_Weight <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Level 2 Weight";
    ui_category = "Level Weights";
> = 1.0;

uniform float _Level_1_Weight <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Level 1 Weight";
    ui_category = "Level Weights";
> = 1.0;

texture2D Render_Color : COLOR;

sampler2D Sample_Color
{
    Texture = Render_Color;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

sampler2D Sample_Common_RGBA16F_1
{
    Texture = Shared_Resources::RGBA16F::Render_Common_1;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D Sample_Common_RGBA16F_2
{
    Texture = Shared_Resources::RGBA16F::Render_Common_2;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D Sample_Common_RGBA16F_3
{
    Texture = Shared_Resources::RGBA16F::Render_Common_3;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D Sample_Common_RGBA16F_4
{
    Texture = Shared_Resources::RGBA16F::Render_Common_4;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D Sample_Common_RGBA16F_5
{
    Texture = Shared_Resources::RGBA16F::Render_Common_5;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D Sample_Common_RGBA16F_6
{
    Texture = Shared_Resources::RGBA16F::Render_Common_6;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D Sample_Common_RGBA16F_7
{
    Texture = Shared_Resources::RGBA16F::Render_Common_7;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D Sample_Common_RGBA16F_8
{
    Texture = Shared_Resources::RGBA16F::Render_Common_8;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

// Vertex shaders
// Sampling kernels: http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare

void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 Coord : TEXCOORD0)
{
    Coord.x = (ID == 2) ? 2.0 : 0.0;
    Coord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(Coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void DownsampleVS(in uint ID, out float4 Position, out float4 Coord[4], float2 Pixel_Size)
{
    float2 VS_Coord = 0.0;
    Basic_VS(ID, Position, VS_Coord);
    // Quadrant
    Coord[0] = VS_Coord.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * Pixel_Size.xyxy;
    // Left column
    Coord[1] = VS_Coord.xyyy + float4(-2.0, 2.0, 0.0, -2.0) * Pixel_Size.xyyy;
    // Center column
    Coord[2] = VS_Coord.xyyy + float4(0.0, 2.0, 0.0, -2.0) * Pixel_Size.xyyy;
    // Right column
    Coord[3] = VS_Coord.xyyy + float4(2.0, 2.0, 0.0, -2.0) * Pixel_Size.xyyy;
}

void UpsampleVS(in uint ID, out float4 Position, out float4 Coord[3], float2 Pixel_Size)
{
    float2 VS_Coord = 0.0;
    Basic_VS(ID, Position, VS_Coord);
    // Left column
    Coord[0] = VS_Coord.xyyy + float4(-2.0, 2.0, 0.0, -2.0) * Pixel_Size.xyyy;
    // Center column
    Coord[1] = VS_Coord.xyyy + float4(0.0, 2.0, 0.0, -2.0) * Pixel_Size.xyyy;
    // Right column
    Coord[2] = VS_Coord.xyyy + float4(2.0, 2.0, 0.0, -2.0) * Pixel_Size.xyyy;
}

void Downsample_1_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_1);
}

void Downsample_2_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_2);
}

void Downsample_3_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_3);
}

void Downsample_4_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_4);
}

void Downsample_5_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_5);
}

void Downsample_6_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_6);
}

void Downsample_7_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_7);
}

void Upsample_7_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_7);
}

void Upsample_6_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_6);
}

void Upsample_5_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_5);
}

void Upsample_4_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_4);
}

void Upsample_3_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_3);
}

void Upsample_2_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_2);
}

void Upsample_1_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float4 Coord[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, Coord, 1.0 / BUFFER_SIZE_1);
}

// Pixel shaders
// Thresholding: https://github.com/keijiro/Kino [MIT]
// Tonemapping: https://github.com/TheRealMJP/BakingLab [MIT]

void Downsample(in sampler2D Source, in float4 Coord[4], out float4 Output)
{
    // A_0    B_0    C_0
    //    D_0    D_1
    // A_1    B_1    C_1
    //    D_2    D_3
    // A_2    B_2    C_2

    float4 D_0 = tex2D(Source, Coord[0].xw);
    float4 D_1 = tex2D(Source, Coord[0].zw);
    float4 D_2 = tex2D(Source, Coord[0].xy);
    float4 D_3 = tex2D(Source, Coord[0].zy);

    float4 A_0 = tex2D(Source, Coord[1].xy);
    float4 A_1 = tex2D(Source, Coord[1].xz);
    float4 A_2 = tex2D(Source, Coord[1].xw);

    float4 B_0 = tex2D(Source, Coord[2].xy);
    float4 B_1 = tex2D(Source, Coord[2].xz);
    float4 B_2 = tex2D(Source, Coord[2].xw);

    float4 C_0 = tex2D(Source, Coord[3].xy);
    float4 C_1 = tex2D(Source, Coord[3].xz);
    float4 C_2 = tex2D(Source, Coord[3].xw);

    const float2 Weights = float2(0.5, 0.125) / 4.0;
    Output  = (D_0 + D_1 + D_2 + D_3) * Weights.x;
    Output += (A_0 + B_0 + A_1 + B_1) * Weights.y;
    Output += (B_0 + C_0 + B_1 + C_1) * Weights.y;
    Output += (A_1 + B_1 + A_2 + B_2) * Weights.y;
    Output += (B_1 + C_1 + B_2 + C_2) * Weights.y;
}

void Upsample(in sampler2D Source, in float4 Coord[3], in float Weight, out float4 Output)
{
    // A_0 B_0 C_0
    // A_1 B_1 C_1
    // A_2 B_2 C_2

    float4 A_0 = tex2D(Source, Coord[0].xy);
    float4 A_1 = tex2D(Source, Coord[0].xz);
    float4 A_2 = tex2D(Source, Coord[0].xw);

    float4 B_0 = tex2D(Source, Coord[1].xy);
    float4 B_1 = tex2D(Source, Coord[1].xz);
    float4 B_2 = tex2D(Source, Coord[1].xw);

    float4 C_0 = tex2D(Source, Coord[2].xy);
    float4 C_1 = tex2D(Source, Coord[2].xz);
    float4 C_2 = tex2D(Source, Coord[2].xw);

    Output  = (A_0 + C_0 + A_2 + C_2) * 1.0;
    Output += (A_1 + B_0 + C_1 + B_2) * 2.0;
    Output += B_1 * 4.0;
    Output *= (1.0 / 16.0);
}

float Median_3(float x, float y, float z)
{
    return max(min(x, y), min(max(x, y), z));
}

void Prefilter_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    const float Knee = mad(_Threshold, _Smooth, 1e-5f);
    const float3 Curve = float3(_Threshold - Knee, Knee * 2.0, 0.25 / Knee);
    float4 Color = tex2D(Sample_Color, Coord);

    // Under-threshold
    float Brightness = Median_3(Color.r, Color.g, Color.b);
    float Response_Curve = clamp(Brightness - Curve.x, 0.0, Curve.y);
    Response_Curve = Curve.z * Response_Curve * Response_Curve;

    // Combine and apply the brightness response curve
    Color = Color * max(Response_Curve, Brightness - _Threshold) / max(Brightness, 1e-10);
    Brightness = Median_3(Color.r, Color.g, Color.b);
    Output_Color_0 = saturate(lerp(Brightness, Color.rgb, _Saturation)) * _Color_Shift;

    // Set alpha to 1.0 so we can see the complete results in ReShade's statistics
    Output_Color_0.a = 1.0;
}

// sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
static const float3x3 ACES_Input_Mat = float3x3
(
    0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
static const float3x3 ACES_Output_Mat = float3x3
(
     1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602
);

float3 RRT_ODT_Fit(float3 V)
{
    float3 A = V * (V + 0.0245786f) - 0.000090537f;
    float3 B = V * (0.983729f * V + 0.4329510f) + 0.238081f;
    return A / B;
}

void Downsample_1_PS(in float4 Position : SV_POSITION, in float4 Coord[4] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Downsample(Sample_Common_RGBA16F_1, Coord, Output_Color_0);
}

void Downsample_2_PS(in float4 Position : SV_POSITION, in float4 Coord[4] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Downsample(Sample_Common_RGBA16F_2, Coord, Output_Color_0);
}

void Downsample_3_PS(in float4 Position : SV_POSITION, in float4 Coord[4] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Downsample(Sample_Common_RGBA16F_3, Coord, Output_Color_0);
}

void Downsample_4_PS(in float4 Position : SV_POSITION, in float4 Coord[4] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Downsample(Sample_Common_RGBA16F_4, Coord, Output_Color_0);
}

void Downsample_5_PS(in float4 Position : SV_POSITION, in float4 Coord[4] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Downsample(Sample_Common_RGBA16F_5, Coord, Output_Color_0);
}

void Downsample_6_PS(in float4 Position : SV_POSITION, in float4 Coord[4] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Downsample(Sample_Common_RGBA16F_6, Coord, Output_Color_0);
}

void Downsample_7_PS(in float4 Position : SV_POSITION, in float4 Coord[4] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Downsample(Sample_Common_RGBA16F_7, Coord, Output_Color_0);
}

void Upsample_7_PS(in float4 Position : SV_POSITION, in float4 Coord[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Upsample(Sample_Common_RGBA16F_8, Coord, _Level_6_Weight, Output_Color_0);
}

void Upsample_6_PS(in float4 Position : SV_POSITION, in float4 Coord[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Upsample(Sample_Common_RGBA16F_7, Coord, _Level_5_Weight, Output_Color_0);
}

void Upsample_5_PS(in float4 Position : SV_POSITION, in float4 Coord[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Upsample(Sample_Common_RGBA16F_6, Coord, _Level_4_Weight, Output_Color_0);
}

void Upsample_4_PS(in float4 Position : SV_POSITION, in float4 Coord[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Upsample(Sample_Common_RGBA16F_5, Coord, _Level_3_Weight, Output_Color_0);
}

void Upsample_3_PS(in float4 Position : SV_POSITION, in float4 Coord[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Upsample(Sample_Common_RGBA16F_4, Coord, _Level_2_Weight, Output_Color_0);
}

void Upsample_2_PS(in float4 Position : SV_POSITION, in float4 Coord[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Upsample(Sample_Common_RGBA16F_3, Coord, _Level_1_Weight, Output_Color_0);
}

void Upsample_1_PS(in float4 Position : SV_POSITION, in float4 Coord[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Upsample(Sample_Common_RGBA16F_2, Coord, 0.0, Output_Color_0);
}

void Composite_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    float4 Src = tex2D(Sample_Common_RGBA16F_1, Coord);
    Src *= _Intensity;
    Src = mul(ACES_Input_Mat, Src.rgb);
    Src = RRT_ODT_Fit(Src.rgb);
    Src = saturate(mul(ACES_Output_Mat, Src.rgb));
    Output_Color_0 = Src;
}

/* [ TECHNIQUE ] */

technique cBloom
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Prefilter_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_1;
    }

    pass
    {
        VertexShader = Downsample_1_VS;
        PixelShader = Downsample_1_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_2;
    }

    pass
    {
        VertexShader = Downsample_2_VS;
        PixelShader = Downsample_2_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_3;
    }

    pass
    {
        VertexShader = Downsample_3_VS;
        PixelShader = Downsample_3_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_4;
    }

    pass
    {
        VertexShader = Downsample_4_VS;
        PixelShader = Downsample_4_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_5;
    }

    pass
    {
        VertexShader = Downsample_5_VS;
        PixelShader = Downsample_5_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_6;
    }

    pass
    {
        VertexShader = Downsample_6_VS;
        PixelShader = Downsample_6_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_7;
    }

    pass
    {
        VertexShader = Downsample_7_VS;
        PixelShader = Downsample_7_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_8;
    }

    pass
    {
        VertexShader = Upsample_7_VS;
        PixelShader = Upsample_7_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_7;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = ONE;
    }

    pass
    {
        VertexShader = Upsample_6_VS;
        PixelShader = Upsample_6_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_6;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = ONE;
    }

    pass
    {
        VertexShader = Upsample_5_VS;
        PixelShader = Upsample_5_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_5;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = ONE;
    }

    pass
    {
        VertexShader = Upsample_4_VS;
        PixelShader = Upsample_4_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_4;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = ONE;
    }

    pass
    {
        VertexShader = Upsample_3_VS;
        PixelShader = Upsample_3_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_3;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = ONE;
    }

    pass
    {
        VertexShader = Upsample_2_VS;
        PixelShader = Upsample_2_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_2;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = ONE;
    }

    pass
    {
        VertexShader = Upsample_1_VS;
        PixelShader = Upsample_1_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_1;
    }

    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Composite_PS;
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
