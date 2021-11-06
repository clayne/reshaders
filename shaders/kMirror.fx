
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

uniform float _Divisor <
    ui_type = "drag";
> = 0.05f;

uniform float _Offset <
    ui_type = "drag";
> = 0.05f;

uniform float _Roll <
    ui_type = "drag";
> = 0.0f;

uniform bool _Symmetry <
> = true;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [ Pixel Shaders ] */

void MirrorPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD, out float4 OutputColor0 : SV_TARGET0)
{
    // Convert to the polar coordinate.
    float2 Polar = TexCoord - 0.5;
    float Phi = atan2(Polar.y, Polar.x);
    float Radius = length(Polar);

    // Angular repeating.
    Phi += _Offset;
    Phi = Phi - _Divisor * floor(Phi / _Divisor);
    Phi = (_Symmetry) ? min(Phi, _Divisor - Phi) : Phi;
    Phi += _Roll - _Offset;

    // Convert back to the texture coordinate.
    float2 PhiSinCos; sincos(Phi, PhiSinCos.x, PhiSinCos.y);
    TexCoord = PhiSinCos.yx * Radius + 0.5;

    // Reflection at the border of the screen.
    TexCoord = max(min(TexCoord, 2.0 - TexCoord), -TexCoord);
    OutputColor0 = tex2D(_SampleColor, TexCoord);
}

technique KinoMirror
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = MirrorPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
