
/*
    Various Dual-Filter Convolutions

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

#define BUFFER_SIZE_0 uint2(BUFFER_WIDTH, BUFFER_HEIGHT)
#define BUFFER_SIZE_1 uint2(BUFFER_WIDTH >> 1, BUFFER_HEIGHT >> 1)
#define BUFFER_SIZE_2 uint2(BUFFER_WIDTH >> 2, BUFFER_HEIGHT >> 2)
#define BUFFER_SIZE_3 uint2(BUFFER_WIDTH >> 3, BUFFER_HEIGHT >> 3)
#define BUFFER_SIZE_4 uint2(BUFFER_WIDTH >> 4, BUFFER_HEIGHT >> 4)

namespace SharedResources
{
    namespace RGBA16F
    {
        texture2D RenderCommon1 < pooled = true; >
        {
            Width = BUFFER_SIZE_1.x;
            Height = BUFFER_SIZE_1.y;
            Format = RGBA16F;
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
    }
}

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

sampler2D SampleCommon1
{
    Texture = SharedResources::RGBA16F::RenderCommon1;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D SampleCommon2
{
    Texture = SharedResources::RGBA16F::RenderCommon2;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D SampleCommon3
{
    Texture = SharedResources::RGBA16F::RenderCommon3;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D SampleCommon4
{
    Texture = SharedResources::RGBA16F::RenderCommon4;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

// Shader properties

uniform int _DownsampleMethod <
    ui_type = "combo";
    ui_items = " Box\0 Jorge\0 Kawase\0 None\0";
    ui_label = "Method";
    ui_tooltip = "Downsampling Method";
> = 0;

uniform int _UpsampleMethod <
    ui_type = "combo";
    ui_items = " Box\0 Jorge\0 Kawase\0 None\0";
    ui_label = "Method";
    ui_tooltip = "Upsampling Method";
> = 0;

// Vertex shaders

void PostProcessVS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void DownsampleVS(in uint ID, inout float4 Position, inout float4 TexCoords[4], float2 PixelSize)
{
    float2 VSTexCoord;
    PostProcessVS(ID, Position, VSTexCoord);
    switch(_DownsampleMethod)
    {
        case 0: // Box
            TexCoords[0] = VSTexCoord.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * PixelSize.xyxy;
            break;
        case 1: // Jorge
            // Sample locations:
            // [1].xy        [2].xy        [3].xy
            //        [0].xw        [0].zw
            // [1].xz        [2].xz        [3].xz
            //        [0].xy        [0].zy
            // [1].xw        [2].xw        [3].xw
            TexCoords[0] = VSTexCoord.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * PixelSize.xyxy;
            TexCoords[1] = VSTexCoord.xyyy + float4(-2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
            TexCoords[2] = VSTexCoord.xyyy + float4(0.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
            TexCoords[3] = VSTexCoord.xyyy + float4(2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
            break;
        case 2: // Kawase
            TexCoords[0] = VSTexCoord.xyxy;
            TexCoords[1] = VSTexCoord.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * PixelSize.xyxy;
            break;
    }
}

void UpsampleVS(in uint ID, inout float4 Position, inout float4 TexCoords[3], float2 PixelSize)
{
    float2 VSTexCoord;
    PostProcessVS(ID, Position, VSTexCoord);
    switch(_UpsampleMethod)
    {
        case 0: // Box
            TexCoords[0] = VSTexCoord.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * PixelSize.xyxy;
            break;
        case 1: // Jorge
            // Sample locations:
            // [0].xy [1].xy [2].xy
            // [0].xz [1].xz [2].xz
            // [0].xw [1].xw [2].xw
            TexCoords[0] = VSTexCoord.xyyy + float4(-2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
            TexCoords[1] = VSTexCoord.xyyy + float4(0.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
            TexCoords[2] = VSTexCoord.xyyy + float4(2.0, 2.0, 0.0, -2.0) * PixelSize.xyyy;
            break;
        case 2: // Kawase
            TexCoords[0] = VSTexCoord.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * PixelSize.xyxy;
            TexCoords[1] = VSTexCoord.xxxy + float4(1.0, 0.0, -1.0, 0.0) * PixelSize.xxxy;
            TexCoords[2] = VSTexCoord.xyyy + float4(0.0, 1.0, 0.0, -1.0) * PixelSize.xyyy;
            break;
    }
}

void Downsample1VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, TexCoords, 1.0 / BUFFER_SIZE_1);
}

void Downsample2VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, TexCoords, 1.0 / BUFFER_SIZE_2);
}

void Downsample3VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, TexCoords, 1.0 / BUFFER_SIZE_3);
}

void Downsample4VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, TexCoords, 1.0 / BUFFER_SIZE_4);
}

void Upsample3VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, TexCoords, 1.0 / BUFFER_SIZE_3);
}

void Upsample2VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, TexCoords, 1.0 / BUFFER_SIZE_2);
}

void Upsample1VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, TexCoords, 1.0 / BUFFER_SIZE_1);
}

void Upsample0VS(in uint ID : SV_VertexID, inout float4 Position : SV_Position, inout float4 TexCoords[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, TexCoords, 1.0 / BUFFER_SIZE_0);
}

// Pixel Shaders
// 1: https://catlikecoding.com/unity/tutorials/advanced-rendering/bloom/
// 2: http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
// 3: https://community.arm.com/cfs-file/__key/communityserver-blogs-components-weblogfiles/00-00-00-20-66/siggraph2015_2D00_mmg_2D00_marius_2D00_slides.pdf
// More: https://github.com/powervr-graphics/Native_SDK

void DownsamplePS(in sampler2D Source, in float4 TexCoords[4], out float4 OutputColor)
{
    OutputColor = 0.0;

    switch(_DownsampleMethod)
    {
        case 0: // Box
            OutputColor += tex2D(Source, TexCoords[0].xw);
            OutputColor += tex2D(Source, TexCoords[0].zw);
            OutputColor += tex2D(Source, TexCoords[0].xy);
            OutputColor += tex2D(Source, TexCoords[0].zy);
            OutputColor = OutputColor / 4.0;
            break;
        case 1: // Jorge
            // Sampler locations
            // A0    B0    C0
            //    D0    D1
            // A1    B1    C1
            //    D2    D3
            // A2    B2    C2
            float4 D0 = tex2D(Source, TexCoords[0].xw);
            float4 D1 = tex2D(Source, TexCoords[0].zw);
            float4 D2 = tex2D(Source, TexCoords[0].xy);
            float4 D3 = tex2D(Source, TexCoords[0].zy);

            float4 A0 = tex2D(Source, TexCoords[1].xy);
            float4 A1 = tex2D(Source, TexCoords[1].xz);
            float4 A2 = tex2D(Source, TexCoords[1].xw);

            float4 B0 = tex2D(Source, TexCoords[2].xy);
            float4 B1 = tex2D(Source, TexCoords[2].xz);
            float4 B2 = tex2D(Source, TexCoords[2].xw);

            float4 C0 = tex2D(Source, TexCoords[3].xy);
            float4 C1 = tex2D(Source, TexCoords[3].xz);
            float4 C2 = tex2D(Source, TexCoords[3].xw);

            const float2 Weights = float2(0.5, 0.125) / 4.0;
            OutputColor += (D0 + D1 + D2 + D3) * Weights.x;
            OutputColor += (A0 + B0 + A1 + B1) * Weights.y;
            OutputColor += (B0 + C0 + B1 + C1) * Weights.y;
            OutputColor += (A1 + B1 + A2 + B2) * Weights.y;
            OutputColor += (B1 + C1 + B2 + C2) * Weights.y;
            break;
        case 2: // Kawase
            OutputColor += tex2D(Source, TexCoords[0].xy) * 4.0;
            OutputColor += tex2D(Source, TexCoords[1].xw);
            OutputColor += tex2D(Source, TexCoords[1].zw);
            OutputColor += tex2D(Source, TexCoords[1].xy);
            OutputColor += tex2D(Source, TexCoords[1].zy);
            OutputColor = OutputColor / 8.0;
            break;
    }

    OutputColor.a = 1.0;
}

void UpsamplePS(in sampler2D Source, in float4 TexCoords[3], out float4 OutputColor)
{
    OutputColor = 0.0;

    switch(_UpsampleMethod)
    {
        case 0: // Box
            OutputColor += tex2D(Source, TexCoords[0].xw);
            OutputColor += tex2D(Source, TexCoords[0].zw);
            OutputColor += tex2D(Source, TexCoords[0].xy);
            OutputColor += tex2D(Source, TexCoords[0].zy);
            OutputColor = OutputColor / 4.0;
            break;
        case 1: // Jorge
            // Sample locations:
            // A0 B0 C0
            // A1 B1 C1
            // A2 B2 C2
            float4 A0 = tex2D(Source, TexCoords[0].xy);
            float4 A1 = tex2D(Source, TexCoords[0].xz);
            float4 A2 = tex2D(Source, TexCoords[0].xw);
            float4 B0 = tex2D(Source, TexCoords[1].xy);
            float4 B1 = tex2D(Source, TexCoords[1].xz);
            float4 B2 = tex2D(Source, TexCoords[1].xw);
            float4 C0 = tex2D(Source, TexCoords[2].xy);
            float4 C1 = tex2D(Source, TexCoords[2].xz);
            float4 C2 = tex2D(Source, TexCoords[2].xw);
            OutputColor = (((A0 + C0 + A2 + C2) * 1.0) + ((B0 + A1 + C1 + B2) * 2.0) + (B1 * 4.0)) / 16.0;
            break;
        case 2:
            OutputColor += tex2D(Source, TexCoords[0].xw) * 2.0;
            OutputColor += tex2D(Source, TexCoords[0].zw);
            OutputColor += tex2D(Source, TexCoords[0].xy);
            OutputColor += tex2D(Source, TexCoords[0].zy);
    }

    OutputColor.a = 1.0;
}

void Downsample1PS(in float4 Position : SV_Position, in float4 TexCoords[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    DownsamplePS(SampleColor, TexCoords, OutputColor0);
}

void Downsample2PS(in float4 Position : SV_Position, in float4 TexCoords[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    DownsamplePS(SampleCommon1, TexCoords, OutputColor0);
}

void Downsample3PS(in float4 Position : SV_Position, in float4 TexCoords[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    DownsamplePS(SampleCommon2, TexCoords, OutputColor0);
}

void Downsample4PS(in float4 Position : SV_Position, in float4 TexCoords[4] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    DownsamplePS(SampleCommon3, TexCoords, OutputColor0);
}

void Upsample3PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    UpsamplePS(SampleCommon4, TexCoords, OutputColor0);
}

void Upsample2PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    UpsamplePS(SampleCommon3, TexCoords, OutputColor0);
}

void Upsample1PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    UpsamplePS(SampleCommon2, TexCoords, OutputColor0);
}

void Upsample0PS(in float4 Position : SV_Position, in float4 TexCoords[3] : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    UpsamplePS(SampleCommon1, TexCoords, OutputColor0);
}

technique cDualFilter
{
    pass
    {
        VertexShader = Downsample1VS;
        PixelShader = Downsample1PS;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon1;
    }

    pass
    {
        VertexShader = Downsample2VS;
        PixelShader = Downsample2PS;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon2;
    }

    pass
    {
        VertexShader = Downsample3VS;
        PixelShader = Downsample3PS;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon3;
    }

    pass
    {
        VertexShader = Downsample4VS;
        PixelShader = Downsample4PS;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon4;
    }

    pass
    {
        VertexShader = Upsample3VS;
        PixelShader = Upsample3PS;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon3;
    }

    pass
    {
        VertexShader = Upsample2VS;
        PixelShader = Upsample2PS;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon2;
    }

    pass
    {
        VertexShader = Upsample1VS;
        PixelShader = Upsample1PS;
        RenderTarget0 = SharedResources::RGBA16F::RenderCommon1;
    }

    pass
    {
        VertexShader = Upsample0VS;
        PixelShader = Upsample0PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
