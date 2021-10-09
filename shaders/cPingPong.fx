
/*
    Ping-Pong gaussian blur shader, for BlueSkyDefender
*/

uniform int _Radius <
    ui_min = 0.0;
    ui_type = "drag";
> = 1.0;

texture2D _RenderColor : COLOR;

texture2D _RenderBufferA
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RGBA8;
};

texture2D _RenderBufferB
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RGBA8;
};

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

sampler2D _SampleBufferA
{
    Texture = _RenderBufferA;
    SRGBTexture = TRUE;
};

sampler2D _SampleBufferB
{
    Texture = _RenderBufferB;
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

float4 Blur1D(sampler2D Source, float2 TexCoord, const float2 Direction)
{
    float4 Output;
    const float2 PixelSize = (1.0 / float2(BUFFER_WIDTH / 2, BUFFER_HEIGHT / 2)) * Direction;
    const float Weight = 1.0 / _Radius;

    for(float Index = -_Radius + 0.5; Index <= _Radius; Index += 2.0)
    {
        Output += tex2Dlod(Source, float4(TexCoord + Index * PixelSize, 0.0, 0.0)) * Weight;
    }

    return Output;
}

void BlitPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleColor, TexCoord);
}

void HorizontalBlurPS0(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = Blur1D(_SampleBufferA, TexCoord, float2(1.0, 0.0));
}

void VerticalBlurPS0(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = Blur1D(_SampleBufferB, TexCoord, float2(0.0, 1.0));
}

void HorizontalBlurPS1(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = Blur1D(_SampleBufferA, TexCoord, float2(1.0, 0.0));
}

void VerticalBlurPS1(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = Blur1D(_SampleBufferB, TexCoord, float2(0.0, 1.0));
}

void OutputPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleBufferA, TexCoord);
}

technique cPingPong
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS;
        RenderTarget0 = _RenderBufferA;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = HorizontalBlurPS0;
        RenderTarget0 = _RenderBufferB;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = VerticalBlurPS0;
        RenderTarget0 = _RenderBufferA;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = HorizontalBlurPS1;
        RenderTarget0 = _RenderBufferB;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = VerticalBlurPS1;
        RenderTarget0 = _RenderBufferA;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OutputPS;
        SRGBWriteEnable = TRUE;
    }
}
