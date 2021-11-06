/*
    KinoContour - Contour line effect

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

uniform float _Threshold <
    ui_label = "Threshold";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.05f;

uniform float _InvRange <
    ui_label = "Inverse Range";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.05f;

uniform float _ColorSensitivity <
    ui_label = "Color Sensitivity";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.0f;

uniform float4 _FrontColor <
    ui_label = "Front Color";
    ui_type = "color";
    ui_min = 0.0; ui_max = 1.0;
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 _BackColor <
    ui_label = "Back Color";
    ui_type = "color";
    ui_min = 0.0; ui_max = 1.0;
> = float4(0.0, 0.0, 0.0, 0.0);

uniform int _Select <
    ui_type = "combo";
    ui_items = " Fwidth\0 Laplacian\0 Sobel\0 Prewitt\0 Robert\0 Scharr\0 Kayyali\0 Kroon\0 FastSobel\0 None\0";
    ui_label = "Method";
    ui_tooltip = "Select Edge Detection";
> = 0;

uniform bool _NormalizeOutput <
    ui_label = "Normalize Output";
    ui_type = "radio";
> = true;

uniform float _NormalWeight <
    ui_label = "Normal Weight";
    ui_type = "drag";
    ui_min = 0.0;
> = 0.1;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void ContourVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 TexCoord[4] : TEXCOORD0)
{
    float2 TexCoord0;
    PostProcessVS(ID, Position, TexCoord0);
    const float2 PixelSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    TexCoord[0] = TexCoord0.xyyy + float4(-PixelSize.x, +PixelSize.y, 0.0, -PixelSize.y);
    TexCoord[1] = TexCoord0.xyyy + float4(0.0, +PixelSize.y, 0.0, -PixelSize.y);
    TexCoord[2] = TexCoord0.xyyy + float4(+PixelSize.x, +PixelSize.y, 0.0, -PixelSize.y);
    TexCoord[3] = TexCoord0.xyxy + float4(PixelSize, -PixelSize) * 0.5;
}

float Magnitude(float3 X, float3 Y)
{
    return sqrt(dot(X, X) + dot(Y, Y));
}

float3 NormalizeValue(float3 Input)
{
    return (_NormalizeOutput) ? Input * rsqrt(dot(Input, Input) + _NormalWeight) : Input;
}

void ContourPS(float4 Position : SV_POSITION, float4 TexCoord[4] : TEXCOORD0, out float3 OutputColor0 : SV_TARGET0)
{
    /*
        A0 B0 C0
        A1 B1 C1
        A2 B2 C2
    */

    float3 A0 = tex2D(_SampleColor, TexCoord[0].xy).rgb;
    float3 A1 = tex2D(_SampleColor, TexCoord[0].xz).rgb;
    float3 A2 = tex2D(_SampleColor, TexCoord[0].xw).rgb;

    float3 B0 = tex2D(_SampleColor, TexCoord[1].xy).rgb;
    float3 B1 = tex2D(_SampleColor, TexCoord[1].xz).rgb;
    float3 B2 = tex2D(_SampleColor, TexCoord[1].xw).rgb;

    float3 C0 = tex2D(_SampleColor, TexCoord[2].xy).rgb;
    float3 C1 = tex2D(_SampleColor, TexCoord[2].xz).rgb;
    float3 C2 = tex2D(_SampleColor, TexCoord[2].xw).rgb;

    float3 Ix, Iy, Edge;

    switch(_Select)
    {
        case 0: // fwidth()
            Ix = NormalizeValue(ddx(B1));
            Iy = NormalizeValue(ddy(B1));
            Edge = Magnitude(Ix, Iy);
            break;
        case 1: // Laplacian
            Edge = (A1 + C1 + B0 + B2) + (B1 * -4.0);
            Edge = NormalizeValue(Edge);
            Edge = length(Edge) / sqrt(3.0);
            break;
        case 2: // Sobel
            Ix = (-A0 + ((-A1 * 2.0) + -A2)) + (C0 + (C1 * 2.0) + C2);
            Iy = (-A0 + ((-B0 * 2.0) + -C0)) + (A2 + (B2 * 2.0) + C2);
            Edge = Magnitude(NormalizeValue(Ix), NormalizeValue(Iy));
            break;
        case 3: // Prewitt
            Ix = (-A0 - A1 - A2) + (C0 + C1 + C2);
            Iy = (-A0 - B0 - C0) + (A2 + B2 + C2);
            Edge = Magnitude(NormalizeValue(Ix), NormalizeValue(Iy));
            break;
        case 4: // Robert's Cross
            Ix = C0 - B1;
            Iy = B0 - C1;
            Edge = Magnitude(NormalizeValue(Ix), NormalizeValue(Iy));
            break;
        case 5: // Scharr
            Ix += A0 * -3.0;
            Ix += A1 * -10.0;
            Ix += A2 * -3.0;
            Ix += C0 * 3.0;
            Ix += C1 * 10.0;
            Ix += C2 * 3.0;

            Iy += A0 * 3.0;
            Iy += B0 * 10.0;
            Iy += C0 * 3.0;
            Iy += A2 * -3.0;
            Iy += B2 * -10.0;
            Iy += C2 * -3.0;
            Edge = Magnitude(NormalizeValue(Ix), NormalizeValue(Iy));
            break;
        case 6: // Kayyali
            float3 Cross = (A0 * 6.0) + (C0 * -6.0) + (A2 * -6.0) + (C2 * 6.0);
            Cross = NormalizeValue(Cross);
            Edge = Magnitude(Cross, -Cross);
            break;
        case 7: // Kroon
            Ix += A0 * -17.0;
            Ix += A1 * -61.0;
            Ix += A2 * -17.0;
            Ix += C0 * 17.0;
            Ix += C1 * 61.0;
            Ix += C2 * 17.0;

            Iy += A0 * 17.0;
            Iy += B0 * 61.0;
            Iy += C0 * 17.0;
            Iy += A2 * -17.0;
            Iy += B2 * -61.0;
            Iy += C2 * -17.0;
            Edge = Magnitude(NormalizeValue(Ix), NormalizeValue(Iy));
            break;
        case 8: // Fast Sobel
            float3 Sample0 = tex2D(_SampleColor, TexCoord[3].zy).rgb; // (-x, +y)
            float3 Sample1 = tex2D(_SampleColor, TexCoord[3].xy).rgb; // (+x, +y)
            float3 Sample2 = tex2D(_SampleColor, TexCoord[3].zw).rgb; // (-x, -y)
            float3 Sample3 = tex2D(_SampleColor, TexCoord[3].xw).rgb; // (+x, -y)
            Ix = ((-Sample2 + -Sample0) + (Sample3 + Sample1)) * 4.0;
            Iy = ((Sample2 + Sample3) + (-Sample0 + -Sample1)) * 4.0;
            Edge = Magnitude(NormalizeValue(Ix), NormalizeValue(Iy));
            break;
        default:
            Edge = tex2D(_SampleColor, TexCoord[1].xz).rgb;
            break;
    }

    // Thresholding
    Edge = Edge * _ColorSensitivity;
    Edge = saturate((Edge - _Threshold) * _InvRange);
    float3 Base = tex2D(_SampleColor, TexCoord[1].xz).rgb;
    float3 ColorBackground = lerp(Base, _BackColor.rgb, _BackColor.a);
    OutputColor0 = lerp(ColorBackground, _FrontColor.rgb, Edge * _FrontColor.a);
}

technique KinoContour
{
    pass
    {
        VertexShader = ContourVS;
        PixelShader = ContourPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
