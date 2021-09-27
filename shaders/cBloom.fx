
uniform float _Threshold <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Threshold";
> = 0.8;

uniform float _Smooth <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Smoothing";
    ui_max = 1.0;
> = 0.5;

uniform float _Saturation <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Saturation";
> = 1.0;

uniform float _Intensity <
    ui_type = "drag";
    ui_min = 0.0;
    ui_label = "Intensity";
> = 1.0;

texture2D _RenderColor : COLOR;
texture2D _RenderBloom1 { Width = BUFFER_WIDTH / 2;   Height = BUFFER_HEIGHT / 2;   Format = RGBA16F; };
texture2D _RenderBloom2 { Width = BUFFER_WIDTH / 4;   Height = BUFFER_HEIGHT / 4;   Format = RGBA16F; };
texture2D _RenderBloom3 { Width = BUFFER_WIDTH / 8;   Height = BUFFER_HEIGHT / 8;   Format = RGBA16F; };
texture2D _RenderBloom4 { Width = BUFFER_WIDTH / 16;  Height = BUFFER_HEIGHT / 16;  Format = RGBA16F; };
texture2D _RenderBloom5 { Width = BUFFER_WIDTH / 32;  Height = BUFFER_HEIGHT / 32;  Format = RGBA16F; };
texture2D _RenderBloom6 { Width = BUFFER_WIDTH / 64;  Height = BUFFER_HEIGHT / 64;  Format = RGBA16F; };
texture2D _RenderBloom7 { Width = BUFFER_WIDTH / 128; Height = BUFFER_HEIGHT / 128; Format = RGBA16F; };
texture2D _RenderBloom8 { Width = BUFFER_WIDTH / 256; Height = BUFFER_HEIGHT / 256; Format = RGBA16F; };

sampler2D _SampleColor { Texture = _RenderColor; SRGBTexture = TRUE; };
sampler2D _SampleBloom1 { Texture = _RenderBloom1; };
sampler2D _SampleBloom2 { Texture = _RenderBloom2; };
sampler2D _SampleBloom3 { Texture = _RenderBloom3; };
sampler2D _SampleBloom4 { Texture = _RenderBloom4; };
sampler2D _SampleBloom5 { Texture = _RenderBloom5; };
sampler2D _SampleBloom6 { Texture = _RenderBloom6; };
sampler2D _SampleBloom7 { Texture = _RenderBloom7; };
sampler2D _SampleBloom8 { Texture = _RenderBloom8; };

/*
    [ Vertex Shaders ]
    Dual Filtering Algorithm
    [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare] [MIT]
*/

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

struct v2fd
{
    float4 vpos : SV_Position;
    float4 uOffset0 : TEXCOORD0; // Inner quad
    float4 uOffset1 : TEXCOORD1; // Outer quad
    float4 uOffset2 : TEXCOORD2; // Horizontal
    float4 uOffset3 : TEXCOORD3; // Vertical
};

v2fd DownsampleVS(uint id, float uFact)
{
    v2fd output;
    float2 coord;
    PostProcessVS(id, output.vpos, coord);
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

v2fu UpsampleVS(uint id, float uFact) {
    v2fu output;
    float2 coord;
    PostProcessVS(id, output.vpos, coord);
    const float2 psize = rcp(float2(BUFFER_WIDTH, BUFFER_HEIGHT) / exp2(uFact));
    output.uOffset0 = coord.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * psize.xyxy;
    output.uOffset1 = coord.xxxy + float4(-1.0,  0.0, 1.0, 0.0) * psize.xxxy;
    output.uOffset2 = coord.yyyx + float4(-1.0,  0.0, 1.0, 0.0) * psize.yyyx;
    return output;
}

v2fd DownsampleVS1(uint id : SV_VertexID) { return DownsampleVS(id, 1.0); }
v2fd DownsampleVS2(uint id : SV_VertexID) { return DownsampleVS(id, 2.0); }
v2fd DownsampleVS3(uint id : SV_VertexID) { return DownsampleVS(id, 3.0); }
v2fd DownsampleVS4(uint id : SV_VertexID) { return DownsampleVS(id, 4.0); }
v2fd DownsampleVS5(uint id : SV_VertexID) { return DownsampleVS(id, 5.0); }
v2fd DownsampleVS6(uint id : SV_VertexID) { return DownsampleVS(id, 6.0); }
v2fd DownsampleVS7(uint id : SV_VertexID) { return DownsampleVS(id, 7.0); }

v2fu UpsampleVS8(uint id : SV_VertexID) { return UpsampleVS(id, 8.0); }
v2fu UpsampleVS7(uint id : SV_VertexID) { return UpsampleVS(id, 7.0); }
v2fu UpsampleVS6(uint id : SV_VertexID) { return UpsampleVS(id, 6.0); }
v2fu UpsampleVS5(uint id : SV_VertexID) { return UpsampleVS(id, 5.0); }
v2fu UpsampleVS4(uint id : SV_VertexID) { return UpsampleVS(id, 4.0); }
v2fu UpsampleVS3(uint id : SV_VertexID) { return UpsampleVS(id, 3.0); }
v2fu UpsampleVS2(uint id : SV_VertexID) { return UpsampleVS(id, 2.0); }

/*
    [ Pixel Shaders ]
    Thresholding - [https://github.com/keijiro/Kino] [MIT]
    Tonemap      - [https://github.com/TheRealMJP/BakingLab] [MIT]
    Noise        - [http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare]
*/

float4 DownsamplePS(sampler2D src, v2fd input)
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
    output += (c1 + c2 + d0 + b3) * weight.y; // Bottom - right quad
    output += (c0 + c1 + b0 + d0) * weight.y; // Bottom - left quad
    return output;
}

float4 UpsamplePS(sampler2D src, v2fu input)
{
    float4 a0 = tex2D(src, input.uOffset0.xy); // (-1.0, -1.0)
    float4 a1 = tex2D(src, input.uOffset0.zw); // ( 1.0,  1.0)
    float4 a2 = tex2D(src, input.uOffset0.xw); // (-1.0,  1.0)
    float4 a3 = tex2D(src, input.uOffset0.zy); // ( 1.0, -1.0)
    float4 c0 = tex2D(src, input.uOffset1.yw); // ( 0.0,  0.0)
    float4 b0 = tex2D(src, input.uOffset1.xw); // (-1.0,  0.0)
    float4 b1 = tex2D(src, input.uOffset1.zw); // ( 1.0,  0.0)
    float4 b2 = tex2D(src, input.uOffset2.wx); // ( 0.0,  1.0)
    float4 b3 = tex2D(src, input.uOffset2.wz); // ( 0.0,  1.0)

    float4 output;
    const float3 weights = float3(1.0, 2.0, 4.0);
    output  = (a0 + a1 + a2 + a3) * weights.x;
    output += (b0 + b1 + b2 + b3) * weights.y;
    output += c0 * weights.z;
    return output / 16.0;
}

void PrefilterPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    const float Knee = mad(_Threshold, _Smooth, 1e-5f);
    const float3 Curve = float3(_Threshold - Knee, Knee * 2.0, 0.25 / Knee);
    float4 Color = tex2D(_SampleColor, TexCoord);

    // Under-threshold
    float Brightness = max(Color.r, max(Color.g, Color.b));
    float Response = clamp(Brightness - Curve.x, 0.0, Curve.y);
    Response = Curve.z * Response * Response;

    // Combine and apply the brightness response curve
    Color *= max(Response, Brightness - _Threshold) / max(Brightness, 1e-10);
    OutputColor0 = saturate(lerp(Brightness, Color.rgb, _Saturation));
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

float4 DownsamplePS1(v2fd input) : SV_Target { return DownsamplePS(_SampleBloom1, input); }
float4 DownsamplePS2(v2fd input) : SV_Target { return DownsamplePS(_SampleBloom2, input); }
float4 DownsamplePS3(v2fd input) : SV_Target { return DownsamplePS(_SampleBloom3, input); }
float4 DownsamplePS4(v2fd input) : SV_Target { return DownsamplePS(_SampleBloom4, input); }
float4 DownsamplePS5(v2fd input) : SV_Target { return DownsamplePS(_SampleBloom5, input); }
float4 DownsamplePS6(v2fd input) : SV_Target { return DownsamplePS(_SampleBloom6, input); }
float4 DownsamplePS7(v2fd input) : SV_Target { return DownsamplePS(_SampleBloom7, input); }

float4 UpsamplePS8(v2fu input) : SV_Target { return UpsamplePS(_SampleBloom8, input); }
float4 UpsamplePS7(v2fu input) : SV_Target { return UpsamplePS(_SampleBloom7, input); }
float4 UpsamplePS6(v2fu input) : SV_Target { return UpsamplePS(_SampleBloom6, input); }
float4 UpsamplePS5(v2fu input) : SV_Target { return UpsamplePS(_SampleBloom5, input); }
float4 UpsamplePS4(v2fu input) : SV_Target { return UpsamplePS(_SampleBloom4, input); }
float4 UpsamplePS3(v2fu input) : SV_Target { return UpsamplePS(_SampleBloom3, input); }
float4 UpsamplePS2(v2fu input) : SV_Target { return UpsamplePS(_SampleBloom2, input); }

void CompositePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float Dither = frac(52.9829189 * frac(dot(Position.xy, float2(0.06711056, 0.00583715))));
    float4 Src = tex2D(_SampleBloom1, TexCoord);
    float4 Dest = tex2D(_SampleColor, TexCoord);
    Src *= _Intensity;
    Src = mul(ACESInputMat, Src.rgb);
    Src = RRTAndODTFit(Src.rgb);
    Src = saturate(mul(ACESOutputMat, Src.rgb));
    OutputColor0 = (Src + Dest) - (Src * Dest);
    OutputColor0 += Dither * (1.0 / 255);
}

/* [ TECHNIQUE ] */

technique c
{
    #define blend(i, j, k) BlendEnable = TRUE; BlendOp = i; SrcBlend = j; DestBlend = k
    pass { VertexShader = PostProcessVS; PixelShader = PrefilterPS; RenderTarget = _RenderBloom1; }
    pass { VertexShader = DownsampleVS1; PixelShader = DownsamplePS1; RenderTarget = _RenderBloom2; }
    pass { VertexShader = DownsampleVS2; PixelShader = DownsamplePS2; RenderTarget = _RenderBloom3; }
    pass { VertexShader = DownsampleVS3; PixelShader = DownsamplePS3; RenderTarget = _RenderBloom4; }
    pass { VertexShader = DownsampleVS4; PixelShader = DownsamplePS4; RenderTarget = _RenderBloom5; }
    pass { VertexShader = DownsampleVS5; PixelShader = DownsamplePS5; RenderTarget = _RenderBloom6; }
    pass { VertexShader = DownsampleVS6; PixelShader = DownsamplePS6; RenderTarget = _RenderBloom7; }
    pass { VertexShader = DownsampleVS7; PixelShader = DownsamplePS7; RenderTarget = _RenderBloom8; }
    pass { VertexShader = UpsampleVS8; PixelShader = UpsamplePS8; RenderTarget = _RenderBloom7; blend(ADD, ONE, ONE); }
    pass { VertexShader = UpsampleVS7; PixelShader = UpsamplePS7; RenderTarget = _RenderBloom6; blend(ADD, ONE, ONE); }
    pass { VertexShader = UpsampleVS6; PixelShader = UpsamplePS6; RenderTarget = _RenderBloom5; blend(ADD, ONE, ONE); }
    pass { VertexShader = UpsampleVS5; PixelShader = UpsamplePS5; RenderTarget = _RenderBloom4; blend(ADD, ONE, ONE); }
    pass { VertexShader = UpsampleVS4; PixelShader = UpsamplePS4; RenderTarget = _RenderBloom3; blend(ADD, ONE, ONE); }
    pass { VertexShader = UpsampleVS3; PixelShader = UpsamplePS3; RenderTarget = _RenderBloom2; blend(ADD, ONE, ONE); }
    pass { VertexShader = UpsampleVS2; PixelShader = UpsamplePS2; RenderTarget = _RenderBloom1; blend(ADD, ONE, ONE); }
    pass { VertexShader = PostProcessVS; PixelShader = CompositePS; SRGBWriteEnable = TRUE; }
}
