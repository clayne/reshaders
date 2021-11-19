
/*
    Ping-Pong gaussian blur shader, for BlueSkyDefender

    Why is this method called ping-ponging?
        Answer: https://diplomacy.state.gov/u-s-diplomacy-stories/ping-pong-diplomacy/
                The game of ping-pong involves two players hitting a ball back-and-forth

        We can apply this logic to shader programming by setting up
            1. The 2 players (textures)
                - One texture will be the hitter (texture we sample from), the other the receiver (texture we write to)
                - The roles for both textures will switch at each pass
            2. The ball (the texels in the pixel shader)
            3. The way the player hits the ball (PixelShader)

    This shader's technique is an example of the 2 steps above
        Pregame: Set up 2 players (_RenderBufferA and _RenderBufferB)
        PingPong1: _RenderBufferA hits (HorizontalBlurPS0) to _RenderBufferB
        PingPong2: _RenderBufferB hits (VerticalBlurPS0) to _RenderBufferA
        PingPong3: _RenderBufferA hits (HorizontalBlurPS1) to _RenderBufferB
        PingPong4: _RenderBufferB hits (VerticalBlurPS1) to _RenderBufferA

    "Why two textures? Can't we just read and write to one texture"?
        Unfortunately we cannot sample from and to memory at the same time

    NOTES
        Be cautious when pingponging in shaders that use BlendOps or involve temporal accumulation.
        Therefore, I recommend you to enable ClearRenderTargets as a sanity check.
        In addition, you may need to use use RenderTargetWriteMask if you're pingponging using textures that stores
        components that do not need pingponging (see my motion shaders as an example of this)
*/

uniform int _Radius <
    ui_min = 1;
    ui_type = "drag";
> = 1;

#ifndef ENABLE_PINGPONG
    #define ENABLE_PINGPONG 1
#endif

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

texture2D _RenderBufferA
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RGBA8;
};

sampler2D _SampleBufferA
{
    Texture = _RenderBufferA;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

texture2D _RenderBufferB
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RGBA8;
};

sampler2D _SampleBufferB
{
    Texture = _RenderBufferB;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [ Pixel Shaders ] */

float4 GaussianBlur(sampler2D Source, float2 TexCoord, const float2 Direction)
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
    OutputColor0 = GaussianBlur(_SampleBufferA, TexCoord, float2(1.0, 0.0));
}

void VerticalBlurPS0(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleBufferB, TexCoord, float2(0.0, 1.0));
}

void HorizontalBlurPS1(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleBufferA, TexCoord, float2(1.0, 0.0));
}

void VerticalBlurPS1(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = GaussianBlur(_SampleBufferB, TexCoord, float2(0.0, 1.0));
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
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }

    pass PingPong1
    {
        VertexShader = PostProcessVS;
        PixelShader = HorizontalBlurPS0;
        RenderTarget0 = _RenderBufferB;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }

    pass PingPong2
    {
        VertexShader = PostProcessVS;
        PixelShader = VerticalBlurPS0;
        RenderTarget0 = _RenderBufferA;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }

    #if ENABLE_PINGPONG
        pass PingPong3
        {
            VertexShader = PostProcessVS;
            PixelShader = HorizontalBlurPS1;
            RenderTarget0 = _RenderBufferB;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }


        pass PingPong4
        {
            VertexShader = PostProcessVS;
            PixelShader = VerticalBlurPS1;
            RenderTarget0 = _RenderBufferA;
            #if BUFFER_COLOR_BIT_DEPTH == 8
                SRGBWriteEnable = TRUE;
            #endif
        }
    #endif

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = OutputPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
