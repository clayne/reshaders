
/*
    https://github.com/keijiro/Kino :: Unlicense

    This is free and unencumbered software released into the public domain.

    Anyone is free to copy, modify, publish, use, compile, sell, or
    distribute this software, either in source code form or as a compiled
    binary, for any purpose, commercial or non-commercial, and by any
    means.

    In jurisdictions that recognize copyright laws, the author or authors
    of this software dedicate any and all copyright interest in the
    software to the public domain. We make this dedication for the benefit
    of the public at large and to the detriment of our heirs and
    successors. We intend this dedication to be an overt act of
    relinquishment in perpetuity of all present and future rights to this
    software under copyright law.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
    OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
    ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    OTHER DEALINGS IN THE SOFTWARE.

    For more information, please refer to <http://unlicense.org/>
*/

#include "ReShade.fxh"

uniform float kIntensity <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Sharpen";
    ui_tooltip = "Increase to sharpen details within the image.";
> = 0.05;

sampler2D sLinear
{
    Texture = ReShade::BackBufferTex;
    #if BUFFER_COLOR_BIT_DEPTH != 10
        SRGBTexture = true;
    #endif
};

int2 offset(int2 i) { return min(max(0, i), BUFFER_SCREEN_SIZE - 1); }

void PS_Fragment(in float4 vpos : SV_Position, in float2 uv : TEXCOORD, out float4 c : SV_Target)
{
    int2 positionSS = uv * BUFFER_SCREEN_SIZE;

    float4 c0 = tex2Doffset(sLinear, uv, + offset(int2(-1, -1)));
    float4 c1 = tex2Doffset(sLinear, uv, + offset(int2( 0, -1)));
    float4 c2 = tex2Doffset(sLinear, uv, + offset(int2(+1, -1)));

    float4 c3 = tex2Doffset(sLinear, uv, + offset(int2(-1, 0)));
    float4 c4 = tex2Doffset(sLinear, uv, + offset(int2( 0, 0)));
    float4 c5 = tex2Doffset(sLinear, uv, + offset(int2(+1, 0)));

    float4 c6 = tex2Doffset(sLinear, uv, + offset(int2(-1, +1)));
    float4 c7 = tex2Doffset(sLinear, uv, + offset(int2( 0, +1)));
    float4 c8 = tex2Doffset(sLinear, uv, + offset(int2(+1, +1)));

    c = c4 - (c0 + c1 + c2 + c3 - 8 * c4 + c5 + c6 + c7 + c8) * kIntensity;
}

technique KinoSharpen
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Fragment;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
