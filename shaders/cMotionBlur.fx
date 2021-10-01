
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
> = 2.0;

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

#define DSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define RSIZE LOG2(RMAX(DSIZE.x, DSIZE.y)) + 1
#define ISIZE 128.0

texture2D _RenderColor : COLOR;

texture2D _RenderBuffer
{
    Width = DSIZE.x;
    Height = DSIZE.y;
    Format = R16F;
    MipLevels = RSIZE;
};

texture2D _RenderInfo0_MotionBlur
{
    Width = ISIZE;
    Height = ISIZE;
    Format = RG16F;
    MipLevels = 8;
};

texture2D _RenderInfo1_MotionBlur
{
    Width = ISIZE;
    Height = ISIZE;
    Format = R16F;
};

texture2D _RenderDerivatives_MotionBlur
{
    Width = ISIZE;
    Height = ISIZE;
    Format = RG16F;
    MipLevels = 8;
};

texture2D _RenderOpticalFlow_MotionBlur
{
    Width = ISIZE;
    Height = ISIZE;
    Format = RG16F;
    MipLevels = 8;
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

sampler2D _SampleInfo0
{
    Texture = _RenderInfo0_MotionBlur;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D _SampleInfo1
{
    Texture = _RenderInfo1_MotionBlur;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D _SampleDerivatives
{
    Texture = _RenderDerivatives_MotionBlur;
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

float2 OutputWeights(const float Index)
{
    float2 Weights;
    Weights[0] = Gaussian1D(Index);
    Weights[1] = Gaussian1D(Index + 1.0);
    return Weights;
}

float2 OutputOffsets(const float Index)
{
    float2 Weights = OutputWeights(Index);
    float WeightL = Weights[0] + Weights[1];
    const float2 Offsets = float2(Index, Index + 1.0);
    float2 Output;
    Output[0] = dot(Offsets, Weights) / WeightL;
    Output[1] = -Output[0]; // store negatives here
    return Output;
}

void HorizontalBlurVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets[7] : TEXCOORD1)
{
    PostProcessVS(ID, Position, TexCoord);
    const float2 Direction = float2(1.0 / ISIZE, 0.0);

    [unroll] for(int i = 0; i < 7; i++)
    {
        const float2 LinearOffset = OutputOffsets(i * 2 + 1);
        Offsets[i] = TexCoord.xyxy + LinearOffset.xxyy * Direction.xyxy;
    }
}

void VerticalBlurVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets[7] : TEXCOORD1)
{
    PostProcessVS(ID, Position, TexCoord);
    const float2 Direction = float2(0.0, 1.0 / ISIZE);

    [unroll] for(int i = 0; i < 7; i++)
    {
        const float2 LinearOffset = OutputOffsets(i * 2 + 1);
        Offsets[i] = TexCoord.xyxy + LinearOffset.xxyy * Direction.xyxy;
    }
}

void DerivativesVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets : TEXCOORD1)
{
    const float2 PixelSize = 1.0 / ISIZE;
    const float4 PixelOffset = float4(PixelSize, -PixelSize);
    PostProcessVS(ID, Position, TexCoord);
    Offsets = TexCoord.xyxy + PixelOffset;
}

/* [ Pixel Shaders ] */

float4 Blur1D(sampler2D Source, float2 TexCoord, float4 Offsets[7])
{
    float Total = Gaussian1D(0.0);
    float4 Output = tex2D(Source, TexCoord) * Gaussian1D(0.0);

    [unroll] for(int i = 0; i < 7; i ++)
    {
        const float2 Weights = OutputWeights(i * 2 + 1);
        const float WeightL = Weights[0] + Weights[1];
        Output += tex2D(Source, Offsets[i].xy) * WeightL;
        Output += tex2D(Source, Offsets[i].zw) * WeightL;
        Total += 2.0 * WeightL;
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
    OutputColor0.y = tex2D(_SampleInfo1, TexCoord).x;
}

void HorizontalBlurPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float OutputColor0 : SV_TARGET0)
{
    OutputColor0 = Blur1D(_SampleInfo0, TexCoord, Offsets).x;
}

void VerticalBlurPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = Blur1D(_SampleInfo1, TexCoord, Offsets).x;
}

void DeriviativesPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0, out float2 OutputColor1 : SV_TARGET1)
{
	float4 Sample0;
    Sample0.x = tex2D(_SampleInfo0, Offsets.zy).x; // (-x, +y)
    Sample0.y = tex2D(_SampleInfo0, Offsets.xy).x; // (+x, +y)
    Sample0.z = tex2D(_SampleInfo0, Offsets.zw).x; // (-x, -y)
    Sample0.w = tex2D(_SampleInfo0, Offsets.xw).x; // (+x, -y)
    OutputColor0.x = dot(Sample0, float4( 6.0, -6.0, -6.0,  6.0));
    OutputColor0.y = dot(Sample0, float4(-6.0,  6.0,  6.0, -6.0));
    OutputColor1 = tex2D(_SampleInfo0, TexCoord).rg;
}

void OpticalFlowPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    const int PyramidLevels = ceil(log2(ISIZE));
    const float Lamdba = max(4.0 * pow(_Constraint * 1e-3, 2.0), 1e-10);
    float2 Flow = 0.0;

    for(int i = PyramidLevels; i >= 0; i--)
    {
        float4 CalculateUV = float4(TexCoord, 0.0, i);
        float2 Frame = tex2Dlod(_SampleInfo0, CalculateUV).xy;
        float3 Derivatives;
        Derivatives.xy = tex2Dlod(_SampleDerivatives, CalculateUV).xy;
        Derivatives.z = Frame.x - Frame.y;

        float Linear = dot(Derivatives.xy, Flow) + Derivatives.z;
        float Smoothness = rcp(dot(Derivatives.xy, Derivatives.xy) + Lamdba);
        Flow = Flow - ((Derivatives.xy * Linear) * Smoothness);
    }

    OutputColor0 = float4(Flow.xy, 0.0, _Blend);
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
    float2 Flow = tex2Dlod(_SampleOpticalFlow, float4(TexCoord, 0.0, _Detail)).xy;
    Flow = Flow * rcp(ISIZE) * AspectRatio;
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
        RenderTarget0 = _RenderInfo0_MotionBlur;
    }

    pass
    {
        VertexShader = HorizontalBlurVS;
        PixelShader = HorizontalBlurPS;
        RenderTarget0 = _RenderInfo1_MotionBlur;
    }

    pass
    {
        VertexShader = VerticalBlurVS;
        PixelShader = VerticalBlurPS;
        RenderTarget0 = _RenderInfo0_MotionBlur;
        RenderTargetWriteMask = 1;
    }

    pass
    {
        VertexShader = DerivativesVS;
        PixelShader = DeriviativesPS;
        RenderTarget0 = _RenderDerivatives_MotionBlur;
        RenderTarget1 = _RenderInfo1_MotionBlur;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OpticalFlowPS;
        RenderTarget0 = _RenderOpticalFlow_MotionBlur;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OutputPS;
        SRGBWriteEnable = TRUE;
    }
}
