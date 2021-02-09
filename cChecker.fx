/*
    Code from https://github.com/ronja-tutorials/ShaderTutorials
    Note from Ronja Böhringer:
    All code in this repository is under the CC-BY license (https://creativecommons.org/licenses/by/4.0/),
    so do with it whatever you want, but please credit me You can credit me as Ronja Böhringer,
    or link to my tutorial website, this repository or my twitter).
    If you use/like what I do, also feel free to support my patreon if you want to https://www.patreon.com/RonjaTutorials.
*/

#include "ReShade.fxh"

struct v2f { float4 vpos : SV_POSITION; float2 uv : TEXCOORD0; };

void ps_checker(v2f input, out float3 c : SV_Target0)
{
    // add different dimensions
    // divide it by 2 and get the fractional part, resulting in a value of 0 for even and 0.5 for odd numbers.
    // multiply it by 2 to make odd values white instead of grey
    float chessboard = floor(input.vpos.x + input.vpos.y);
    c = frac(chessboard * 0.5) * 2.0;
}

technique CheckerBoard
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ps_checker;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
        BlendEnable = true;
        BlendOp = ADD;
        SrcBlend = DESTCOLOR;
        DestBlend = SRCALPHA;
    }
}
