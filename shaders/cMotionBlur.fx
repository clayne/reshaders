
/*
    Optical flow motion blur using color by Brimson
    Special Thanks to
    - MartinBFFan and Pao on Discord for reporting bugs
    - BSD for bug propaganda and helping to solve my issue
*/

uniform float _Constraint <
    ui_type = "slider";
    ui_label = "Constraint";
    ui_tooltip = "Higher = Smoother flow";
    ui_min = 0.0;
    ui_max = 10.0;
> = 1.0;

uniform float _Scale <
    ui_type = "slider";
    ui_label = "Flow Scale";
    ui_tooltip = "Higher = More motion blur";
    ui_min = 0.0;
    ui_max = 10.0;
> = 1.0;

uniform float _Detail <
    ui_type = "slider";
    ui_label = "Mipmap Bias";
    ui_tooltip = "Higher = Less spatial noise";
    ui_min = 0.0;
    ui_max = 7.0;
> = 3.5;

uniform float _Blend <
    ui_type = "slider";
    ui_label = "Temporal Blending";
    ui_tooltip = "Higher = Less temporal noise";
    ui_min = 0.0;
    ui_max = 0.5;
> = 0.25;

uniform bool _FrameRateScaling <
    ui_type = "radio";
    ui_label = "Frame-Rate Scaling";
    ui_tooltip = "Enables frame-rate scaling";
> = false;

uniform float _TargetFrameRate <
    ui_type = "drag";
    ui_label = "Target Frame-Rate";
    ui_tooltip = "Targeted frame-rate";
> = 60.00;

uniform float _FrameTime < source = "frametime"; >;

#define _HALFSIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define _BUFFERSIZE uint2(128, 128)

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

texture2D _RenderBuffer
{
    Width = _HALFSIZE.x;
    Height = _HALFSIZE.y;
    Format = R16F;
    MipLevels = 8;
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
    MipLevels = 8;
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
    MipLevels = 8;
};

sampler2D _SampleData1
{
    Texture = _RenderData1;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

texture2D _RenderCopy_MotionBlur
{
    Width = _BUFFERSIZE.x;
    Height = _BUFFERSIZE.y;
    Format = R16F;
};

sampler2D _SampleCopy
{
    Texture = _RenderCopy_MotionBlur;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

texture2D _RenderOpticalFlow_MotionBlur
{
    Width = _BUFFERSIZE.x;
    Height = _BUFFERSIZE.y;
    Format = RG16F;
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

void DerivativesVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets : TEXCOORD1)
{
    const float2 PixelSize = 0.5 / _BUFFERSIZE;
    const float4 PixelOffset = float4(PixelSize, -PixelSize);
    PostProcessVS(ID, Position, TexCoord);
    Offsets = TexCoord.xyxy + PixelOffset;
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
    OutputColor0 = max(max(Color.r, Color.g), Color.b);
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

    // Store blurred image for the next before we overwrite the rendertarget!
    OutputColor1 = OutputColor0.x;
}

void DerivativesPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0)
{
    float2 Sample0 = tex2D(_SampleData0, Offsets.zy).xy; // (-x, +y)
    float2 Sample1 = tex2D(_SampleData0, Offsets.xy).xy; // (+x, +y)
    float2 Sample2 = tex2D(_SampleData0, Offsets.zw).xy; // (-x, -y)
    float2 Sample3 = tex2D(_SampleData0, Offsets.xw).xy; // (+x, -y)
    float2 Ix = (-Sample2 + -Sample0) + (Sample3 + Sample1);
    float2 Iy = (Sample2 + Sample3) + (-Sample0 + -Sample1);
    OutputColor0.x = dot(Ix, 0.5);
    OutputColor0.y = dot(Iy, 0.5);
}

void OpticalFlowPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    const float MaxLevel = 6.5;
    OutputColor0.xy = 0.0;

    for(float Level = MaxLevel; Level > 0.0; Level--)
    {
        const float Lambda = (_Constraint * 1e-3) / pow(4.0, MaxLevel - Level);
        float4 LevelCoord = float4(TexCoord, 0.0, Level);

        float2 SampleFrame = tex2Dlod(_SampleData0, LevelCoord).xy;
        float4 I;
        I.xy = tex2Dlod(_SampleData1, LevelCoord).xy;
        I.z = SampleFrame.x - SampleFrame.y;
        I.w = 1.0 / (dot(I.xy, I.xy) + Lambda);

        OutputColor0.x = lerp(OutputColor0.x, OutputColor0.x - (I.x * (dot(I.xy, OutputColor0.xy) + I.z)) * I.w, 1.5);
        OutputColor0.x = lerp(OutputColor0.x - (I.x * (dot(I.xy, OutputColor0.xy) + I.z)) * I.w, OutputColor0.x, 1.5);
        OutputColor0.y = lerp(OutputColor0.y, OutputColor0.y - (I.y * (dot(I.xy, OutputColor0.xy) + I.z)) * I.w, 1.5);
        OutputColor0.y = lerp(OutputColor0.y - (I.y * (dot(I.xy, OutputColor0.xy) + I.z)) * I.w, OutputColor0.y, 1.5);
    }

    OutputColor0.ba = _Blend;
}

void PPHorizontalBlurPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleOpticalFlow, TexCoord, Offsets).xy;
}

void PPVerticalBlurPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleData0, TexCoord, Offsets).xy;
}

void OutputPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
{
    const int Samples = 4;
    float Noise = frac(52.9829189 * frac(dot(Position.xy, float2(0.06711056, 0.00583715))));
    float FrameTimeRatio = _TargetFrameRate / (1e+3 / _FrameTime);
    float2 Velocity = (tex2Dlod(_SampleData1, float4(TexCoord, 0.0, _Detail)).xy / _BUFFERSIZE) * _Scale;
    Velocity /= (_FrameRateScaling) ? FrameTimeRatio : 1.0;

    for(int k = 0; k < Samples; ++k)
    {
        float2 Offset = Velocity * (Noise + k);
        OutputColor0 += tex2D(_SampleColor, (TexCoord + Offset));
        OutputColor0 += tex2D(_SampleColor, (TexCoord - Offset));
    }

    OutputColor0 /= (Samples * 2.0);
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
        RenderTarget1 = _RenderCopy_MotionBlur;
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
        RenderTarget0 = _RenderOpticalFlow_MotionBlur;
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
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
