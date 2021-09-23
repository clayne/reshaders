
uniform float kScale <
    ui_label = "Scale";
    ui_type = "drag";
    ui_step = 0.1;
> = 100.0;

uniform float2 kCenter <
    ui_label = "Center";
    ui_type = "drag";
    ui_step = 0.001;
> = float2(0.0, 0.0);

texture2D r_color : COLOR;

sampler2D s_color
{
    Texture = r_color;
    AddressU = MIRROR;
    AddressV = MIRROR;
    SRGBTexture = TRUE;
};

struct v2f
{
    float4 vpos : SV_POSITION;
    float2 uv : TEXCOORD0;
};

void vsinit(in uint id,
            inout float2 uv,
            inout float4 vpos)
{
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

v2f vs_tile(in uint id : SV_VertexID)
{
    v2f output;
    float2 coord;
    vsinit(id, coord, output.vpos);
    const float2 screensize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);

    output.uv -= 0.5;
    output.uv += coord + float2(kCenter.x, -kCenter.y);
    float2 s = output.uv * screensize * (kScale * 0.01);
    output.uv = floor(s) / screensize;
    output.uv += 0.5;
    return output;
}

void ps_tile(v2f input, out float3 c : SV_Target0)
{
    c = tex2D(s_color, input.uv).rgb;
}

technique Tile
{
    pass
    {
        VertexShader = vs_tile;
        PixelShader = ps_tile;
        SRGBWriteEnable = TRUE;
    }
}
