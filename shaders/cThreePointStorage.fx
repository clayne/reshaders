
/*
    Three-point storage shader

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

namespace ThreePointStorage
{
    // Consideration: Use A8 channel for difference requirement (normalize BW image)

    texture2D Render_Color : COLOR;

    sampler2D Sample_Color
    {
        Texture = Render_Color;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Frame_3
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
        MipLevels = 9;
    };

    sampler2D Sample_Frame_3
    {
        Texture = Render_Frame_3;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Frame_2
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
        MipLevels = 9;
    };

    sampler2D Sample_Frame_2
    {
        Texture = Render_Frame_2;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    texture2D Render_Frame_1
    {
        Width = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA8;
        MipLevels = 9;
    };

    sampler2D Sample_Frame_1
    {
        Texture = Render_Frame_1;
        MagFilter = LINEAR;
        MinFilter = LINEAR;
        MipFilter = LINEAR;
    };

    void PostProcessVS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 TexCoord : TEXCOORD0)
    {
        TexCoord.x = (ID == 2) ? 2.0 : 0.0;
        TexCoord.y = (ID == 1) ? 2.0 : 0.0;
        Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    }

    /*
        BlueSkyDefender's three-frame storage
        
        [Frame_1] [Frame_2] [Frame_3]
        
        Scenario: Three Frames
        Frame 0: [Frame_1 (new back buffer data)] [Frame_2 (no data yet)] [Frame_3 (no data yet)]
        Frame 1: [Frame_1 (new back buffer data)] [Frame_2 (sample Frame_1 data)] [Frame_3 (no data yet)]
        Frame 2: [Frame_1 (new back buffer data)] [Frame_2 (sample Frame_1 data)] [Frame_3 (sample Frame_2 data)]
        ... and so forth
    */

    void Store_Frame_3_PS(float4 Position : SV_Position, float2 TexCoord : TEXCOORD, out float4 Color : SV_Target0)
    {
        Color = tex2D(Sample_Frame_2, TexCoord);
    }

    void Store_Frame_2_PS(float4 Position : SV_Position, float2 TexCoord : TEXCOORD, out float4 Color : SV_Target0)
    {
        Color = tex2D(Sample_Frame_1, TexCoord);
    }

    void Current_Frame_1_PS(float4 Position : SV_Position, float2 TexCoord : TEXCOORD, out float4 Color : SV_Target0)
    {
        Color = tex2D(Sample_Color, TexCoord);
    }

    /*
        TODO (bottom text)
        - Calculate vectors on Frame 3 and Frame 1 (can use pyramidal method via MipMaps)
        - Calculate warp Frame 3 and Frame 1 to Frame 2
    */

    technique cThreePointStorage
    {
        pass Store_Frame_3
        {
            VertexShader = PostProcessVS;
            PixelShader = Store_Frame_3_PS;
            RenderTarget = Render_Frame_3;
        }

        pass Store_Frame_2
        {
            VertexShader = PostProcessVS;
            PixelShader = Store_Frame_2_PS;
            RenderTarget = Render_Frame_2;
        }

        pass Store_Frame_1
        {
            VertexShader = PostProcessVS;
            PixelShader = Current_Frame_1_PS;
            RenderTarget = Render_Frame_1;
        }
    }
}
