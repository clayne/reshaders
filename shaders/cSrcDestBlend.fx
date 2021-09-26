
texture2D r_color : COLOR;

texture2D r_blit
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA8;
};

sampler2D s_color
{
    Texture = r_color;
};

sampler2D s_blit
{
    Texture = r_blit;
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

/* [Pixel Shaders] */

void ps_blit(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0, out float4 r0 : SV_TARGET0)
{
    r0 = tex2D(s_color, uv);
}

void ps_blend(float4 vpos : SV_POSITION, float2 uv : TEXCOORD0, out float4 r0 : SV_TARGET0)
{
    float4 src = tex2D(s_blit, uv);
    float4 dest = tex2D(s_color, uv);
    r0 = (src + dest);
}

technique CopyBuffer
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_blit;
        RenderTarget0 = r_blit;
    }
}

technique BlendBuffer
{
    pass
    {
        VertexShader = vs_generic;
        PixelShader = ps_blend;
        SRGBWriteEnable = TRUE;
    }
}
