
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
    }
}

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

// Pixel Shaders
// 1: https://catlikecoding.com/unity/tutorials/advanced-rendering/bloom/
// 2: http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
// 3: https://community.arm.com/cfs-file/__key/communityserver-blogs-components-weblogfiles/00-00-00-20-66/siggraph2015_2D00_mmg_2D00_marius_2D00_slides.pdf
// More: https://github.com/powervr-graphics/Native_SDK



technique cDualFilter
{

}
