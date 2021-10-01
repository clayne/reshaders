
uniform float _Constraint <
    ui_type = "drag";
    ui_label = "Constraint";
    ui_tooltip = "Higher = Smoother flow";
> = 1.0;

uniform float _Blend <
    ui_type = "slider";
    ui_label = "Blending";
    ui_min = 0.0;
    ui_max = 0.5;
> = 0.25;

uniform float _Detail <
    ui_type = "drag";
    ui_label = "Mipmap Bias";
    ui_tooltip = "Higher = Less spatial noise";
> = 0.0;

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

#define _SIZE uint2(BUFFER_WIDTH, BUFFER_HEIGHT)
#define _MIPS LOG2(RMAX(_SIZE.x, _SIZE.y)) + 1

texture2D _RenderColor : COLOR;

texture2D _RenderCurrent
{
    Width = _SIZE.x;
    Height = _SIZE.y;
    Format = R16F;
    MipLevels = _MIPS;
};

texture2D _RenderDerivatives_OpticalFlow
{
    Width = _SIZE.x;
    Height = _SIZE.y;
    Format = RG16F;
    MipLevels = _MIPS;
};

texture2D _RenderOpticalFlow_OpticalFlow
{
    Width = _SIZE.x;
    Height = _SIZE.y;
    Format = RG16F;
    MipLevels = _MIPS;
};

texture2D _RenderPrevious
{
    Width = _SIZE.x;
    Height = _SIZE.y;
    Format = R16F;
    MipLevels = _MIPS;
};

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

sampler2D _SampleCurrent
{
    Texture = _RenderCurrent;
};

sampler2D _SampleDerivatives
{
    Texture = _RenderDerivatives_OpticalFlow;
};

sampler2D _SampleOpticalFlow
{
    Texture = _RenderOpticalFlow_OpticalFlow;
};

sampler2D _SamplePrevious
{
    Texture = _RenderPrevious;
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = TexCoord.xyxy * float4(2.0, -2.0, 0.0, 0.0) + float4(-1.0, 1.0, 0.0, 1.0);
}

void DerivativesVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets : TEXCOORD1)
{
    const float2 PixelSize = 0.5 / _SIZE;
    const float4 PixelOffset = float4(PixelSize, -PixelSize);
    PostProcessVS(ID, Position, TexCoord);
    Offsets = TexCoord.xyxy + PixelOffset;
}

/* [Pixel Shaders] */

void BlitPS0(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float OutputColor0 : SV_TARGET0)
{
    float3 Color = tex2D(_SampleColor, TexCoord).rgb;
    Color /= dot(Color, 1.0);
    Color /= max(max(Color.r, Color.g), Color.b);
    OutputColor0 = dot(Color, 1.0 / 3.0);
}

void DerivativesPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0)
{
    float2 Sample0; // (-x, +y)
    Sample0.x = tex2D(_SampleCurrent, Offsets.zy).x;
    Sample0.y = tex2D(_SamplePrevious, Offsets.zy).x;
    float2 Sample1; // (+x, +y)
    Sample1.x = tex2D(_SampleCurrent, Offsets.xy).x;
    Sample1.y = tex2D(_SamplePrevious, Offsets.xy).x;
    float2 Sample2; // (-x, -y)
    Sample2.x = tex2D(_SampleCurrent, Offsets.zw).x;
    Sample2.y = tex2D(_SamplePrevious, Offsets.zw).x;
    float2 Sample3; // (+x, -y)
    Sample3.x = tex2D(_SampleCurrent, Offsets.xw).x;
    Sample3.y = tex2D(_SamplePrevious, Offsets.xw).x;
    float4 DerivativeX;
    DerivativeX.xy = Sample1 - Sample0;
    DerivativeX.zw = Sample3 - Sample2;
    float4 DerivativeY;
    DerivativeY.xy = Sample0 - Sample2;
    DerivativeY.zw = Sample1 - Sample3;
    OutputColor0.x = dot(DerivativeX, 0.25);
    OutputColor0.y = dot(DerivativeY, 0.25);
}

void OpticalFlowPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    const int PyramidLevels = ceil(_MIPS) - 1;
    const float Lamdba = max(4.0 * pow(_Constraint * 1e-3, 2.0), 1e-10);
    float2 Flow = 0.0;

    for(float i = PyramidLevels; i >= 0; i--)
    {
        float4 CalculateUV = float4(TexCoord, 0.0, i);
        float CurrentFrame = tex2Dlod(_SampleCurrent, CalculateUV).x;
        float PreviousFrame = tex2Dlod(_SamplePrevious, CalculateUV).x;
        float3 Derivatives;
        Derivatives.xy = tex2Dlod(_SampleDerivatives, CalculateUV).xy;
        Derivatives.z = CurrentFrame - PreviousFrame;

        float Linear = dot(Derivatives.xy, Flow) + Derivatives.z;
        float Smoothness = rcp(dot(Derivatives.xy, Derivatives.xy) + Lamdba);
        Flow = Flow - ((Derivatives.xy * Linear) * Smoothness);
    }

    OutputColor0 = float4(Flow.xy, 0.0, _Blend);
}

void OutputPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float2 Velocity = tex2Dlod(_SampleOpticalFlow, float4(TexCoord, 0.0, _Detail)).xy;
    float VelocityLength = rsqrt(dot(Velocity, Velocity) + 1.0);
    OutputColor0.rg = 0.5 * (1.0 + Velocity.xy * VelocityLength);
    OutputColor0.b = 0.5 * (2.0 - (OutputColor0.r + OutputColor0.g));
    OutputColor0.a = 1.0;
}

void BlitPS1(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleCurrent, TexCoord).x;
}

technique cOpticalFlow
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS0;
        RenderTarget0 = _RenderCurrent;
    }

    pass
    {
        VertexShader = DerivativesVS;
        PixelShader = DerivativesPS;
        RenderTarget0 = _RenderDerivatives_OpticalFlow;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OpticalFlowPS;
        RenderTarget0 = _RenderOpticalFlow_OpticalFlow;
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

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS1;
        RenderTarget0 = _RenderPrevious;
    }
}
