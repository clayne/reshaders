
texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    SRGBTexture = TRUE;
};

texture2D _RenderMipMaps
{
    Width = BUFFER_WIDTH / 2;
    Height = BUFFER_HEIGHT / 2;
    Format = RGBA8;
    MipLevels = 3;
};

sampler2D _SampleMipMaps
{
    Texture = _RenderMipMaps;
    SRGBTexture = TRUE;
};

texture2D _RenderImage
{
    Width = BUFFER_WIDTH / 16;
    Height = BUFFER_HEIGHT / 16;
    Format = RGBA8;
};

sampler2D _SampleImage
{
    Texture = _RenderImage;
    SRGBTexture = TRUE;
};

/* [Vertex Shaders] */

void PostProcessVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/* [Pixel Shaders] */

float MipLODLevel(float2 TexCoord, float2 InputSize, float Bias)
{
    float2 PixelIndex = TexCoord * InputSize;
    float2 Ix = ddx(PixelIndex);
    float2 Iy = ddy(PixelIndex);
    float Product = max(dot(Ix, Ix), dot(Iy, Iy));
    return max(log2(Product) * 0.5 + Bias, 0.0);
}

// Function inspired by http://web.cse.ohio-state.edu/~crawfis.3/cse781/Readings/MipMapLevels-Blog.html
float MipLODLevel3(float2 InputSize, float2 OutputSize, float Bias)
{
    float InputPixels = InputSize.x * InputSize.y;
    float OutputPixels = OutputSize.x * OutputSize.y;
    float MipLevel = (log2(InputPixels / OutputPixels) * 0.5);
    return max(MipLevel + Bias, 0.0);
}

void BlitPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleColor, TexCoord);
}

void MipLevelPS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    float2 InputSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT) / 2.0;
    float2 InputSize2 = float2(BUFFER_WIDTH, BUFFER_HEIGHT) / 16.0;
    float MipLevel = MipLODLevel(TexCoord, InputSize, 0.0);
    float MipLevel1 = MipLODLevel3(InputSize, InputSize2, 0.0);
    OutputColor0 = tex2Dlod(_SampleMipMaps, float4(TexCoord, 0.0, MipLevel));
    //OutputColor0 = tex2D(_SampleMipMaps, TexCoord);
}

void ImagePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleImage, TexCoord);
}

technique cMipLevels
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = BlitPS;
        RenderTarget0 = _RenderMipMaps;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = MipLevelPS;
        RenderTarget0 = _RenderImage;
        SRGBWriteEnable = TRUE;
    }

    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = ImagePS;
        SRGBWriteEnable = TRUE;
    }
}
