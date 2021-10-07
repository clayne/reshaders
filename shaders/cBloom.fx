
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

#define VSINPUT in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION

void PostProcessVS(VSINPUT, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void DownsampleVS(VSINPUT, inout float4 TexCoord[4] : TEXCOORD0, float Factor)
{
    float2 TexCoord0;
    PostProcessVS(ID, Position, TexCoord0);
    const float2 pSize = rcp(float2(BUFFER_WIDTH, BUFFER_HEIGHT) / exp2(Factor));
    TexCoord[0] = TexCoord0.xyxy + float4(-1.0, -1.0, 1.0, 1.0) * pSize.xyxy; // Quad
    TexCoord[1] = TexCoord0.xyyy + float4(-2.0, 2.0, 0.0, -2.0) * pSize.xyyy; // Left column
    TexCoord[2] = TexCoord0.xyyy + float4(0.0, 2.0, 0.0, -2.0) * pSize.xyyy; // Center column
    TexCoord[3] = TexCoord0.xyyy + float4(2.0, 2.0, 0.0, -2.0) * pSize.xyyy; // Right column
}

void UpsampleVS(VSINPUT, inout float4 TexCoord[3] : TEXCOORD0, float Factor)
{
    float2 TexCoord0;
    PostProcessVS(ID, Position, TexCoord0);
    const float2 pSize = rcp(float2(BUFFER_WIDTH, BUFFER_HEIGHT) / exp2(Factor));
    TexCoord[0] = TexCoord0.xyyy + float4(-1.0, 1.0, 0.0, -1.0) * pSize.xyyy; // Left column
    TexCoord[1] = TexCoord0.xyyy + float4(0.0, 1.0, 0.0, -1.0) * pSize.xyyy; // Center column
    TexCoord[2] = TexCoord0.xyyy + float4(1.0, 1.0, 0.0, -1.0) * pSize.xyyy; // Right column
}

void DownsampleVS1(VSINPUT, inout float4 TexCoord[4] : TEXCOORD0) { DownsampleVS(ID, Position, TexCoord, 1.0); }
void DownsampleVS2(VSINPUT, inout float4 TexCoord[4] : TEXCOORD0) { DownsampleVS(ID, Position, TexCoord, 2.0); }
void DownsampleVS3(VSINPUT, inout float4 TexCoord[4] : TEXCOORD0) { DownsampleVS(ID, Position, TexCoord, 3.0); }
void DownsampleVS4(VSINPUT, inout float4 TexCoord[4] : TEXCOORD0) { DownsampleVS(ID, Position, TexCoord, 4.0); }
void DownsampleVS5(VSINPUT, inout float4 TexCoord[4] : TEXCOORD0) { DownsampleVS(ID, Position, TexCoord, 5.0); }
void DownsampleVS6(VSINPUT, inout float4 TexCoord[4] : TEXCOORD0) { DownsampleVS(ID, Position, TexCoord, 6.0); }
void DownsampleVS7(VSINPUT, inout float4 TexCoord[4] : TEXCOORD0) { DownsampleVS(ID, Position, TexCoord, 7.0); }

void UpsampleVS8(VSINPUT, inout float4 TexCoord[3] : TEXCOORD0) { UpsampleVS(ID, Position, TexCoord, 8.0); }
void UpsampleVS7(VSINPUT, inout float4 TexCoord[3] : TEXCOORD0) { UpsampleVS(ID, Position, TexCoord, 7.0); }
void UpsampleVS6(VSINPUT, inout float4 TexCoord[3] : TEXCOORD0) { UpsampleVS(ID, Position, TexCoord, 6.0); }
void UpsampleVS5(VSINPUT, inout float4 TexCoord[3] : TEXCOORD0) { UpsampleVS(ID, Position, TexCoord, 5.0); }
void UpsampleVS4(VSINPUT, inout float4 TexCoord[3] : TEXCOORD0) { UpsampleVS(ID, Position, TexCoord, 4.0); }
void UpsampleVS3(VSINPUT, inout float4 TexCoord[3] : TEXCOORD0) { UpsampleVS(ID, Position, TexCoord, 3.0); }
void UpsampleVS2(VSINPUT, inout float4 TexCoord[3] : TEXCOORD0) { UpsampleVS(ID, Position, TexCoord, 2.0); }

/*
    [ Pixel Shaders ]
    Thresholding - [https://github.com/keijiro/Kino] [MIT]
    Tonemap - [https://github.com/TheRealMJP/BakingLab] [MIT]
*/

float4 DownsamplePS(sampler2D Source, float4 TexCoord[4])
{
    /*
        A0    B0    C0
           D0    D1
        A1    B1    C1
           D2    D3
        A2    B2    C2
    */

    float4 D0 = tex2D(Source, TexCoord[0].xw);
    float4 D1 = tex2D(Source, TexCoord[0].zw);
    float4 D2 = tex2D(Source, TexCoord[0].xy);
    float4 D3 = tex2D(Source, TexCoord[0].zy);

    float4 A0 = tex2D(Source, TexCoord[1].xy);
    float4 A1 = tex2D(Source, TexCoord[1].xz);
    float4 A2 = tex2D(Source, TexCoord[1].xw);

    float4 B0 = tex2D(Source, TexCoord[2].xy);
    float4 B1 = tex2D(Source, TexCoord[2].xz);
    float4 B2 = tex2D(Source, TexCoord[2].xw);

    float4 C0 = tex2D(Source, TexCoord[3].xy);
    float4 C1 = tex2D(Source, TexCoord[3].xz);
    float4 C2 = tex2D(Source, TexCoord[3].xw);

    float4 Output;
    const float2 Weights = float2(0.5, 0.125) / 4.0;
    Output += (D0 + D1 + D2 + D3) * Weights.x;
    Output += (A0 + B0 + A1 + B1) * Weights.y;
    Output += (B0 + C0 + B1 + C1) * Weights.y;
    Output += (A1 + B1 + A2 + B2) * Weights.y;
    Output += (B1 + C1 + B2 + C2) * Weights.y;
    return Output;
}

float4 UpsamplePS(sampler2D Source, float4 TexCoord[3])
{
    /*
        A0 B0 C0
        A1 B1 C1
        A2 B2 C2
    */

    float4 A0 = tex2D(Source, TexCoord[0].xy);
    float4 A1 = tex2D(Source, TexCoord[0].xz);
    float4 A2 = tex2D(Source, TexCoord[0].xw);

    float4 B0 = tex2D(Source, TexCoord[1].xy);
    float4 B1 = tex2D(Source, TexCoord[1].xz);
    float4 B2 = tex2D(Source, TexCoord[1].xw);

    float4 C0 = tex2D(Source, TexCoord[2].xy);
    float4 C1 = tex2D(Source, TexCoord[2].xz);
    float4 C2 = tex2D(Source, TexCoord[2].xw);

    float4 Output;
    Output  = (A0 + C0 + A2 + C2) * 1.0;
    Output += (A1 + B0 + C1 + B2) * 2.0;
    Output += B1 * 4.0;
    return Output / 16.0;
}

void PrefilterPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    const float Knee = mad(_Threshold, _Smooth, 1e-5f);
    const float3 Curve = float3(_Threshold - Knee, Knee * 2.0, 0.25 / Knee);
    float4 Color = tex2D(_SampleColor, TexCoord);

    // Under-threshold
    float Brightness = max(Color.r, max(Color.g, Color.b));
    float ResponseCurve = clamp(Brightness - Curve.x, 0.0, Curve.y);
    ResponseCurve = Curve.z * ResponseCurve * ResponseCurve;

    // Combine and apply the brightness response curve
    Color = Color * max(ResponseCurve, Brightness - _Threshold) / max(Brightness, 1e-10);
    Brightness = max(max(Color.r, Color.g), Color.b);
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

#define PSINPUT(i) float4 Position : SV_POSITION, float4 TexCoord[i] : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0

void DownsamplePS1(PSINPUT(4)) { OutputColor0 = DownsamplePS(_SampleBloom1, TexCoord); }
void DownsamplePS2(PSINPUT(4)) { OutputColor0 = DownsamplePS(_SampleBloom2, TexCoord); }
void DownsamplePS3(PSINPUT(4)) { OutputColor0 = DownsamplePS(_SampleBloom3, TexCoord); }
void DownsamplePS4(PSINPUT(4)) { OutputColor0 = DownsamplePS(_SampleBloom4, TexCoord); }
void DownsamplePS5(PSINPUT(4)) { OutputColor0 = DownsamplePS(_SampleBloom5, TexCoord); }
void DownsamplePS6(PSINPUT(4)) { OutputColor0 = DownsamplePS(_SampleBloom6, TexCoord); }
void DownsamplePS7(PSINPUT(4)) { OutputColor0 = DownsamplePS(_SampleBloom7, TexCoord); }

void UpsamplePS8(PSINPUT(3)) { OutputColor0 = UpsamplePS(_SampleBloom8, TexCoord); }
void UpsamplePS7(PSINPUT(3)) { OutputColor0 = UpsamplePS(_SampleBloom7, TexCoord); }
void UpsamplePS6(PSINPUT(3)) { OutputColor0 = UpsamplePS(_SampleBloom6, TexCoord); }
void UpsamplePS5(PSINPUT(3)) { OutputColor0 = UpsamplePS(_SampleBloom5, TexCoord); }
void UpsamplePS4(PSINPUT(3)) { OutputColor0 = UpsamplePS(_SampleBloom4, TexCoord); }
void UpsamplePS3(PSINPUT(3)) { OutputColor0 = UpsamplePS(_SampleBloom3, TexCoord); }
void UpsamplePS2(PSINPUT(3)) { OutputColor0 = UpsamplePS(_SampleBloom2, TexCoord); }

void CompositePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float4 Src = tex2D(_SampleBloom1, TexCoord);
    Src *= _Intensity;
    Src = mul(ACESInputMat, Src.rgb);
    Src = RRTAndODTFit(Src.rgb);
    Src = saturate(mul(ACESOutputMat, Src.rgb));
    OutputColor0 = Src;
}

/* [ TECHNIQUE ] */

technique cBloom
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
    pass { VertexShader = UpsampleVS2; PixelShader = UpsamplePS2; RenderTarget = _RenderBloom1; }
    pass { VertexShader = PostProcessVS; PixelShader = CompositePS; blend(ADD, ONE, INVSRCCOLOR); SRGBWriteEnable = TRUE; }
}
