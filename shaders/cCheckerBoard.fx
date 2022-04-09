
/*
    Simple 2-color checkerboarding shader

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

uniform float4 _Color_1 <
    ui_min = 0.0;
    ui_label = "Color 1";
    ui_type = "color";
> = 1.0;

uniform float4 _Color_2 <
    ui_min = 0.0;
    ui_label = "Color 2";
    ui_type = "color";
> = 0.0;

uniform bool _Invert_Checkerboard <
    ui_type = "radio";
    ui_label = "Invert Checkerboard Pattern";
> = false;

// Vertex shaders

void Basic_VS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 Coord : TEXCOORD0)
{
    Coord.x = (ID == 2) ? 2.0 : 0.0;
    Coord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(Coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Pixel shaders

void Checkerboard_PS(in float4 Position : SV_POSITION, in float2 Coord : TEXCOORD0, out float4 Output_Color_0 : SV_TARGET0)
{
    float4 Checkerboard = frac(dot(Position.xy, 0.5)) * 2.0;
    Checkerboard = _Invert_Checkerboard ? 1.0 - Checkerboard : Checkerboard;
    Output_Color_0 = Checkerboard == 1.0 ? _Color_1 : _Color_2;
}

technique cCheckerBoard
{
    pass
    {
        VertexShader = Basic_VS;
        PixelShader = Checkerboard_PS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
