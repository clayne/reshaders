
/*
    KinoVignette ReShade port that does not require backbuffer copy

    KinoVignette - Natural vignetting effect

    Copyright (C) 2015 Keijiro Takahashi

    Permission is hereby granted, free of charge, to any person obtaining a copy of
    this software and associated documentation files (the "Software"), to deal in
    the Software without restriction, including without limitation the rights to
    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
    the Software, and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
    FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
    COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
    IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include "ReShade.fxh"

uniform float kFalloff <
    ui_label = "Falloff";
    ui_type = "drag";
> = 0.5f;

void ps_vignette(in float4 vpos : SV_Position, in float2 uv : TEXCOORD, out float3 c : SV_Target)
{
    float2 coord = (uv - 0.5) * BUFFER_ASPECT_RATIO * 2.0;
    float rf = length(coord) * kFalloff;
    float rf2_1 = mad(rf, rf, 1.0);
    c = rcp(rf2_1 * rf2_1);
}

technique KinoVignette
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ps_vignette;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
        // Multiplication blend mode
        BlendEnable = true;
        BlendOp = ADD;
        SrcBlend = DESTCOLOR;
        DestBlend = SRCALPHA;
    }
}
