/*
    Custom version of KinoBloom. Should be lighter than qUINT_Bloom

    MIT License

    Copyright (c) 2015-2017 Keijiro Takahashi

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

uniform float BLOOM_CURVE <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 10.0;
    ui_label = "Bloom Curve";
    ui_tooltip = "Higher values limit bloom to bright light sources only.";
> = 8.0;

uniform float BLOOM_SAT <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 5.0;
    ui_label = "Bloom Saturation";
    ui_tooltip = "Adjusts the color strength of the bloom effect";
> = 2.0;

texture2D _Source : COLOR;
texture2D _Bloom1 { Width = BUFFER_WIDTH / 2;   Height = BUFFER_HEIGHT / 2;   Format = RGBA16F; };
texture2D _Bloom2 { Width = BUFFER_WIDTH / 4;   Height = BUFFER_HEIGHT / 4;   Format = RGBA16F; };
texture2D _Bloom3 { Width = BUFFER_WIDTH / 8;   Height = BUFFER_HEIGHT / 8;   Format = RGBA16F; };
texture2D _Bloom4 { Width = BUFFER_WIDTH / 16;  Height = BUFFER_HEIGHT / 16;  Format = RGBA16F; };
texture2D _Bloom5 { Width = BUFFER_WIDTH / 32;  Height = BUFFER_HEIGHT / 32;  Format = RGBA16F; };
texture2D _Bloom6 { Width = BUFFER_WIDTH / 64;  Height = BUFFER_HEIGHT / 64;  Format = RGBA16F; };
texture2D _Bloom7 { Width = BUFFER_WIDTH / 128; Height = BUFFER_HEIGHT / 128; Format = RGBA16F; };

sampler2D s_Source
{
    Texture = _Source;
    #if BUFFER_COLOR_BIT_DEPTH != 10
        SRGBTexture = true;
    #endif
};

sampler2D s_Bloom1 { Texture = _Bloom1; };
sampler2D s_Bloom2 { Texture = _Bloom2; };
sampler2D s_Bloom3 { Texture = _Bloom3; };
sampler2D s_Bloom4 { Texture = _Bloom4; };
sampler2D s_Bloom5 { Texture = _Bloom5; };
sampler2D s_Bloom6 { Texture = _Bloom6; };
sampler2D s_Bloom7 { Texture = _Bloom7; };

struct v2f { float4 vpos : SV_Position; float4 uv[2] : TEXCOORD0; };

v2f v_samp(uint id, sampler2D src, float ufac)
{
    v2f o;
    float2 texcoord;
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    o.vpos = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    // 9 tap gaussian using 4 texture fetches by CeeJayDK
    // https://github.com/CeeJayDK/SweetFX - LumaSharpen.fx
    float2 ts = rcp(tex2Dsize(src, 0.0).xy);
    o.uv[0].xy = texcoord + float2( ts.x * 0.5, -ts.y * ufac); // South South East
    o.uv[0].zw = texcoord + float2(-ts.x * ufac,-ts.y * 0.5); // West South West
    o.uv[1].xy = texcoord + float2( ts.x * ufac, ts.y * 0.5); // East North East
    o.uv[1].zw = texcoord + float2(-ts.x * 0.5,  ts.y * ufac); // North North West
    return o;
}

v2f vs_dsamp0(uint id : SV_VertexID) { return v_samp(id, s_Source, 2.0); }
v2f vs_dsamp1(uint id : SV_VertexID) { return v_samp(id, s_Bloom1, 2.0); }
v2f vs_dsamp2(uint id : SV_VertexID) { return v_samp(id, s_Bloom2, 2.0); }
v2f vs_dsamp3(uint id : SV_VertexID) { return v_samp(id, s_Bloom3, 2.0); }
v2f vs_dsamp4(uint id : SV_VertexID) { return v_samp(id, s_Bloom4, 2.0); }
v2f vs_dsamp5(uint id : SV_VertexID) { return v_samp(id, s_Bloom5, 2.0); }
v2f vs_dsamp6(uint id : SV_VertexID) { return v_samp(id, s_Bloom6, 2.0); }

v2f vs_usamp7(uint id : SV_VertexID) { return v_samp(id, s_Bloom7, 1.0); }
v2f vs_usamp6(uint id : SV_VertexID) { return v_samp(id, s_Bloom6, 1.0); }
v2f vs_usamp5(uint id : SV_VertexID) { return v_samp(id, s_Bloom5, 1.0); }
v2f vs_usamp4(uint id : SV_VertexID) { return v_samp(id, s_Bloom4, 1.0); }
v2f vs_usamp3(uint id : SV_VertexID) { return v_samp(id, s_Bloom3, 1.0); }
v2f vs_usamp2(uint id : SV_VertexID) { return v_samp(id, s_Bloom2, 1.0); }
v2f vs_usamp1(uint id : SV_VertexID) { return v_samp(id, s_Bloom1, 1.0); }

float4 p_dsamp(sampler src, float4 uv[2])
{
    float4x4 s = float4x4(tex2D(src, uv[0].xy), tex2D(src, uv[0].zw),
                          tex2D(src, uv[1].xy), tex2D(src, uv[1].zw));

    // Karis's luma weighted average
    const float4 w = float2(1.0 / 3.0, 1.0).xxxy;
    float4 luma;
    luma.x = rcp(dot(s[0], w));
    luma.y = rcp(dot(s[1], w));
    luma.z = rcp(dot(s[2], w));
    luma.w = rcp(dot(s[3], w));
    float o_div_wsum = rcp(dot(luma, 1.0));

    return mul(luma, s) * o_div_wsum;
}

// Instead of vanilla bilinear, we use gaussian from CeeJayDK's SweetFX LumaSharpen.
float3 p_usamp(sampler2D src, float4 uv[2])
{
    float3 s  = tex2D(src, uv[0].xy).rgb * 0.25; // South South East
           s += tex2D(src, uv[0].zw).rgb * 0.25; // West South West
           s += tex2D(src, uv[1].xy).rgb * 0.25; // East North East
           s += tex2D(src, uv[1].zw).rgb * 0.25; // North North West
    return s;
}

void ps_dsamp0(v2f input, out float4 c : SV_Target0)
{
    float3 s  = tex2D(s_Source, input.uv[0].xy).rgb * 0.25;
           s += tex2D(s_Source, input.uv[0].zw).rgb * 0.25;
           s += tex2D(s_Source, input.uv[1].xy).rgb * 0.25;
           s += tex2D(s_Source, input.uv[1].zw).rgb * 0.25;

    float l = dot(s, 1.0 / 3.0);
    c.rgb   = saturate(lerp(l, s, BLOOM_SAT));
    c.rgb  *= pow(abs(l), BLOOM_CURVE) / l;
    c.a = 1.0;
}

void ps_dsamp1(v2f input, out float4 c : SV_Target0) { c = p_dsamp(s_Bloom1, input.uv); }
void ps_dsamp2(v2f input, out float4 c : SV_Target0) { c = p_dsamp(s_Bloom2, input.uv); }
void ps_dsamp3(v2f input, out float4 c : SV_Target0) { c = p_dsamp(s_Bloom3, input.uv); }
void ps_dsamp4(v2f input, out float4 c : SV_Target0) { c = p_dsamp(s_Bloom4, input.uv); }
void ps_dsamp5(v2f input, out float4 c : SV_Target0) { c = p_dsamp(s_Bloom5, input.uv); }
void ps_dsamp6(v2f input, out float4 c : SV_Target0) { c = p_dsamp(s_Bloom6, input.uv); }

void ps_usamp7(v2f input, out float3 c : SV_Target0) { c = p_usamp(s_Bloom7, input.uv); }
void ps_usamp6(v2f input, out float3 c : SV_Target0) { c = p_usamp(s_Bloom6, input.uv); }
void ps_usamp5(v2f input, out float3 c : SV_Target0) { c = p_usamp(s_Bloom5, input.uv); }
void ps_usamp4(v2f input, out float3 c : SV_Target0) { c = p_usamp(s_Bloom4, input.uv); }
void ps_usamp3(v2f input, out float3 c : SV_Target0) { c = p_usamp(s_Bloom3, input.uv); }
void ps_usamp2(v2f input, out float3 c : SV_Target0) { c = p_usamp(s_Bloom2, input.uv); }
void ps_usamp1(v2f input, out float3 c : SV_Target0)
{
    c = p_usamp(s_Bloom1, input.uv).rgb;

    // From https://github.com/TheRealMJP/BakingLab - ACES.hlsl
    // sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
    const float3x3 ACESInputMat = float3x3(
        0.59719, 0.35458, 0.04823,
        0.07600, 0.90834, 0.01566,
        0.02840, 0.13383, 0.83777
    );

    // ODT_SAT => XYZ => D60_2_D65 => sRGB
    const float3x3 ACESOutputMat = float3x3(
         1.60475, -0.53108, -0.07367,
        -0.10208,  1.10813, -0.00605,
        -0.00327, -0.07276,  1.07602
    );

    float3 a = c * (c + 0.0245786f) - 0.000090537f;
    float3 b = c * (0.983729f * c + 0.4329510f) + 0.238081f;
    float3 RRTAndODTFit = a / b;

    c = mul(ACESInputMat, c);
    c = mul(ACESOutputMat, RRTAndODTFit);
}

technique KBloom
{
    #define vsd(i)     VertexShader = vs_dsamp##i
    #define vsu(i)     VertexShader = vs_usamp##i
    #define psd(i, j)  PixelShader = ps_dsamp##i; RenderTarget = _Bloom##j
    #define psu(i, j)  PixelShader = ps_usamp##i; RenderTarget = _Bloom##j
    #define blendadd() BlendEnable = true; SrcBlend = ONE; DestBlend = ONE

    pass { vsd(0); psd(0, 1); }
    pass { vsd(1); psd(1, 2); }
    pass { vsd(2); psd(2, 3); }
    pass { vsd(3); psd(3, 4); }
    pass { vsd(4); psd(4, 5); }
    pass { vsd(5); psd(5, 6); }
    pass { vsd(6); psd(6, 7); }
    pass { vsu(7); psu(7, 6); blendadd(); }
    pass { vsu(6); psu(6, 5); blendadd(); }
    pass { vsu(5); psu(5, 4); blendadd(); }
    pass { vsu(4); psu(4, 3); blendadd(); }
    pass { vsu(3); psu(3, 2); blendadd(); }
    pass { vsu(2); psu(2, 1); blendadd(); }
    pass
    {
        vsu(1);
        PixelShader = ps_usamp1;
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
        BlendEnable = true;
        DestBlend = INVSRCCOLOR;
    }
}
