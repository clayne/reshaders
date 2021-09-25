
uniform float2 uRadius <
    ui_type = "drag";
    ui_label = "Mosaic Radius";
> = 16.0;

uniform int uShape <
    ui_type = "slider";
    ui_label = "Mosaic Shape";
    ui_max = 2;
> = 0;

texture2D r_color : COLOR;

sampler2D s_color
{
    Texture = r_color;
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

float4 ps_mosaic(float4 vpos : SV_POSITION,
                 float2 uv : TEXCOORD0) : SV_Target0
{
    float2 gFragCoord = uv * float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float2 gPixelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    float2 mCoord, gCoord;
    float2 gRadius;

    [branch] switch(uShape)
    {
        // Circle https://www.shadertoy.com/view/4d2SWy
        case 0:
            gRadius = max(uRadius.x, uRadius.y);
            mCoord = floor(gFragCoord / gRadius) * gRadius;
            gCoord = mCoord * gPixelSize;
            float4 c0 = tex2Dlod(s_color, float4(gCoord, 0.0, 0.0));

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
            return tex2Dlod(s_color, float4(mCoord + gComposite, 0.0, 0.0));
        default:
            mCoord = round(gFragCoord / uRadius) * uRadius;
            gCoord = mCoord * gPixelSize;
            return tex2Dlod(s_color, float4(gCoord, 0.0, 0.0));
    }
}

technique cMosaic
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_mosaic;
        SRGBWriteEnable = TRUE;
    }
}
