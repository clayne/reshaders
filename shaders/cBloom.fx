
uniform float uThreshold <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Threshold";
> = 0.8;

uniform float uSmoothing <
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

    Dual Filtering Algorithm
    [https://github.com/powervr-graphics/Native_SDK] [MIT]
*/

struct v2fd
{
    float4 vpos   : SV_Position;
    float2 uv0    : TEXCOORD0;
    float4 uv1[2] : TEXCOORD1;
};

struct v2fu
{
    float4 vpos   : SV_Position;
    float4 uv0[4] : TEXCOORD0;
};

static const float2 uSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);

v2fd downsample2Dvs(const uint id, float uFact)
{
    v2fd output;
    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    output.vpos = float4(coord.xy * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    const float2 psize = uSize * exp2(uFact);
    const float2 hsize = psize / 2.0f;
    const float2 offst = psize + hsize;
    const float4 oset[2] = { float4(-offst.x, -offst.y,  offst.x, offst.y),
                             float4( offst.x, -offst.y, -offst.x, offst.y) };
    output.uv0 = coord;
    output.uv1[0].xy = coord + oset[0].xy;
    output.uv1[0].zw = coord + oset[0].zw;
    output.uv1[1].xy = coord + oset[1].xy;
    output.uv1[1].zw = coord + oset[1].zw;
    return output;
}

v2fu upsample2Dvs(const uint id, float uFact)
{
    v2fu output;
    float2 coord;
    coord.x = (id == 2) ? 2.0 : 0.0;
    coord.y = (id == 1) ? 2.0 : 0.0;
    output.vpos = float4(coord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    const float2 psize = ldexp(uSize, uFact);
    const float2 hsize = psize / 2.0f;
    const float2 offst = psize + hsize;
    const float4 oset[4] = { float4(-offst.x * 2.0, 0.0, -offst.x,  offst.y),
                             float4(0.0,  offst.y * 2.0,  offst.x,  offst.y),
                             float4( offst.x * 2.0, 0.0,  offst.x, -offst.y),
                             float4(0.0, -offst.y * 2.0, -offst.x, -offst.y) };
    output.uv0[0].xy = coord + oset[0].xy;
    output.uv0[0].zw = coord + oset[0].zw;
    output.uv0[1].xy = coord + oset[1].xy;
    output.uv0[1].zw = coord + oset[1].zw;
    output.uv0[2].xy = coord + oset[2].xy;
    output.uv0[2].zw = coord + oset[2].zw;
    output.uv0[3].xy = coord + oset[3].xy;
    output.uv0[3].zw = coord + oset[3].zw;
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

    1st pass quadratic color thresholding
    [https://github.com/keijiro/KinoBloom] [MIT]

    ACES Filmic Tone Mapping Curve
    [https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/]

    Interleaved Gradient Noise
    [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
*/

float4 downsample2Dps(sampler2D src, v2fd input)
{
    float4 output;
    output += tex2D(src, input.uv0) * 4.0;
    output += tex2D(src, input.uv1[0].xy);
    output += tex2D(src, input.uv1[0].zw);
    output += tex2D(src, input.uv1[1].xy);
    output += tex2D(src, input.uv1[1].zw);
    return output * (1.0 / 8.0);
}

float4 upsample2Dps(sampler2D src, v2fu input)
{
    float4 output;
    output += tex2D(src, input.uv0[0].xy);
    output += tex2D(src, input.uv0[0].zw) * 2.0;
    output += tex2D(src, input.uv0[1].xy);
    output += tex2D(src, input.uv0[1].zw) * 2.0;
    output += tex2D(src, input.uv0[2].xy);
    output += tex2D(src, input.uv0[2].zw) * 2.0;
    output += tex2D(src, input.uv0[3].xy);
    output += tex2D(src, input.uv0[3].zw) * 2.0;
    return output * (1.0 / 12.0);
}

float4 ps_downsample0(v2fd input): SV_TARGET
{
    const float  knee = mad(uThreshold, uSmoothing, 1e-5f);
    const float3 curve = float3(uThreshold - knee, knee * 2.0, 0.25 / knee);
    float4 s = downsample2Dps(s_color, input);

    // Under-threshold
    s.a = max(s.r, max(s.g, s.b));
    s = saturate(lerp(s.a, s, uSaturation));
    float rq = clamp(s.a - curve.x, 0.0, curve.y);
    rq = curve.z * rq * rq;

    // Combine and apply the brightness response curve
    s *= max(rq, s.a - uThreshold) / max(s.a, 1e-4);
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
    const float4 n = float4(0.06711056, 0.00583715, 52.9829189, 0.5 / 255);
    float f = frac(n.z * frac(dot(input.vpos.xy, n.xy))) * n.w;
    float4 o = upsample2Dps(s_bloom1, input) * uIntensity;
    o = saturate(o * mad(2.51, o, 0.03) / mad(o, mad(2.43, o, 0.59), 0.14));
    return o + f;
}

/* [ TECHNIQUE ] */

technique cBloom
{
    #define vsd(i) VertexShader = vs_downsample##i
    #define vsu(i) VertexShader = vs_upsample##i
    #define psd(i) PixelShader  = ps_downsample##i
    #define psu(i) PixelShader  = ps_upsample##i
    #define rt(i)  RenderTarget = r_bloom##i
    #define blend(i) BlendEnable = TRUE; DestBlend = ##i

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
