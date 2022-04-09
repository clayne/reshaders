
/*
    Various Pyramid Convolutions

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

#define BUFFER_SIZE_0 int2(BUFFER_WIDTH, BUFFER_HEIGHT)
#define BUFFER_SIZE_1 int2(BUFFER_WIDTH >> 1, BUFFER_HEIGHT >> 1)
#define BUFFER_SIZE_2 int2(BUFFER_WIDTH >> 2, BUFFER_HEIGHT >> 2)
#define BUFFER_SIZE_3 int2(BUFFER_WIDTH >> 3, BUFFER_HEIGHT >> 3)
#define BUFFER_SIZE_4 int2(BUFFER_WIDTH >> 4, BUFFER_HEIGHT >> 4)

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
    }
}

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

sampler2D Sample_Common_1
{
    Texture = Shared_Resources::RGBA16F::Render_Common_1;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D Sample_Common_2
{
    Texture = Shared_Resources::RGBA16F::Render_Common_2;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D Sample_Common_3
{
    Texture = Shared_Resources::RGBA16F::Render_Common_3;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

sampler2D Sample_Common_4
{
    Texture = Shared_Resources::RGBA16F::Render_Common_4;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
};

// Shader properties

uniform int _Downsample_Method <
    ui_type = "combo";
    ui_items = " 2x2 Box\0 3x3 Tent\0 Jorge\0 Kawase\0";
    ui_label = "Downsample kernel";
    ui_tooltip = "Downsampling Method";
> = 0;

uniform int _Upsample_Method <
    ui_type = "combo";
    ui_items = " 2x2 Box\0 3x3 Tent\0 Kawase\0";
    ui_label = "Upsample kernel";
    ui_tooltip = "Upsampling Method";
> = 0;

// Vertex shaders

void Basic_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 Coord : TEXCOORD0)
{
    Coord.x = (ID == 2) ? 2.0 : 0.0;
    Coord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(Coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void DownsampleVS(in uint ID, inout float4 Position, inout float4 Coords[4], float2 Texel_Size)
{
    float2 VS_Coord;;
    Basic_VS(ID, Position, VS_Coord);
    switch(_Downsample_Method)
    {
        case 0: // 4x4 Box
            Coords[0] = VS_Coord.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * Texel_Size.xyxy;
            break;
        case 1: // 6x6 Tent
            Coords[0] = VS_Coord.xyyy + float4(-2.0, 2.0, 0.0, -2.0) * Texel_Size.xyyy;
            Coords[1] = VS_Coord.xyyy + float4(0.0, 2.0, 0.0, -2.0) * Texel_Size.xyyy;
            Coords[2] = VS_Coord.xyyy + float4(2.0, 2.0, 0.0, -2.0) * Texel_Size.xyyy;
            break;
        case 2: // Jorge
            Coords[0] = VS_Coord.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * Texel_Size.xyxy;
            Coords[1] = VS_Coord.xyyy + float4(-2.0, 2.0, 0.0, -2.0) * Texel_Size.xyyy;
            Coords[2] = VS_Coord.xyyy + float4(0.0, 2.0, 0.0, -2.0) * Texel_Size.xyyy;
            Coords[3] = VS_Coord.xyyy + float4(2.0, 2.0, 0.0, -2.0) * Texel_Size.xyyy;
            break;
        case 3: // Kawase
            Coords[0] = VS_Coord.xyxy;
            Coords[1] = VS_Coord.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * Texel_Size.xyxy;
            break;
    }
}

void UpsampleVS(in uint ID, inout float4 Position, inout float4 Coords[3], float2 Texel_Size)
{
    float2 VS_Coord = 0.0;
    Basic_VS(ID, Position, VS_Coord);
    switch(_Upsample_Method)
    {
        case 0: // 4x4 Box
            Coords[0] = VS_Coord.xyxy + float4(-0.5, -0.5, 0.5, 0.5) * Texel_Size.xyxy;
            break;
        case 1: // 6x6 Tent
            Coords[0] = VS_Coord.xyyy + float4(-1.0, 1.0, 0.0, -1.0) * Texel_Size.xyyy;
            Coords[1] = VS_Coord.xyyy + float4(0.0, 1.0, 0.0, -1.0) * Texel_Size.xyyy;
            Coords[2] = VS_Coord.xyyy + float4(1.0, 1.0, 0.0, -1.0) * Texel_Size.xyyy;
            break;
        case 2: // Kawase
            Coords[0] = VS_Coord.xyxy + float4(-0.5, -0.5, 0.5, 0.5) * Texel_Size.xyxy;
            Coords[1] = VS_Coord.xxxy + float4(1.0, 0.0, -1.0, 0.0) * Texel_Size.xxxy;
            Coords[2] = VS_Coord.xyyy + float4(0.0, 1.0, 0.0, -1.0) * Texel_Size.xyyy;
            break;
    }
}

void Downsample_1_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coords[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, Coords, 1.0 / BUFFER_SIZE_0);
}

void Downsample_2_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coords[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, Coords, 1.0 / BUFFER_SIZE_1);
}

void Downsample_3_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coords[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, Coords, 1.0 / BUFFER_SIZE_2);
}

void Downsample_4_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coords[4] : TEXCOORD0)
{
    DownsampleVS(ID, Position, Coords, 1.0 / BUFFER_SIZE_3);
}

void Upsample_3_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coords[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, Coords, 1.0 / BUFFER_SIZE_4);
}

void Upsample_2_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coords[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, Coords, 1.0 / BUFFER_SIZE_3);
}

void Upsample_1_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coords[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, Coords, 1.0 / BUFFER_SIZE_2);
}

void Upsample_0_VS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Coords[3] : TEXCOORD0)
{
    UpsampleVS(ID, Position, Coords, 1.0 / BUFFER_SIZE_1);
}

// Pixel Shaders
// 1: https://catlikecoding.com/unity/tutorials/advanced-rendering/bloom/
// 2: http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
// 3: https://community.arm.com/cfs-file/__key/communityserver-blogs-components-weblogfiles/00-00-00-20-66/siggraph2015_2D00_mmg_2D00_marius_2D00_slides.pdf
// More: https://github.com/powervr-graphics/Native_SDK

void DownsamplePS(in sampler2D Source, in float4 Coords[4], out float4 Output_Color)
{
    Output_Color = 0.0;

    float4 A_0, A_1, A_2, A_3,
           B_0, B_1, B_2, B_3,
           C_0, C_1, C_2, C_3,
           D0, D1, D2, D3;

    switch(_Downsample_Method)
    {
        case 0: // 2x2 Box
            Output_Color += tex2D(Source, Coords[0].xw);
            Output_Color += tex2D(Source, Coords[0].zw);
            Output_Color += tex2D(Source, Coords[0].xy);
            Output_Color += tex2D(Source, Coords[0].zy);
            Output_Color = Output_Color / 4.0;
            break;
        case 1: // 3x3 Tent
            // Sampler locations
            // A_0 B_0 C_0
            // A_1 B_1 C_1
            // A_2 B_2 C_2
            A_0 = tex2D(Source, Coords[0].xy);
            A_1 = tex2D(Source, Coords[0].xz);
            A_2 = tex2D(Source, Coords[0].xw);

            B_0 = tex2D(Source, Coords[1].xy);
            B_1 = tex2D(Source, Coords[1].xz);
            B_2 = tex2D(Source, Coords[1].xw);

            C_0 = tex2D(Source, Coords[2].xy);
            C_1 = tex2D(Source, Coords[2].xz);
            C_2 = tex2D(Source, Coords[2].xw);

            Output_Color += ((A_0 + C_0 + A_2 + C_2) * 1.0);
            Output_Color += ((B_0 + A_1 + C_1 + B_2) * 2.0);
            Output_Color += (B_1 * 4.0);
            Output_Color = Output_Color / 16.0;
            break;
        case 2: // Jorge
            // Sampler locations
            // A_0    B_0    C_0
            //    D0    D1
            // A_1    B_1    C_1
            //    D2    D3
            // A_2    B_2    C_2
            D0 = tex2D(Source, Coords[0].xw);
            D1 = tex2D(Source, Coords[0].zw);
            D2 = tex2D(Source, Coords[0].xy);
            D3 = tex2D(Source, Coords[0].zy);

            A_0 = tex2D(Source, Coords[1].xy);
            A_1 = tex2D(Source, Coords[1].xz);
            A_2 = tex2D(Source, Coords[1].xw);

            B_0 = tex2D(Source, Coords[2].xy);
            B_1 = tex2D(Source, Coords[2].xz);
            B_2 = tex2D(Source, Coords[2].xw);

            C_0 = tex2D(Source, Coords[3].xy);
            C_1 = tex2D(Source, Coords[3].xz);
            C_2 = tex2D(Source, Coords[3].xw);

            const float2 Weights = float2(0.5, 0.125) / 4.0;
            Output_Color += (D0 + D1 + D2 + D3) * Weights.x;
            Output_Color += (A_0 + B_0 + A_1 + B_1) * Weights.y;
            Output_Color += (B_0 + C_0 + B_1 + C_1) * Weights.y;
            Output_Color += (A_1 + B_1 + A_2 + B_2) * Weights.y;
            Output_Color += (B_1 + C_1 + B_2 + C_2) * Weights.y;
            break;
        case 3: // Kawase
            Output_Color += tex2D(Source, Coords[0].xy) * 4.0;
            Output_Color += tex2D(Source, Coords[1].xw);
            Output_Color += tex2D(Source, Coords[1].zw);
            Output_Color += tex2D(Source, Coords[1].xy);
            Output_Color += tex2D(Source, Coords[1].zy);
            Output_Color = Output_Color / 8.0;
            break;
    }

    Output_Color.a = 1.0;
}

void UpsamplePS(in sampler2D Source, in float4 Coords[3], out float4 Output_Color)
{
    Output_Color = 0.0;

    switch(_Upsample_Method)
    {
        case 0: // 2x2 Box
            Output_Color += tex2D(Source, Coords[0].xw);
            Output_Color += tex2D(Source, Coords[0].zw);
            Output_Color += tex2D(Source, Coords[0].xy);
            Output_Color += tex2D(Source, Coords[0].zy);
            Output_Color = Output_Color / 4.0;
            break;
        case 1: // 3x3 Tent
            // Sample locations:
            // A_0 B_0 C_0
            // A_1 B_1 C_1
            // A_2 B_2 C_2
            float4 A_0 = tex2D(Source, Coords[0].xy);
            float4 A_1 = tex2D(Source, Coords[0].xz);
            float4 A_2 = tex2D(Source, Coords[0].xw);
            float4 B_0 = tex2D(Source, Coords[1].xy);
            float4 B_1 = tex2D(Source, Coords[1].xz);
            float4 B_2 = tex2D(Source, Coords[1].xw);
            float4 C_0 = tex2D(Source, Coords[2].xy);
            float4 C_1 = tex2D(Source, Coords[2].xz);
            float4 C_2 = tex2D(Source, Coords[2].xw);
            Output_Color = (((A_0 + C_0 + A_2 + C_2) * 1.0) + ((B_0 + A_1 + C_1 + B_2) * 2.0) + (B_1 * 4.0)) / 16.0;
            break;
        case 2: // Kawase
            Output_Color += tex2D(Source, Coords[0].xw) * 2.0;
            Output_Color += tex2D(Source, Coords[0].zw) * 2.0;
            Output_Color += tex2D(Source, Coords[0].xy) * 2.0;
            Output_Color += tex2D(Source, Coords[0].zy) * 2.0;
            Output_Color += tex2D(Source, Coords[1].xw);
            Output_Color += tex2D(Source, Coords[1].zw);
            Output_Color += tex2D(Source, Coords[2].xy);
            Output_Color += tex2D(Source, Coords[2].xw);
            Output_Color = Output_Color / 12.0;
            break;
    }

    Output_Color.a = 1.0;
}

void Downsample_1_PS(in float4 Position : SV_POSITION, in float4 Coords[4] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    DownsamplePS(Sample_Color, Coords, Output_Color_0);
}

void Downsample_2_PS(in float4 Position : SV_POSITION, in float4 Coords[4] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    DownsamplePS(Sample_Common_1, Coords, Output_Color_0);
}

void Downsample_3_PS(in float4 Position : SV_POSITION, in float4 Coords[4] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    DownsamplePS(Sample_Common_2, Coords, Output_Color_0);
}

void Downsample_4_PS(in float4 Position : SV_POSITION, in float4 Coords[4] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    DownsamplePS(Sample_Common_3, Coords, Output_Color_0);
}

void Upsample_3_PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    UpsamplePS(Sample_Common_4, Coords, Output_Color_0);
}

void Upsample_2_PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    UpsamplePS(Sample_Common_3, Coords, Output_Color_0);
}

void Upsample_1_PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    UpsamplePS(Sample_Common_2, Coords, Output_Color_0);
}

void Upsample_0_PS(in float4 Position : SV_POSITION, in float4 Coords[3] : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    UpsamplePS(Sample_Common_1, Coords, Output_Color_0);
}

technique cDualFilter
{
    pass
    {
        VertexShader = Downsample_1_VS;
        PixelShader = Downsample_1_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_1;
    }

    pass
    {
        VertexShader = Downsample_2_VS;
        PixelShader = Downsample_2_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_2;
    }

    pass
    {
        VertexShader = Downsample_3_VS;
        PixelShader = Downsample_3_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_3;
    }

    pass
    {
        VertexShader = Downsample_4_VS;
        PixelShader = Downsample_4_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_4;
    }

    pass
    {
        VertexShader = Upsample_3_VS;
        PixelShader = Upsample_3_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_3;
    }

    pass
    {
        VertexShader = Upsample_2_VS;
        PixelShader = Upsample_2_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_2;
    }

    pass
    {
        VertexShader = Upsample_1_VS;
        PixelShader = Upsample_1_PS;
        RenderTarget0 = Shared_Resources::RGBA16F::Render_Common_1;
    }

    pass
    {
        VertexShader = Upsample_0_VS;
        PixelShader = Upsample_0_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
