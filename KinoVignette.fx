
/*
    KinoContour - Natural vignetting effect

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

uniform float _Falloff <
    ui_label = "Falloff";
    ui_type = "drag";
> = 0.5f;

sampler _MainTex { Texture = ReShade::BackBufferTex; SRGBTexture = true; };
static const float2 _Aspect = BUFFER_ASPECT_RATIO;

float4 PS_Vignette(in float4 vpos : SV_Position, in float2 uv : TEXCOORD) : SV_Target
{
    float2 coord = (uv - 0.5) * _Aspect * 2;
    float rf = sqrt(dot(coord, coord)) * _Falloff;
    float rf2_1 = rf * rf + 1.0;
    float e = 1.0 / (rf2_1 * rf2_1);

    float4 src = tex2D(_MainTex, uv);
    return float4(src.rgb * e, src.a);
}

technique KinoVignette
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Vignette;
        SRGBWriteEnable = true;
    }
}
