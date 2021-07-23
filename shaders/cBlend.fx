
/*
    Frame blending without blendops
*/

uniform float uBlend <
    ui_label = "Blend Factor"; ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
> = 0.5;

#define size float2(BUFFER_WIDTH, BUFFER_HEIGHT)

texture2D r_color  : COLOR;
texture2D r_previous { Width = size.x; Height = size.y; };

sampler2D s_color    { Texture = r_color;    SRGBTexture = TRUE; };
sampler2D s_previous { Texture = r_previous; SRGBTexture = TRUE; };

/* [Vertex Shaders] */

void v2f_core(  in uint id,
                inout float2 uv,
                inout float4 vpos)
{
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

void vs_common( in uint id : SV_VERTEXID,
                inout float4 vpos : SV_POSITION,
                inout float2 uv : TEXCOORD0)
{
    v2f_core(id, uv, vpos);
}

/* [Pixel Shaders] */

float4 ps_blend(float4 vpos : SV_POSITION, float2 uv: TEXCOORD0) : SV_TARGET
{
    float4 cframe = tex2D(s_color, uv);
    float4 pframe = tex2D(s_previous, uv);
    return lerp(cframe, pframe, uBlend);
}

float4 ps_previous(float4 vpos : SV_POSITION, float2 uv: TEXCOORD0) : SV_TARGET
{
    return tex2D(s_color, uv);
}

technique cBlending
{
    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_blend;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = vs_common;
        PixelShader = ps_previous;
        RenderTarget = r_previous;
        SRGBWriteEnable = TRUE;
    }
}
