/*
    Code from https://github.com/ronja-tutorials/ShaderTutorials
    Note from Ronja Böhringer:
    All code in this repository is under the CC-BY license (https://creativecommons.org/licenses/by/4.0/),
    so do with it whatever you want, but please credit me You can credit me as Ronja Böhringer,
    or link to my tutorial website, this repository or my twitter).
    If you use/like what I do, also feel free to support my patreon if you want to https://www.patreon.com/RonjaTutorials.
*/

float4 vs_checker(const uint id : SV_VertexID) : SV_Position
{
    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    return float4(coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

float4 ps_checker(float4 vpos : SV_Position) : SV_Target
{
    // add different dimensions
    // divide it by 2 and get the fractional part, resulting in a value of 0 for even and 0.5 for odd numbers.
    // multiply it by 2 to make odd values white instead of grey
    float chessboard = floor(dot(vpos.xy, 1.0));
    return frac(chessboard * 0.5) * 2.0;
}

technique CheckerBoard
{
    pass
    {
        VertexShader = vs_checker;
        PixelShader = ps_checker;
        BlendEnable = true;
        BlendOp = ADD;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
