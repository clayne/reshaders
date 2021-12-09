
/*
    Quasi frame-rate interpolation shader
        Note: Make better masking
*/

uniform float _Blend <
    ui_type = "slider";
    ui_label = "Temporal Blending";
    ui_tooltip = "Higher = Less temporal noise";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.25;

uniform float _Constraint <
    ui_type = "slider";
    ui_label = "Constraint";
    ui_tooltip = "Higher = Smoother flow";
> = 0.1;

uniform float _Detail <
    ui_type = "slider";
    ui_label = "Mipmap Bias";
    ui_tooltip = "Higher = Less spatial noise";
    ui_max = 7.0;
> = 0.0;

#define BUFFER_SIZE uint2(128, 128)

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

texture2D _RenderFrame0_Interpolation
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA8;
    MipLevels = 8;
};

sampler2D _SampleFrame0
{
    Texture = _RenderFrame0_Interpolation;
    SRGBTexture = TRUE;
};

texture2D _RenderData0_Interpolation
{
    Width = BUFFER_SIZE.x;
    Height = BUFFER_SIZE.y;
    Format = RG16F;
    MipLevels = 8;
};

sampler2D _SampleData0
{
    Texture = _RenderData0_Interpolation;
};

texture2D _RenderData1_Interpolation
{
    Width = BUFFER_SIZE.x;
    Height = BUFFER_SIZE.y;
    Format = RG16F;
    MipLevels = 8;
};

sampler2D _SampleData1
{
    Texture = _RenderData1_Interpolation;
};

texture2D _RenderCopy_Interpolation
{
    Width = BUFFER_SIZE.x;
    Height = BUFFER_SIZE.y;
    Format = R16F;
};

sampler2D _SampleCopy
{
    Texture = _RenderCopy_Interpolation;
};

texture2D _RenderOpticalFlow
{
    Width = BUFFER_SIZE.x;
    Height = BUFFER_SIZE.y;
    Format = RG16F;
};

sampler2D _SampleOpticalFlow
{
    Texture = _RenderOpticalFlow;
};

texture2D _RenderFrame1_Interpolation
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA8;
};

sampler2D _SampleFrame1
{
    Texture = _RenderFrame1_Interpolation;
    SRGBTexture = TRUE;
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

static const float KernelSize = 14;

float GaussianWeight(const int PixelPosition)
{
    const float Sigma = KernelSize / 3.0;
    const float Pi = 3.1415926535897932384626433832795f;
    float Output = rsqrt(2.0 * Pi * (Sigma * Sigma));
    return Output * exp(-(PixelPosition * PixelPosition) / (2.0 * (Sigma * Sigma)));
}

void OutputOffsets(in float2 TexCoord, inout float4 Offsets[7], float2 Direction)
{
    int OutputIndex = 0;
    float PixelIndex = 1.0;

    while(OutputIndex < 7)
    {
        float Offset1 = PixelIndex;
        float Offset2 = PixelIndex + 1.0;
        float Weight1 = GaussianWeight(Offset1);
        float Weight2 = GaussianWeight(Offset2);
        float WeightL = Weight1 + Weight2;
        float Offset = ((Offset1 * Weight1) + (Offset2 * Weight2)) / WeightL;
        Offsets[OutputIndex] = TexCoord.xyxy + float2(Offset, -Offset).xxyy * Direction.xyxy;

        OutputIndex += 1;
        PixelIndex += 2.0;
    }
}

void HorizontalBlurVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets[7] : TEXCOORD1)
{
    PostProcessVS(ID, Position, TexCoord);
    OutputOffsets(TexCoord, Offsets, float2(1.0 / BUFFER_SIZE.x, 0.0));
}

void VerticalBlurVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets[7] : TEXCOORD1)
{
    PostProcessVS(ID, Position, TexCoord);
    OutputOffsets(TexCoord, Offsets, float2(0.0, 1.0 / BUFFER_SIZE.y));
}

void DerivativesVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets : TEXCOORD1)
{
    const float2 PixelSize = 0.5 / BUFFER_SIZE;
    const float4 PixelOffset = float4(PixelSize, -PixelSize);
    PostProcessVS(ID, Position, TexCoord);
    Offsets = TexCoord.xyxy + PixelOffset;
}

/* [Pixel Shaders] */

float4 GaussianBlur(sampler2D Source, float2 TexCoord, float4 Offsets[7])
{
    float Total = GaussianWeight(0.0);
    float4 Output = tex2D(Source, TexCoord) * GaussianWeight(0.0);

    int Index = 0;
    float PixelIndex = 1.0;

    while(Index < 7)
    {
        float Offset1 = PixelIndex;
        float Offset2 = PixelIndex + 1.0;
        float Weight1 = GaussianWeight(Offset1);
        float Weight2 = GaussianWeight(Offset2);
        float WeightL = Weight1 + Weight2;
        Output += tex2D(Source, Offsets[Index].xy) * WeightL;
        Output += tex2D(Source, Offsets[Index].zw) * WeightL;
        Total += 2.0 * WeightL;
        Index += 1.0;
        PixelIndex += 2.0;
    }

    return Output / Total;
}

void BlitPS0(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleColor, TexCoord);
}

void NormalizePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float OutputColor0 : SV_TARGET0)
{
    float3 Color = max(tex2D(_SampleFrame0, TexCoord).rgb, 1e-7);
    Color = normalize(Color);
    OutputColor0.x = max(max(Color.r, Color.g), Color.b);
}

void HorizontalBlurPS0(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float OutputColor0 : SV_TARGET0)
{
    OutputColor0.x = GaussianBlur(_SampleData0, TexCoord, Offsets).x;
}

void VerticalBlurPS0(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0.x = GaussianBlur(_SampleData1, TexCoord, Offsets).x;
    OutputColor0.y = tex2D(_SampleCopy, TexCoord).x; // Store previous blurred image before it gets overwritten!
}

void DerivativesPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0, out float2 OutputColor1 : SV_TARGET1)
{
    float Sample0 = tex2D(_SampleData0, Offsets.zy).x; // (-x, +y)
    float Sample1 = tex2D(_SampleData0, Offsets.xy).x; // (+x, +y)
    float Sample2 = tex2D(_SampleData0, Offsets.zw).x; // (-x, -y)
    float Sample3 = tex2D(_SampleData0, Offsets.xw).x; // (+x, -y)
    OutputColor0.x = (Sample3 + Sample1) - (Sample2 + Sample0);
    OutputColor0.y = (Sample2 + Sample3) - (Sample0 + Sample1);
    OutputColor0 *= 4.0;
    OutputColor1 = tex2D(_SampleData0, TexCoord).x;
}

void OpticalFlowPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    const float MaxLevel = 6.5;
    OutputColor0.xy = 0.0;

    [unroll] for(float Level = MaxLevel; Level > 0.0; Level--)
    {
        const float Lambda = ldexp(_Constraint * 1e-5, Level - MaxLevel);
        float4 LevelCoord = float4(TexCoord, 0.0, Level);

        float2 SampleFrame = tex2Dlod(_SampleData0, LevelCoord).xy;
        float4 I;
        I.xy = tex2Dlod(_SampleData1, LevelCoord).xy;
        I.z = SampleFrame.x - SampleFrame.y;
        I.w = 1.0 / (dot(I.xy, I.xy) + Lambda);

        OutputColor0.x = OutputColor0.x - (I.x * (dot(I.xy, OutputColor0.xy) + I.z)) * I.w;
        OutputColor0.y = OutputColor0.y - (I.y * (dot(I.xy, OutputColor0.xy) + I.z)) * I.w;
    }

    OutputColor0.ba = _Blend;
}

void HorizontalBlurPS1(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleOpticalFlow, TexCoord, Offsets).xy;
}

void VerticalBlurPS1(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleData0, TexCoord, Offsets).xy;
}

float4 Median(float4 A, float4 B, float4 C)
{
    return max(min(A, B), min(max(A, B), C));
}

void InterpolatePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float2 MotionVectors = tex2Dlod(_SampleData1, float4(TexCoord, 0.0, _Detail)).xy / BUFFER_SIZE;
    float4 FrameF = tex2D(_SampleFrame1, TexCoord + MotionVectors);
    float4 FrameB = tex2D(_SampleFrame0, TexCoord - MotionVectors);
    float4 FrameP = tex2D(_SampleFrame1, TexCoord);
    float4 FrameC = tex2D(_SampleFrame0, TexCoord);
    float4 FrameA = lerp(FrameC, FrameP, 64.0 / 256.0);
    OutputColor0 = Median(FrameA, FrameF, FrameB);
}

void BlitPS1(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleFrame0, TexCoord);
}

technique cInterpolation
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS0;
        RenderTarget0 = _RenderFrame0_Interpolation;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = NormalizePS;
        RenderTarget0 = _RenderData0_Interpolation;
    }

    pass
    {
        VertexShader = HorizontalBlurVS;
        PixelShader = HorizontalBlurPS0;
        RenderTarget0 = _RenderData1_Interpolation;
    }

    pass
    {
        VertexShader = VerticalBlurVS;
        PixelShader = VerticalBlurPS0;
        RenderTarget0 = _RenderData0_Interpolation;
    }

    pass
    {
        VertexShader = DerivativesVS;
        PixelShader = DerivativesPS;
        RenderTarget0 = _RenderData1_Interpolation;
        RenderTarget1 = _RenderCopy_Interpolation;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OpticalFlowPS;
        RenderTarget0 = _RenderOpticalFlow;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
    }

    pass
    {
        VertexShader = HorizontalBlurVS;
        PixelShader = HorizontalBlurPS1;
        RenderTarget0 = _RenderData0_Interpolation;
    }

    pass
    {
        VertexShader = VerticalBlurVS;
        PixelShader = VerticalBlurPS1;
        RenderTarget0 = _RenderData1_Interpolation;
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
        PixelShader = BlitPS1;
        RenderTarget = _RenderFrame1_Interpolation;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
