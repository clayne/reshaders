
#include "cFunctions.fxh"

uniform float uThreshold <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Threshold";
> = 0.8;

uniform float uSmooth <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Smoothing";
> = 0.5;

uniform float uSaturation <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Saturation";
> = 1.5;

uniform float uIntensity <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Intensity";
> = 1.0;

texture2D r_color : COLOR;
texture2D r_bloom1 { Width = BUFFER_WIDTH / 2;   Height = BUFFER_HEIGHT / 2;   Format = RGBA16F; };
texture2D r_bloom2 { Width = BUFFER_WIDTH / 4;   Height = BUFFER_HEIGHT / 4;   Format = RGBA16F; };
texture2D r_bloom3 { Width = BUFFER_WIDTH / 8;   Height = BUFFER_HEIGHT / 8;   Format = RGBA16F; };
texture2D r_bloom4 { Width = BUFFER_WIDTH / 16;  Height = BUFFER_HEIGHT / 16;  Format = RGBA16F; };
texture2D r_bloom5 { Width = BUFFER_WIDTH / 32;  Height = BUFFER_HEIGHT / 32;  Format = RGBA16F; };
texture2D r_bloom6 { Width = BUFFER_WIDTH / 64;  Height = BUFFER_HEIGHT / 64;  Format = RGBA16F; };
texture2D r_bloom7 { Width = BUFFER_WIDTH / 128; Height = BUFFER_HEIGHT / 128; Format = RGBA16F; };
texture2D r_bloom8 { Width = BUFFER_WIDTH / 256; Height = BUFFER_HEIGHT / 256; Format = RGBA16F; };

sampler2D s_color
{
    Texture = r_color;
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

/*
    [ Vertex Shaders ]
    Dual Filtering Algorithm - [https://github.com/powervr-graphics/Native_SDK] [MIT]
*/

void v2f_offset(in float2 coord, in float uFact, out float4 offset)
{
    const float2 psize = ldexp(core::getpixelsize(), uFact);
    const float2 hoffset = psize + (psize / 2.0f);
    const float4 uoffset = float4(-hoffset.x, -hoffset.y, hoffset.x, hoffset.y);
    offset = coord.xyxy + uoffset; // --++
}

struct v2fd
{
    float4 vpos : SV_Position;
    float2 uv : TEXCOORD0;
    float4 uOffset : TEXCOORD1;
};

v2fd downsample2Dvs(uint id, float uFact)
{
    v2fd output;
    core::vsinit(id, output.uv, output.vpos);
    v2f_offset(output.uv, uFact, output.uOffset);
    return output;
}

struct v2fu
{
    float4 vpos : SV_Position;
    float4 uOffset : TEXCOORD0;
};

v2fu upsample2Dvs(uint id, float uFact)
{
    v2fu output;
    float2 coord;
    core::vsinit(id, coord, output.vpos);
    v2f_offset(coord, uFact, output.uOffset);
    return output;
}

v2fd vs_downsample0(uint id : SV_VertexID) { return downsample2Dvs(id, 1.0); }
v2fd vs_downsample1(uint id : SV_VertexID) { return downsample2Dvs(id, 2.0); }
v2fd vs_downsample2(uint id : SV_VertexID) { return downsample2Dvs(id, 3.0); }
v2fd vs_downsample3(uint id : SV_VertexID) { return downsample2Dvs(id, 4.0); }
v2fd vs_downsample4(uint id : SV_VertexID) { return downsample2Dvs(id, 5.0); }
v2fd vs_downsample5(uint id : SV_VertexID) { return downsample2Dvs(id, 6.0); }
v2fd vs_downsample6(uint id : SV_VertexID) { return downsample2Dvs(id, 7.0); }
v2fd vs_downsample7(uint id : SV_VertexID) { return downsample2Dvs(id, 8.0); }

v2fu vs_upsample8(uint id : SV_VertexID) { return upsample2Dvs(id, 7.0); }
v2fu vs_upsample7(uint id : SV_VertexID) { return upsample2Dvs(id, 6.0); }
v2fu vs_upsample6(uint id : SV_VertexID) { return upsample2Dvs(id, 5.0); }
v2fu vs_upsample5(uint id : SV_VertexID) { return upsample2Dvs(id, 4.0); }
v2fu vs_upsample4(uint id : SV_VertexID) { return upsample2Dvs(id, 3.0); }
v2fu vs_upsample3(uint id : SV_VertexID) { return upsample2Dvs(id, 2.0); }
v2fu vs_upsample2(uint id : SV_VertexID) { return upsample2Dvs(id, 1.0); }
v2fu vs_upsample1(uint id : SV_VertexID) { return upsample2Dvs(id, 0.0); }

/*
    [ Pixel Shaders ]
    Thresholding - [https://github.com/keijiro/KinoBloom] [MIT]
    Tonemap - [https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/]
    Noise - [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
*/

float4 downsample2Dps(sampler2D src, v2fd input)
{
    float4 output;
    output += tex2D(src, input.uv) * 0.5;
    output += tex2D(src, input.uOffset.xy) * 0.125; // --
    output += tex2D(src, input.uOffset.zw) * 0.125; // ++
    output += tex2D(src, input.uOffset.xw) * 0.125; // -+
    output += tex2D(src, input.uOffset.zy) * 0.125; // +-
    return output;
}

float4 upsample2Dps(sampler2D src, v2fu input)
{
    float4 output;
    output  = tex2D(src, input.uOffset.xy) * 0.25; // --
    output += tex2D(src, input.uOffset.zw) * 0.25; // ++
    output += tex2D(src, input.uOffset.xw) * 0.25; // -+
    output += tex2D(src, input.uOffset.zy) * 0.25; // +-
    return output;
}

float4 ps_downsample0(v2fd input): SV_TARGET
{
    const float  knee = mad(uThreshold, uSmooth, 1e-5f);
    const float3 curve = float3(uThreshold - knee, knee * 2.0, 0.25 / knee);
    float4 s = downsample2Dps(s_color, input);

    // Under-threshold
    s.a = max(s.r, max(s.g, s.b));
    float rq = clamp(s.a - curve.x, 0.0, curve.y);
    rq = curve.z * rq * rq;

    // Combine and apply the brightness response curve
    s *= max(rq, s.a - uThreshold) / max(s.a, 1e-4);
    s = saturate(lerp(s.a, s, uSaturation) * uIntensity);
    return s;
}

float4 ps_downsample1(v2fd input) : SV_Target { return downsample2Dps(s_bloom1, input); }
float4 ps_downsample2(v2fd input) : SV_Target { return downsample2Dps(s_bloom2, input); }
float4 ps_downsample3(v2fd input) : SV_Target { return downsample2Dps(s_bloom3, input); }
float4 ps_downsample4(v2fd input) : SV_Target { return downsample2Dps(s_bloom4, input); }
float4 ps_downsample5(v2fd input) : SV_Target { return downsample2Dps(s_bloom5, input); }
float4 ps_downsample6(v2fd input) : SV_Target { return downsample2Dps(s_bloom6, input); }
float4 ps_downsample7(v2fd input) : SV_Target { return downsample2Dps(s_bloom7, input); }

float4 ps_upsample8(v2fu input) : SV_Target { return upsample2Dps(s_bloom8, input); }
float4 ps_upsample7(v2fu input) : SV_Target { return upsample2Dps(s_bloom7, input); }
float4 ps_upsample6(v2fu input) : SV_Target { return upsample2Dps(s_bloom6, input); }
float4 ps_upsample5(v2fu input) : SV_Target { return upsample2Dps(s_bloom5, input); }
float4 ps_upsample4(v2fu input) : SV_Target { return upsample2Dps(s_bloom4, input); }
float4 ps_upsample3(v2fu input) : SV_Target { return upsample2Dps(s_bloom3, input); }
float4 ps_upsample2(v2fu input) : SV_Target { return upsample2Dps(s_bloom2, input); }
float4 ps_upsample1(v2fu input) : SV_Target
{
    float4 o = upsample2Dps(s_bloom1, input);
    o = saturate(o * mad(2.51, o, 0.03) / mad(o, mad(2.43, o, 0.59), 0.14));
    const float bit = 1.0 / 255;
    return o + core::noise(input.vpos.xy) * bit;
}

/* [ TECHNIQUE ] */

technique cBloom
{
    #define vsd(i) VertexShader = vs_downsample##i
    #define vsu(i) VertexShader = vs_upsample##i
    #define psd(i) PixelShader  = ps_downsample##i
    #define psu(i) PixelShader  = ps_upsample##i
    #define rt(i)  RenderTarget = r_bloom##i
    #define blend(i, j, k) BlendEnable = TRUE; BlendOp = i; SrcBlend = j; DestBlend = k

    pass { vsd(0); psd(0); rt(1); }
    pass { vsd(1); psd(1); rt(2); }
    pass { vsd(2); psd(2); rt(3); }
    pass { vsd(3); psd(3); rt(4); }
    pass { vsd(4); psd(4); rt(5); }
    pass { vsd(5); psd(5); rt(6); }
    pass { vsd(6); psd(6); rt(7); }
    pass { vsd(7); psd(7); rt(8); }
    pass { vsu(8); psu(8); rt(7); blend(ADD, ONE, ONE); }
    pass { vsu(7); psu(7); rt(6); blend(ADD, ONE, ONE); }
    pass { vsu(6); psu(6); rt(5); blend(ADD, ONE, ONE); }
    pass { vsu(5); psu(5); rt(4); blend(ADD, ONE, ONE); }
    pass { vsu(4); psu(4); rt(3); blend(ADD, ONE, ONE); }
    pass { vsu(3); psu(3); rt(2); blend(ADD, ONE, ONE); }
    pass { vsu(2); psu(2); rt(1); blend(ADD, ONE, ONE); }
    pass { vsu(1); psu(1); blend(ADD, ONE, INVSRCCOLOR);
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = TRUE;
        #endif
    }
}
