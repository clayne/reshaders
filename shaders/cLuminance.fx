
/*
    Various luminance algorithms

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

uniform int _Select <
    ui_type = "combo";
    ui_items = " Average\0 Sum\0 Max\0 Median\0 Length\0 Clamped Length\0 None\0";
    ui_label = "Method";
    ui_tooltip = "Select Luminance";
> = 0;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

// Vertex shaders

void PostProcessVS(in uint ID : SV_VertexID, out float4 Position : SV_Position, out float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Pixel shaders

void LuminancePS(in float4 Position : SV_Position, in float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target0)
{
    float4 Color = tex2D(_SampleColor, TexCoord);
    switch(_Select)
    {
        case 0:
            // Average
            OutputColor0 = dot(Color.rgb, 1.0 / 3.0);
            break;
        case 1:
            // Sum
            OutputColor0 = dot(Color.rgb, 1.0);
            break;
        case 2:
            // Max
            OutputColor0 = max(Color.r, max(Color.g, Color.b));
            break;
        case 3:
            // Median
            OutputColor0 = max(min(Color.r, Color.g), min(max(Color.r, Color.g), Color.b));
            break;
        case 4:
            // Length
            OutputColor0 = length(Color.rgb);
            break;
        case 4:
            // Clamped Length
            OutputColor0 = length(Color.rgb) * rsqrt(3.0);
            break;
        default:
            OutputColor0 = Color;
            break;
    }
}

technique cLuminance
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = LuminancePS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
