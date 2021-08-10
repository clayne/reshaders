
#include "cFunctions.fxh"

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
    #if BUFFER_COLOR_BIT_DEPTH != 10
        SRGBTexture = true;
    #endif
};

struct v2f { float4 vpos : SV_POSITION; float2 uv : TEXCOORD0; };

v2f vs_tile(in uint id : SV_VertexID)
{
    v2f output;
    float2 coord;
    core::vsinit(id, coord, output.vpos);

    output.uv -= 0.5;
    output.uv += coord + float2(kCenter.x, -kCenter.y);
    float2 s = output.uv * core::getscreensize() * (kScale * 0.01);
    output.uv = floor(s) / core::getscreensize();
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
        #if BUFFER_COLOR_BIT_DEPTH != 10
            SRGBWriteEnable = true;
        #endif
    }
}
