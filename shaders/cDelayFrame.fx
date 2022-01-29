/*
    Delay frame shader
    
    BSD 3-Clause License

    Copyright (c) 2022, brimson
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

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
};

texture2D _RenderBackwardFrame
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
};

sampler2D _SampleBackwardFrame
{
    Texture = _RenderBackwardFrame;
};

texture2D _RenderForwardFrame
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
};

sampler2D _SampleForwardFrame
{
    Texture = _RenderForwardFrame;
};

// Vertex shaders

void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = TexCoord.xyxy * float4(2.0, -2.0, 0.0, 0.0) + float4(-1.0, 1.0, 0.0, 1.0);
}

// Pixel shaders

void StoreBackwardFramePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    OutputColor0 = tex2D(_SampleCurrentFrame, TexCoord);
}

void StoreActualFramePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    OutputColor0 = tex2D(_SampleCurrentFrame, TexCoord);
}

void StoreForwardFramePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    OutputColor0 = tex2D(_SampleColor, TexCoord);
}

void OutputPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    OutputColor0 = tex2D(_SampleColor, TexCoord);
}

technique
{
    pass StoreBackwardFrame
    {
        VertexShader = PostProcessVS;
        PixelShader = StoreBackwardFramePS;
        RenderTarget0 = _RenderPreviousFrame;
    }

    pass StoreActualFrame
    {
        VertexShader = PostProcessVS;
        PixelShader = StoreActualFramePS;
        RenderTarget0 = _RenderPreviousFrame;
    }

    pass StoreForwardFrame
    {
        VertexShader = PostProcessVS;
        PixelShader = StoreForwardFramePS;
        RenderTarget0 = _SampleCurrentFrame;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OutputPS;
    }
}
