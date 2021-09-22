
// Simple, crispy unsharp shader

uniform float uWeight <
    ui_type = "drag";
> = 8.0;

uniform bool uDebug <
    ui_type = "radio";
> = true;

texture2D r_color : COLOR;

sampler2D s_color
{
    Texture = r_color;
    SRGBTexture = TRUE;
};

/* [Vertex Shaders] */

void vs_generic(in uint id : SV_VERTEXID,
                out float4 position : SV_POSITION,
                out float2 texcoord : TEXCOORD)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [ Pixel Shaders ] */

float4 ps_shard(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET
{
    const float2 pSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float4 uOriginal = tex2D(s_color, uv);
    float4 uBlur;
    uBlur += tex2D(s_color, uv + float2(-0.5, +0.5) * pSize) * 0.25;
    uBlur += tex2D(s_color, uv + float2(+0.5, +0.5) * pSize) * 0.25;
    uBlur += tex2D(s_color, uv + float2(-0.5, -0.5) * pSize) * 0.25;
    uBlur += tex2D(s_color, uv + float2(+0.5, -0.5) * pSize) * 0.25;
	float4 uOutput = uOriginal + (uOriginal - uBlur) * uWeight;
	return (uDebug) ? (uOriginal - uBlur) * uWeight * 0.5 + 0.5 : uOutput;
}

technique cShard
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_shard;
        SRGBWriteEnable = TRUE;
    }
}
