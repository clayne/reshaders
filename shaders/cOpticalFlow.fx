
/*
    Uniforms
        https://github.com/diwi/PixelFlow/blob/master/src/com/thomasdiewald/pixelflow/java/imageprocessing/DwOpticalFlow.java#L230
    Vertex Shader
        https://github.com/diwi/PixelFlow/blob/master/src/com/thomasdiewald/pixelflow/glsl/OpticalFlow/renderVelocityStreams.vert
    Pixel Shader
        https://github.com/diwi/PixelFlow/blob/master/src/com/thomasdiewald/pixelflow/glsl/OpticalFlow/renderVelocityStreams.frag
*/

uniform float _Blend <
    ui_type = "slider";
    ui_label = "Blending";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.25;

uniform float _Constraint <
    ui_type = "drag";
    ui_label = "Constraint";
    ui_tooltip = "Higher = Smoother flow";
> = 0.5;

uniform float _Detail <
    ui_type = "drag";
    ui_label = "Mipmap Bias";
    ui_tooltip = "Higher = Less spatial noise";
> = 0.0;

uniform bool _Normal <
    ui_label = "Lines Normal Direction";
    ui_tooltip = "Normal to velocity direction";
    ui_type = "radio";
> = true;

#define SCREEN_SIZE uint2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)
#define PIXEL_SIZE uint2(1 / SCREEN_SIZE)

#ifndef RENDER_VELOCITY_STREAMS
    #define RENDER_VELOCITY_STREAMS 1
#endif

#ifndef VERTEX_SPACING
    #define VERTEX_SPACING 10
#endif

#define LINES_X uint(BUFFER_WIDTH / VERTEX_SPACING)
#define LINES_Y uint(BUFFER_HEIGHT / VERTEX_SPACING)
#define NUM_LINES (LINES_X * LINES_Y)
#define SPACE_X (BUFFER_WIDTH / LINES_X)
#define SPACE_Y (BUFFER_HEIGHT / LINES_Y)
#define VELOCITY_SCALE (SPACE_X + SPACE_Y) * 1

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

texture2D _RenderData0_HS
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RG16F;
    MipLevels = 8;
};

sampler2D _SampleData0
{
    Texture = _RenderData0_HS;
};

texture2D _RenderData1_HS
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RG16F;
    MipLevels = 8;
};

sampler2D _SampleData1
{
    Texture = _RenderData1_HS;
};

texture2D _RenderCopy_HS
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = R16F;
};

sampler2D _SampleCopy
{
    Texture = _RenderCopy_HS;
};

texture2D _RenderOpticalFlow_HS
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RG16F;
};

sampler2D _SampleOpticalFlow
{
    Texture = _RenderOpticalFlow_HS;
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = TexCoord.xyxy * float4(2.0, -2.0, 0.0, 0.0) + float4(-1.0, 1.0, 0.0, 1.0);
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
    const float2 Direction = float2(1.0 / (BUFFER_WIDTH / 2.0), 0.0);

    [unroll] for(int i = 0; i < 7; i++)
    {
        const float2 LinearOffset = OutputOffsets(i * 2 + 1);
        Offsets[i] = TexCoord.xyxy + LinearOffset.xxyy * Direction.xyxy;
    }
}

void VerticalBlurVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets[7] : TEXCOORD1)
{
    PostProcessVS(ID, Position, TexCoord);
    const float2 Direction = float2(0.0, 1.0 / (BUFFER_HEIGHT / 2.0));

    [unroll] for(int i = 0; i < 7; i++)
    {
        const float2 LinearOffset = OutputOffsets(i * 2 + 1);
        Offsets[i] = TexCoord.xyxy + LinearOffset.xxyy * Direction.xyxy;
    }
}

void DerivativesVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Offsets : TEXCOORD0)
{
    const float2 PixelSize = 0.5 / (float2(BUFFER_WIDTH, BUFFER_HEIGHT) / 2.0);
    const float4 PixelOffset = float4(PixelSize, -PixelSize);
    float2 TexCoord0;
    PostProcessVS(ID, Position, TexCoord0);
    Offsets = TexCoord0.xyxy + PixelOffset;
}

void VelocityStreamsVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 Velocity : TEXCOORD0)
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
    Velocity = tex2Dlod(_SampleData1, float4(Origin.x * wh_rcp.x, 1.0 - Origin.y * wh_rcp.y, 0.0, _Detail)).xy;

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
    }
    else
    {
        // lines,in velocity direction
        VertexPosition = Origin + Direction * VertexID;
    }

    // finish vertex coordinate
    float2 VertexPositionNormal = (VertexPosition + 0.5) * wh_rcp; // [0, 1]
    Position = float4(VertexPositionNormal * 2.0 - 1.0, 0.0, 1.0); // ndc: [-1, +1]
}

/* [Pixel Shaders] */

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

void BlitPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
{
    float3 Color = max(tex2D(_SampleColor, TexCoord).rgb, 1e-7);
    float3 NColor = Color / dot(Color, 1.0);
    NColor /= max(max(NColor.r, NColor.g), NColor.b);
    OutputColor0.x = dot(NColor, 1.0 / 3.0);
    OutputColor0.y = tex2D(_SampleCopy, TexCoord).x;
}

void HorizontalBlurPS0(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleData0, TexCoord, Offsets);
}

void VerticalBlurPS0(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float4 OutputColor0 : SV_TARGET0, out float4 OutputColor1 : SV_TARGET1)
{
    OutputColor0 = GaussianBlur(_SampleData1, TexCoord, Offsets);
    OutputColor1 = OutputColor0;
}

void DerivativesPS(float4 Position : SV_POSITION, float4 Offsets : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
{
    float2 Sample0 = tex2D(_SampleData0, Offsets.zy).xy; // (-x, +y)
    float2 Sample1 = tex2D(_SampleData0, Offsets.xy).xy; // (+x, +y)
    float2 Sample2 = tex2D(_SampleData0, Offsets.zw).xy; // (-x, -y)
    float2 Sample3 = tex2D(_SampleData0, Offsets.xw).xy; // (+x, -y)
    OutputColor0.x = dot((-Sample2 + -Sample0) + (Sample3 + Sample1), 0.5);
    OutputColor0.y = dot((Sample2 + Sample3) + (-Sample0 + -Sample1), 0.5);
}

float2 OpticalFlow(float2 TexCoord, float Level, inout float2 OpticalFlow)
{
    const float MaxLevel = 6.5;
    const float Lambda = (_Constraint * 1e-5) * 1e+3 / pow(4.0, MaxLevel - Level);
    const float BufferPixels = (BUFFER_WIDTH / 2) * (BUFFER_HEIGHT / 2);
    const float Iterations = exp2(exp(1.0));

    float4 LevelCoord = float4(TexCoord, 0.0, Level);
    float2 SampleFrame = tex2Dlod(_SampleData0, LevelCoord).xy;
    float4 I;
    I.xy = tex2Dlod(_SampleData1, LevelCoord).xy;
    I.z = SampleFrame.x - SampleFrame.y;
    I.w = 1.0 / (dot(I.xy, I.xy) + Lambda);

    [unroll] for(int i = 0; i <= Iterations; i++)
    {
        OpticalFlow.x -= ((I.x * (dot(I.xy, OpticalFlow.xy) + I.z)) * I.w);
        OpticalFlow.y -= ((I.y * (dot(I.xy, OpticalFlow.xy) + I.z)) * I.w);
    }

    return OpticalFlow;
}

void OpticalFlowPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = 0.0;
    OutputColor0.xy += OpticalFlow(TexCoord, 6.5, OutputColor0.xy);
    OutputColor0.xy += OpticalFlow(TexCoord, 5.5, OutputColor0.xy);
    OutputColor0.xy += OpticalFlow(TexCoord, 4.5, OutputColor0.xy);
    OutputColor0.xy += OpticalFlow(TexCoord, 3.5, OutputColor0.xy);
    OutputColor0.xy += OpticalFlow(TexCoord, 2.5, OutputColor0.xy);
    OutputColor0.xy += OpticalFlow(TexCoord, 1.5, OutputColor0.xy);
    OutputColor0.xy = OpticalFlow(TexCoord, 0.5, OutputColor0.xy);
    OutputColor0.a = _Blend;
}

void HorizontalBlurPS1(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleOpticalFlow, TexCoord, Offsets);
}

void VerticalBlurPS1(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleData0, TexCoord, Offsets);
}

void VelocityShadingPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
{
    float2 Velocity = tex2Dlod(_SampleData1, float4(TexCoord, 0.0, _Detail)).xy;
    float VelocityLength = rsqrt(dot(Velocity, Velocity) + 1.0);
    OutputColor0.rg = 0.5 * (1.0 + Velocity.xy * VelocityLength);
    OutputColor0.b = 0.5 * (2.0 - (OutputColor0.r + OutputColor0.g));
    OutputColor0.a = 1.0;
}

void VelocityStreamsPS(float4 Position : SV_POSITION, float2 Velocity : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float Length = length(Velocity) * VELOCITY_SCALE * 0.05;
    OutputColor0.rg = 0.5 * (1.0 + Velocity.xy / (Length + 1e-4));
    OutputColor0.b = 0.5 * (2.0 - dot(OutputColor0.rg, 1.0));
    OutputColor0.a = 1.0;
}

technique cOpticalFlow
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS;
        RenderTarget0 = _RenderData0_HS;
    }

    pass
    {
        VertexShader = HorizontalBlurVS;
        PixelShader = HorizontalBlurPS0;
        RenderTarget0 = _RenderData1_HS;
        RenderTargetWriteMask = 1;
    }

    pass
    {
        VertexShader = VerticalBlurVS;
        PixelShader = VerticalBlurPS0;
        RenderTarget0 = _RenderData0_HS;
        RenderTarget1 = _RenderCopy_HS;
        RenderTargetWriteMask = 1;
    }

    pass
    {
        VertexShader = DerivativesVS;
        PixelShader = DerivativesPS;
        RenderTarget0 = _RenderData1_HS;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OpticalFlowPS;
        RenderTarget0 = _RenderOpticalFlow_HS;
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
        RenderTarget0 = _RenderData0_HS;
    }

    pass
    {
        VertexShader = VerticalBlurVS;
        PixelShader = VerticalBlurPS1;
        RenderTarget0 = _RenderData1_HS;
    }

    #if RENDER_VELOCITY_STREAMS
        pass
        {
            PrimitiveTopology = LINELIST;
            VertexCount = NUM_LINES * 2;
            VertexShader = VelocityStreamsVS;
            PixelShader = VelocityStreamsPS;
            ClearRenderTargets = FALSE;
            BlendEnable = TRUE;
            BlendOp = ADD;
            SrcBlend = SRCALPHA;
            DestBlend = INVSRCALPHA;
            SrcBlendAlpha = ONE;
            DestBlendAlpha = ONE;
        }
    #else
        pass
        {
            VertexShader = PostProcessVS;
            PixelShader = VelocityShadingPS;
            SRGBWriteEnable = TRUE;
        }
    #endif
}
