
/*
    Buffer blending shader

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

uniform int _Blend <
    ui_label = "Blend Mode";
    ui_type = "combo";
    ui_items = " Add\0 Subtract\0 Multiply\0 Min\0 Max\0 Screen\0 Lerp\0";
> = 0;

uniform float _Lerp_Weight <
    ui_label = "Lerp Weight";
    ui_type = "slider";
> = 0.5;

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

texture2D Render_Copy
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA8;
};

sampler2D Sample_Copy
{
    Texture = Render_Copy;
    MagFilter = LINEAR;
    MinFilter = LINEAR;
    MipFilter = LINEAR;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

// Vertex shaders

void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 Coord : TEXCOORD0)
{
    Coord.x = (ID == 2) ? 2.0 : 0.0;
    Coord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(Coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Pixel shaders

void Blit_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    Output_Color_0 = tex2D(Sample_Color, Coord);
}

void Blend_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    float4 Src = tex2D(Sample_Copy, Coord);
    float4 Dest = tex2D(Sample_Color, Coord);

    switch(_Blend)
    {
        case 0: // Add
            Output_Color_0 = Src + Dest;
            break;
        case 1: // Subtract
            Output_Color_0 = Src - Dest;
            break;
        case 2: // Multiply
            Output_Color_0 = Src * Dest;
            break;
        case 3: // Min
            Output_Color_0 = min(Src, Dest);
            break;
        case 4: // Max
            Output_Color_0 = max(Src, Dest);
            break;
        case 5: // Screen
            Output_Color_0 = (Src + Dest) - (Src * Dest);
            break;
        case 6: // Lerp
            Output_Color_0 = lerp(Src, Dest, _Lerp_Weight);
            break;
        default:
            Output_Color_0 = Dest;
            break;
    }
}

technique cCopyBuffer
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Blit_PS;
        RenderTarget0 = Render_Copy;
        #if BUFFER_COLOR_BIT_DEPTH == 8
           SRGBWriteEnable = TRUE;
        #endif
    }
}

technique cBlendBuffer
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Blend_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
           SRGBWriteEnable = TRUE;
        #endif
    }
}
