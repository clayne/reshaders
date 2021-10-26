
/*
    This shader will NOT insert frames, just something I played around with
    It's practically useless in games and media players
    However, putting frame blending to 1 does do a weird paint effect LUL

    Optical flow motion blur using color by Brimson
    Special Thanks to
    - MartinBFFan and Pao on Discord for reporting bugs
    - BSD for bug propaganda and helping to solve my issue
    - Lord of Lunacy, KingEric1992, and Marty McFly for power of 2 function
*/

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
> = 2.5;

uniform float _Average <
    ui_type = "drag";
    ui_label = "Frame average";
    ui_tooltip = "Higher = More past frame blend influence";
    ui_max = 1.0;
> = 0.0;

uniform bool _Lerp <
    ui_type = "radio";
    ui_label = "Lerp interpolation";
    ui_tooltip = "Lerp mix interpolated frames";
> = false;

#define _HALFSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define _BUFFERSIZE uint2(_HALFSIZE / 8)

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

texture2D _RenderBuffer
{
    Width = _HALFSIZE.x;
    Height = _HALFSIZE.y;
    Format = R16F;
    MipLevels = 3;
};

sampler2D _SampleBuffer
{
    Texture = _RenderBuffer;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

texture2D _RenderData0
{
    Width = _BUFFERSIZE.x;
    Height = _BUFFERSIZE.y;
    Format = RG16F;
    MipLevels = 6;
};

sampler2D _SampleData0
{
    Texture = _RenderData0;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

texture2D _RenderData1
{
    Width = _BUFFERSIZE.x;
    Height = _BUFFERSIZE.y;
    Format = RG16F;
    MipLevels = 6;
};

sampler2D _SampleData1
{
    Texture = _RenderData1;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

texture2D _RenderCopy_Interpolate
{
    Width = _BUFFERSIZE.x;
    Height = _BUFFERSIZE.y;
    Format = R16F;
};

sampler2D _SampleCopy
{
    Texture = _RenderCopy_Interpolate;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

texture2D _RenderOpticalFlow_Interpolate
{
    Width = _BUFFERSIZE.x;
    Height = _BUFFERSIZE.y;
    Format = RG16F;
};

sampler2D _SampleOpticalFlow
{
    Texture = _RenderOpticalFlow_Interpolate;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

texture2D _RenderFrame_Interpolate
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
};

sampler2D _SampleFrame
{
    Texture = _RenderFrame_Interpolate;
    SRGBTexture = TRUE;
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

float GaussianWeight(const int Position)
{
    const float Sigma = KernelSize / 3.0;
    const float Pi = 3.1415926535897932384626433832795f;
    float Output = rsqrt(2.0 * Pi * (Sigma * Sigma));
    return Output * exp(-(Position * Position) / (2.0 * (Sigma * Sigma)));
}

float3 OutputWeights(const float Index)
{
    float Weight0 = GaussianWeight(Index);
    float Weight1 = GaussianWeight(Index + 1.0);
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
    const float2 Direction = float2(1.0 / _BUFFERSIZE.x, 0.0);

    [unroll] for(int i = 0; i < 7; i++)
    {
        const float2 LinearOffset = OutputOffsets(i * 2 + 1);
        Offsets[i] = TexCoord.xyxy + LinearOffset.xxyy * Direction.xyxy;
    }
}

void VerticalBlurVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets[7] : TEXCOORD1)
{
    PostProcessVS(ID, Position, TexCoord);
    const float2 Direction = float2(0.0, 1.0 / _BUFFERSIZE.y);

    [unroll] for(int i = 0; i < 7; i++)
    {
        const float2 LinearOffset = OutputOffsets(i * 2 + 1);
        Offsets[i] = TexCoord.xyxy + LinearOffset.xxyy * Direction.xyxy;
    }
}

void DerivativesVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Offsets : TEXCOORD0)
{
    const float2 PixelSize = 0.5 / _BUFFERSIZE;
    const float4 PixelOffset = float4(PixelSize, -PixelSize);
    float2 TexCoord0;
    PostProcessVS(ID, Position, TexCoord0);
    Offsets = TexCoord0.xyxy + PixelOffset;
}

/* [ Pixel Shaders ] */

float4 GaussianBlur(sampler2D Source, float2 TexCoord, float4 Offsets[7])
{
    float Total = GaussianWeight(0.0);
    float4 Output = tex2D(Source, TexCoord) * GaussianWeight(0.0);

    [unroll] for(int i = 0; i < 7; i ++)
    {
        const float LinearWeight = OutputWeights(i * 2 + 1).z;
        Output += tex2D(Source, Offsets[i].xy) * LinearWeight;
        Output += tex2D(Source, Offsets[i].zw) * LinearWeight;
        Total += 2.0 * LinearWeight;
    }

    return Output / Total;
}

void NormalizePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float OutputColor0 : SV_TARGET0)
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
    OutputColor0 = GaussianBlur(_SampleData0, TexCoord, Offsets).x;
}

void VerticalBlurPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float OutputColor0 : SV_TARGET0, out float OutputColor1 : SV_TARGET1)
{
    OutputColor0 = GaussianBlur(_SampleData1, TexCoord, Offsets).x;
    OutputColor1 = OutputColor0;
}

void DerivativesPS(float4 Position : SV_POSITION, float4 Offsets : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
{
    float2 Sample0 = tex2D(_SampleData0, Offsets.zy).xy; // (-x, +y)
    float2 Sample1 = tex2D(_SampleData0, Offsets.xy).xy; // (+x, +y)
    float2 Sample2 = tex2D(_SampleData0, Offsets.zw).xy; // (-x, -y)
    float2 Sample3 = tex2D(_SampleData0, Offsets.xw).xy; // (+x, -y)
    float2 _ddx = (-Sample2 + -Sample0) + (Sample3 + Sample1);
    float2 _ddy = (Sample2 + Sample3) + (-Sample0 + -Sample1);
    OutputColor0.x = dot(_ddx, 0.5);
    OutputColor0.y = dot(_ddy, 0.5);
}

float2 GaussSeidel(float4 _I, float Levels, float2 InitialFlow)
{
    float2 Output = InitialFlow;

    while(Levels >= 0.0)
    {
        Output.x -= ((_I.x * (dot(_I.xy, Output.xy) + _I.z)) * _I.w);
        Output.y -= ((_I.y * (dot(_I.xy, Output.xy) + _I.z)) * _I.w);
        Levels = Levels - 1.0;
    }

    return Output;
}

void OpticalFlowPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float MaxLevel = 5.0 - 0.5;
    float2 OutputFlow = 0.0;

    for(float Level = MaxLevel; Level >= 0.0; Level--)
    {
        const float Lambda = (_Constraint * 1e-5) / pow(4.0, MaxLevel - Level);
        float4 CalculateUV = float4(TexCoord, 0.0, Level);
        float2 Frame = tex2Dlod(_SampleData0, CalculateUV).xy;
        float4 _I;
        _I.xy = tex2Dlod(_SampleData1, CalculateUV).xy;
        _I.z = Frame.x - Frame.y;
        _I.w = 1.0 / (dot(_I.xy, _I.xy) + Lambda);
        OutputFlow.xy = GaussSeidel(_I, Level, OutputFlow.xy);
    }

    OutputColor0.rgb = OutputFlow;
    OutputColor0.a = _Blend;
}
void PPHorizontalBlurPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleOpticalFlow, TexCoord, Offsets).xy;
}

void PPVerticalBlurPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleData0, TexCoord, Offsets).xy;
}

// Median masking inspired by vs-mvtools
// https://github.com/dubhater/vapoursynth-mvtools

float4 Median3(float4 A, float4 B, float4 C)
{
    return max(min(A, B), min(max(A, B), C));
}

void InterpolatePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    const float2 PixelSize = rcp(_BUFFERSIZE);
    float2 MotionVectors = tex2Dlod(_SampleData1, float4(TexCoord, 0.0, _Detail)).xy;
    float4 Reference = tex2D(_SampleColor, TexCoord);
    float4 Source = tex2D(_SampleFrame, TexCoord);
    float4 BCompensation, FCompensation;

    if(_Lerp)
    {
        BCompensation = tex2D(_SampleColor, TexCoord + MotionVectors * PixelSize);
        FCompensation = tex2D(_SampleFrame, TexCoord - MotionVectors * PixelSize);
    }
    else
    {
        BCompensation = tex2D(_SampleColor, TexCoord - MotionVectors * PixelSize);
        FCompensation = tex2D(_SampleFrame, TexCoord + MotionVectors * PixelSize);
    }

    float4 Average = lerp(Reference, Source, _Average);
    OutputColor0 = (_Lerp) ? lerp(FCompensation, BCompensation, Average) : Median3(FCompensation, BCompensation, Average);
}

void CopyPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleColor, TexCoord);
}

technique cInterpolate
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
        RenderTarget1 = _RenderCopy_Interpolate;
        RenderTargetWriteMask = 1;
    }

    pass
    {
        VertexShader = DerivativesVS;
        PixelShader = DerivativesPS;
        RenderTarget0 = _RenderData1;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OpticalFlowPS;
        RenderTarget0 = _RenderOpticalFlow_Interpolate;
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
        PixelShader = InterpolatePS;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = CopyPS;
        RenderTarget = _RenderFrame_Interpolate;
        SRGBWriteEnable = TRUE;
    }
}
