
/*
    Frame blending without blendops
*/

uniform float _Blend <
    ui_label = "Blend Factor";
    ui_type = "slider";
    ui_min = 0.0;
    ui_max = 1.0;
> = 0.5;

texture2D _RenderColor : COLOR;

texture2D _RenderCopy
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
};

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

sampler2D _SampleCopy
{
    Texture = _RenderCopy;
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

// Execute the blending first (the pframe will initially be 0)

void BlendPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float4 CurrentFrame = tex2D(_SampleColor, TexCoord);
    float4 PreviousFrame = tex2D(_SampleCopy, TexCoord);
    OutputColor0 = lerp(CurrentFrame, PreviousFrame, _Blend);
}

// Save the results generated from ps_blend() into a texture to use later

void CopyPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleColor, TexCoord);
}

technique cBlending
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlendPS;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = CopyPS;
        RenderTarget = _RenderCopy;
        SRGBWriteEnable = TRUE;
    }
}
