
/*
    Ping-Pong gaussian blur shader, for BlueSkyDefender

    Why is this method called ping-ponging?
        Answer: https://diplomacy.state.gov/u-s-diplomacy-stories/ping-pong-diplomacy/
                The game of ping-pong involves two players hitting a ball back-and-forth

        We can apply this logic to shader programming by setting up:
            1.  The 2 players (textures)
                - One texture will be the hitter (texture we sample from), the other the receiver (texture we write to)
                - The roles for both textures will switch at each pass
            2. The ball (Pixel shader)

    This shader's technique is an example of the 2 steps above:
        Prelude1: Set up the players (_RenderBufferA and _RenderBufferB)
        StartGame: Simply copy the texture to a downscaled buffer (no blur here for performance reasons)
        PingPong1: _RenderBufferA hits (HorizontalBlurPS0) to _RenderBufferB
        PingPong2: _RenderBufferB hits (VerticalBlurPS0) to _RenderBufferA
        PingPong3: _RenderBufferA hits (HorizontalBlurPS1) to _RenderBufferB
        PingPong4: _RenderBufferB hits (VerticalBlurPS1) to _RenderBufferA
        Endgame: Display the texture to properly interpolate the downsampled texels;

    "Why two textures? Can't we just read and write to one texture"?
        Unfortunately GPUs do not work that way. We cannot sample from and write to memory at the same time

    NOTE:
        Be cautious when pingponging in shaders that use BlendOps or involve temporal accumulation.
        Therefore, I recommend you to enable ClearRenderTargets as a sanity check.
        In addition, you may need to use use RenderTargetWriteMask if you're pingponging using textures that stores
        components that do not need pingponging (see my motion shaders as an example of this)
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
    pass StartGame
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS;
        RenderTarget0 = _RenderBufferA;
        SRGBWriteEnable = TRUE;
    }

    pass PingPong1
    {
        VertexShader = PostProcessVS;
        PixelShader = HorizontalBlurPS0;
        RenderTarget0 = _RenderBufferB;
        SRGBWriteEnable = TRUE;
    }

    pass PingPong2
    {
        VertexShader = PostProcessVS;
        PixelShader = VerticalBlurPS0;
        RenderTarget0 = _RenderBufferA;
        SRGBWriteEnable = TRUE;
    }

    pass PingPong3
    {
        VertexShader = PostProcessVS;
        PixelShader = HorizontalBlurPS1;
        RenderTarget0 = _RenderBufferB;
        SRGBWriteEnable = TRUE;
    }

    pass PingPong4
    {
        VertexShader = PostProcessVS;
        PixelShader = VerticalBlurPS1;
        RenderTarget0 = _RenderBufferA;
        SRGBWriteEnable = TRUE;
    }

    pass Endgame
    {
        VertexShader = PostProcessVS;
        PixelShader = OutputPS;
        SRGBWriteEnable = TRUE;
    }
}
