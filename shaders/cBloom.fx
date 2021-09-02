
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
        SRGBTexture = TRUE;
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
    [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare] [MIT]
*/

void v2f_core(in uint id,
              inout float2 uv,
              inout float4 vpos)
{
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

struct v2fd
{
    float4 vpos : SV_Position;
    float4 uOffset0 : TEXCOORD0; // Inner quad
    float4 uOffset1 : TEXCOORD1; // Outer quad
    float4 uOffset2 : TEXCOORD2; // Horiz quad
    float4 uOffset3 : TEXCOORD3; // Verti quad
};

v2fd downsample2Dvs(uint id, float uFact)
{
    v2fd output;
    float2 coord;
    v2f_core(id, coord, output.vpos);
    const float2 psize = rcp(float2(BUFFER_WIDTH, BUFFER_HEIGHT) / exp2(uFact));
    output.uOffset0 = coord.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * psize.xyxy;
    output.uOffset1 = coord.xyxy + float4(-2.0, -2.0, 2.0, 2.0) * psize.xyxy;
    output.uOffset2 = coord.xxxy + float4(-2.0,  0.0, 2.0, 0.0) * psize.xxxy;
    output.uOffset3 = coord.yyyx + float4(-2.0,  0.0, 2.0, 0.0) * psize.yyyx;
    return output;
}

struct v2fu
{
    float4 vpos : SV_Position;
    float4 uOffset0 : TEXCOORD0; // Center taps
    float4 uOffset1 : TEXCOORD1; // Verizontal Taps
    float4 uOffset2 : TEXCOORD2; // Hortical Taps
};

v2fu upsample2Dvs(uint id, float uFact)
{
    v2fu output;
    float2 coord;
    v2f_core(id, coord, output.vpos);
    const float2 psize = rcp(float2(BUFFER_WIDTH, BUFFER_HEIGHT) / exp2(uFact));
    output.uOffset0 = coord.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * psize.xyxy;
    output.uOffset1 = coord.xxxy + float4(-1.0,  0.0, 1.0, 0.0) * psize.xxxy;
    output.uOffset2 = coord.yyyx + float4(-1.0,  0.0, 1.0, 0.0) * psize.yyyx;
    return output;
}

v2fd vs_downsample0(uint id : SV_VertexID) { return downsample2Dvs(id, 0.0); }
v2fd vs_downsample1(uint id : SV_VertexID) { return downsample2Dvs(id, 1.0); }
v2fd vs_downsample2(uint id : SV_VertexID) { return downsample2Dvs(id, 2.0); }
v2fd vs_downsample3(uint id : SV_VertexID) { return downsample2Dvs(id, 3.0); }
v2fd vs_downsample4(uint id : SV_VertexID) { return downsample2Dvs(id, 4.0); }
v2fd vs_downsample5(uint id : SV_VertexID) { return downsample2Dvs(id, 5.0); }
v2fd vs_downsample6(uint id : SV_VertexID) { return downsample2Dvs(id, 6.0); }
v2fd vs_downsample7(uint id : SV_VertexID) { return downsample2Dvs(id, 7.0); }

v2fu vs_upsample8(uint id : SV_VertexID) { return upsample2Dvs(id, 8.0); }
v2fu vs_upsample7(uint id : SV_VertexID) { return upsample2Dvs(id, 7.0); }
v2fu vs_upsample6(uint id : SV_VertexID) { return upsample2Dvs(id, 6.0); }
v2fu vs_upsample5(uint id : SV_VertexID) { return upsample2Dvs(id, 5.0); }
v2fu vs_upsample4(uint id : SV_VertexID) { return upsample2Dvs(id, 4.0); }
v2fu vs_upsample3(uint id : SV_VertexID) { return upsample2Dvs(id, 3.0); }
v2fu vs_upsample2(uint id : SV_VertexID) { return upsample2Dvs(id, 2.0); }
v2fu vs_upsample1(uint id : SV_VertexID) { return upsample2Dvs(id, 1.0); }

/*
    [ Pixel Shaders ]
    Thresholding - [https://github.com/keijiro/KinoBloom] [MIT]
    Tonemap      - [https://github.com/TheRealMJP/BakingLab] [MIT]
    Noise        - [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
*/

float4 downsample2Dps(sampler2D src, v2fd input)
{
    float4 a0 = tex2D(src, input.uOffset0.xy); // (-1.0, -1.0)
    float4 a1 = tex2D(src, input.uOffset0.zw); // ( 1.0,  1.0)
    float4 a2 = tex2D(src, input.uOffset0.xw); // (-1.0,  1.0)
    float4 a3 = tex2D(src, input.uOffset0.zy); // ( 1.0, -1.0)

    float4 b0 = tex2D(src, input.uOffset1.xy); // (-2.0, -2.0)
    float4 b1 = tex2D(src, input.uOffset1.zw); // ( 2.0,  2.0)
    float4 b2 = tex2D(src, input.uOffset1.xw); // (-2.0,  2.0)
    float4 b3 = tex2D(src, input.uOffset1.zy); // ( 2.0, -2.0)

    float4 c0 = tex2D(src, input.uOffset2.xw); // (-2.0, 0.0)
    float4 c1 = tex2D(src, input.uOffset2.yw); // ( 0.0, 0.0)
    float4 c2 = tex2D(src, input.uOffset2.zw); // ( 2.0, 0.0)

    float4 d0 = tex2D(src, input.uOffset3.wx); // (0.0, -2.0)
    float4 d1 = tex2D(src, input.uOffset3.wz); // (0.0,  2.0)

    float4 output;
    const float2 weight = float2(0.5, 0.125) / 4.0;
    output  = (a0 + a1 + a2 + a3) * weight.x; // Center quad
    output += (b2 + d1 + c0 + c1) * weight.y; // Top - left quad
    output += (d1 + b1 + c1 + c2) * weight.y; // Top - right quad
    output += (c1 + c2 + d0 + b0) * weight.y; // Bottom - right quad
    output += (c0 + c1 + b0 + d0) * weight.y; // Bottom - left quad
    return output;
}

float4 upsample2Dps(sampler2D src, v2fu input)
{
    float4 a0 = tex2D(src, input.uOffset0.xy);
    float4 a1 = tex2D(src, input.uOffset0.zw);
    float4 a2 = tex2D(src, input.uOffset0.xw);
    float4 a3 = tex2D(src, input.uOffset0.zy);
    float4 c0 = tex2D(src, input.uOffset1.yw);
    float4 b0 = tex2D(src, input.uOffset1.xw);
    float4 b1 = tex2D(src, input.uOffset1.zw);
    float4 b2 = tex2D(src, input.uOffset2.wx);
    float4 b3 = tex2D(src, input.uOffset2.wz);

    float4 output;
    const float3 weights = float3(1.0, 2.0, 4.0) / 16.0;
    output  = (a0 + a1 + a2 + a3) * weights.x;
    output += (b0 + b1 + b2 + b3) * weights.y;
    output += c0 * weights.z;
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
    s = saturate(lerp(s.a, s, uSaturation));
    return s;
}

// sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
static const float3x3 ACESInputMat = float3x3(
    0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
static const float3x3 ACESOutputMat = float3x3(
     1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602
);

float3 RRTAndODTFit(float3 v)
{
    float3 a = v * (v + 0.0245786f) - 0.000090537f;
    float3 b = v * (0.983729f * v + 0.4329510f) + 0.238081f;
    return a / b;
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
    float4 o = upsample2Dps(s_bloom1, input);
    o *= uIntensity;
    o = mul(ACESInputMat, o.rgb);
    o = RRTAndODTFit(o.rgb);
    o = mul(ACESOutputMat, o.rgb);
    return saturate(o + f);
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
