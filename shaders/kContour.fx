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

uniform bool _NormalizeInput <
    ui_label = "Normalize Color Input";
    ui_type = "radio";
> = false;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

void ContourVS(in uint ID : SV_VertexID, inout float4 Position : SV_POSITION, inout float4 Offset[2] : TEXCOORD)
{
    float2 TexCoord;
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    float2 ts = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    Offset[0].xy = TexCoord;
    Offset[0].zw = TexCoord + ts.xy;
    Offset[1].xy = TexCoord + float2(ts.x, 0.0);
    Offset[1].zw = TexCoord + float2(0.0, ts.y);
}

void ContourPS(float4 Position : SV_POSITION, float4 Offset[2] : TEXCOORD0, out float3 OutputColor0 : SV_Target0)
{
    // Color samples
    float3 SampledColor[4];
    SampledColor[0] = tex2D(_SampleColor, Offset[0].xy).rgb;
    SampledColor[1] = tex2D(_SampleColor, Offset[0].zw).rgb;
    SampledColor[2] = tex2D(_SampleColor, Offset[1].xy).rgb;
    SampledColor[3] = tex2D(_SampleColor, Offset[1].zw).rgb;
    float3 CrossA, CrossB;

    // Roberts cross operator
    if(_NormalizeInput)
    {
        CrossA = normalize(SampledColor[1]) - normalize(SampledColor[0]);
        CrossB = normalize(SampledColor[3]) - normalize(SampledColor[2]);
    }
    else
    {
        CrossA = SampledColor[1] - SampledColor[0];
        CrossB = SampledColor[3] - SampledColor[2];
    }

    float Cross = sqrt(dot(CrossA, CrossA) + dot(CrossB, CrossB));

    // Thresholding
    float Edge = Cross * _ColorSensitivity;
    Edge = saturate((Edge - _Threshold) * _InvRange);
    float3 ColorBackground = lerp(SampledColor[0], _BackColor.rgb, _BackColor.a);
    OutputColor0 = lerp(ColorBackground, _FrontColor.rgb, Edge * _FrontColor.a);
}

technique KinoContour
{
    pass
    {
        VertexShader = ContourVS;
        PixelShader = ContourPS;
        SRGBWriteEnable = TRUE;
    }
}
