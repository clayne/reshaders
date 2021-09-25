
uniform int2 uRadius <
    ui_type = "drag";
    ui_label = "Mosaic Radius";
> = 16.0;

uniform int uShape <
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

texture2D r_color : COLOR;

texture2D r_lods
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    MipLevels = RMIPS;
    Format = RGBA8;
};

sampler2D s_color
{
    Texture = r_color;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = TRUE;
};

sampler2D s_lods
{
    Texture = r_lods;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = TRUE;
};

/* [Vertex Shaders] */

void vs_generic(in uint id : SV_VERTEXID,
                inout float4 position : SV_POSITION,
                inout float2 texcoord : TEXCOORD0)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

float4 ps_blit(float4 vpos : SV_POSITION,
               float2 uv : TEXCOORD0) : SV_Target0
{
    return tex2D(s_color, uv);
}

float4 ps_mosaic(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_Target0
{
    float2 gFragCoord = uv * float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float2 gPixelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    float2 mCoord, gCoord;
    float gRadius = max(uRadius.x, uRadius.y);

    [branch] switch(uShape)
    {
        // Circle https://www.shadertoy.com/view/4d2SWy
        case 0:
            mCoord = floor(gFragCoord / gRadius) * gRadius;
            gCoord = mCoord * gPixelSize;
            float4 c0 = tex2Dlod(s_lods, float4(gCoord, 0.0, log2(gRadius) - 1.0));

            float2 gOffset = gFragCoord - mCoord;
            float2 gCenter = gRadius / 2.0;
            float gLength = distance(gCenter, gOffset);
            float gCircle = 1.0 - smoothstep(-2.0 , 0.0, gLength - gCenter.x);
            return c0 * gCircle;
        // Triangle https://www.shadertoy.com/view/4d2SWy
        case 1:
            mCoord = floor(uv * uRadius) / uRadius;
            uv -= mCoord;
            uv *= uRadius;
            float2 gComposite;
            gComposite.x = step(1.0 - uv.y, uv.x) / (2.0 * uRadius.x);
            gComposite.y = step(uv.x, uv.y) / (2.0 * uRadius.y);
            return tex2Dlod(s_lods, float4(mCoord + gComposite, 0.0, log2(gRadius) - 1.0));
        default:
            mCoord = round(gFragCoord / uRadius) * uRadius;
            gCoord = mCoord * gPixelSize;
            return tex2Dlod(s_lods, float4(gCoord, 0.0, log2(gRadius) - 1.0));
    }
}

technique cMosaic
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_blit;
        RenderTarget0 = r_lods;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_mosaic;
        SRGBWriteEnable = TRUE;
    }
}
