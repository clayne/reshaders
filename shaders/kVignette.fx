
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

uniform float uFalloff <
    ui_label = "Falloff";
    ui_type = "drag";
> = 0.5f;

/* [Vertex Shaders] */

void vs_generic(in uint id : SV_VERTEXID,
                out float4 position : SV_POSITION,
                out float2 texcoord : TEXCOORD)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [ Pixel Shaders ] */

float4 ps_vignette(float4 vpos : SV_POSITION,
                   float2 uv : TEXCOORD0) : SV_Target
{
    const float aspectratio = BUFFER_WIDTH / BUFFER_HEIGHT;
    float2 coord = (uv - 0.5) * aspectratio * 2.0;
    float rf = length(coord) * uFalloff;
    float rf2_1 = mad(rf, rf, 1.0);
    return rcp(rf2_1 * rf2_1);
}

technique KinoVignette
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_vignette;
        SRGBWriteEnable = true;
        // Multiplication blend mode
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
    }
}
