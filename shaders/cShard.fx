
// Simple, crispy unsharp shader

uniform float _Weight <
    ui_type = "drag";
> = 8.0;

uniform bool _Debug <
    ui_type = "radio";
> = true;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [ Pixel Shaders ] */

float4 ShardPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0) : SV_TARGET
{
    const float2 pSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float4 uOriginal = tex2D(_SampleColor, TexCoord);
    float4 uBlur;
    uBlur += tex2D(_SampleColor, TexCoord + float2(-0.5, +0.5) * pSize) * 0.25;
    uBlur += tex2D(_SampleColor, TexCoord + float2(+0.5, +0.5) * pSize) * 0.25;
    uBlur += tex2D(_SampleColor, TexCoord + float2(-0.5, -0.5) * pSize) * 0.25;
    uBlur += tex2D(_SampleColor, TexCoord + float2(+0.5, -0.5) * pSize) * 0.25;
    float4 uOutput = uOriginal + (uOriginal - uBlur) * _Weight;
    return (_Debug) ? (uOriginal - uBlur) * _Weight * 0.5 + 0.5 : uOutput;
}

technique cShard
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ShardPS;
        SRGBWriteEnable = TRUE;
    }
}
