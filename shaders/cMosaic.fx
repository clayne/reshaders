
uniform int2 _Radius <
    ui_type = "drag";
    ui_label = "Mosaic Radius";
> = 32.0;

uniform int _Shape <
    ui_type = "slider";
    ui_label = "Mosaic Shape";
    ui_max = 2;
> = 0;

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

#define RMIPS LOG2(RMAX(BUFFER_WIDTH, BUFFER_HEIGHT)) + 1

texture2D _RenderColor : COLOR;

texture2D _RenderMosaicLOD < pooled = false; >
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    MipLevels = RMIPS;
    Format = RGBA8;
};

sampler2D _SampleColor
{
    Texture = _RenderColor;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = TRUE;
};

sampler2D _SampleMosaicLOD
{
    Texture = _RenderMosaicLOD;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = TRUE;
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

void BlitPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleColor, TexCoord);
}

void MosaicPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float2 FragCoord = TexCoord * float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    const float2 ScreenSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float2 PixelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    float2 BlockCoord, MosaicCoord;
    float MaxRadius = max(_Radius.x, _Radius.y);

    [branch] switch(_Shape)
    {
        // Circle https://www.shadertoy.com/view/4d2SWy
        case 0:
            BlockCoord = floor(FragCoord / MaxRadius) * MaxRadius;
            MosaicCoord = BlockCoord * PixelSize;
            float4 Color = tex2Dlod(_SampleMosaicLOD, float4(MosaicCoord, 0.0, log2(MaxRadius) - 1.0));

            float2 Offset = FragCoord - BlockCoord;
            float2 Center = MaxRadius / 2.0;
            float Length = distance(Center, Offset);
            float Circle = 1.0 - smoothstep(-2.0 , 0.0, Length - Center.x);
            OutputColor0 = Color * Circle;
            break;
        // Triangle https://www.shadertoy.com/view/4d2SWy
        case 1:
        	const float MaxLODLevel = log2(max(BUFFER_WIDTH, BUFFER_HEIGHT)) - log2(MaxRadius);
            const float2 Divisor = 1.0 / (2.0 * _Radius);
            BlockCoord = floor(TexCoord * _Radius) / _Radius;
            TexCoord -= BlockCoord;
            TexCoord *= _Radius;
            float2 Composite;
            Composite.x = step(1.0 - TexCoord.y, TexCoord.x);
            Composite.y = step(TexCoord.x, TexCoord.y);
            OutputColor0 = tex2Dlod(_SampleMosaicLOD, float4(BlockCoord + Composite * Divisor, 0.0, MaxLODLevel - 1));
            break;
        default:
            BlockCoord = round(FragCoord / MaxRadius) * MaxRadius;
            MosaicCoord = BlockCoord * PixelSize;
            OutputColor0 = tex2Dlod(_SampleMosaicLOD, float4(MosaicCoord, 0.0, log2(MaxRadius) - 1.0));
            break;
    }
}

technique cMosaic
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS;
        RenderTarget0 = _RenderMosaicLOD;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = MosaicPS;
        SRGBWriteEnable = TRUE;
    }
}
