
/*
    Frame blending through BlendOps
*/

uniform float _BlendFactor <
    ui_label = "Blend Factor";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    #if BUFFER_COLOR_BIT_DEPTH == 8
        SRGBTexture = TRUE;
    #endif
};

texture2D _RenderCopy
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
};

sampler2D _SampleCopy
{
    Texture = _RenderCopy;
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

/* [Pixel Shaders] */

void BlendPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    // Copy backbuffer to a that continuously blends with its previous result 
    OutputColor0 = float4(tex2D(_SampleColor, TexCoord).rgb, _BlendFactor);
}

void DisplayPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    // Display the buffer
    OutputColor0 = tex2D(_SampleCopy, TexCoord);
}

technique cFrameBlending
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlendPS;
        RenderTarget0 = _RenderCopy;
        ClearRenderTargets = FALSE;
        BlendEnable = TRUE;
        BlendOp = ADD;
        SrcBlend = INVSRCALPHA;
        DestBlend = SRCALPHA;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = DisplayPS;
        #if BUFFER_COLOR_BIT_DEPTH == 8
            SRGBWriteEnable = TRUE;
        #endif
    }
}
