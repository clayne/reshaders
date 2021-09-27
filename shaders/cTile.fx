
uniform float _Scale <
    ui_label = "Scale";
    ui_type = "drag";
    ui_step = 0.1;
> = 100.0;

uniform float2 _Center <
    ui_label = "Center";
    ui_type = "drag";
    ui_step = 0.001;
> = float2(0.0, 0.0);

texture2D _RenderColor : COLOR;

sampler2D _SampleColor
{
    Texture = _RenderColor;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = TRUE;
};

void TileVS(in uint ID : SV_VERTEXID, inout float4 Position : SV_POSITION, inout float2 TexCoord : TEXCOORD0)
{
    TexCoord.x = (ID == 2) ? 2.0 : 0.0;
    TexCoord.y = (ID == 1) ? 2.0 : 0.0;
    Position = float4(TexCoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

    const float2 screensize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    TexCoord -= 0.5;
    TexCoord += TexCoord + float2(_Center.x, -_Center.y);
    float2 Scaling = TexCoord * screensize * (_Scale * 0.01);
    TexCoord = floor(Scaling) / screensize;
    TexCoord += 0.5;
}

void TilePS(float4 Position : SV_POSITION, float2 TexCoord : TEXCOORD0, out float4 OutputColor0 : SV_TARGET0)
{
    OutputColor0 = tex2D(_SampleColor, TexCoord);
}

technique Tile
{
    pass
    {
        VertexShader = TileVS;
        PixelShader = TilePS;
        SRGBWriteEnable = TRUE;
    }
}
