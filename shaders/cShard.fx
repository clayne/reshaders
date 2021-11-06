
// Simple, crispy unsharp shader

uniform float _Weight <
    ui_type = "drag";
> = 1.0;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

/* [Vertex Shaders] */

void ShardVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0, inout float4 Offset : TEXCOORD1)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    const float2 pSize = 0.5 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    Offset = TexCoord.xyxy + float4(-pSize, pSize);
}

/* [ Pixel Shaders ] */

void ShardPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, float4 Offset : TEXCOORD1, out float4 OutputColor0 : SV_TARGET0)
{
    float4 OriginalSample = tex2D(_SampleColor, TexCoord);
    float4 BlurSample;
    BlurSample += tex2D(_SampleColor, Offset.xw) * 0.25;
    BlurSample += tex2D(_SampleColor, Offset.zw) * 0.25;
    BlurSample += tex2D(_SampleColor, Offset.xy) * 0.25;
    BlurSample += tex2D(_SampleColor, Offset.zy) * 0.25;
    OutputColor0 = OriginalSample + (OriginalSample - BlurSample) * _Weight;
}

technique cShard
{
    pass
    {
        VertexShader = ShardVS;
        PixelShader = ShardPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
