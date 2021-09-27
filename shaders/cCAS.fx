/*
    LICENSE
    =======
    Copyright (c) 2017-2019 Advanced Micro Devices, Inc. All rights reserved.
    -------
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
    files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
    modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:
    -------
    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
    Software.
    -------
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
    WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR
    COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
    ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE

    Initial port to ReShade: SLSNe https://gist.github.com/SLSNe/bbaf2d77db0b2a2a0755df581b3cf00c

    Optimizations by Marty McFly:
    vectorized math, even with scalar gcn hardware this should work
    out the same, order of operations has not changed
    For some reason, it went from 64 to 48 instructions, a lot of MOV gone
    Also modified the way the final window is calculated

    reordered min() and max() operations, from 11 down to 9 registers

    restructured final weighting, 49 -> 48 instructions

    delayed RCP to replace SQRT with RSQRT

    removed the saturate() from the control var as it is clamped
    by UI manager already, 48 -> 47 instructions

    Further modified by OopyDoopy and Lord of Lunacy:
        Changed wording in the UI for the existing variable and added a new variable and relevant code to adjust sharpening strength.

    Fix by Lord of Lunacy:
        Made the shader use a linear colorspace rather than sRGB, as recommended by the original AMD documentation from FidelityFX.

    Modified by CeeJay.dk:
        Included a label and tooltip description. I followed AMDs official naming guidelines for FidelityFX.
*/

uniform float _Contrast <
    ui_type = "drag";
    ui_label = "Contrast Adaptation";
    ui_tooltip = "Adjusts the range the shader adapts to high contrast (0 is not all the way off).  Higher values = more high contrast sharpening.";
    ui_min = 0.0; ui_max = 1.0;
> = 0.0;

uniform float _Sharpening <
    ui_type = "drag";
    ui_label = "Sharpening intensity";
    ui_tooltip = "Adjusts sharpening intensity by averaging the original pixels to the sharpened result.  1.0 is the unmodified default.";
    ui_min = 0.0; ui_max = 1.0;
> = 1.0;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

void SharpenVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Offset[3] : TEXCOORD0)
{
    float2 TexCoord;
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    const float2 PixelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    Offset[0] = TexCoord.xyxy + float4(-1.0,-1.0, 1.0, 1.0) * PixelSize.xyxy;
    Offset[1] = TexCoord.xxxy + float4(-1.0, 1.0, 0.0, 0.0) * PixelSize.xxxy;
    Offset[2] = TexCoord.yyxx + float4(-1.0, 1.0, 0.0, 0.0) * PixelSize.yyxx;
}

void SharpenPS(float4 Position : SV_POSITION, float4 Offset[3] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    // fetch a 3x3 neighborhood around the pixel 'e',
    //  A B C
    //  D(E)F
    //  G H I

    float3 A = tex2D(_SampleColor, Offset[0].xw).rgb; // [-1, 1]
    float3 B = tex2D(_SampleColor, Offset[2].zy).rgb; // [ 0, 1]
    float3 C = tex2D(_SampleColor, Offset[0].zw).rgb; // [ 1, 1]

    float3 D = tex2D(_SampleColor, Offset[1].xw).rgb; // [-1, 0]
    float3 E = tex2D(_SampleColor, Offset[1].zw).rgb; // [ 0, 0]
    float3 F = tex2D(_SampleColor, Offset[1].yw).rgb; // [ 1, 0]

    float3 G = tex2D(_SampleColor, Offset[0].xy).rgb; // [-1,-1]
    float3 H = tex2D(_SampleColor, Offset[2].zx).rgb; // [ 0,-1]
    float3 I = tex2D(_SampleColor, Offset[0].zy).rgb; // [ 1,-1]

    // Soft min and max.
    //  A B C             B
    //  D E F * 0.5  +  D E F * 0.5
    //  G H I             H
    // These are 2.0x bigger (factored out the extra multiply).

    float3 MinRGB  = min(min(min(D, E), min(F, B)), H);
    float3 MinRGB2 = min(MinRGB, min(min(A, C), min(G, I)));
    MinRGB += MinRGB2;

    float3 MaxRGB  = max(max(max(D, E), max(F, B)), H);
    float3 MaxRGB2 = max(MaxRGB, max(max(A, C), max(G, I)));
    MaxRGB += MaxRGB2;

    // Smooth minimum distance to signal limit divided by smooth max.
    float3 RCPMaxRGB = rcp(MaxRGB);
    float3 AmpRGB  = saturate(min(MinRGB, 2.0 - MaxRGB) * RCPMaxRGB);

    // Shaping amount of sharpening.
    AmpRGB = rsqrt(AmpRGB);
    float Peak = mad(-3.0, _Contrast, 8.0);
    float3 WeightRGB = -rcp(AmpRGB * Peak);
    float3 RCPWeightRGB = rcp(mad(4.0, WeightRGB, 1.0));

    //                0 W 0
    //  Filter shape: W 1 W
    //                0 W 0
    float3 Window = B + D + F + H;
    float3 Output = mad(Window, WeightRGB, E) * RCPWeightRGB;
    OutputColor0 = saturate(lerp(E, Output, _Sharpening));
}

technique ContrastAdaptiveSharpen
    <
    ui_label = "AMD FidelityFX Contrast Adaptive Sharpening";
    ui_tooltip =
    "CAS is a low overhead adaptive sharpening algorithm that AMD includes with their drivers.\n"
    "This port to Reshade works with all cards from all vendors,\n"
    "but cannot do the optional scaling that CAS is normally also capable of when activated in the AMD drivers.\n"
    "\n"
    "The algorithm adjusts the amount of sharpening per pixel to target an even level of sharpness across the image.\n"
    "Areas of the input image that are already sharp are sharpened less, while areas that lack detail are sharpened more.\n"
    "This allows for higher overall natural visual sharpness with fewer artifacts.";
    >
{
    pass
    {
        VertexShader = SharpenVS;
        PixelShader  = SharpenPS;
        SRGBWriteEnable = TRUE;
    }
}
