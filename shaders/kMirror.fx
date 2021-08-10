
/*
    KinoContour - Mirroring and kaleidoscope effect

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

#include "cFunctions.fxh"

uniform float kDivisor <
    ui_label = "Divisor";
    ui_type = "drag";
> = 0.05f;

uniform float kOffset <
    ui_label = "Offset";
    ui_type = "drag";
> = 0.05f;

uniform float kRoll <
    ui_label = "Roll";
    ui_type = "drag";
> = 0.0f;

uniform bool kSymmetry <
    ui_label = "Symmetry?";
> = true;

void ps_mirror(in float4 vpos : SV_Position, in float2 uv : TEXCOORD, out float4 c : SV_Target)
{
    // Convert to the polar coordinate.
    float2 sc = uv - 0.5;
    float phi = atan2(sc.y, sc.x);
    float r = length(sc);

    // Angular repeating.
    phi += kOffset;
    phi = phi - kDivisor * floor(phi / kDivisor);

    if(kSymmetry) { phi = min(phi, kDivisor - phi); }
    phi += kRoll - kOffset;

    // Convert back to the texture coordinate.
    float2 scphi; sincos(phi, scphi.x, scphi.y);
    uv = scphi.yx * r + 0.5;

    // Reflection at the border of the screen.
    uv = max(min(uv, 2.0 - uv), -uv);

    c = tex2D(core::samplers::srgb, uv);
}

technique KinoMirror
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_mirror;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
