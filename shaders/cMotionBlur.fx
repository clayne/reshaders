
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to
    - MartinBFFan and Pao on Discord for reporting bugs
    - BSD for bug propaganda and helping to solve my issue
    - Lord of Lunacy, KingEric1992, and Marty McFly for power of 2 function
*/

uniform float _Scale <
    ui_type = "drag";
    ui_label = "Flow Scale";
    ui_tooltip = "Higher = More motion blur";
> = 3.0;

uniform float _Constraint <
    ui_type = "drag";
    ui_label = "Constraint";
    ui_tooltip = "Higher = Smoother flow";
> = 1.0;

uniform float _Blend <
    ui_type = "drag";
    ui_label = "Temporal Blending";
    ui_tooltip = "Higher = Less temporal noise";
    ui_max = 0.5;
> = 0.25;

uniform float _Detail <
    ui_type = "drag";
    ui_label = "Mipmap Bias";
    ui_tooltip = "Higher = Less spatial noise";
> = 4.5;

#define CONST_LOG2(x) (\
    (uint((x)  & 0xAAAAAAAA) != 0) | \
    (uint(((x) & 0xFFFF0000) != 0) << 4) | \
    (uint(((x) & 0xFF00FF00) != 0) << 3) | \
    (uint(((x) & 0xF0F0F0F0) != 0) << 2) | \
    (uint(((x) & 0xCCCCCCCC) != 0) << 1))

#define BIT2_LOG2(x)  ((x) | (x) >> 1)
#define BIT4_LOG2(x)  (BIT2_LOG2(x) | BIT2_LOG2(x) >> 2)
#define BIT8_LOG2(x)  (BIT4_LOG2(x) | BIT4_LOG2(x) >> 4)
#define BIT16_LOG2(x) (BIT8_LOG2(x) | BIT8_LOG2(x) >> 8)
#define LOG2(x)       (CONST_LOG2((BIT16_LOG2(x) >> 1) + 1))
#define RMAX(x, y)     x ^ ((x ^ y) & -(x < y)) // max(x, y)

#define _HALFSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define _MIPLEVELS LOG2(RMAX(_HALFSIZE.x, _HALFSIZE.y)) + 1
#define _DATASIZE 128.0

texture2D _RenderColor : COLOR;

texture2D _RenderBuffer
{
    Width = _HALFSIZE.x;
    Height = _HALFSIZE.y;
    Format = R16F;
    MipLevels = _MIPLEVELS;
};

texture2D _RenderData0
{
    Width = _DATASIZE;
    Height = _DATASIZE;
    Format = RG16F;
    MipLevels = 8;
};

texture2D _RenderData1
{
    Width = _DATASIZE;
    Height = _DATASIZE;
    Format = RG16F;
    MipLevels = 8;
};

texture2D _RenderCopy_MotionBlur
{
    Width = _DATASIZE;
    Height = _DATASIZE;
    Format = R16F;
};

texture2D _RenderOpticalFlow_MotionBlur
{
    Width = _DATASIZE;
    Height = _DATASIZE;
    Format = RG16F;
};

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

sampler2D _SampleBuffer
{
    Texture = _RenderBuffer;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D _SampleData0
{
    Texture = _RenderData0;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D _SampleData1
{
    Texture = _RenderData1;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D _SampleCopy
{
    Texture = _RenderCopy_MotionBlur;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D _SampleOpticalFlow
{
    Texture = _RenderOpticalFlow_MotionBlur;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

static const float KernelSize = 14;

float Gaussian1D(const int Position)
{
    const float Sigma = KernelSize / 3.0;
    const float Pi = 3.1415926535897932384626433832795f;
    float Output = rsqrt(2.0 * Pi * (Sigma * Sigma));
    return Output * exp(-0.5 * Position * Position / (Sigma * Sigma));
}

float3 OutputWeights(const float Index)
{
    float Weight0 = Gaussian1D(Index);
    float Weight1 = Gaussian1D(Index + 1.0);
    float LinearWeight = Weight0 + Weight1;
    return float3(Weight0, Weight1, LinearWeight);
}

float2 OutputOffsets(const float Index)
{
    float3 Weights = OutputWeights(Index);
    float Offset = dot(float2(Index, Index + 1.0), Weights.xy) / Weights.z;
    return float2(Offset, -Offset);
}

void HorizontalBlurVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets[7] : TEXCOORD1)
{
    PostProcessVS(ID, Position, TexCoord);
    const float2 Direction = float2(1.0 / _DATASIZE, 0.0);

    [unroll] for(int i = 0; i < 7; i++)
    {
        const float2 LinearOffset = OutputOffsets(i * 2 + 1);
        Offsets[i] = TexCoord.xyxy + LinearOffset.xxyy * Direction.xyxy;
    }
}

void VerticalBlurVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets[7] : TEXCOORD1)
{
    PostProcessVS(ID, Position, TexCoord);
    const float2 Direction = float2(0.0, 1.0 / _DATASIZE);

    [unroll] for(int i = 0; i < 7; i++)
    {
        const float2 LinearOffset = OutputOffsets(i * 2 + 1);
        Offsets[i] = TexCoord.xyxy + LinearOffset.xxyy * Direction.xyxy;
    }
}

/* [ Pixel Shaders ] */

float4 Blur1D(sampler2D Source, float2 TexCoord, float4 Offsets[7])
{
    float Total = Gaussian1D(0.0);
    float4 Output = tex2D(Source, TexCoord) * Gaussian1D(0.0);

    [unroll] for(int i = 0; i < 7; i ++)
    {
        const float LinearWeight = OutputWeights(i * 2 + 1).z;
        Output += tex2D(Source, Offsets[i].xy) * LinearWeight;
        Output += tex2D(Source, Offsets[i].zw) * LinearWeight;
        Total += 2.0 * LinearWeight;
    }

    return Output / Total;
}

void NormalizePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
{
    float3 Color = max(1e-7, tex2D(_SampleColor, TexCoord).rgb);
    Color /= dot(Color, 1.0);
    Color /= max(max(Color.r, Color.g), Color.b);
    OutputColor0 = dot(Color, 1.0 / 3.0);
}

void BlitPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0.x = tex2D(_SampleBuffer, TexCoord).x;
    OutputColor0.y = tex2D(_SampleCopy, TexCoord).x;
}

void HorizontalBlurPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float OutputColor0 : SV_TARGET0)
{
    OutputColor0 = Blur1D(_SampleData0, TexCoord, Offsets).x;
}

void VerticalBlurPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = Blur1D(_SampleData1, TexCoord, Offsets).x;
}

void OpticalFlowPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0, out float4 OutputColor1 : SV_TARGET1)
{
    int MaxLevel = ceil(log2(_DATASIZE));
    const float Lamdba = max(4.0 * pow(_Constraint * 1e-3, 2.0), 1e-10);

    while(MaxLevel >= 0)
    {
        const float2 ScaleSize = 1.0 / ldexp(_DATASIZE, -MaxLevel);
        float2 A = tex2Dlod(_SampleData0, float4(TexCoord + float2(-0.5, +0.5) * ScaleSize, 0.0, MaxLevel)).xy;
        float2 B = tex2Dlod(_SampleData0, float4(TexCoord + float2(+0.5, +0.5) * ScaleSize, 0.0, MaxLevel)).xy;
        float2 C = tex2Dlod(_SampleData0, float4(TexCoord + float2(-0.5, -0.5) * ScaleSize, 0.0, MaxLevel)).xy;
        float2 D = tex2Dlod(_SampleData0, float4(TexCoord + float2(+0.5, -0.5) * ScaleSize, 0.0, MaxLevel)).xy;

        float3 _I;
        _I.x = dot((-A + -C) + (B + D), 0.5);
        _I.y = dot((C + D) + (-A + -B), 0.5);
        _I.z = dot(A + B + C + D, float2(0.25, -0.25));

        float Linear = dot(_I.xy, OutputColor0.xy) + _I.z;
        float Smoothness = rcp(dot(_I.xy, _I.xy) + Lamdba);
        OutputColor0.xy -= ((_I.xy * Linear) * Smoothness);
        MaxLevel = MaxLevel - 1;
    }

    OutputColor0 = float4(OutputColor0.xy, 0.0, _Blend);
    OutputColor1 = float4(tex2D(_SampleData0, TexCoord).xxx, 0.0);
}

void PPHorizontalBlurPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = Blur1D(_SampleOpticalFlow, TexCoord, Offsets).xy;
}

void PPVerticalBlurPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = Blur1D(_SampleData0, TexCoord, Offsets).xy;
}

float Noise(float2 vpos)
{
    return frac(52.9829189 * frac(dot(vpos.xy, float2(0.06711056, 0.00583715))));
}

void OutputPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
{
    float4 Blur;
    const float AspectRatio = BUFFER_WIDTH / BUFFER_HEIGHT;
    const float Samples = 1.0 / (8.0 - 1.0);
    float2 Flow = tex2Dlod(_SampleData1, float4(TexCoord, 0.0, _Detail)).xy;
    Flow = Flow * rcp(_DATASIZE) * AspectRatio;
    Flow *= _Scale;

    for(int k = 0; k < 9; k++)
    {
        float2 CalculatePosition = (Noise(Position.xy) + k) * Samples - 0.5;
        float4 Color = tex2D(_SampleColor, Flow * CalculatePosition + TexCoord);
        Blur = lerp(Blur, Color, rcp(float(k) + 1));
    }

    OutputColor0 = Blur;
}

technique cMotionBlur
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = NormalizePS;
        RenderTarget0 = _RenderBuffer;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS;
        RenderTarget0 = _RenderData0;
    }

    pass
    {
        VertexShader = HorizontalBlurVS;
        PixelShader = HorizontalBlurPS;
        RenderTarget0 = _RenderData1;
        RenderTargetWriteMask = 1;
    }

    pass
    {
        VertexShader = VerticalBlurVS;
        PixelShader = VerticalBlurPS;
        RenderTarget0 = _RenderData0;
        RenderTargetWriteMask = 1;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OpticalFlowPS;
        RenderTarget0 = _RenderOpticalFlow_MotionBlur;
        RenderTarget1 = _RenderCopy_MotionBlur;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
    }

    pass
    {
        VertexShader = HorizontalBlurVS;
        PixelShader = PPHorizontalBlurPS;
        RenderTarget0 = _RenderData0;
    }

    pass
    {
        VertexShader = VerticalBlurVS;
        PixelShader = PPVerticalBlurPS;
        RenderTarget0 = _RenderData1;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OutputPS;
        SRGBWriteEnable = TRUE;
    }
}
