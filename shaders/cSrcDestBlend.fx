
texture2D _RenderColor : COLOR;

texture2D _RenderFrame
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA8;
};

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

sampler2D _SampleFrame
{
    Texture = _RenderFrame;
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

void BlendPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float4 src = tex2D(_SampleFrame, TexCoord);
    float4 dest = tex2D(_SampleColor, TexCoord);
    OutputColor0 = (src + dest);
}

technique cCopyBuffer
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS;
        RenderTarget0 = _RenderFrame;
        SRGBWriteEnable = TRUE;
    }
}

technique cBlendBuffer
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlendPS;
        SRGBWriteEnable = TRUE;
    }
}
