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

uniform float kThreshold <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Threshold";
> = 0.8;

uniform float kSmooth <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Smoothing";
> = 0.5;

uniform float kSaturation <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Saturation";
> = 2.0;

texture2D r_source : COLOR;
texture2D r_bloom1 { Width = BUFFER_WIDTH / 2;   Height = BUFFER_HEIGHT / 2;   Format = RGBA16F; };
texture2D r_bloom2 { Width = BUFFER_WIDTH / 4;   Height = BUFFER_HEIGHT / 4;   Format = RGBA16F; };
texture2D r_bloom3 { Width = BUFFER_WIDTH / 8;   Height = BUFFER_HEIGHT / 8;   Format = RGBA16F; };
texture2D r_bloom4 { Width = BUFFER_WIDTH / 16;  Height = BUFFER_HEIGHT / 16;  Format = RGBA16F; };
texture2D r_bloom5 { Width = BUFFER_WIDTH / 32;  Height = BUFFER_HEIGHT / 32;  Format = RGBA16F; };
texture2D r_bloom6 { Width = BUFFER_WIDTH / 64;  Height = BUFFER_HEIGHT / 64;  Format = RGBA16F; };
texture2D r_bloom7 { Width = BUFFER_WIDTH / 128; Height = BUFFER_HEIGHT / 128; Format = RGBA16F; };
texture2D r_bloom8 { Width = BUFFER_WIDTH / 256; Height = BUFFER_HEIGHT / 256; Format = RGBA16F; };

sampler2D s_source
{
    Texture = r_source;
    #if BUFFER_COLOR_BIT_DEPTH != 10
        SRGBTexture = true;
    #endif
};

sampler2D s_bloom1 { Texture = r_bloom1; };
sampler2D s_bloom2 { Texture = r_bloom2; };
sampler2D s_bloom3 { Texture = r_bloom3; };
sampler2D s_bloom4 { Texture = r_bloom4; };
sampler2D s_bloom5 { Texture = r_bloom5; };
sampler2D s_bloom6 { Texture = r_bloom6; };
sampler2D s_bloom7 { Texture = r_bloom7; };
sampler2D s_bloom8 { Texture = r_bloom8; };

struct v2f { float4 vpos : SV_Position; float4 uv[2] : TEXCOORD0; };

v2f v_samp(const uint id, sampler2D src, const float ufac)
{
    v2f o;
    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    o.vpos = float4(coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    // 9 tap gaussian using 4 texture fetches by CeeJayDK
    // https://github.com/CeeJayDK/SweetFX - LumaSharpen.fx
    const float2 ts = ufac / tex2Dsize(src, 0.0);
    o.uv[0].xy = coord + float2( ts.x * 0.5, -ts.y); // South South East
    o.uv[0].zw = coord + float2(-ts.x ,-ts.y * 0.5); // West  South West
    o.uv[1].xy = coord + float2( ts.x,  ts.y * 0.5); // East  North East
    o.uv[1].zw = coord + float2(-ts.x * 0.5,  ts.y); // North North West
    return o;
}

v2f vs_dsamp0(uint id : SV_VertexID) { return v_samp(id, s_source, 2.0); }
v2f vs_dsamp1(uint id : SV_VertexID) { return v_samp(id, s_bloom1, 2.0); }
v2f vs_dsamp2(uint id : SV_VertexID) { return v_samp(id, s_bloom2, 2.0); }
v2f vs_dsamp3(uint id : SV_VertexID) { return v_samp(id, s_bloom3, 2.0); }
v2f vs_dsamp4(uint id : SV_VertexID) { return v_samp(id, s_bloom4, 2.0); }
v2f vs_dsamp5(uint id : SV_VertexID) { return v_samp(id, s_bloom5, 2.0); }
v2f vs_dsamp6(uint id : SV_VertexID) { return v_samp(id, s_bloom6, 2.0); }
v2f vs_dsamp7(uint id : SV_VertexID) { return v_samp(id, s_bloom7, 2.0); }

v2f vs_usamp8(uint id : SV_VertexID) { return v_samp(id, s_bloom8, 1.0); }
v2f vs_usamp7(uint id : SV_VertexID) { return v_samp(id, s_bloom7, 1.0); }
v2f vs_usamp6(uint id : SV_VertexID) { return v_samp(id, s_bloom6, 1.0); }
v2f vs_usamp5(uint id : SV_VertexID) { return v_samp(id, s_bloom5, 1.0); }
v2f vs_usamp4(uint id : SV_VertexID) { return v_samp(id, s_bloom4, 1.0); }
v2f vs_usamp3(uint id : SV_VertexID) { return v_samp(id, s_bloom3, 1.0); }
v2f vs_usamp2(uint id : SV_VertexID) { return v_samp(id, s_bloom2, 1.0); }
v2f vs_usamp1(uint id : SV_VertexID) { return v_samp(id, s_bloom1, 1.0); }

float4 p_dsamp(sampler src, const float4 uv[2])
{
    float4x4 s = float4x4(tex2D(src, uv[0].xy),
                          tex2D(src, uv[0].zw),
                          tex2D(src, uv[1].xy),
                          tex2D(src, uv[1].zw));

    // Karis' luma weighted average
    const float4 w = float2(rcp(3.0), 1.0).xxxy;
    float4 luma = mul(s, w);
           luma = rcp(luma);
    return mul(luma, s) / dot(luma, 1.0);
}

float4 p_usamp(sampler2D src, const float4 uv[2])
{
    float4 s  = tex2D(src, uv[0].xy) * 0.25;
           s += tex2D(src, uv[0].zw) * 0.25;
           s += tex2D(src, uv[1].xy) * 0.25;
    return s +  tex2D(src, uv[1].zw) * 0.25;
}

// Quadratic color thresholding from
// https://github.com/Unity-Technologies/Graphics

void ps_dsamp0(v2f input, out float4 o : SV_Target0)
{
    float4 s  = tex2D(s_source, input.uv[0].xy) * 0.25;
           s += tex2D(s_source, input.uv[0].zw) * 0.25;
           s += tex2D(s_source, input.uv[1].xy) * 0.25;
           s += tex2D(s_source, input.uv[1].zw) * 0.25;

    const float2 n = float2(1.0, 0.0);
    const float  knee = kThreshold * kSmooth + 1e-5f;
    const float3 curve = float3(kThreshold - knee, knee * 2.0, 0.25 / knee);

    // Pixel brightness
    s.a = max(s.r, max(s.g, s.b));

    // Under-threshold part
    float rq = clamp(s.a - curve.x, 0.0, curve.y);
    rq = curve.z * rq * rq;

    // Combine and apply the brightness response curve
    o = s.rgb * max(rq, s.a - kThreshold) / s.a;
    o.a = dot(o.rgb, rcp(3.0));
    o = saturate(lerp(o.a, o.rgb, kSaturation));
    o = mad(o.xyzw, n.xxxy, n.yyyx);
}

void ps_dsamp1(v2f input, out float4 o : SV_Target0) { o = p_dsamp(s_bloom1, input.uv); }
void ps_dsamp2(v2f input, out float4 o : SV_Target0) { o = p_dsamp(s_bloom2, input.uv); }
void ps_dsamp3(v2f input, out float4 o : SV_Target0) { o = p_dsamp(s_bloom3, input.uv); }
void ps_dsamp4(v2f input, out float4 o : SV_Target0) { o = p_dsamp(s_bloom4, input.uv); }
void ps_dsamp5(v2f input, out float4 o : SV_Target0) { o = p_dsamp(s_bloom5, input.uv); }
void ps_dsamp6(v2f input, out float4 o : SV_Target0) { o = p_dsamp(s_bloom6, input.uv); }
void ps_dsamp7(v2f input, out float4 o : SV_Target0) { o = p_dsamp(s_bloom7, input.uv); }

void ps_usamp8(v2f input, out float4 o : SV_Target0) { o = p_usamp(s_bloom8, input.uv); }
void ps_usamp7(v2f input, out float4 o : SV_Target0) { o = p_usamp(s_bloom7, input.uv); }
void ps_usamp6(v2f input, out float4 o : SV_Target0) { o = p_usamp(s_bloom6, input.uv); }
void ps_usamp5(v2f input, out float4 o : SV_Target0) { o = p_usamp(s_bloom5, input.uv); }
void ps_usamp4(v2f input, out float4 o : SV_Target0) { o = p_usamp(s_bloom4, input.uv); }
void ps_usamp3(v2f input, out float4 o : SV_Target0) { o = p_usamp(s_bloom3, input.uv); }
void ps_usamp2(v2f input, out float4 o : SV_Target0) { o = p_usamp(s_bloom2, input.uv); }
void ps_usamp1(v2f input, out float4 o : SV_Target0)
{
    // ACES Filmic Tone Mapping Curve from
    // https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
    o = p_usamp(s_bloom1, input.uv).rgb;
    o = saturate(o * mad(2.51, o, 0.03) / mad(o, mad(2.43, o, 0.59), 0.14));
}

technique KinoBloom
{
    #define vsd(i)   VertexShader = vs_dsamp##i
    #define vsu(i)   VertexShader = vs_usamp##i
    #define psd(i)   PixelShader  = ps_dsamp##i
    #define psu(i)   PixelShader  = ps_usamp##i
    #define rt(i)    RenderTarget = r_bloom##i
    #define blend(i) BlendEnable  = true; DestBlend = ##i

    pass { vsd(0); psd(0); rt(1); }
    pass { vsd(1); psd(1); rt(2); }
    pass { vsd(2); psd(2); rt(3); }
    pass { vsd(3); psd(3); rt(4); }
    pass { vsd(4); psd(4); rt(5); }
    pass { vsd(5); psd(5); rt(6); }
    pass { vsd(6); psd(6); rt(7); }
    pass { vsd(7); psd(7); rt(8); }
    pass { vsu(8); psu(8); rt(7); blend(ONE); }
    pass { vsu(7); psu(7); rt(6); blend(ONE); }
    pass { vsu(6); psu(6); rt(5); blend(ONE); }
    pass { vsu(5); psu(5); rt(4); blend(ONE); }
    pass { vsu(4); psu(4); rt(3); blend(ONE); }
    pass { vsu(3); psu(3); rt(2); blend(ONE); }
    pass { vsu(2); psu(2); rt(1); blend(ONE); }
    pass { vsu(1); psu(1); blend(INVSRCCOLOR);
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
