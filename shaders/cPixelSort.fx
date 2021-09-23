
texture2D r_color : COLOR;

texture2D r_pcolor
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA8;
};

sampler2D s_color
{
    Texture = r_color;
    SRGBTexture = TRUE;
};

sampler2D s_pcolor
{
    Texture = r_color;
    SRGBTexture = TRUE;
};

void vs_generic(in uint id : SV_VERTEXID,
                out float4 position : SV_POSITION,
                out float2 texcoord : TEXCOORD)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}
