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

uniform float kThreshold <
    ui_label = "Threshold";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.05f;

uniform float kInvRange <
    ui_label = "Inverse Range";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.05f;

uniform float kColorSensitivity <
    ui_label = "Color Sensitivity";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.0f;

uniform float4 kFrontColor <
    ui_label = "Front Color";
    ui_type = "color";
    ui_min = 0.0; ui_max = 1.0;
> = float4(1.0, 1.0, 1.0, 1.0);

uniform float4 kBackColor <
    ui_label = "Back Color";
    ui_type = "color";
    ui_min = 0.0; ui_max = 1.0;
> = float4(0.0, 0.0, 0.0, 0.0);

texture2D r_color : COLOR;

sampler2D s_color
{
    Texture = r_color;
    #if BUFFER_COLOR_BIT_DEPTH != 10
        SRGBTexture = true;
    #endif
};

struct v2f { float4 vpos : SV_Position; float4 uv[2] : TEXCOORD0; };

v2f vs_contour(in uint id : SV_VertexID)
{
    v2f output;
    float2 texcoord;
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    output.vpos = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    float2 ts = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    output.uv[0].xy = texcoord.xy;
    output.uv[0].zw = texcoord.xy + ts.xy;
    output.uv[1].xy = texcoord.xy + float2(ts.x, 0.0);
    output.uv[1].zw = texcoord.xy + float2(0.0, ts.y);
    return output;
}

void ps_contour(v2f input, out float3 c : SV_Target0)
{
    // Color samples
    float3 cImage[4];
    cImage[0] = tex2D(s_color, input.uv[0].xy).rgb;
    cImage[1] = tex2D(s_color, input.uv[0].zw).rgb;
    cImage[2] = tex2D(s_color, input.uv[1].xy).rgb;
    cImage[3] = tex2D(s_color, input.uv[1].zw).rgb;

    // Roberts cross operator
    float3 cga = cImage[1] - cImage[0];
    float3 cgb = cImage[3] - cImage[2];
    float cg = sqrt(dot(cga, cga) + dot(cgb, cgb));

    // Thresholding
    float edge = cg * kColorSensitivity;
    edge = saturate((edge - kThreshold) * kInvRange);
    float3 cb = lerp(cImage[0], kBackColor.rgb, kBackColor.a);
    c = lerp(cb, kFrontColor.rgb, edge * kFrontColor.a);
}

technique KinoContour
{
    pass
    {
        VertexShader = vs_contour;
        PixelShader  = ps_contour;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
