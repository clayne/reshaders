
/*
    Sources
        Angle-Retaining Chromaticity
            Title = "ARC: Angle-Retaining Chromaticity diagram for color constancy error analysis"
            Authors = Marco Buzzelli and Simone Bianco and Raimondo Schettini
            Year = 2020
            Link = http://www.ivl.disco.unimib.it/activities/arc/
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
> = 1.0;

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
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
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
    Format = RGBA16F;
    MipLevels = 8;
};

sampler2D _SampleData1
{
    Texture = _RenderData1_HS;
};

texture2D _RenderData2_HS
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RG16F;
    MipLevels = 8;
};

sampler2D _SampleData2
{
    Texture = _RenderData2_HS;
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
    OutputOffsets(TexCoord, Offsets, float2(1.0 / SCREEN_SIZE.x, 0.0));
}

void VerticalBlurVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offsets[7] : TEXCOORD1)
{
    PostProcessVS(ID, Position, TexCoord);
    OutputOffsets(TexCoord, Offsets, float2(0.0, 1.0 / SCREEN_SIZE.y));
}

void DerivativesVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float4 Offsets : TEXCOORD0)
{
    const float2 PixelSize = 0.5 / SCREEN_SIZE.xy;
    const float4 PixelOffset = float4(PixelSize, -PixelSize);
    float2 TexCoord0;
    PostProcessVS(ID, Position, TexCoord0);
    Offsets = TexCoord0.xyxy + PixelOffset;
}

void VelocityStreamsVS(in uint ID : SV_VERTEXID, out float4 Position : SV_POSITION, out float2 Velocity : TEXCOORD0)
{
    int LineID = ID / 2; // Line Index
    int VertexID = ID % 2; // Vertex Index within the line (0 = start, 1 = end)

    // Get Row (x) and Column (y) position
    int Row = LineID / LINES_X;
    int Column = LineID - LINES_X * Row;

    // Compute origin (line-start)
    const float2 Spacing = float2(SPACE_X, SPACE_Y);
    float2 Offset = Spacing * 0.5;
    float2 Origin = Offset + float2(Column, Row) * Spacing;

    // Get velocity from texture at origin location
    const float2 PixelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    float2 VelocityCoord;
    VelocityCoord.x = Origin.x * PixelSize.x;
    VelocityCoord.y = 1.0 - Origin.y * PixelSize.y;
    Velocity = tex2Dlod(_SampleData2, float4(VelocityCoord, 0.0, _Detail)).xy;

    // Scale velocity
    float2 Direction = Velocity * VELOCITY_SCALE;

    float Length = length(Direction + 1e-5);
    Direction = Direction / sqrt(Length * 0.1);

    // Color for fragmentshader
    Velocity = Direction * 0.2;

    // Compute current vertex position (based on VertexID)
    float2 VertexPosition = 0.0;

    if(_Normal)
    {
        // Lines: Normal to velocity direction
        Direction *= 0.5;
        float2 DirectionNormal = float2(Direction.y, -Direction.x);
        VertexPosition = Origin + Direction - DirectionNormal + DirectionNormal * VertexID * 2;
    }
    else
    {
        // Lines: Velocity direction
        VertexPosition = Origin + Direction * VertexID;
    }

    // Finish vertex position
    float2 VertexPositionNormal = (VertexPosition + 0.5) * PixelSize; // [0, 1]
    Position = float4(VertexPositionNormal * 2.0 - 1.0, 0.0, 1.0); // ndc: [-1, +1]
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

void CopyPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleData0, TexCoord).rg;
}

void BlitPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float2 OutputColor0 : SV_TARGET0)
{
    float3 Color = max(tex2D(_SampleColor, TexCoord).rgb, 1e-7);

    // Angle-Retaining Chromaticity (Optimized for GPU)
    float2 AlphaA;
    AlphaA.x = dot(Color.gb, float2(sqrt(3.0), -sqrt(3.0)));;
    AlphaA.y = dot(Color, float3(2.0, -1.0, -1.0));
    float AlphaR = acos(dot(Color, 1.0) / (sqrt(3.0) * length(Color)));
    float AlphaC = AlphaR / length(AlphaA);
    float2 Alpha = AlphaC * AlphaA.yx;

    float2 AlphaMin, AlphaMax;
    AlphaMin.y = -(sqrt(3.0) / 2.0) * acos(rsqrt(3.0));
    AlphaMax.y = (sqrt(3.0) / 2.0) * acos(rsqrt(3.0));
    AlphaMin.x = -acos(sqrt(2.0 / 3.0));
    AlphaMax.x = AlphaMin.x + (AlphaMax.y - AlphaMin.y);
    Alpha.xy = (Alpha.xy - AlphaMin.xy) / (AlphaMax.xy - AlphaMin.xy);
    OutputColor0 = Alpha.xy;
}

void HorizontalBlurPS0(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleData0, TexCoord, Offsets);
}

void VerticalBlurPS0(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleData1, TexCoord, Offsets);
}

void DerivativesPS(float4 Position : SV_POSITION, float4 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float2 Sample0 = tex2D(_SampleData0, TexCoord.zy).xy; // (-x, +y)
    float2 Sample1 = tex2D(_SampleData0, TexCoord.xy).xy; // (+x, +y)
    float2 Sample2 = tex2D(_SampleData0, TexCoord.zw).xy; // (-x, -y)
    float2 Sample3 = tex2D(_SampleData0, TexCoord.xw).xy; // (+x, -y)
    OutputColor0.xz = (Sample3 + Sample1) - (Sample2 + Sample0);
    OutputColor0.yw = (Sample2 + Sample3) - (Sample0 + Sample1);
    OutputColor0 *= 4.0;
}

void OpticalFlowPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float RedChecker = frac(dot(Position.xy, 0.5)) * 2.0;
    float BlackChecker = 1.0 - RedChecker;
    const float MaxLevel = 6.5;
    float4 OpticalFlow;
    float2 Smoothness;
    float2 Value;

    [unroll] for(float Level = MaxLevel; Level > 0.0; Level--)
    {
        const float Lambda = ldexp(_Constraint * 1e-5, Level - MaxLevel);

        // .xy = Normalized Red Channel (x, y)
        // .zw = Normalized Green Channel (x, y)
        float4 SampleIxy = tex2Dlod(_SampleData1, float4(TexCoord, 0.0, Level)).xyzw;
        float4 RedIxy = SampleIxy * RedChecker;
        float4 BlackIxy = SampleIxy * BlackChecker;

        // .xy = Current frame (r, g)
        // .zw = Previous frame (r, g)
        float4 SampleFrames;
        SampleFrames.xy = tex2Dlod(_SampleData0, float4(TexCoord, 0.0, Level)).rg;
        SampleFrames.zw = tex2Dlod(_SampleData2, float4(TexCoord, 0.0, Level)).rg;
        float2 RedIz = (SampleFrames.xy - SampleFrames.zw) * RedChecker;
        float2 BlackIz = (SampleFrames.xy - SampleFrames.zw) * BlackChecker;

        Value.r = dot(RedIxy.xy, OpticalFlow.xy) + RedIz.r;
        Value.g = dot(RedIxy.zw, OpticalFlow.zw) + RedIz.g;
        Smoothness.r = dot(RedIxy.xy, RedIxy.xy) + Lambda;
        Smoothness.g = dot(RedIxy.zw, RedIxy.zw) + Lambda;
        OpticalFlow -= (RedIxy.xyzw * (Value.rrgg / Smoothness.rrgg));

        Value.r = dot(BlackIxy.xy, OpticalFlow.xy) + BlackIz.r;
        Value.g = dot(BlackIxy.zw, OpticalFlow.zw) + BlackIz.g;
        Smoothness.r = dot(BlackIxy.xy, BlackIxy.xy) + Lambda;
        Smoothness.g = dot(BlackIxy.zw, BlackIxy.zw) + Lambda;
        OpticalFlow -= (BlackIxy.xyzw * (Value.rrgg / Smoothness.rrgg));
    }

    OutputColor0.xy = OpticalFlow.xy + OpticalFlow.zw;
    OutputColor0.ba = _Blend;
}

void HorizontalBlurPS1(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleOpticalFlow, TexCoord, Offsets);
}

void VerticalBlurPS1(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offsets[7] : TEXCOORD1, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleData1, TexCoord, Offsets);
}

void VelocityShadingPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_Target)
{
    float2 Velocity = tex2Dlod(_SampleData2, float4(TexCoord, 0.0, _Detail)).xy;
    float VelocityLength = saturate(rsqrt(dot(Velocity, Velocity)));
    OutputColor0.rg = (Velocity * VelocityLength) * 0.5 + 0.5;
    OutputColor0.b = -dot(OutputColor0.rg, 1.0) * 0.5 + 1.0;
    OutputColor0.a = 1.0;
}

void VelocityStreamsPS(float4 Position : SV_POSITION, float2 Velocity : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float Length = length(Velocity) * VELOCITY_SCALE * 0.05;
    OutputColor0.rg = (Velocity.xy / Length) * 0.5 + 0.5;
    OutputColor0.b = -dot(OutputColor0.rg, 1.0) * 0.5 + 1.0;
    OutputColor0.a = 1.0;
}

technique cOpticalFlow
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = CopyPS;
        RenderTarget0 = _RenderData2_HS;
    }

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
    }

    pass
    {
        VertexShader = VerticalBlurVS;
        PixelShader = VerticalBlurPS0;
        RenderTarget0 = _RenderData0_HS;
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
        RenderTarget0 = _RenderData1_HS;
    }

    pass
    {
        VertexShader = VerticalBlurVS;
        PixelShader = VerticalBlurPS1;
        RenderTarget0 = _RenderData2_HS;
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
        }
    #endif
}
