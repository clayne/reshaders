
/*
    Simple, crispy unsharp shader

    MIT License

    Copyright (c) 2022 brimson

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
*/

uniform float _Weight <
    ui_type = "drag";
> = 1.0;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

// Vertex shaders

void ShardVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0, out float4 Offset : TEXCOORD1)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    const float2 pSize = 0.5 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    Offset = TexCoord.xyxy + float4(-pSize, pSize);
}

/* [ Pixel Shaders ] */

void ShardPS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, in float4 Offset : TEXCOORD1, out float4 OutputColor0 : SV_Target0)
{
    float4 OriginalSample = tex2D(_SampleColor, TexCoord);
    float4 BlurSample;
    BlurSample += tex2D(_SampleColor, Offset.xw) * 0.25;
    BlurSample += tex2D(_SampleColor, Offset.zw) * 0.25;
    BlurSample += tex2D(_SampleColor, Offset.xy) * 0.25;
    BlurSample += tex2D(_SampleColor, Offset.zy) * 0.25;
    OutputColor0 = OriginalSample + (OriginalSample - BlurSample) * _Weight;
}

technique cShard
{
    pass
    {
        VertexShader = ShardVS;
        PixelShader = ShardPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
