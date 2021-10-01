
/*
    ReShadeFX implementation of PixelFlow's RenderStreams
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
> = 0.0;

uniform bool _Normal <
    ui_label = "Lines Normal Direction";
    ui_tooltip = "Normal to velocity direction";
> = true;

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

texture2D _RenderInfo0_VectorLines
{
    Width = ISIZE;
    Height = ISIZE;
    Format = RG16F;
    MipLevels = 8;
};

texture2D _RenderInfo1_VectorLines
{
    Width = ISIZE;
    Height = ISIZE;
    Format = R16F;
};

texture2D _RenderDerivatives_VectorLines
{
    Width = ISIZE;
    Height = ISIZE;
    Format = RG16F;
    MipLevels = 8;
};

texture2D _RenderOpticalFlow_VectorLines
{
    Width = ISIZE;
    Height = ISIZE;
    Format = RG16F;
    MipLevels = 8;
};

sampler2D _SampleOpticalFlow
{
    Texture = _RenderOpticalFlow_VectorLines;
    AddressU = MIRROR;
    AddressV = MIRROR;
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
    Texture = _RenderInfo0_VectorLines;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D _SampleInfo1
{
    Texture = _RenderInfo1_VectorLines;
    AddressU = MIRROR;
    AddressV = MIRROR;
};

sampler2D _SampleDerivatives
{
    Texture = _RenderDerivatives_VectorLines;
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
    const float2 PixelSize = 0.5 / ISIZE;
    const float4 PixelOffset = float4(PixelSize, -PixelSize);
    PostProcessVS(ID, Position, TexCoord);
    Offsets = TexCoord.xyxy + PixelOffset;
}

/* [Pixel Shaders] */

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

void DeriviativesPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets : TEXCOORD1, out float2 OutputColor0 : SV_TARGET0, out float OutputColor1 : SV_TARGET1)
{
    float2 Sample0 = tex2D(_SampleInfo0, Offsets.zy).xy; // (-x, +y)
    float2 Sample1 = tex2D(_SampleInfo0, Offsets.xy).xy; // (+x, +y)
    float2 Sample2 = tex2D(_SampleInfo0, Offsets.zw).xy; // (-x, -y)
    float2 Sample3 = tex2D(_SampleInfo0, Offsets.xw).xy; // (+x, -y)
    float4 DerivativeX;
    DerivativeX.xy = Sample1 - Sample0;
    DerivativeX.zw = Sample3 - Sample2;
    float4 DerivativeY;
    DerivativeY.xy = Sample0 - Sample2;
    DerivativeY.zw = Sample1 - Sample3;
    OutputColor0.x = dot(DerivativeX, 0.25);
    OutputColor0.y = dot(DerivativeY, 0.25);
    OutputColor1 = tex2D(_SampleInfo0, TexCoord).x;
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

/*
    Uniforms: https://github.com/diwi/PixelFlow/blob/master/src/com/thomasdiewald/pixelflow/java/imageprocessing/DwOpticalFlow.java#L230
    Vertex Shader : https://github.com/diwi/PixelFlow/blob/master/src/com/thomasdiewald/pixelflow/glsl/OpticalFlow/renderVelocityStreams.vert
    Pixel Shader : https://github.com/diwi/PixelFlow/blob/master/src/com/thomasdiewald/pixelflow/glsl/OpticalFlow/renderVelocityStreams.frag
*/

#ifndef VERTEX_SPACING
    #define VERTEX_SPACING 10
#endif

#define LINES_X uint(BUFFER_WIDTH / VERTEX_SPACING)
#define LINES_Y uint(BUFFER_HEIGHT / VERTEX_SPACING)
#define NUM_LINES (LINES_X * LINES_Y)
#define SPACE_X (BUFFER_WIDTH / LINES_X)
#define SPACE_Y (BUFFER_HEIGHT / LINES_Y)
#define VELOCITY_SCALE (SPACE_X + SPACE_Y) * 1

void OutputVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 Velocity : TEXCOORD0)
{
    // get line index / vertex index
    int LineID = ID / 2;
    int VertexID  = ID % 2; // either 0 (line-start) or 1 (line-end)

    // get position (xy)
    int Row = LineID / LINES_X;
    int Column = LineID - LINES_X * Row;

    // compute origin (line-start)
    const float2 Spacing = float2(SPACE_X, SPACE_Y);
    float2 Offset = Spacing * 0.5;
    float2 Origin = Offset + float2(Column, Row) * Spacing;

    // get velocity from texture at origin location
    const float2 wh_rcp = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    Velocity = tex2Dlod(_SampleOpticalFlow, float4(Origin.x * wh_rcp.x, 1.0 - Origin.y * wh_rcp.y, 0.0, _Detail)).xy;

    // SCALE velocity
    float2 Direction = Velocity * VELOCITY_SCALE;

    float Length = length(Direction + 1e-5);
    Direction = Direction / sqrt(Length * 0.1);

    // for fragmentshader ... coloring
    Velocity = Direction * 0.2;

    // compute current vertex position (based on vtx_id)
    float2 VertexPosition = (0.0);

    if(_Normal)
    {
        // lines, normal to velocity direction
        Direction *= 0.5;
        float2 DirectionNormal = float2(Direction.y, -Direction.x);
        VertexPosition = Origin + Direction - DirectionNormal + DirectionNormal * VertexID * 2;
    } else {
        // lines,in velocity direction
        VertexPosition = Origin + Direction * VertexID;
    }

    // finish vertex coordinate
    float2 VertexPositionNormal = (VertexPosition + 0.5) * wh_rcp; // [0, 1]
    Position = float4(VertexPositionNormal * 2.0 - 1.0, 0.0, 1.0); // ndc: [-1, +1]
}

void OutputPS(float4 Position : SV_POSITION, float2 Velocity : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float Length = length(Velocity) * VELOCITY_SCALE * 0.05;
    OutputColor0.rg = 0.5 * (1.0 + Velocity.xy / (Length + 1e-4));
    OutputColor0.b = 0.5 * (2.0 - dot(OutputColor0.rg, 1.0));
    OutputColor0.a = 1.0;
}

technique cVectorLines
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
        RenderTarget0 = _RenderInfo0_VectorLines;
    }

    pass
    {
        VertexShader = HorizontalBlurVS;
        PixelShader = HorizontalBlurPS;
        RenderTarget0 = _RenderInfo1_VectorLines;
    }

    pass
    {
        VertexShader = VerticalBlurVS;
        PixelShader = VerticalBlurPS;
        RenderTarget0 = _RenderInfo0_VectorLines;
        RenderTargetWriteMask = 1;
    }

    pass
    {
        VertexShader = DerivativesVS;
        PixelShader = DeriviativesPS;
        RenderTarget0 = _RenderDerivatives_VectorLines;
        RenderTarget1 = _RenderInfo1_VectorLines;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OpticalFlowPS;
        RenderTarget0 = _RenderOpticalFlow_VectorLines;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
    }

    pass
    {
        PrimitiveTopology = LINELIST;
        VertexCount = NUM_LINES * 2;
        VertexShader = OutputVS;
        PixelShader = OutputPS;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = SRCALPHA;
        DestBlend = INVSRCALPHA;
        SrcBlendAlpha = ONE;
        DestBlendAlpha = ONE;
    }
}
