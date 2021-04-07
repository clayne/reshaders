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

    Modified by Brimson:
        Calculate offsets in the Vertex Shader. Should yield a ~10-20% performance increase as we're on D3D9
*/

uniform float kContrast <
    ui_type = "drag";
    ui_label = "Contrast Adaptation";
    ui_tooltip = "Adjusts the range the shader adapts to high contrast (0 is not all the way off).  Higher values = more high contrast sharpening.";
    ui_min = 0.0; ui_max = 1.0;
> = 0.0;

uniform float kSharpening <
    ui_type = "drag";
    ui_label = "Sharpening intensity";
    ui_tooltip = "Adjusts sharpening intensity by averaging the original pixels to the sharpened result.  1.0 is the unmodified default.";
    ui_min = 0.0; ui_max = 1.0;
> = 1.0;

texture2D r_source : COLOR;

sampler s_source
{
    Texture = r_source;
    #if BUFFER_COLOR_BIT_DEPTH != 10
        SRGBTexture = true;
    #endif
};

struct v2f { float4 vpos  : SV_Position; float4 uv[5] : TEXCOORD0; };

v2f vs_cas(in uint id : SV_VertexID)
{
    v2f o;
    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    o.vpos = float4(coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    const float2 ts = 1.0 / tex2Dsize(s_source, 0.0);
    o.uv[0].xy = mad(ts, float2(-1.0,-1.0), coord);
    o.uv[0].zw = mad(ts, float2( 0.0,-1.0), coord);
    o.uv[1].xy = mad(ts, float2( 1.0,-1.0), coord);
    o.uv[1].zw = mad(ts, float2(-1.0, 0.0), coord);
    o.uv[2].xy = mad(ts, float2(-1.0, 1.0), coord);
    o.uv[2].zw = coord;
    o.uv[3].xy = mad(ts, float2( 1.0, 0.0), coord);
    o.uv[3].zw = mad(ts, float2( 0.0, 1.0), coord);
    o.uv[4].xy = mad(ts, float2( 1.0, 1.0), coord);
    o.uv[4].zw = 0.0;
    return o;
}

float3 ps_cas(v2f input) : SV_Target
{
    // fetch a 3x3 neighborhood around the pixel 'e',
    //  a b c
    //  d(e)f
    //  g h i

    float3 a = tex2D(s_source, input.uv[0].xy).rgb;
    float3 b = tex2D(s_source, input.uv[0].zw).rgb;
    float3 c = tex2D(s_source, input.uv[1].xy).rgb;
    float3 d = tex2D(s_source, input.uv[1].zw).rgb;

    float3 g = tex2D(s_source, input.uv[2].xy).rgb;
    float3 e = tex2D(s_source, input.uv[2].zw).rgb;
    float3 f = tex2D(s_source, input.uv[3].xy).rgb;

    float3 h = tex2D(s_source, input.uv[3].zw).rgb;
    float3 i = tex2D(s_source, input.uv[4].xy).rgb;

    // Soft min and max.
    //  a b c             b
    //  d e f * 0.5  +  d e f * 0.5
    //  g h i             h
    // These are 2.0x bigger (factored out the extra multiply).
    float3 mnRGB  = min(min(min(d, e), min(f, b)), h);
    float3 mnRGB2 = min(mnRGB, min(min(a, c), min(g, i)));
    mnRGB += mnRGB2;

    float3 mxRGB  = max(max(max(d, e), max(f, b)), h);
    float3 mxRGB2 = max(mxRGB, max(max(a, c), max(g, i)));
    mxRGB += mxRGB2;

    // Smooth minimum distance to signal limit divided by smooth max.
    float3 rcpMRGB = rcp(mxRGB);
    float3 ampRGB  = saturate(min(mnRGB, 2.0 - mxRGB) * rcpMRGB);

    // Shaping amount of sharpening.
    ampRGB = rsqrt(ampRGB);

    float peak = mad(-3.0, kContrast, 8.0);
    float3 wRGB = -rcp(ampRGB * peak);

    float3 rcpWeightRGB = rcp(mad(4.0, wRGB, 1.0));

    //                          0 w 0
    //  Filter shape:           w 1 w
    //                          0 w 0
    float3 window = b + d + f + h;
    float3 o = mad(window, wRGB, e) * rcpWeightRGB;
    return saturate(lerp(e, o, kSharpening));
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
        VertexShader = vs_cas;
        PixelShader  = ps_cas;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
