/*
    Custom version of Unity's bloom
    Differences:
    - Do gamma conversions in samplerstate and renderstate (should be free)
    - Calculate texture coordinates in vertex shader (~20% performance boost)
    - Replace original 9-tap upsampler with custom 4-tap version
    - Blend with renderstate instead of pixelshader (deducts a tap for each upsample)

    Copyright © 2020 Unity Technologies ApS

    Licensed under the Unity Companion License for Unity-dependent projects
    -- see https://unity3d.com/legal/licenses/Unity_Companion_License

    Unless expressly provided otherwise, the Software under this license is made available
    strictly on an “AS IS” BASIS WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.
    Please review the license for details on these and other terms and conditions.
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

/* - VERTEX SHADERS - */

struct v2fd
{
    float4 vpos : SV_Position;
    float4 uv[3] : TEXCOORD0;
};

struct v2fu
{
    float4 vpos : SV_Position;
    float4 uv[2] : TEXCOORD0;
};

v2fd v_dsamp(const uint id, sampler2D src)
{
    v2fd o;
    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    o.vpos = float4(coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    // Kawase dual-filter downsampling kernel from StreamFX
    // https://github.com/Xaymar/obs-StreamFX
    const float2 ts = 2.0 / tex2Dsize(src, 0.0);
    o.uv[0]    = coord.xyxy;
    o.uv[1].xy = coord - ts;
    o.uv[1].zw = coord + ts;
    o.uv[2].xy = coord + float2(ts.x, -ts.y);
    o.uv[2].zw = coord - float2(ts.x, -ts.y);
    return o;
}

v2fu v_usamp(const uint id, sampler2D src)
{
    v2fu o;
    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    o.vpos = float4(coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    // 9-tap pyramid filter using 4 texture fetches by CeeJayDK
    // https://github.com/CeeJayDK/SweetFX/blob/master/Shaders/LumaSharpen.fx
    const float2 ts = 1.0 / tex2Dsize(src, 0.0);
    o.uv[0].xy = coord + float2( ts.x * 0.5, -ts.y); // ( 1, -2)
    o.uv[0].zw = coord + float2(-ts.x, -ts.y * 0.5); // (-2, -1)
    o.uv[1].xy = coord + float2( ts.x,  ts.y * 0.5); // ( 2,  1)
    o.uv[1].zw = coord + float2(-ts.x * 0.5,  ts.y); // (-1,  2)
    return o;
}

v2fd vs_dsamp0(uint id : SV_VertexID) { return v_dsamp(id, s_source); }
v2fd vs_dsamp1(uint id : SV_VertexID) { return v_dsamp(id, s_bloom1); }
v2fd vs_dsamp2(uint id : SV_VertexID) { return v_dsamp(id, s_bloom2); }
v2fd vs_dsamp3(uint id : SV_VertexID) { return v_dsamp(id, s_bloom3); }
v2fd vs_dsamp4(uint id : SV_VertexID) { return v_dsamp(id, s_bloom4); }
v2fd vs_dsamp5(uint id : SV_VertexID) { return v_dsamp(id, s_bloom5); }
v2fd vs_dsamp6(uint id : SV_VertexID) { return v_dsamp(id, s_bloom6); }
v2fd vs_dsamp7(uint id : SV_VertexID) { return v_dsamp(id, s_bloom7); }

v2fu vs_usamp8(uint id : SV_VertexID) { return v_usamp(id, s_bloom8); }
v2fu vs_usamp7(uint id : SV_VertexID) { return v_usamp(id, s_bloom7); }
v2fu vs_usamp6(uint id : SV_VertexID) { return v_usamp(id, s_bloom6); }
v2fu vs_usamp5(uint id : SV_VertexID) { return v_usamp(id, s_bloom5); }
v2fu vs_usamp4(uint id : SV_VertexID) { return v_usamp(id, s_bloom4); }
v2fu vs_usamp3(uint id : SV_VertexID) { return v_usamp(id, s_bloom3); }
v2fu vs_usamp2(uint id : SV_VertexID) { return v_usamp(id, s_bloom2); }
v2fu vs_usamp1(uint id : SV_VertexID) { return v_usamp(id, s_bloom1); }

/* - PIXEL SHADERS - */

float4 p_dsamp(sampler2D src, const float4 uv[3])
{
    float4 s  = tex2D(src, uv[0].xy) * 4.0;
           s += tex2D(src, uv[1].xy);
           s += tex2D(src, uv[1].zw);
           s += tex2D(src, uv[2].xy);
           s += tex2D(src, uv[2].zw);
    return s / 8.0;
}

float4 p_usamp(sampler2D src, const float4 uv[2])
{
    float4 s  = tex2D(src, uv[0].xy) * 0.25;
           s += tex2D(src, uv[0].zw) * 0.25;
           s += tex2D(src, uv[1].xy) * 0.25;
    return s += tex2D(src, uv[1].zw) * 0.25;
}

// Quadratic color thresholding

float4 ps_dsamp0(v2fd input): SV_TARGET
{
    const float  knee = mad(kThreshold, kSmooth, 1e-5f);
    const float3 curve = float3(kThreshold - knee, knee * 2.0, 0.25 / knee);
    float4 s = p_dsamp(s_source, input.uv);

    // Pixel brightness
    s.a = max(s.r, max(s.g, s.b));

    // Under-threshold part
    float rq = clamp(s.a - curve.x, 0.0, curve.y);
    rq = curve.z * rq * rq;

    // Combine and apply the brightness response curve
    s.rgb *= max(rq, s.a - kThreshold) / max(s.a, 1e-4);
    s.a = dot(s.rgb, rcp(3.0));
    s.rgb = saturate(lerp(s.a, s.rgb, kSaturation));
    s.a = 1.0;
    return s;
}

float4 ps_dsamp1(v2fd input) : SV_Target { return p_dsamp(s_bloom1, input.uv); }
float4 ps_dsamp2(v2fd input) : SV_Target { return p_dsamp(s_bloom2, input.uv); }
float4 ps_dsamp3(v2fd input) : SV_Target { return p_dsamp(s_bloom3, input.uv); }
float4 ps_dsamp4(v2fd input) : SV_Target { return p_dsamp(s_bloom4, input.uv); }
float4 ps_dsamp5(v2fd input) : SV_Target { return p_dsamp(s_bloom5, input.uv); }
float4 ps_dsamp6(v2fd input) : SV_Target { return p_dsamp(s_bloom6, input.uv); }
float4 ps_dsamp7(v2fd input) : SV_Target { return p_dsamp(s_bloom7, input.uv); }

float4 ps_usamp8(v2fu input) : SV_Target { return p_usamp(s_bloom8, input.uv); }
float4 ps_usamp7(v2fu input) : SV_Target { return p_usamp(s_bloom7, input.uv); }
float4 ps_usamp6(v2fu input) : SV_Target { return p_usamp(s_bloom6, input.uv); }
float4 ps_usamp5(v2fu input) : SV_Target { return p_usamp(s_bloom5, input.uv); }
float4 ps_usamp4(v2fu input) : SV_Target { return p_usamp(s_bloom4, input.uv); }
float4 ps_usamp3(v2fu input) : SV_Target { return p_usamp(s_bloom3, input.uv); }
float4 ps_usamp2(v2fu input) : SV_Target { return p_usamp(s_bloom2, input.uv); }
float4 ps_usamp1(v2fu input) : SV_Target
{
    // Interleaved Gradient Noise from
    // http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
    const float4 n = float4(0.06711056, 0.00583715, 52.9829189, 0.5 / 255);
    float f = frac(n.z * frac(dot(input.vpos.xy, n.xy))) * n.w;

    // ACES Filmic Tone Mapping Curve from
    // https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
    float4 o = p_usamp(s_bloom1, input.uv);
    o = saturate(o * mad(2.51, o, 0.03) / mad(o, mad(2.43, o, 0.59), 0.14));
    return o + f;
}

/* - TECHNIQUE - */

technique kBloom
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
